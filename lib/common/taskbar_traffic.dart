import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:synchronized/synchronized.dart';

import 'print.dart';

typedef TaskbarProcessStarter =
    Future<Process> Function(String executable, List<String> arguments);

class TaskbarTraffic {
  TaskbarTraffic({
    @visibleForTesting Future<String?> Function()? resolveExecutable,
    @visibleForTesting TaskbarProcessStarter? startProcess,
  }) : _resolveExecutable = resolveExecutable ?? _findExecutable,
       _startProcess = startProcess ?? Process.start;

  final Future<String?> Function() _resolveExecutable;
  final TaskbarProcessStarter _startProcess;
  final Lock _lock = Lock();
  Process? _process;

  static Future<String?> _findExecutable() async {
    final localAppData = Platform.environment['LOCALAPPDATA'];
    final candidates = [
      p.join(p.dirname(Platform.resolvedExecutable), 'taskbar-traffic.exe'),
      if (localAppData != null)
        p.join(
          localAppData,
          'Programs',
          'TaskbarTraffic',
          'taskbar-traffic.exe',
        ),
    ];
    for (final path in candidates) {
      if (await File(path).exists()) return path;
    }
    return null;
  }

  Future<bool> setEnabled(bool enabled) => _lock.synchronized(() async {
    if (!enabled) {
      final process = _process;
      _process = null;
      if (process != null) {
        await process.stdin.close().catchError((_) {});
        await process.exitCode.timeout(
          const Duration(seconds: 2),
          onTimeout: () {
            process.kill();
            return -1;
          },
        );
      }
      return true;
    }
    if (_process != null) return true;
    final executable = await _resolveExecutable();
    if (executable == null) return false;
    try {
      final process = await _startProcess(executable, ['--stdin']);
      _process = process;
      unawaited(process.stdout.drain<void>());
      unawaited(process.stderr.drain<void>());
      unawaited(process.stdin.done.catchError((_) {}));
      unawaited(
        process.exitCode.then((_) {
          if (identical(_process, process)) _process = null;
        }),
      );
      return true;
    } catch (error) {
      commonPrint.warn('Could not start taskbar traffic: $error');
      return false;
    }
  });

  void update(int upload, int download) {
    final process = _process;
    if (process == null) return;
    try {
      process.stdin.writeln('$upload $download');
    } catch (error) {
      commonPrint.warn('Could not update taskbar traffic: $error');
    }
  }
}

final taskbarTraffic = TaskbarTraffic();
