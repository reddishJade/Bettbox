import 'package:bett_box/common/common.dart';
import 'package:bett_box/l10n/l10n.dart';
import 'package:bett_box/views/rules.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows running rules, filters and refreshes', (tester) async {
    await AppLocalizations.load(const Locale('en'));
    var loads = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RulesView(
            loadRules: () async {
              loads++;
              return [
                (type: 'Domain', payload: 'example.com', proxy: 'Proxy'),
                (type: 'Match', payload: '', proxy: 'DIRECT'),
              ];
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('example.com'), findsOneWidget);
    expect(find.text('DIRECT'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'proxy');
    await tester.pump();
    expect(find.text('example.com'), findsOneWidget);
    expect(find.text('DIRECT'), findsNothing);
    await tester.tap(find.byTooltip(appLocalizations.update));
    await tester.pumpAndSettle();
    expect(loads, 2);
  });
}
