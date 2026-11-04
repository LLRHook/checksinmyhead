// Billington: Privacy-first receipt spliting
//     Copyright (C) 2025  Kruski Ko.
//     Email us: checkmateapp@duck.com

//     This program is free software: you can redistribute it and/or modify
//     it under the terms of the GNU General Public License as published by
//     the Free Software Foundation, either version 3 of the License, or
//     (at your option) any later version.

//     This program is distributed in the hope that it will be useful,
//     but WITHOUT ANY WARRANTY; without even the implied warranty of
//     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//     GNU General Public License for more details.

//     You should have received a copy of the GNU General Public License
//     along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:checks_frontend/services/receipt_io_client.dart';
import 'package:checks_frontend/services/api_config.dart';
import 'package:checks_frontend/services/receipt_parser.dart';

/// Each attempt owns its client, abort trigger, upload/body cleanup and deadline.
/// There are no implicit retries; cancel leaves this service usable for manual retry.
class ReceiptApiService {
  static const _timeout = Duration(seconds: 45);
  static const _bodyLimit = 1024 * 1024;
  final Uri _baseUrl;
  final http.Client Function() _createClient;
  final Future<http.MultipartFile> Function(String) _prepareImage;
  final Duration _operationTimeout;
  final Duration Function()? _elapsed;
  final DateTime Function() _now;
  final _operations = <_ReceiptOperation>{};
  bool _disposed = false;

  ReceiptApiService()
    : _baseUrl = Uri.parse(ApiConfig.baseUrl),
      _createClient = ReceiptIoClient.new,
      _prepareImage = _imageFromPath,
      _operationTimeout = _timeout,
      _elapsed = null,
      _now = DateTime.now;

  /// The factory transfers exclusive client ownership for each attempt. Never
  /// return a shared client. Loopback and time overrides are test-only, not a
  /// release API URL setting.
  @visibleForTesting
  ReceiptApiService.forTesting({
    required Uri baseUrl,
    required http.Client Function() createClient,
    Future<http.MultipartFile> Function(String)? prepareImage,
    Duration timeout = _timeout,
    Duration Function()? elapsed,
    DateTime Function()? now,
  }) : _baseUrl = baseUrl,
       _createClient = createClient,
       _prepareImage = prepareImage ?? _imageFromPath,
       _operationTimeout = timeout,
       _elapsed = elapsed,
       _now = now ?? DateTime.now;

  static Future<http.MultipartFile> _imageFromPath(String path) =>
      http.MultipartFile.fromPath('image', path);

  void cancel() {
    for (final operation in _operations.toList()) {
      operation.stop(ReceiptParseException.cancelled());
    }
  }

  void dispose() {
    _disposed = true;
    cancel();
  }

  Future<ParsedReceipt> parseReceipt(String imagePath) async {
    if (_disposed) throw ReceiptParseException.cancelled();
    // Starts before client/file/setup, not just before sending headers.
    final operation = _ReceiptOperation(_operationTimeout, _elapsed);
    _operations.add(operation);
    late ParsedReceipt result;
    try {
      operation.client = _createClient();
      operation.check();
      final request = http.AbortableMultipartRequest(
        'POST',
        _baseUrl.resolve('/api/receipts/parse'),
        abortTrigger: operation.abort.future,
      )..followRedirects = false;
      final image = await operation.wait(_prepareImage(imagePath));
      final upload = operation.upload = _ReceiptUpload(image);
      request.files.add(upload.file);
      operation.check();
      // Native send and upload-input cleanup have separate completion handles.
      // Join both; the transport also owns and joins TLS setup teardown.
      final response = await operation.client!.send(request);
      final bytes = await _readBody(response.stream, operation);
      operation.check();
      if (response.statusCode != 200) {
        throw _responseError(response.statusCode, response.headers, bytes);
      }
      final source = utf8.decode(bytes);
      operation.check();
      result = ParsedReceipt.decode(source);
      // Timers cannot preempt synchronous CPU work. Bound it first and check
      // monotonic elapsed time after preflight/JSON/typed validation as well.
      operation.check();
    } on ReceiptValidationException {
      operation.check();
      throw ReceiptParseException(ReceiptValidationException.message);
    } on ReceiptParseException {
      operation.check();
      rethrow;
    } on FormatException {
      operation.check();
      throw ReceiptParseException(ReceiptValidationException.message);
    } on SocketException {
      operation.check();
      throw ReceiptParseException(
        'Could not connect to server. Check your connection.',
      );
    } catch (_) {
      operation.check();
      throw ReceiptParseException(
        'Could not process the receipt. Please try again.',
      );
    } finally {
      await operation.finish();
      _operations.remove(operation);
    }
    // Cleanup itself must not turn a late result into success.
    operation.check();
    return result;
  }

