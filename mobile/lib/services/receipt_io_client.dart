import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

abstract interface class JoinedReceiptClient implements http.Client {
  Future<void> finish();
}

/// One attempt owns a byte-transparent TCP relay. The relay's
/// upstream socket is never upgraded/detached, so cancellation retains an actual
/// native handle throughout the client's TLS handshake. HTTP/TLS stay in SDK/http.
/// No retry, certificate override, global override, worker or protocol parser.
class ReceiptIoClient extends IOClient implements JoinedReceiptClient {
  final _ReceiptConnection _connection;

  factory ReceiptIoClient() => ReceiptIoClient._(_ReceiptConnection());

  @visibleForTesting
  factory ReceiptIoClient.forTesting({
    SecurityContext? context,
    Future<void> Function()? beforeConnect,
    Future<void> Function()? afterTcpConnect,
    Future<void> Function()? afterTeardown,
    Future<void> Function(int port)? afterRelayListen,
    Future<void> Function()? beforeLocalRegistration,
    void Function(int remotePort)? onAccept,
  }) => ReceiptIoClient._(
    _ReceiptConnection(
      context: context,
      beforeConnect: beforeConnect,
      afterTcpConnect: afterTcpConnect,
      afterTeardown: afterTeardown,
      afterRelayListen: afterRelayListen,
      beforeLocalRegistration: beforeLocalRegistration,
      onAccept: onAccept,
    ),
  );

  ReceiptIoClient._(this._connection)
    : super(
        HttpClient(context: _connection.context)
          ..findProxy = ((_) => 'DIRECT')
          ..connectionFactory = _connection.connect,
      );

  /// close() starts teardown synchronously; the attempt must also await finish().
  @override
  void close() {
    _connection.stop();
    super.close();
  }

  @override
  Future<void> finish() => _connection.finish();

  @visibleForTesting
  Map<String, int> get resourceCounts => {
    'sockets': _connection._sockets.length,
    'pendingAccepts': _connection._pendingAccepted.length,
    'acceptedEndpoints': _connection._acceptCount,
    'tasks': _connection._tasks.length,
    'pumps': _connection._pumps.length,
    'listeners': _connection._listener == null ? 0 : 1,
  };
}

class _ReceiptConnection {
  final SecurityContext? context;
  final Future<void> Function()? beforeConnect;
  final Future<void> Function()? afterTcpConnect;
  final Future<void> Function()? afterTeardown;
  final Future<void> Function(int port)? afterRelayListen;
  final Future<void> Function()? beforeLocalRegistration;
  final void Function(int remotePort)? onAccept;
  // Includes rejected endpoints: a local flood fails this attempt, never retries.
  static const _acceptBudget = 8;
  int _acceptCount = 0;
  final _pendingAccepted = <Socket>[];
  Socket? _localEndpoint;
  final _pumps = <Future<void>>[];
  final _tasks = <ConnectionTask<Socket>>[];
  final _sockets = <Socket>[];
  ServerSocket? _listener;
  StreamSubscription<Socket>? _accept;
  Completer<Socket>? _accepted;
  Future<Socket>? _opening;
  Future<void>? _finished;
  Future<void>? _acceptClosing;
  bool _stopped = false;

  _ReceiptConnection({
    this.context,
    this.beforeConnect,
    this.afterTcpConnect,
    this.afterTeardown,
    this.afterRelayListen,
    this.beforeLocalRegistration,
    this.onAccept,
  });

  Future<ConnectionTask<Socket>> connect(
    Uri uri,
    String? proxyHost,
    int? proxyPort,
  ) async {
    if (_opening != null ||
        proxyHost != null ||
        proxyPort != null ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      throw const SocketException('Receipt connection unavailable');
    }
    _check();
    final future = _opening = _open(uri);
    // Observe errors immediately even if the SDK is still attaching its handler.
    unawaited(future.then<void>((_) {}, onError: (Object _) {}));
    return ConnectionTask.fromSocket(future, stop);
  }

  void _check() {
    if (_stopped) throw const SocketException('Receipt connection closed');
  }

  Future<Socket> _tcp(Object host, int port) async {
    _check();
    final task = await Socket.startConnect(host, port);
    _tasks.add(task);
    if (_stopped) task.cancel();
    final socket = await task.socket;
    _own(socket);
    if (_stopped) socket.destroy();
    _check();
    return socket;
  }

