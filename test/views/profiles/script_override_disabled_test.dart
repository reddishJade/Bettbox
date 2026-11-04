import 'dart:io';

import 'package:bett_box/common/common.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/state.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

class _TestPaths extends PathProviderPlatform {
  final String path;
  _TestPaths(this.path);

  @override
  Future<String?> getApplicationSupportPath() async => path;
  @override
  Future<String?> getTemporaryPath() async => path;
  @override
  Future<String?> getDownloadsPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'legacy selected JavaScript is not included in setup parameters',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'bettbox_no_script_',
      );
      final oldPaths = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _TestPaths(directory.path);
      addTearDown(() async {
        PathProviderPlatform.instance = oldPaths;
        await directory.delete(recursive: true);
      });
      const profile = Profile(
        id: 'test',
        autoUpdateDuration: Duration(hours: 1),
        groupSwitches: {'disabled': false},
      );
      globalState.appState = AppState(
        brightness: Brightness.light,
        version: 0,
        viewSize: Size.zero,
        requests: FixedList(maxLength),
        logs: FixedList(maxLogLength),
        traffics: FixedList(30),
        totalTraffic: Traffic(),
        systemUiOverlayStyle: const SystemUiOverlayStyle(),
      );
      globalState.config = Config(
        themeProps: defaultThemeProps,
        patchClashConfig: defaultClashConfig,
        currentProfileId: profile.id,
        profiles: const [profile],
        scriptProps: const ScriptProps(
          currentId: 'legacy',
          scripts: [
            Script(
              id: 'legacy',
              label: 'legacy',
              content: 'throw Error("executed")',
            ),
          ],
        ),
      );
      final params = await globalState.buildSetupParams(
        patchConfig: globalState.config.patchClashConfig,
      );
      expect(params.scriptedConfig, isEmpty);
      expect(params.patch?['disabled-groups'], ['disabled']);
    },
  );
}
