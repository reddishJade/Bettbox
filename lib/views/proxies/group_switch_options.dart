import 'package:bett_box/common/common.dart';
import 'package:bett_box/enum/enum.dart';
import 'package:bett_box/models/models.dart';
import 'package:bett_box/providers/providers.dart';
import 'package:bett_box/state.dart';
import 'package:bett_box/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

const Duration _kMinLoadingDuration = Duration(seconds: 1);

Future<void> showGroupSwitchOptions(
  BuildContext context, {
  required String profileId,
}) async {
  await showExtend(
    context,
    builder: (_, type) {
      return _GroupSwitchOptionsSheet(type: type, profileId: profileId);
    },
  );
}

class _GroupSwitchOptionsSheet extends ConsumerStatefulWidget {
  final SheetType type;
  final String profileId;

  const _GroupSwitchOptionsSheet({required this.type, required this.profileId});

  @override
  ConsumerState<_GroupSwitchOptionsSheet> createState() =>
      _GroupSwitchOptionsSheetState();
}

class _GroupSwitchOptionsSheetState
    extends ConsumerState<_GroupSwitchOptionsSheet> {
  late final Mode _mode;
  List<String> _groupNames = [];
  String? _matchTarget;
  Map<String, bool> _options = {};
  Map<String, bool> _originalOptions = {};
  Set<String> _lockedGroups = {};
  bool _isLoading = true;
  bool _dirty = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _mode = ref.read(patchClashConfigProvider).mode;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.afterRouteTransition(_load);
    });
  }

  Future<void> _load() async {
    if (!mounted) return;
    final rawConfig = await globalState.appController.safeRun(
      silence: false,
      () => globalState.getProfileConfig(widget.profileId),
    );
    if (!mounted) return;
    if (rawConfig == null) {
      Navigator.of(context).pop();
      return;
    }
    final rules = rawConfig['rules'] as List? ?? [];
    final proxyGroups = rawConfig['proxy-groups'] as List? ?? [];
    String? matchTarget;
    for (final rule in rules) {
      if (rule is! String) continue;
      final parsed = ParsedRule.parseString(rule);
      final target = parsed.ruleTarget;
      if (parsed.ruleAction == RuleAction.MATCH &&
          target != null &&
          target.isNotEmpty) {
        matchTarget = target;
        break;
      }
    }
    final groupSwitches = ref.read(currentProfileProvider)?.groupSwitches ?? {};
    final isGlobalMode = _mode == Mode.global;
    setState(() {
      _groupNames = [
        for (final g in proxyGroups)
          if (g is Map && g['name'] is String) g['name'] as String,
      ];
      _matchTarget = matchTarget;
      _options = {
        for (final name in _groupNames)
          if (isGlobalMode || name != 'GLOBAL')
            name: groupSwitches[name] ?? true,
      };
      _originalOptions = Map<String, bool>.from(_options);
      _lockedGroups = _computeLockedGroups();
      _isLoading = false;
    });
  }

  Set<String> _computeLockedGroups() {
    final locked = <String>{};
    final firstNonGlobal = _options.keys.firstWhere(
      (k) => k != 'GLOBAL',
      orElse: () => '',
    );
    if (firstNonGlobal.isNotEmpty) {
      locked.add(firstNonGlobal);
    }
    if (_mode == Mode.global && _options.containsKey('GLOBAL')) {
      locked.add('GLOBAL');
    }
    final matchTarget = _matchTarget;
    if (matchTarget != null && matchTarget.isNotEmpty) {
      locked.add(matchTarget);
    }
    return locked;
  }

  bool get _hasUnsavedChanges => _dirty;

  void _onOptionChanged(String key, bool value) {
    setState(() {
      _options[key] = value;
      _dirty = true;
    });
  }

  Future<bool> _confirmDiscard() async {
    if (_isSaving) return false;
    if (!_hasUnsavedChanges) return true;
    final res = await globalState.showCommonDialog<bool>(
      child: CommonDialog(
        title: appLocalizations.saveChanges,
        actions: [
          TextButton(
            onPressed: () => globalState.navigatorKey.currentState?.pop(false),
            child: Text(appLocalizations.cancel),
          ),
          FilledButton(
            onPressed: () => globalState.navigatorKey.currentState?.pop(true),
            child: Text(appLocalizations.save),
          ),
        ],
      ),
    );
    if (res == true) {
      await _handleSave();
      return false;
    }
    return res == false;
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    if (widget.profileId != ref.read(currentProfileIdProvider)) {
      _dirty = false;
      if (mounted) setState(() {});
      return;
    }

    if (mounted) setState(() => _isSaving = true);

    try {
      final validOptions = {
        for (final name in _groupNames) name: _options[name] ?? true,
      };

      ref
          .read(profilesProvider.notifier)
          .updateProfile(
            widget.profileId,
            (state) => state.copyWith(groupSwitches: validOptions),
          );

      final patchConfig = ref.read(patchClashConfigProvider);
      final message = await globalState.validatePatchedConfig(
        patchConfig: patchConfig,
      );

      if (message.isNotEmpty) {
        ref
            .read(profilesProvider.notifier)
            .updateProfile(
              widget.profileId,
              (state) => state.copyWith(groupSwitches: _originalOptions),
            );
        if (mounted) {
          await globalState.showMessage(
            message: TextSpan(
              text: '${appLocalizations.profileParseErrorDesc}: $message',
            ),
            cancelable: false,
          );
        }
        return;
      }

      final applyFuture = globalState.appController.applyProfile(silence: true);
      await Future.wait([applyFuture, Future.delayed(_kMinLoadingDuration)]);

      _dirty = false;
      _originalOptions = Map<String, bool>.from(validOptions);
    } finally {
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) {
        setState(() => _isSaving = false);
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final keys = _options.keys.toList();
    return CommonPopScope(
      onPop: _confirmDiscard,
      child: AbsorbPointer(
        absorbing: _isSaving,
        child: AdaptiveSheetScaffold(
          type: widget.type,
          title: appLocalizations.custom,
          actions: [
            IconButton(
              onPressed: (_dirty && !_isSaving) ? _handleSave : null,
              icon: const Icon(Icons.save),
              tooltip: appLocalizations.save,
            ),
          ],
          body: Column(
            children: [
              if (_isSaving)
                LinearProgressIndicator(
                  minHeight: 2,
                  color: context.colorScheme.primary,
                ),
              Expanded(
                child: FadeBox(
                  alignment: Alignment.center,
                  child: _isLoading
                      ? const Center(
                          child: SyncedLoading(
                            size: 40,
                            child: CircularProgressIndicator(),
                          ),
                        )
                      : keys.isEmpty
                      ? NullStatus(label: appLocalizations.noStatusAvailable)
                      : RepaintBoundary(
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 16,
                            ),
                            itemCount: keys.length,
                            itemBuilder: (_, index) {
                              final key = keys[index];
                              final val = _options[key] ?? true;
                              final locked = _lockedGroups.contains(key);
                              return RepaintBoundary(
                                child: Container(
                                  margin: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: CommonCard(
                                    type: CommonCardType.filled,
                                    child: ListTile(
                                      contentPadding: const EdgeInsets.only(
                                        left: 16,
                                        right: 16,
                                      ),
                                      leading: const Icon(Icons.alt_route),
                                      title: Text(key),
                                      trailing: Switch(
                                        value: val,
                                        onChanged: locked
                                            ? null
                                            : (v) {
                                                _onOptionChanged(key, v);
                                              },
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