  Future<Socket> _open(Uri uri) async {
    try {
      await beforeConnect?.call();
      _check();
      final upstream = await _tcp(uri.host, uri.port);
      await afterTcpConnect?.call();
      _check();
      final listener =
          _listener = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      _check();
      final accepted = _accepted = Completer<Socket>();
      unawaited(accepted.future.then<void>((_) {}, onError: (Object _) {}));
      _accept = listener.listen(
        (socket) {
          final remotePort = socket.remotePort;
          _own(socket);
          _acceptCount++;
          if (_stopped || accepted.isCompleted) {
            socket.destroy();
          } else {
            // Accept can precede completion/registration of the local connect.
            // Keep a bounded set until its actual endpoint is known.
            _pendingAccepted.add(socket);
            _pairAccepted();
            if (!accepted.isCompleted && _acceptCount >= _acceptBudget) stop();
          }
          onAccept?.call(remotePort);
        },
        onError: (Object error, StackTrace trace) {
          if (!accepted.isCompleted) accepted.completeError(error, trace);
        },
      );
      await afterRelayListen?.call(listener.port);
      _check();
      // Initiate accept before connecting; retain both sides on every exit path.
      final local = await _tcp(InternetAddress.loopbackIPv4, listener.port);
      await beforeLocalRegistration?.call();
      _check();
      _localEndpoint = local;
      _pairAccepted();
      final relay = await accepted.future;
      await _closeAccept();
      _check();
      _pump(relay, upstream);
      _pump(upstream, relay);
      if (uri.scheme == 'http') return local;
      // Only this local endpoint is transferred. Upstream/relay keep valid handles.
      final handshake = SecureSocket.secure(
        local,
        host: uri.host,
        context: context,
      );
      // secure() takes ownership of local; its old facade is no longer a valid
      // cancellation handle. The still-valid upstream/relay terminate handoff.
      _sockets.remove(local);
      _localEndpoint = null;
      final secure = await handshake;
      _own(secure);
      if (_stopped) secure.destroy();
      _check();
      return secure;
    } catch (_) {
      stop();
      rethrow;
    }
  }

  void _pairAccepted() {
    final local = _localEndpoint;
    final accepted = _accepted!;
    if (local == null || _stopped || accepted.isCompleted) return;
    for (final socket in _pendingAccepted) {
      if (!accepted.isCompleted &&
          socket.remotePort == local.port &&
          socket.remoteAddress.address == local.address.address &&
          socket.port == local.remotePort &&
          socket.address.address == local.remoteAddress.address) {
        accepted.complete(socket);
        // Cancel delivery synchronously, before another endpoint can be retained.
        unawaited(_closeAccept());
      } else {
        socket.destroy();
      }
    }
    _pendingAccepted.clear();
  }

  Future<void> _closeAccept() {
    if (_acceptClosing case final closing?) return closing;
    final closing =
        _acceptClosing = Future.wait<void>([
          if (_accept case final accept?) accept.cancel(),
          if (_listener case final listener?)
            listener.close().then<void>((_) {}),
        ]).then<void>((_) {
          _listener = null;
        });
    // stop() can initiate this before _open is ready to await it.
    unawaited(closing.then<void>((_) {}, onError: (Object _) {}));
    return closing;
  }

  void _pump(Socket source, Socket target) {
    _pumps.add(
      target
          .addStream(source)
          .then<void>((_) async {
            await target.close();
          })
          .catchError((Object _) {
            // Observe close errors as well as copy errors before the final join.
            stop();
          }),
    );
  }

  void _own(Socket socket) {
    _sockets.add(socket);
    unawaited(socket.done.then<void>((_) {}, onError: (Object _) {}));
  }

  void stop() {
    _stopped = true;
    if (_listener != null) unawaited(_closeAccept());
    final accepted = _accepted;
    if (accepted != null && !accepted.isCompleted) {
      accepted.completeError(
        const SocketException('Receipt connection closed'),
      );
    }
    for (final task in _tasks) {
      task.cancel();
    }
    for (final socket in _sockets) {
      socket.destroy();
    }
  }

  Future<void> finish() => _finished ??= _join();

  Future<void> _join() async {
    stop();
    try {
      await _opening;
    } catch (_) {
      // send() owns the transport error; cleanup owns its terminal join.
    }
    stop();
    if (_listener != null || _acceptClosing != null) await _closeAccept();
    await Future.wait(_pumps);
    await Future.wait(
      _sockets.map(
        (socket) => socket.close().then<void>((_) {}, onError: (Object _) {}),
      ),
    );
    await Future.wait(
      _sockets.map(
        (socket) => socket.done.then<void>((_) {}, onError: (Object _) {}),
      ),
    );
    _pendingAccepted.clear();
    _localEndpoint = null;
    _sockets.clear();
    _tasks.clear();
    _pumps.clear();
    await afterTeardown?.call();
  }
}
