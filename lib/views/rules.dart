import 'dart:convert';

import 'package:bett_box/clash/clash.dart';
import 'package:bett_box/common/common.dart';
import 'package:material_ui/material_ui.dart';

typedef RunningRule = ({String type, String payload, String proxy});

Future<List<RunningRule>> loadRunningRules() async {
  final response = await clashCore.clashInterface.getRules();
  if (response.isEmpty) return [];
  final values = jsonDecode(response) as List;
  return values.map((entry) {
    final rule = entry as Map<String, dynamic>;
    return (
      type: rule['type'] as String,
      payload: rule['payload'] as String,
      proxy: rule['proxy'] as String,
    );
  }).toList();
}

class RulesView extends StatefulWidget {
  final Future<List<RunningRule>> Function()? loadRules;
  const RulesView({super.key, this.loadRules});

  @override
  State<RulesView> createState() => _RulesViewState();
}

class _RulesViewState extends State<RulesView> {
  late Future<List<RunningRule>> _rules;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
    _rules = (widget.loadRules ?? loadRunningRules)();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: appLocalizations.search,
                  ),
                  onChanged: (value) =>
                      setState(() => _query = value.toLowerCase()),
                ),
              ),
              IconButton(
                onPressed: () => setState(_refresh),
                icon: const Icon(Icons.refresh),
                tooltip: appLocalizations.update,
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<RunningRule>>(
            future: _rules,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text(snapshot.error.toString()));
              }
              final rules = (snapshot.data ?? [])
                  .where(
                    (rule) => '${rule.type} ${rule.payload} ${rule.proxy}'
                        .toLowerCase()
                        .contains(_query),
                  )
                  .toList();
              if (rules.isEmpty) {
                return Center(child: Text(appLocalizations.noData));
              }
              return ListView.builder(
                itemCount: rules.length,
                itemBuilder: (context, index) {
                  final rule = rules[index];
                  return ListTile(
                    title: Text(
                      rule.payload.isEmpty ? rule.type : rule.payload,
                    ),
                    subtitle: Text(rule.type),
                    trailing: Text(rule.proxy),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
