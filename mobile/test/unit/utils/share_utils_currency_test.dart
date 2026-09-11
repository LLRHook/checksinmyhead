import 'package:checks_frontend/models/bill_item.dart';
import 'package:checks_frontend/screens/quick_split/bill_summary/utils/share_utils.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('share text labels original non-USD receipt amounts', () async {
    SharedPreferences.setMockInitialValues({});

    final text = await ShareUtils.generateShareText(
      participants: const [],
      personShares: const {},
      items: [BillItem(name: 'Coffee', price: 4.5, assignments: {})],
      subtotal: 4.5,
      tax: 0,
      tipAmount: 0,
      total: 4.5,
      birthdayPerson: null,
      tipPercentage: 0,
      isCustomTipAmount: false,
      showAllItems: true,
      showPersonItems: false,
      showBreakdown: true,
      currencyCode: 'EUR',
    );

    expect(text, contains('Total: EUR 4.50'));
    expect(text, contains('• Coffee: EUR 4.50'));
    expect(text, isNot(contains(r'$4.50')));
  });
}
