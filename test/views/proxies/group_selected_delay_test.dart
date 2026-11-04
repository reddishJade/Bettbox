import 'dart:async';

import 'package:bett_box/clash/clash.dart';
import 'package:bett_box/clash/interface.dart';
import 'package:bett_box/common/common.dart';
import 'package:bett_box/controller.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/l10n/l10n.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/views/proxies/list.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

class _FakeClash implements ClashHandlerInterface {
  final result = Completer<String>();
  String? testedUrl;
  String? testedProxy;

  @override
  Future<String> asyncTestDelay(String url, String proxyName) {
    testedUrl = url;
    testedProxy = proxyName;
    return result.future;
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
    await tester.tap(find.text('19 ms'));
    await tester.pump();
    expect(fake.testedProxy, 'DIRECT');
    expect(fake.testedUrl, 'https://group.test');
    fake.result.complete(
      '{"name":"DIRECT","url":"https://group.test","value":42}',
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('42 ms'), findsOneWidget);
    expect(find.text('first'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
