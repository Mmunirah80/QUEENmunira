// ============================================================
// FROZEN SCREEN — Account frozen state. RTL, TC theme.
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_design_system.dart';
import '../../auth/presentation/providers/auth_provider.dart';

class _NC {
  static const primary = AppDesignSystem.primary;
  static const primaryLight = AppDesignSystem.primaryLight;
  static const bg = AppDesignSystem.backgroundOffWhite;
  static const text = AppDesignSystem.textPrimary;
  static const textSub = AppDesignSystem.textSecondary;
}

class FrozenScreen extends ConsumerStatefulWidget {
  const FrozenScreen({super.key});

  @override
  ConsumerState<FrozenScreen> createState() => _FrozenScreenState();
}

class _FrozenScreenState extends ConsumerState<FrozenScreen> {
  DateTime? _freezeUntil;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadFreezeUntil();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadFreezeUntil() async {
    final cookId = ref.read(authStateProvider).valueOrNull?.id;
    if (cookId == null || cookId.isEmpty) return;
    try {
      final row = await Supabase.instance.client
          .from('chef_profiles')
          .select('freeze_until')
          .eq('id', cookId)
          .maybeSingle();
      final raw = row?['freeze_until'];
      if (raw is String) {
        setState(() => _freezeUntil = DateTime.tryParse(raw));
      } else if (raw is DateTime) {
        setState(() => _freezeUntil = raw);
      }
    } catch (e) {
      debugPrint('[FrozenScreen] load freeze_until error=$e');
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _freezeUntilLabel() {
    final u = _freezeUntil;
    if (u == null) return 'End date unavailable';
    final local = u.toLocal();
    return DateFormat.yMMMd().add_jm().format(local);
  }

  String _countdownText() {
    if (_freezeUntil == null) return 'Remaining time unavailable';
    final diff = _freezeUntil!.difference(DateTime.now());
    if (diff.isNegative) return 'Freeze period ended';
    final days = diff.inDays;
    final hours = diff.inHours % 24;
    final minutes = diff.inMinutes % 60;
    final d = days == 1 ? 'day' : 'days';
    final h = hours == 1 ? 'hour' : 'hours';
    final m = minutes == 1 ? 'minute' : 'minutes';
    return '$days $d $hours $h $minutes $m remaining';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: _NC.bg,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: _NC.primaryLight.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.ac_unit_rounded, size: 48, color: _NC.primary),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Account Frozen',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _NC.text),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your account is temporarily frozen. You cannot accept orders or edit the menu until the freeze ends.',
                  style: TextStyle(fontSize: 15, color: _NC.textSub, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Until: ${_freezeUntilLabel()}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _NC.text),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _countdownText(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _NC.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'You can still open Notifications for messages from the team.',
                  style: TextStyle(fontSize: 14, color: _NC.textSub, height: 1.45),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => context.push(RouteNames.chefNotifications),
                    icon: const Icon(Icons.notifications_outlined, color: _NC.primary),
                    label: const Text('Open notifications'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _NC.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      await ref.read(authStateProvider.notifier).logout();
                      if (context.mounted) context.go(RouteNames.login);
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: _NC.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Logout'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
