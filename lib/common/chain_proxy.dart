const chainProxySelectedMapPrefix = '__flclash_dialer_proxy__::';

String chainProxySelectedMapKey(String proxyName) =>
    '$chainProxySelectedMapPrefix$proxyName';

Map<String, String> getChainProxyOverrides(Map<String, String> selectedMap) {
  final overrides = <String, String>{};
  for (final entry in selectedMap.entries) {
    if (!entry.key.startsWith(chainProxySelectedMapPrefix)) {
      continue;
    }
    final proxyName = entry.key.substring(chainProxySelectedMapPrefix.length);
    if (proxyName.isEmpty || entry.value.isEmpty) {
      continue;
    }
    overrides[proxyName] = entry.value;
  }
  return overrides;
}

Map<String, String> setChainProxyOverride(
  Map<String, String> selectedMap, {
  required String proxyName,
  String? dialerProxy,
}) {
  final next = Map<String, String>.from(selectedMap);
  final key = chainProxySelectedMapKey(proxyName);
  if (dialerProxy == null || dialerProxy.isEmpty) {
    next.remove(key);
  } else {
    next[key] = dialerProxy;
  }
  return next;
}

Map<String, dynamic> applyChainProxyOverrides(
  Map<String, dynamic> rawConfig,
  Map<String, String> selectedMap,
) {
  final overrides = getChainProxyOverrides(selectedMap);
  if (overrides.isEmpty) {
    return rawConfig;
  }

  final rawProxies = rawConfig['proxies'];
  if (rawProxies is! List) {
    return rawConfig;
  }

  var changed = false;
  final proxies = rawProxies.map((item) {
    if (item is! Map) {
      return item;
    }
    final proxy = Map<String, dynamic>.from(item);
    final name = proxy['name'];
    if (name is! String) {
      return proxy;
    }
    final dialerProxy = overrides[name];
    if (dialerProxy == null || dialerProxy.isEmpty || dialerProxy == name) {
      return proxy;
    }
    proxy['dialer-proxy'] = dialerProxy;
    changed = true;
    return proxy;
  }).toList();

  if (!changed) {
    return rawConfig;
  }

  return Map<String, dynamic>.from(rawConfig)..['proxies'] = proxies;
}

bool wouldCreateChainProxyCycle(
  Map<String, String> overrides, {
  required String proxyName,
  required String dialerProxy,
}) {
  if (proxyName == dialerProxy) {
    return true;
  }

  final next = Map<String, String>.from(overrides)
    ..[proxyName] = dialerProxy;
  final visited = <String>{};
  var current = proxyName;
  while (true) {
    if (!visited.add(current)) {
      return true;
    }
    final parent = next[current];
    if (parent == null || parent.isEmpty) {
      return false;
    }
    current = parent;
  }
}
