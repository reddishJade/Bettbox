import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bett_box/common/taskbar_traffic.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeProcess implements Process {
  _FakeProcess() {
    input.stream.listen(
      (bytes) => writes.add(utf8.decode(bytes)),
      onDone: () => _exit.complete(0),
    );
    _stdin = IOSink(input.sink);
  }

  final input = StreamController<List<int>>();
  final writes = <String>[];
  final _exit = Completer<int>();
  late final IOSink _stdin;

  @override
  IOSink get stdin => _stdin;
  @override
  Stream<List<int>> get stdout => const Stream.empty();
  @override
  Stream<List<int>> get stderr => const Stream.empty();
  @override
  Future<int> get exitCode => _exit.future;
  @override
  int get pid => 1;
  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    if (!_exit.isCompleted) _exit.complete(-1);
    return true;
  }
}

void main() {
  test('reports a missing component without starting a process', () async {
    final manager = TaskbarTraffic(resolveExecutable: () async => null);
    expect(await manager.setEnabled(true), isFalse);
  });

  test('starts once, sends bytes per second, and closes stdin', () async {
    final process = _FakeProcess();
    var starts = 0;
    final manager = TaskbarTraffic(
      resolveExecutable: () async => 'taskbar-traffic.exe',
      startProcess: (executable, arguments) async {
        starts++;
        expect(executable, 'taskbar-traffic.exe');
        expect(arguments, ['--stdin']);
        return process;
      },
    );
    expect(
      await Future.wait([manager.setEnabled(true), manager.setEnabled(true)]),
      [true, true],
    );
    expect(starts, 1);
    manager.update(1024, 2048);
    await manager.setEnabled(false);
    expect(process.writes.join(), '1024 2048\n');
    expect(await process.exitCode, 0);
  });
}
