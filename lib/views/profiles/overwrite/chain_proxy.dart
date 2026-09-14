import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/features/overwrite/overwrite.dart';
import 'package:fl_clash/models/models.dart';
import 'package:fl_clash/providers/providers.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class ChainProxyView extends ConsumerWidget {
  final int profileId;

  const ChainProxyView({super.key, required this.profileId});

  void _updateOverride(
    WidgetRef ref, {
    required String proxyName,
    String? dialerProxy,
  }) {
    ref.read(profilesProvider.notifier).updateProfile(profileId, (profile) {
      return profile.copyWith(
        selectedMap: setChainProxyOverride(
          profile.selectedMap,
          proxyName: proxyName,
          dialerProxy: dialerProxy,
        ),
      );
    });
    if (ref.read(currentProfileIdProvider) == profileId) {
      ref
          .read(setupActionProvider.notifier)
          .applyProfileDebounce(silence: true);
    }
  }

  Future<String?> _selectTarget(
    BuildContext context,
    WidgetRef ref,
    ClashConfig config,
  ) {
    final typeMap = {for (final proxy in config.proxies) proxy.name: proxy.type};
    final names = config.proxies.map((proxy) => proxy.name).toList();
    return showSheet<String>(
      context: context,
      props: const SheetProps(isScrollControlled: true),
      builder: (context) => OverwriteSelectionSheet<String>(
        title: context.appLocalizations.chainProxyExit,
        sections: [
          OverwriteSelectionSection<String>(
            label: context.appLocalizations.proxies,
            items: names,
            subtitleBuilder: (_, name) => typeMap[name] ?? '',
          ),
        ],
        labelBuilder: (item) => item,
        selectedOf: (_) => null,
        onSelected: (item) => Navigator.of(context).pop(item),
        emptyLabel: context.appLocalizations.proxiesEmpty,
      ),
    );
  }

  Future<String?> _selectDialer(
    BuildContext context,
    WidgetRef ref,
    ClashConfig config, {
    required String proxyName,
    String? current,
  }) {
    final profile = ref.read(profileProvider(profileId));
    final overrides = getChainProxyOverrides(
      profile?.selectedMap ?? const <String, String>{},
    );
    final proxyTypes = {
      for (final proxy in config.proxies) proxy.name: proxy.type,
    };
    final groupTypes = {
      for (final group in config.proxyGroups) group.name: group.type.value,
    };

    final proxyNames = config.proxies
        .map((proxy) => proxy.name)
        .where(
          (name) =>
              name != proxyName &&
              !wouldCreateChainProxyCycle(
                overrides,
                proxyName: proxyName,
                dialerProxy: name,
              ),
        )
        .toList();
    final groupNames = config.proxyGroups
        .map((group) => group.name)
        .where((name) => name != proxyName)
        .toList();

    return showSheet<String>(
      context: context,
      props: const SheetProps(isScrollControlled: true),
      builder: (context) => OverwriteSelectionSheet<String>(
        title: context.appLocalizations.chainProxyFirstHop,
        sections: [
          OverwriteSelectionSection<String>(
            label: context.appLocalizations.proxyGroup,
            items: groupNames,
            subtitleBuilder: (_, name) => groupTypes[name] ?? '',
          ),
          OverwriteSelectionSection<String>(
            label: context.appLocalizations.proxies,
            items: proxyNames,
            subtitleBuilder: (_, name) => proxyTypes[name] ?? '',
          ),
        ],
        labelBuilder: (item) => item,
        selectedOf: (_) => current,
        onSelected: (item) => Navigator.of(context).pop(item),
        emptyLabel: context.appLocalizations.proxiesEmpty,
      ),
    );
  }

  Future<void> _handleAdd(
    BuildContext context,
    WidgetRef ref,
    ClashConfig config,
  ) async {
    final target = await _selectTarget(context, ref, config);
    if (target == null || !context.mounted) {
      return;
    }
    final dialer = await _selectDialer(
      context,
      ref,
      config,
      proxyName: target,
    );
    if (dialer == null) {
      return;
    }
    _updateOverride(ref, proxyName: target, dialerProxy: dialer);
  }

  Future<void> _handleEdit(
    BuildContext context,
    WidgetRef ref,
    ClashConfig config, {
    required String proxyName,
    required String current,
  }) async {
    final dialer = await _selectDialer(
      context,
      ref,
      config,
      proxyName: proxyName,
      current: current,
    );
    if (dialer == null) {
      return;
    }
    _updateOverride(ref, proxyName: proxyName, dialerProxy: dialer);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configState = ref.watch(clashConfigProvider(profileId));
    final config = configState.value;
    final profile = ref.watch(profileProvider(profileId));
    final overrides = getChainProxyOverrides(
      profile?.selectedMap ?? const <String, String>{},
    );
    final entries = overrides.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return CommonScaffold(
      title: context.appLocalizations.proxyChains,
      isLoading: configState.isLoading,
      floatingActionButton: CommonFloatingActionButton(
        icon: const Icon(Icons.add),
        label: context.appLocalizations.add,
        onPressed: config == null
            ? null
            : () => _handleAdd(context, ref, config),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Text(
            context.appLocalizations.chainProxyDesc,
            style: context.textTheme.bodySmall?.copyWith(
              color: context.colorScheme.onSurfaceVariant.opacity80,
            ),
          ),
          const SizedBox(height: 16),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  context.appLocalizations.chainProxyEmpty,
                  style: context.textTheme.bodyMedium,
                ),
              ),
            )
          else
            for (final entry in entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: CommonCard(
                  radius: AppCorner.xl,
                  onPressed: config == null
                      ? null
                      : () => _handleEdit(
                          context,
                          ref,
                          config,
                          proxyName: entry.key,
                          current: entry.value,
                        ),
                  child: ListTile(
                    title: Text('${entry.value}  →  ${entry.key}'),
                    trailing: IconButton(
                      tooltip: context.appLocalizations.delete,
                      onPressed: () => _updateOverride(
                        ref,
                        proxyName: entry.key,
                      ),
                      icon: const Icon(Icons.delete_outline),
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
