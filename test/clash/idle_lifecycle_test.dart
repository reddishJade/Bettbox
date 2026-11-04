import 'package:bett_box/clash/clash.dart';
import 'package:bett_box/clash/interface.dart';
import 'package:bett_box/common/common.dart';
import 'package:bett_box/controller.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/state.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

class _UnexpectedCore implements ClashHandlerInterface {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected core operation: ${invocation.memberName}');
}

class _RejectedStartCore extends _UnexpectedCore {
  @override
  Future<bool> startListener() async => false;
}

void main() {
  testWidgets('desktop changes stay idle until the user starts', (
    tester,
  ) async {
    globalState.startTime = null;
    globalState.appState = AppState(
      brightness: Brightness.light,
      version: 0,
      viewSize: const Size(400, 800),
      requests: FixedList(maxLength),
      logs: FixedList(maxLogLength),
      traffics: FixedList(30),
      totalTraffic: Traffic(),
      systemUiOverlayStyle: const SystemUiOverlayStyle(),
    );
    globalState.config = Config(
      themeProps: defaultThemeProps,
      currentProfileId: 'p',
      profiles: const [
        Profile(id: 'p', autoUpdateDuration: Duration(hours: 1)),
      ],
    );
    final oldInterface = clashCore.clashInterface;
    clashCore.clashInterface = _UnexpectedCore();
    addTearDown(() => clashCore.clashInterface = oldInterface);
    late AppController controller;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) {
                controller = AppController(context, ref);
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );
    await controller.applyProfile(silence: true);
    await controller.handleChangeProfile(hardRestart: true);
    await controller.setupClashConfig();
    await controller.updateClashConfig();
    clashCore.clashInterface = _RejectedStartCore();
    await expectLater(clashCore.startListener(), throwsStateError);
    expect(tester.takeException(), isNull);
  });
}
