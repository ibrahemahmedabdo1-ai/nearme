import 'package:flutter_test/flutter_test.dart';
import 'package:near_me_core/near_me_core.dart';
import 'package:near_me_customer/app_state.dart';
import 'package:near_me_customer/main.dart';

void main() {
  testWidgets('shows auth screen when signed out', (tester) async {
    final state = AppState(ApiClient(baseUrl: 'http://localhost'));
    await tester.pumpWidget(NearMeApp(state: state));
    expect(find.text('NEAR ME'), findsOneWidget);
    expect(find.text('تسجيل الدخول'), findsWidgets);
  });
}