  Future<Uint8List> _readBody(
    Stream<List<int>> stream,
    _ReceiptOperation operation,
  ) async {
    final iterator = StreamIterator(stream);
    final bytes = BytesBuilder(copy: false);
    try {
      while (await operation.wait(iterator.moveNext())) {
        operation.check();
        final chunk = iterator.current;
        final remaining = _bodyLimit + 1 - bytes.length;
        bytes.add(
          chunk.length > remaining ? chunk.sublist(0, remaining) : chunk,
        );
        if (bytes.length > _bodyLimit) {
          operation.stop(
            ReceiptParseException(ReceiptValidationException.message),
          );
          operation.check();
        }
      }
      return bytes.takeBytes();
    } finally {
      await iterator.cancel();
    }
  }

  ReceiptParseException _responseError(
    int status,
    Map<String, String> headers,
    Uint8List bytes,
  ) {
    Object? code;
    try {
      final source = utf8.decode(bytes);
      preflightReceiptJson(source);
      final body = jsonDecode(source);
      if (body is Map<String, dynamic>) code = body['code'];
    } on FormatException {
      // Known status fallback, never arbitrary server/provider text.
    } on ReceiptValidationException {
      // The same byte/shape limits also apply to untrusted error bodies.
    }
    final retry = _retryAfter(headers['retry-after']);
    if (status == 429) {
      return ReceiptParseException(
        'Too many scans. Please wait a moment and try again.',
        isRateLimit: true,
        retryAfterSeconds: retry,
      );
    }
    if (status == 413) {
      return ReceiptParseException(
        'Image is too large. Try a lower resolution photo.',
      );
    }
    if (status == 422) {
      return ReceiptParseException(
        code == 'invalid_request'
            ? 'Could not read this image. Try another receipt photo.'
            : 'Could not read the receipt. Try a clearer photo.',
      );
    }
    if (status == 503) {
      return ReceiptParseException(
        code == 'overloaded'
            ? 'Scanner is busy. Please wait and try again.'
            : 'Scanner is temporarily unavailable. Please try again later.',
        retryAfterSeconds: retry,
      );
    }
    if (status == 400) {
      return ReceiptParseException(
        'Could not read this image. Try another receipt photo.',
      );
    }
    return ReceiptParseException(
      'Could not process the receipt. Please try again.',
    );
  }

  int? _retryAfter(String? value) {
    if (value == null ||
        value.length > 128 ||
        utf8.encode(value).length > 128) {
      return null;
    }
    final input = value.trim();
    if (RegExp(r'^[0-9]+$').hasMatch(input)) {
      // Arbitrarily large valid integers mean a longer wait, never a shorter one.
      final seconds = int.tryParse(input);
      if (seconds == null || seconds > 86400) return null;
      return seconds < 1 ? 1 : seconds;
    }
    try {
      final wait = HttpDate.parse(input).difference(_now().toUtc());
      if (wait > const Duration(days: 1)) return null;
      final seconds =
          (wait.inMicroseconds / Duration.microsecondsPerSecond).ceil();
      return seconds < 1 ? 1 : seconds;
    } on HttpException {
      return null;
    }
  }
}

// IOClient's socket consumer does not await upload cancellation. Keep the
// original subscription and its one cleanup future owned by the attempt, also
// when an error causes an intermediate serializer to cancel itself.
class _ReceiptUpload {
  final http.MultipartFile _source;
  late final StreamController<List<int>> _events;
  StreamSubscription<List<int>>? _input;
  Completer<void>? _starting;
  Future<void>? _cleanup;
  bool _closed = false;
  bool cleanupFailed = false;

