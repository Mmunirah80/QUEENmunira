import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../presentation/providers/admin_providers.dart';
import '../presentation/widgets/admin_design_system_widgets.dart';
import 'admin_inspections_screen.dart';
import 'admin_users_screen.dart';

/// Users directory + inspection in one place (replaces a separate bottom-nav tab).
class AdminUsersHubScreen extends ConsumerStatefulWidget {
  const AdminUsersHubScreen({super.key});

  @override
  ConsumerState<AdminUsersHubScreen> createState() => _AdminUsersHubScreenState();
}

class _AdminUsersHubScreenState extends ConsumerState<AdminUsersHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _hub;

  @override
  void initState() {
    super.initState();
    _hub = TabController(length: 2, vsync: this);
    _hub.addListener(_onHubChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final want = ref.read(adminUsersHubTabProvider).clamp(0, 1);
      if (_hub.index != want) {
        _hub.index = want;
      }
    });
  }

  void _onHubChanged() {
    setState(() {});
    if (_hub.indexIsChanging) return;
    ref.read(adminUsersHubTabProvider.notifier).state = _hub.index;
  }

  @override
  void dispose() {
    _hub.removeListener(_onHubChanged);
    _hub.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    ref.listen<int>(adminUsersHubTabProvider, (prev, next) {
      final i = next.clamp(0, 1);
      if (!mounted || _hub.indexIsChanging) return;
      if (_hub.index != i) {
        _hub.animateTo(i);
      }
    });
    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(
        titleSpacing: 20,
        title: const Text('Workspace'),
        actions: const [AdminSignOutIconButton()],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Material(
            color: scheme.surfaceContainerLow,
            child: TabBar(
              key: const ValueKey<String>('adminUsersHubTabBar'),
              controller: _hub,
              indicatorWeight: 3,
              indicatorSize: TabBarIndicatorSize.label,
              overlayColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return scheme.primary.withValues(alpha: 0.12);
                }
                return scheme.primary.withValues(alpha: 0.06);
              }),
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
              labelColor: scheme.primary,
              unselectedLabelColor: scheme.onSurface.withValues(alpha: 0.55),
              indicatorColor: scheme.primary,
              tabs: const [
                Tab(
                  height: 44,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.people_outline, size: 20),
                      SizedBox(width: 8),
                      Text('Directory'),
                    ],
                  ),
                ),
                Tab(
                  height: 44,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.fact_check_outlined, size: 20),
                      SizedBox(width: 8),
                      Text('Kitchen inspection'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _hub,
        children: const [
          AdminUsersScreen(embedded: true),
          AdminInspectionsScreen(embedded: true),
        ],
      ),
    );
  }
}
