import 'dart:convert';

import 'package:bett_box/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Windows taskbar traffic defaults off and persists independently', () {
    expect(const VpnProps().enableTaskbarTraffic, isFalse);
    final restored = VpnProps.fromJson(
      jsonDecode(
            jsonEncode(
              const VpnProps(
                enableTaskbarTraffic: true,
                enableTraySpeed: false,
              ),
            ),
          )
          as Map<String, dynamic>,
    );
    expect(restored.enableTaskbarTraffic, isTrue);
    expect(restored.enableTraySpeed, isFalse);
  });
}