  _ReceiptUpload(this._source) {
    _events = StreamController<List<int>>(
      sync: true,
      onListen: _startInput,
      onPause: () => _input?.pause(),
      onResume: () => _input?.resume(),
      onCancel: finish,
    );
  }

  http.MultipartFile get file => http.MultipartFile(
    _source.field,
    _events.stream,
    _source.length,
    filename: _source.filename,
    contentType: _source.contentType,
  );

  void _startInput() {
    if (_closed) {
      _closeEvents();
      return;
    }
    final starting = _starting = Completer<void>();
    try {
      _input = _source.finalize().listen(
        (chunk) {
          if (!_closed) _events.add(chunk);
        },
        onError: (Object error, StackTrace trace) {
          if (!_closed) _events.addError(error, trace);
        },
        onDone: _closeEvents,
        // Retain this subscription until our own cancellation has been joined.
        // Automatic cancellation on error could discard its cleanup future.
        cancelOnError: false,
      );
    } catch (error, trace) {
      if (!_closed) _events.addError(error, trace);
      _closeEvents();
    } finally {
      starting.complete();
    }
  }

  void _closeEvents() {
    if (!_events.isClosed) unawaited(_events.close());
  }

  Future<void> finish() {
    _closed = true;
    return _cleanup ??= _cancelInput();
  }

  Future<void> _cancelInput() async {
    try {
      // A custom source can cancel reentrantly during listen. Do not lose the
      // subscription that will be returned when that synchronous call unwinds.
      await _starting?.future;
      await _input?.cancel();
    } catch (_) {
      cleanupFailed = true;
    } finally {
      _closeEvents();
    }
  }
}

class _ReceiptOperation {
  final Duration timeout;
  final Duration Function()? _elapsed;
  final _watch = Stopwatch()..start();
  final abort = Completer<void>();
  final _stopped = Completer<ReceiptParseException>();
  late final Timer _timer;
  http.Client? client;
  _ReceiptUpload? upload;
  ReceiptParseException? _failure;
  bool _closed = false;

  _ReceiptOperation(this.timeout, this._elapsed) {
    _timer = Timer(timeout, () => stop(ReceiptParseException.timedOut()));
  }

  void check() {
    if (_failure == null && (_elapsed?.call() ?? _watch.elapsed) >= timeout) {
      stop(ReceiptParseException.timedOut());
    }
    if (_failure != null) throw _failure!;
  }

  Future<T> wait<T>(Future<T> future) async {
    final value = await Future.any<T>([
      future,
      _stopped.future.then<T>((error) => throw error),
    ]);
    check();
    return value;
  }

  void stop(ReceiptParseException error) {
    if (_failure != null) return;
    _failure = error;
    if (!_stopped.isCompleted) _stopped.complete(error);
    _close();
    // Start source cancellation now, even if native send/TLS is still pending.
    // finish() below always joins this same observed, non-throwing future.
    unawaited(upload?.finish() ?? Future<void>.value());
  }

  void _close() {
    if (!abort.isCompleted) abort.complete();
    if (!_closed) {
      _closed = true;
      client?.close(); // IOClient uses HttpClient.close(force: true).
    }
  }

  Future<void> finish() async {
    _timer.cancel();
    if (!_stopped.isCompleted) {
      _stopped.complete(ReceiptParseException.cancelled());
    }
    _close();
    if (client case JoinedReceiptClient native) await native.finish();
    await upload?.finish();
    if (upload?.cleanupFailed ?? false) {
      _failure ??= ReceiptParseException(
        'Could not finish the receipt scan. Please try again.',
      );
    }
    _watch.stop();
  }
}

/// Messages contain only finite local selections, never server/provider content.
class ReceiptParseException implements Exception {
  final String message;
  final bool isRateLimit;
  final bool isCancelled;
  final int? retryAfterSeconds;

  ReceiptParseException(
    this.message, {
    this.isRateLimit = false,
    this.isCancelled = false,
    this.retryAfterSeconds,
  });
  ReceiptParseException.cancelled()
    : this('Receipt scan cancelled.', isCancelled: true);
  ReceiptParseException.timedOut()
    : this('Request timed out. Check your connection and try again.');

  @override
  String toString() => message;
}
