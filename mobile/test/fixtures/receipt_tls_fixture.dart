import 'dart:convert';
import 'dart:io';

/// Owned synthetic localhost PKI. Regenerated per host test run (two-day validity),
/// so dated proof certificates never become a permanent expiring dependency.
/// Native app probes receive PEM bytes generated on the host, not this executable.
class ReceiptTlsFixture {
  final Directory directory;
  ReceiptTlsFixture._(this.directory);
  String get root => '${directory.path}/root.pem';
  String get cert => '${directory.path}/cert.pem';
  String get key => '${directory.path}/key.pem';

  static Future<ReceiptTlsFixture> create() async {
    final fixture = ReceiptTlsFixture._(
      await Directory.systemTemp.createTemp('receipt-synthetic-tls-'),
    );
    try {
      final tool = Platform.environment['RECEIPT_TEST_OPENSSL'] ?? 'openssl';
      Future<String> run(List<String> arguments) async {
        final result = await Process.run(
          tool,
          arguments,
          workingDirectory: fixture.directory.path,
        );
        if (result.exitCode != 0) {
          throw StateError(
            'Synthetic TLS fixture: $tool $arguments: ${result.stderr}',
          );
        }
        return result.stdout.toString();
      }

      final version = await run(['version', '-a']);
      await run([
        'req',
        '-x509',
        '-newkey',
        'rsa:2048',
        '-nodes',
        '-keyout',
        'root-key.pem',
        '-out',
        'root.pem',
        '-days',
        '2',
        '-subj',
        '/CN=Receipt SYNTHETIC Test Root',
        '-addext',
        'basicConstraints=critical,CA:TRUE',
        '-addext',
        'keyUsage=critical,keyCertSign,cRLSign',
      ]);
      await run([
        'req',
        '-newkey',
        'rsa:2048',
        '-nodes',
        '-keyout',
        'key.pem',
        '-out',
        'leaf.csr',
        '-subj',
        '/CN=localhost',
      ]);
      await File('${fixture.directory.path}/leaf.ext').writeAsString(
        'basicConstraints=critical,CA:FALSE\nkeyUsage=critical,digitalSignature,keyEncipherment\n'
        'extendedKeyUsage=serverAuth\nsubjectAltName=DNS:localhost\n',
      );
      await run([
        'x509',
        '-req',
        '-in',
        'leaf.csr',
        '-CA',
        'root.pem',
        '-CAkey',
        'root-key.pem',
        '-CAcreateserial',
        '-out',
        'cert.pem',
        '-days',
        '2',
        '-extfile',
        'leaf.ext',
      ]);
      final verify = await run([
        'verify',
        '-CAfile',
        'root.pem',
        '-verify_hostname',
        'localhost',
        'cert.pem',
      ]);
      final dates = await run([
        'x509',
        '-in',
        'cert.pem',
        '-noout',
        '-dates',
        '-fingerprint',
        '-sha256',
      ]);
      await File('${fixture.directory.path}/generation.json').writeAsString(
        jsonEncode({
          'tool': tool,
          'version': version,
          'verify': verify,
          'dates': dates,
          'purpose':
              'Synthetic localhost only; never production credentials or a trust-store mutation',
        }),
      );
      // Optional retained evidence receives only this run's synthetic material.
      final evidence = Platform.environment['RECEIPT_TLS_FIXTURE_EVIDENCE'];
      if (evidence != null) {
        final target = await Directory(
          '$evidence/${fixture.directory.uri.pathSegments.where((s) => s.isNotEmpty).last}',
        ).create(recursive: true);
        for (final entity in fixture.directory.listSync().whereType<File>()) {
          await entity.copy('${target.path}/${entity.uri.pathSegments.last}');
        }
      }
      return fixture;
    } catch (_) {
      await fixture.close();
      rethrow;
    }
  }

  Future<void> close() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}
