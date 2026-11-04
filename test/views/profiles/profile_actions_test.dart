import 'package:bett_box/common/common.dart';
import 'package:bett_box/controller.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/l10n/l10n.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/views/profiles/profiles.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('profiles can be dragged directly and expose separate editors', (
    tester,
  ) async {
    globalState.appState = AppState(
      brightness: Brightness.light,
      version: 0,
      viewSize: const Size(800, 600),
      requests: FixedList(maxLength),
      logs: FixedList(maxLogLength),
      traffics: FixedList(30),
      totalTraffic: Traffic(),
      systemUiOverlayStyle: const SystemUiOverlayStyle(),
    );
    globalState.config = Config(
      themeProps: defaultThemeProps,
      currentProfileId: 'a',
      profiles: const [
        Profile(
          id: 'a',
          label: 'Alpha',
          autoUpdateDuration: Duration(hours: 1),
        ),
        Profile(id: 'b', label: 'Beta', autoUpdateDuration: Duration(hours: 1)),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: const [AppLocalizations.delegate],
          home: Consumer(
            builder: (context, ref, _) {
              globalState.appController = AppController(context, ref);
              globalState.measure = Measure.of(context, 1);
              return const ProfilesView();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.sort), findsNothing);
    expect(find.byTooltip(appLocalizations.runtimeConfig), findsOneWidget);
    expect(find.byType(DragTarget<String>), findsNWidgets(2));
    final start = tester.getCenter(find.text('Alpha'));
    final end = tester.getCenter(find.text('Beta'));
    final gesture = await tester.startGesture(start);
    await gesture.moveBy(const Offset(20, 0));
    await tester.pump();
    await gesture.moveTo(end);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(globalState.config.profiles.map((p) => p.id), ['b', 'a']);
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    expect(find.text(appLocalizations.editInfo), findsOneWidget);
    expect(find.text(appLocalizations.editFile), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('resources are between profiles and connections in navigation', () {
    final items = navigation.getItems(hasProxies: true);
    final profiles = items.indexWhere(
      (item) => item.label == PageLabel.profiles,
    );
    final resources = items.indexWhere(
      (item) => item.label == PageLabel.resources,
    );
    final connections = items.indexWhere(
      (item) => item.label == PageLabel.connections,
    );
    expect(resources, profiles + 1);
    expect(connections, resources + 1);
    expect(items[resources].modes, contains(NavigationItemMode.desktop));
    expect(items[resources].modes, isNot(contains(NavigationItemMode.more)));
  });

  test('resources are absent from settings shortcuts', () {
    expect(
      SidebarFlyoutEntry.supportedValues,
      isNot(contains(SidebarFlyoutEntry.resources)),
    );
  });
}
