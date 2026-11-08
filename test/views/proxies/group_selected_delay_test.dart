import 'dart:async';
import 'dart:convert';

import 'package:bett_box/clash/clash.dart';
import 'package:bett_box/clash/interface.dart';
import 'package:bett_box/common/common.dart';
import 'package:bett_box/controller.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/l10n/l10n.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/views/proxies/common.dart';
import 'package:bett_box/views/proxies/list.dart';
import 'package:bett_box/views/proxies/proxies.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

class _FakeClash implements ClashHandlerInterface {
  final requests = <(String, String)>[];
  final result = Completer<void>();

  @override
  Future<String> asyncTestDelay(String url, String proxyName) async {
    requests.add((url, proxyName));
    await result.future;
    return jsonEncode({'name': proxyName, 'url': url, 'value': 42});
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('group header follows the selected node delay and test URL', (
    tester,
  ) async {
    globalState.appState = AppState(
      brightness: Brightness.light,
      version: 0,
      viewSize: const Size(400, 800),
      requests: FixedList(maxLength),
      logs: FixedList(maxLogLength),
      traffics: FixedList(30),
      totalTraffic: Traffic(),
      systemUiOverlayStyle: const SystemUiOverlayStyle(),
      groups: const [
        Group(
          name: 'Main',
          type: GroupType.Selector,
          testUrl: 'https://group.test',
          all: [
            Proxy(name: 'first', type: 'Shadowsocks'),
            Proxy(name: 'second', type: 'Shadowsocks'),
            Proxy(name: 'DIRECT', type: 'Direct'),
          ],
        ),
      ],
      delayMap: const {
        'https://group.test': {'first': 123, 'second': 456, 'DIRECT': 19},
        'https://other.test': {'first': 999},
      },
    );
    globalState.config = Config(
      themeProps: defaultThemeProps,
      overrideTestUrl: false,
      currentProfileId: 'p',
      profiles: const [
        Profile(
          id: 'p',
          autoUpdateDuration: Duration(hours: 1),
          selectedMap: {'Main': 'first'},
        ),
      ],
      proxiesStyle: defaultProxiesStyle.copyWith(type: ProxiesType.list),
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: const [AppLocalizations.delegate],
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                globalState.appController = AppController(context, ref);
                globalState.measure = Measure.of(context, 1);
                return const ProxiesListView();
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('123 ms'), findsOneWidget);
    expect(find.text('999 ms'), findsNothing);
    var profile = container.read(currentProfileProvider)!;
    container
        .read(profilesProvider.notifier)
        .setProfile(profile.copyWith(selectedMap: {'Main': 'second'}));
    await tester.pumpAndSettle();
    expect(find.text('123 ms'), findsNothing);
    expect(find.text('456 ms'), findsOneWidget);
    profile = container.read(currentProfileProvider)!;
    container
        .read(profilesProvider.notifier)
        .setProfile(profile.copyWith(selectedMap: {'Main': 'DIRECT'}));
    await tester.pumpAndSettle();
    expect(find.text('19 ms'), findsOneWidget);
    final fake = _FakeClash();
    clashCore.clashInterface = fake;
    expect(find.byIcon(Icons.bolt), findsNothing);
    expect(find.byIcon(Icons.network_ping), findsOneWidget);
    expect(
      tester.getCenter(find.text('Selector')).dy,
      closeTo(tester.getCenter(find.text('19 ms')).dy, 1),
    );
    await tester.tap(find.byTooltip(appLocalizations.startTest));
    await tester.pump();
    expect(fake.requests, contains(('https://group.test', 'DIRECT')));
    expect(find.text('first'), findsNothing);
    fake.result.complete();
    await tester.pumpAndSettle();
    expect(find.text('42 ms'), findsOneWidget);
    expect(find.text('first'), findsNothing);

    final allFake = _FakeClash();
    clashCore.clashInterface = allFake;
    final allTest = delayTestAllGroups(const [
      Group(
        name: 'Main',
        type: GroupType.Selector,
        testUrl: 'https://group.test',
        all: [Proxy(name: 'first', type: 'Shadowsocks')],
      ),
      Group(
        name: 'Other',
        type: GroupType.Selector,
        testUrl: 'https://other.test',
        all: [Proxy(name: 'first', type: 'Shadowsocks')],
      ),
      Group(
        name: 'Duplicate',
        type: GroupType.Selector,
        testUrl: 'https://group.test',
        all: [Proxy(name: 'first', type: 'Shadowsocks')],
      ),
    ]);
    await tester.pump();
    expect(delayTestCoordinator.isTestingAll, isTrue);
    expect(allFake.requests, contains(('https://group.test', 'first')));
    expect(allFake.requests, contains(('https://other.test', 'first')));
    expect(allFake.requests, hasLength(2));
    allFake.result.complete();
    await allTest;
    await tester.pumpAndSettle();
    expect(delayTestCoordinator.isTesting, isFalse);

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: const [AppLocalizations.delegate],
          home: Consumer(
            builder: (context, ref, _) {
              globalState.appController = AppController(context, ref);
              globalState.measure = Measure.of(context, 1);
              return const ProxiesView();
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final pageFake = _FakeClash();
    clashCore.clashInterface = pageFake;
    await tester.tap(find.byTooltip(appLocalizations.testAllGroups));
    await tester.pump();
    expect(delayTestCoordinator.isTestingAll, isTrue);
    expect(pageFake.requests, contains(('https://group.test', 'DIRECT')));
    pageFake.result.complete();
    await tester.pumpAndSettle();
    expect(delayTestCoordinator.isTesting, isFalse);
    expect(tester.takeException(), isNull);
  });
}
