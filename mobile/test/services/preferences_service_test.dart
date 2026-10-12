import 'package:checks_frontend/screens/settings/services/preferences_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('USD bill totals default off and can be enabled', () async {
    final preferences = PreferencesService();
    expect(await preferences.getShowBillTotalsInUSD(), isFalse);

    await preferences.setShowBillTotalsInUSD(true);
    expect(await preferences.getShowBillTotalsInUSD(), isTrue);
  });
}
