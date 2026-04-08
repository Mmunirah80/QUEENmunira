import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/debug/debug_auth_bypass.dart';
import 'core/routing/app_router.dart';
import 'core/theme/naham_theme.dart';
import 'core/supabase/supabase_config.dart';
import 'features/auth/presentation/providers/auth_provider.dart';

void _showDebugAuthRoleDialog(WidgetRef ref, DebugRole current) {
  final navCtx = appRootNavigatorKey.currentContext;
  if (navCtx == null) {
    return;
  }
  final router = ref.read(routerProvider);
  showDialog<void>(
    context: navCtx,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Debug auth role (mock)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              title: const Text('Chef (c001)'),
              trailing: current == DebugRole.chef ? const Icon(Icons.check) : null,
              onTap: () {
                Navigator.pop(dialogContext);
                ref.read(debugAuthRoleProvider.notifier).state = DebugRole.chef;
                router.go(DebugAuthBypass.homeRouteFor(DebugRole.chef));
              },
            ),
            ListTile(
              title: const Text('Customer (c003)'),
              trailing: current == DebugRole.customer ? const Icon(Icons.check) : null,
              onTap: () {
                Navigator.pop(dialogContext);
                ref.read(debugAuthRoleProvider.notifier).state = DebugRole.customer;
                router.go(DebugAuthBypass.homeRouteFor(DebugRole.customer));
              },
            ),
            ListTile(
              title: const Text('Admin (a001)'),
              trailing: current == DebugRole.admin ? const Icon(Icons.check) : null,
              onTap: () {
                Navigator.pop(dialogContext);
                ref.read(debugAuthRoleProvider.notifier).state = DebugRole.admin;
                router.go(DebugAuthBypass.homeRouteFor(DebugRole.admin));
              },
            ),
          ],
        ),
      );
    },
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseConfig.init();

  if (kDebugMode && kIsWeb) {
    debugPrint('[WEB] app started mockAuth=$authBypassIsOn');
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(
    const ProviderScope(
      child: NahamApp(),
    ),
  );
}

class NahamApp extends ConsumerWidget {
  const NahamApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: NahamTheme.lightTheme,
      routerConfig: router,
      builder: (context, child) {
        if (!authBypassIsOn) {
          return child ?? const SizedBox.shrink();
        }
        return Consumer(
          builder: (context, ref, _) {
            final role = ref.watch(debugAuthRoleProvider);
            return Stack(
              fit: StackFit.expand,
              children: [
                if (child != null) child,
                Positioned(
                  top: MediaQuery.paddingOf(context).top + 4,
                  right: 6,
                  child: Material(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(8),
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.all(6),
                      icon: const Icon(Icons.bug_report, color: Colors.white, size: 22),
                      onPressed: () => _showDebugAuthRoleDialog(ref, role),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
