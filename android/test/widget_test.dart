import 'package:flutter_test/flutter_test.dart';
import 'package:offscreen/main.dart';

void main() {
  testWidgets('home opens with mission planning and bottom navigation', (tester) async {
    await tester.pumpWidget(const OffscreenApp());
    await tester.pumpAndSettle();
    expect(find.text('Offscreen'), findsOneWidget);
    expect(find.text('Plan your break'), findsOneWidget);
    expect(find.text('Give me a mission'), findsOneWidget);
    expect(find.text('A little less scrolling.\nA little more noticing.'), findsOneWidget);
  });

  testWidgets('bottom navigation switches between journal, progress, and settings', (tester) async {
    await tester.pumpWidget(const OffscreenApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Journal').last);
    await tester.pumpAndSettle();
    expect(find.text('Your nature journal'), findsOneWidget);
    await tester.tap(find.text('Progress').last);
    await tester.pumpAndSettle();
    expect(find.text('Your progress'), findsOneWidget);
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    expect(find.text('Your model, your journal, your device.'), findsOneWidget);
  });

  testWidgets('quick focus chips update the selected focus', (tester) async {
    await tester.pumpWidget(const OffscreenApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bird sounds'));
    await tester.pumpAndSettle();
    expect(find.text('Bird sounds'), findsOneWidget);
  });
}
