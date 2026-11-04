import 'dart:convert';

import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('old configuration loads without retaining removed settings', () {
    final original = Config(
      themeProps: defaultThemeProps,
      profiles: const [
        Profile(id: 'p', autoUpdateDuration: Duration(hours: 1)),
      ],
    );
    final data = jsonDecode(jsonEncode(original)) as Map<String, dynamic>;
    data['scriptProps'] = {'currentId': 'old', 'scripts': []};
    (data['profiles'] as List).first['useScriptOverride'] = true;
    (data['appSetting'] as Map)['sidebarFlyoutEntries'] = ['script', 'theme'];
    final config = Config.fromJson(data);
    expect(config.profiles.single.id, 'p');
    expect(config.appSetting.sidebarFlyoutEntries, [SidebarFlyoutEntry.theme]);
    final saved = jsonDecode(jsonEncode(config)) as Map<String, dynamic>;
    expect(saved.containsKey('scriptProps'), isFalse);
    expect(
      (saved['profiles'] as List).first.containsKey('useScriptOverride'),
      isFalse,
    );
  });
}
