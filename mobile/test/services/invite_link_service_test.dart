import 'package:checks_frontend/services/invite_link_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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

  test(
    'clearing a routed link preserves a newer link received meanwhile',
    () async {
      SharedPreferences.setMockInitialValues({
        'pending_tab_invite': 'https://billingtonapp.vercel.app/t/20?t=new',
      });
      InviteLinkService.pendingShareLink.value =
          'https://billingtonapp.vercel.app/t/20?t=new';

      await InviteLinkService().clearPendingInvite(
        expectedLink: 'https://billingtonapp.vercel.app/t/19?t=old',
      );

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('pending_tab_invite'), contains('/t/20'));
      expect(InviteLinkService.pendingShareLink.value, contains('/t/20'));
    },
  );
}
