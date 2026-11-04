import 'package:bett_box/common/proxy.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/providers/state.dart';
import 'package:material_ui/material_ui.dart';
import 'package:synchronized/synchronized.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProxyManager extends ConsumerStatefulWidget {
  final Widget child;

  const ProxyManager({super.key, required this.child});

  @override
  ConsumerState createState() => _ProxyManagerState();
}

class _ProxyManagerState extends ConsumerState<ProxyManager> {
  final _proxyLock = Lock();
  bool _ownsSystemProxy = false;

  Future<void> _updateProxy(ProxyState proxyState) {
    return _proxyLock.synchronized(() async {
      if (proxyState.isStart && proxyState.systemProxy) {
        final enabled = await proxy?.startProxy(
          proxyState.port,
          proxyState.bypassDomain,
        );
        if (enabled == true) _ownsSystemProxy = true;
      } else if (_ownsSystemProxy) {
        await proxy?.stopProxy();
        _ownsSystemProxy = false;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    ref.listenManual(proxyStateProvider, (prev, next) {
      if (prev != next) {
        _updateProxy(next);
      }
    }, fireImmediately: true);
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
