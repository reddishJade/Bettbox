import 'package:bett_box/common/common.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/l10n/l10n.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/views/connection/item.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('connection shows both total traffic and speed', (tester) async {
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
    globalState.config = Config(themeProps: defaultThemeProps);
    final tracker = TrackerInfo(
      id: 'one',
      start: DateTime(2026),
      metadata: const Metadata(host: 'example.com'),
      chains: const [],
      rule: '',
      rulePayload: '',
      upload: 1024,
      download: 2048,
      uploadSpeed: 512,
      downloadSpeed: 256,
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: const [AppLocalizations.delegate],
          home: Builder(
            builder: (context) {
              globalState.measure = Measure.of(context, 1);
              return Scaffold(
                body: SizedBox(
                  height: TrackerInfoItem.height + 1,
                  child: TrackerInfoItem(
                    trackerInfo: tracker,
                    detailTitle: 'Details',
                    index: 0,
                    count: 1,
                    showSpeed: true,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    final up = TrafficValue(value: tracker.upload);
    final down = TrafficValue(value: tracker.download);
    final upSpeed = TrafficValue(value: tracker.uploadSpeed);
    final downSpeed = TrafficValue(value: tracker.downloadSpeed);
    expect(find.text('$up↑ $down↓\n$upSpeed/s↑ $downSpeed/s↓'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
