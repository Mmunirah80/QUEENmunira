// ============================================================
// FROZEN SCREEN — Account frozen state. RTL, TC theme.
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

  String _countdownText() {
    if (_freezeUntil == null) return 'Freeze end time unavailable';
    final diff = _freezeUntil!.difference(DateTime.now());
    if (diff.isNegative) return 'Freeze period ended';
    final days = diff.inDays;
    final hours = diff.inHours % 24;
    final minutes = diff.inMinutes % 60;
    final seconds = diff.inSeconds % 60;
    return '$days d $hours h $minutes m $seconds s remaining';
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
                  'Account frozen',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _NC.text),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your account is temporarily frozen. You can continue after the timer ends.',
                  style: TextStyle(fontSize: 15, color: _NC.textSub, height: 1.5),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  _countdownText(),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _NC.primary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
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
                    child: const Text('Sign out'),
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
