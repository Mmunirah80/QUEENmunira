import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_names.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../presentation/widgets/admin_design_system_widgets.dart';

/// Privacy, cookies, and sign-out (opened from Dashboard — header stays minimal).
class AdminSettingsScreen extends ConsumerWidget {
  const AdminSettingsScreen({super.key});

  void _showManageCookiesInfo(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Manage cookies',
              style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Text(
              'Use this area for your cookie banner, consent choices, and links to your privacy policy when you connect them (e.g. web view or policy URL).',
              style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                    height: 1.4,
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAndLogout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out'),
        content: const Text('You will need to sign in again to use the admin panel.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign out')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await ref.read(authStateProvider.notifier).logout();
    if (context.mounted) context.go(RouteNames.login);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: const AdminAppBarTitle(
          title: 'Privacy & cookies',
          subtitle: 'Session & preferences',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AdminPanelTokens.cardRadiusLarge)),
            elevation: 0,
            color: scheme.surfaceContainerLowest,
            shadowColor: scheme.shadow.withValues(alpha: 0.08),
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.privacy_tip_outlined, color: scheme.primary),
                  title: const Text('Manage cookies'),
                  subtitle: const Text('Cookie preferences and related data choices'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _showManageCookiesInfo(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.logout_rounded, color: scheme.error),
                  title: const Text('Sign out'),
                  subtitle: const Text('End this admin session'),
                  onTap: () => _confirmAndLogout(context, ref),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
