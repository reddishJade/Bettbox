import 'package:bett_box/common/print.dart';
import 'package:code_forge/code_forge.dart';

Future<bool>? _rustLibReady;

Future<bool> ensureRustLib() => _rustLibReady ??= _initRustLib();

Future<bool> _initRustLib() async {
  try {
    await RustLib.init();
    return true;
  } catch (e) {
    commonPrint.error('Failed to initialize RustLib: $e');
    _rustLibReady = null;
    return false;
  }
}
