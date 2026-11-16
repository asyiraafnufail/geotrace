import 'package:flutter_test/flutter_test.dart';
import 'package:geotrace/main.dart';

void main() {
  testWidgets('GeoTrace initial widget smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const GeoTraceApp(isConfigured: false));
    expect(find.text('Setup Supabase GeoTrace'), findsOneWidget);
  });
}
