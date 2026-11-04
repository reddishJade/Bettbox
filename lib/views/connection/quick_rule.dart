import 'dart:io';

import 'package:bett_box/models/models.dart';

/// Rules that are guaranteed to match fields present on this connection.
List<({String type, String value})> connectionRuleCandidates(
  Metadata metadata,
) {
  final result = <({String type, String value})>[];
  void address(String value) {
    value = value.trim();
    if (value.startsWith('[') && value.endsWith(']')) {
      value = value.substring(1, value.length - 1);
    }
    final ip = InternetAddress.tryParse(value);
    if (ip != null) {
      final v6 = ip.type == InternetAddressType.IPv6;
      result.add((
        type: v6 ? 'IP-CIDR6' : 'IP-CIDR',
        value: '$value/${v6 ? 128 : 32}',
      ));
    } else if (RegExp(
      r'^[a-z\d_-]+(?:\.[a-z\d_-]+)*\.?$',
      caseSensitive: false,
    ).hasMatch(value)) {
      result.add((type: 'DOMAIN', value: value));
      result.add((type: 'DOMAIN-SUFFIX', value: value));
    }
  }

  address(metadata.host);
  address(metadata.destinationIP);
  for (final (type, value) in [
    ('PROCESS-NAME', metadata.process),
    ('PROCESS-PATH', metadata.processPath),
  ]) {
    if (value.isNotEmpty && !RegExp(r'[,\r\n]').hasMatch(value)) {
      result.add((type: type, value: value));
    }
  }
  return result.toSet().toList();
}

Profile addConnectionOverride(Profile profile, String value) {
  final data = profile.overrideData;
  final rule = data.rule.updateRules(
    (rules) => rules.any((rule) => rule.value == value)
        ? rules
        : [Rule.value(value), ...rules],
  );
  return profile.copyWith(
    overrideData: data.copyWith(enable: true, rule: rule),
  );
}
