import 'package:fl_clash/common/chain_proxy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'stores chain proxy overrides inside selectedMap without touching selections',
    () {
      const selectedMap = <String, String>{'Auto': 'Node A'};
      final updated = setChainProxyOverride(
        selectedMap,
        proxyName: 'Exit',
        dialerProxy: 'Node A',
      );

      expect(updated['Auto'], 'Node A');
      expect(getChainProxyOverrides(updated), {'Exit': 'Node A'});

      final removed = setChainProxyOverride(
        updated,
        proxyName: 'Exit',
        dialerProxy: null,
      );
      expect(getChainProxyOverrides(removed), isEmpty);
      expect(removed['Auto'], 'Node A');
    },
  );

  test('applies dialer-proxy only to the configured outbound', () {
    final result = applyChainProxyOverrides(
      <String, dynamic>{
        'proxies': [
          {'name': 'First', 'type': 'ss', 'server': 'a.example.com'},
          {'name': 'Exit', 'type': 'ss', 'server': 'b.example.com'},
        ],
      },
      {
        chainProxySelectedMapKey('Exit'): 'First',
      },
    );

    final proxies = result['proxies'] as List;
    expect((proxies[0] as Map)['dialer-proxy'], isNull);
    expect((proxies[1] as Map)['dialer-proxy'], 'First');
  });

  test('does not overwrite the source config when there is no app override', () {
    final config = <String, dynamic>{
      'proxies': [
        {
          'name': 'Exit',
          'type': 'ss',
          'dialer-proxy': 'Source Dialer',
        },
      ],
    };

    expect(applyChainProxyOverrides(config, const {}), same(config));
    expect((config['proxies'] as List).single['dialer-proxy'], 'Source Dialer');
  });

  test('detects direct and multi-hop cycles', () {
    expect(
      wouldCreateChainProxyCycle(
        const {},
        proxyName: 'A',
        dialerProxy: 'A',
      ),
      isTrue,
    );

    expect(
      wouldCreateChainProxyCycle(
        const {'B': 'A'},
        proxyName: 'A',
        dialerProxy: 'B',
      ),
      isTrue,
    );

    expect(
      wouldCreateChainProxyCycle(
        const {'B': 'C'},
        proxyName: 'A',
        dialerProxy: 'B',
      ),
      isFalse,
    );
  });
}
