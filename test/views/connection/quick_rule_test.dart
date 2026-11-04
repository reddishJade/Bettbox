import 'package:bett_box/models/models.dart';
import 'package:bett_box/views/connection/quick_rule.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('candidates match connection metadata and reject invalid values', () {
    final candidates = connectionRuleCandidates(
      const Metadata(
        host: 'example.com',
        destinationIP: '2001:db8::1',
        process: 'browser',
        processPath: '/a,b',
      ),
    );
    expect(candidates, contains((type: 'DOMAIN', value: 'example.com')));
    expect(candidates, contains((type: 'DOMAIN-SUFFIX', value: 'example.com')));
    expect(candidates, contains((type: 'IP-CIDR6', value: '2001:db8::1/128')));
    expect(candidates, contains((type: 'PROCESS-NAME', value: 'browser')));
    expect(candidates.any((item) => item.type == 'PROCESS-PATH'), isFalse);
    expect(
      connectionRuleCandidates(const Metadata(host: 'https://invalid')),
      isEmpty,
    );
  });
  test('enables override, prepends and avoids duplicates', () {
    final profile = Profile.normal();
    final updated = addConnectionOverride(profile, 'DOMAIN,example.com,DIRECT');
    final repeated = addConnectionOverride(
      updated,
      'DOMAIN,example.com,DIRECT',
    );
    expect(repeated.overrideData.enable, isTrue);
    expect(repeated.overrideData.rule.rules.map((rule) => rule.value), [
      'DOMAIN,example.com,DIRECT',
    ]);
  });
}
