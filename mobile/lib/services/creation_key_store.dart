import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

enum CreationKeyStatus { available, absent, locked, error, unsupported }

class CreationKeyResult {
  const CreationKeyResult(this.status, [this.bytes]);
  final CreationKeyStatus status;
  final Uint8List? bytes;

  String? get canonicalKey {
    if (status != CreationKeyStatus.available || bytes?.length != 32) {
      return null;
    }
    return base64Url.encode(bytes!).replaceAll('=', '');
  }
}

/// Only the locator is durable in Drift. Never replace an attempted operation's
/// missing key: a restored database does not prove that its POST never committed.
abstract interface class CreationKeyStore {
  Future<CreationKeyResult> read(String locator);
  Future<CreationKeyResult> createIfAbsent(String locator);
}

class IOSCreationKeyStore implements CreationKeyStore {
  static const channel = MethodChannel('app.billington/receipt_creation_keys');

  Future<CreationKeyResult> _invoke(String method, String locator) async {
    if (!Platform.isIOS) {
      return const CreationKeyResult(CreationKeyStatus.unsupported);
    }
    try {
      final result = await channel.invokeMapMethod<String, dynamic>(method, {
        'locator': locator,
      });
      final status = switch (result?['status']) {
        'available' => CreationKeyStatus.available,
        'absent' => CreationKeyStatus.absent,
        'locked' => CreationKeyStatus.locked,
        _ => CreationKeyStatus.error,
      };
      final bytes = result?['bytes'];
      if (status == CreationKeyStatus.available &&
          (bytes is! Uint8List || bytes.length != 32)) {
        return const CreationKeyResult(CreationKeyStatus.error);
      }
      return CreationKeyResult(status, bytes is Uint8List ? bytes : null);
    } catch (_) {
      return const CreationKeyResult(CreationKeyStatus.error);
    }
  }

  @override
  Future<CreationKeyResult> read(String locator) => _invoke('read', locator);
  @override
  Future<CreationKeyResult> createIfAbsent(String locator) =>
      _invoke('createIfAbsent', locator);
}
