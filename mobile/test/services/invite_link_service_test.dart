import 'package:checks_frontend/services/invite_link_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InviteLinkService.normalizeShareLink', () {
    test('converts bill app links into the bill viewer URL', () {
      final link = InviteLinkService.normalizeShareLink(
        Uri.parse('billington://bill/27?t=secret'),
      );

      expect(link, 'https://billingtonapp.vercel.app/b/27?t=secret');
    });

    test('converts existing tab app links into the trip URL', () {
      final link = InviteLinkService.normalizeShareLink(
        Uri.parse('billington://tab/19?t=secret'),
      );

      expect(link, 'https://billingtonapp.vercel.app/t/19?t=secret');
    });

    test('accepts the legacy path-style bill app link', () {
      final link = InviteLinkService.normalizeShareLink(
        Uri.parse('billington:///bill/27?t=secret'),
      );

      expect(link, 'https://billingtonapp.vercel.app/b/27?t=secret');
    });

    test('rejects links without a supported route or token', () {
      expect(
        InviteLinkService.normalizeShareLink(Uri.parse('billington://bill/27')),
        isNull,
      );
      expect(
        InviteLinkService.normalizeShareLink(
          Uri.parse('https://example.com/b/27?t=secret'),
        ),
        isNull,
      );
    });
  });
}
