// ============================================================
// COOK PROFILE — Supabase-backed, RTL, TC theme. Vacation + working hours.
// ============================================================

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_design_system.dart';
import '../../auth/screens/login_screen.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/utils/supabase_error_message.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../notifications/presentation/providers/notifications_provider.dart';
import '../data/models/chef_doc_model.dart';
import '../presentation/providers/chef_providers.dart';
import '../dev/cook_dev_review.dart';
import 'bank_account_screen.dart';
import '_time_chip.dart';
import 'earnings_screen.dart';
import 'documents_screen.dart';
import '../../customer/screens/map_pin_picker_screen.dart';
import 'package:latlong2/latlong.dart';

class _C {
  static const primary = AppDesignSystem.primary;
  static const primaryDark = AppDesignSystem.primaryDark;
  static const primaryLight = AppDesignSystem.primaryLight;
  static const bg = AppDesignSystem.backgroundOffWhite;
  static const surface = AppDesignSystem.cardWhite;
  static const text = AppDesignSystem.textPrimary;
  static const textSub = AppDesignSystem.textSecondary;
}

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _devSimulateBusy = false;

  Future<void> _afterSimulateRefresh() async {
    await ref.read(authStateProvider.notifier).refreshUser();
    ref.invalidate(chefDocStreamProvider);
    ref.invalidate(chefNotificationsProvider);
  }

  Future<void> _runSimulateApprove() async {
    if (_devSimulateBusy) return;
    setState(() => _devSimulateBusy = true);
    try {
      await CookDevReview.simulateApprove();
      await _afterSimulateRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Simulate approve: same RPC as admin (check Notifications + Support chat).')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userFriendlyErrorMessage(e)),
            backgroundColor: AppDesignSystem.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _devSimulateBusy = false);
    }
  }

  Future<void> _runSimulateReject() async {
    if (_devSimulateBusy) return;
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => const _SimulateChefRejectReasonDialog(),
    );
    if (reason == null || reason.isEmpty) return;
    setState(() => _devSimulateBusy = true);
    try {
      await CookDevReview.simulateReject(reason: reason);
      await _afterSimulateRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Simulate reject: same RPC as admin (check Notifications + Support chat).')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userFriendlyErrorMessage(e)),
            backgroundColor: AppDesignSystem.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _devSimulateBusy = false);
    }
  }

  Widget _buildDevSimulateSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF59E0B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.science_outlined, size: 20, color: Color(0xFFB45309)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Simulation mode: document review (temporary)',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: Color(0xFF92400E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Calls apply_chef_document_review — the same RPC as the admin panel (notifications + Support chat).\n'
            'Run supabase_apply_chef_document_review.sql, then enable DB flag:\n'
            'UPDATE dev_feature_flags SET enabled = true WHERE key = \'chef_document_review_simulation\';\n'
            'Use for QA only; disable flag in production.',
            style: TextStyle(fontSize: 11, color: Color(0xFFB45309)),
          ),
          const SizedBox(height: 12),
          if (_devSimulateBusy)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(child: LinearProgressIndicator()),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _runSimulateApprove,
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF16A34A)),
                    child: const Text('Simulate Approve'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: _runSimulateReject,
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEA580C)),
                    child: const Text('Simulate Reject'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chefDocAsync = ref.watch(chefDocStreamProvider);
    final user = ref.watch(authStateProvider).valueOrNull;
    final chefId = user?.id;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: _C.bg,
        body: chefDocAsync.when(
          data: (chefDoc) {
            final kitchenName = chefDoc?.kitchenName ?? user?.name ?? '—';
            final isOnline = chefDoc?.isOnline ?? false;
            final workingHours = chefDoc?.workingHoursDisplay ?? '—';
            final warningCount = chefDoc?.warningCount ?? 0;
            final freezeUntil = chefDoc?.freezeUntil;

            if (freezeUntil != null && freezeUntil.isAfter(DateTime.now()) && warningCount >= 1 && warningCount < 3) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  context.go(RouteNames.chefFrozen);
                }
              });
            }

            // If blocked, redirect to dedicated blocked screen so cook cannot access other screens.
            if (warningCount >= 3) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  context.go(RouteNames.accountSuspended);
                }
              });
            }

            return Column(
              children: [
                _buildHeader(context, user?.name ?? '—', kitchenName),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildVerificationCard(context, chefId, isOnline),
                        const SizedBox(height: 16),
                        _buildWorkingHoursCard(workingHours),
                        const SizedBox(height: 16),
                        if (chefDoc != null) _buildProfileDetailsCard(context, chefDoc!),
                        if (chefDoc != null) const SizedBox(height: 16),
                        _buildOptions(context, chefDoc, warningCount, freezeUntil),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: LoadingWidget()),
          error: (e, _) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(userFriendlyErrorMessage(e), textAlign: TextAlign.center, style: const TextStyle(color: AppDesignSystem.errorRed)),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => ref.invalidate(chefDocStreamProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String name, String kitchenName) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 20,
        bottom: 30,
        left: 16,
        right: 16,
      ),
      decoration: const BoxDecoration(
        color: _C.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  image: null,
                ),
                child: const Icon(Icons.person_rounded, size: 48, color: Colors.white),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute<void>(builder: (_) => const EditProfileScreen()),
                  ),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt_rounded, size: 16, color: _C.primary),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            name,
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text(
            kitchenName,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _statItem('—', 'Orders'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem(String value, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildVerificationCard(BuildContext context, String? chefId, bool isOnline) {
    final chefDoc = ref.read(chefDocStreamProvider).valueOrNull;
    final vacationOn = chefDoc?.vacationMode ?? false;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: _C.primaryLight.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.beach_access_rounded, color: _C.primary, size: 24),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Vacation mode: hide your kitchen from customers', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text('Turn this on when you are away. Your kitchen will be hidden and you will not receive new orders.', style: TextStyle(color: _C.textSub, fontSize: 12)),
                ],
              ),
            ),
            Switch(
              value: vacationOn,
              onChanged: chefId == null || chefId.isEmpty
                  ? null
                  : (v) async {
                      try {
                        final client = Supabase.instance.client;
                        if (v) {
                          await client
                              .from('chef_profiles')
                              .update({'vacation_mode': true, 'is_online': false})
                              .eq('id', chefId);
                        } else {
                          await client
                              .from('chef_profiles')
                              .update({'vacation_mode': false})
                              .eq('id', chefId);
                        }
                        ref.invalidate(chefDocStreamProvider);
                      } catch (_) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Generic error')),
                          );
                        }
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkingHoursCard(String workingHours) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GestureDetector(
        onTap: () {
          _openWorkingHoursEditor(context);
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _C.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.schedule_rounded, size: 22, color: _C.primary),
              const SizedBox(width: 12),
              const Text('Working hours', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(width: 12),
              Expanded(child: Text(workingHours, style: const TextStyle(fontSize: 13, color: _C.textSub))),
              const Icon(Icons.edit_calendar_rounded, size: 18, color: _C.textSub),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openWorkingHoursEditor(BuildContext context) async {
    final chefId = ref.read(authStateProvider).valueOrNull?.id;
    if (chefId == null || chefId.isEmpty) return;
    final chefDoc = ref.read(chefDocStreamProvider).valueOrNull;
    final existing = Map<String, dynamic>.from(chefDoc?.workingHours ?? {});
    const days = [
      'Mon',
      'Tue',
      'Wed',
      'Thu',
      'Fri',
      'Sat',
      'Sun',
    ];
    final friendly = {
      'Mon': 'Monday',
      'Tue': 'Tuesday',
      'Wed': 'Wednesday',
      'Thu': 'Thursday',
      'Fri': 'Friday',
      'Sat': 'Saturday',
      'Sun': 'Sunday',
    };

    Map<String, dynamic> local = {};
    for (final d in days) {
      final v = existing[d];
      if (v is Map) {
        local[d] = {
          'enabled': true,
          'open': v['open'] ?? '09:00',
          'close': v['close'] ?? '21:00',
        };
      } else {
        local[d] = {
          'enabled': false,
          'open': '09:00',
          'close': '21:00',
        };
      }
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateSheet) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Working hours per day',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        children: days.map((d) {
                          final row = local[d] as Map<String, dynamic>;
                          final enabled = row['enabled'] as bool;
                          final open = row['open'] as String;
                          final close = row['close'] as String;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    friendly[d] ?? d,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Switch(
                                  value: enabled,
                                  onChanged: (v) {
                                    setStateSheet(() {
                                      row['enabled'] = v;
                                    });
                                  },
                                ),
                                const SizedBox(width: 4),
                                TimeChip(
                                  label: open,
                                  enabled: enabled,
                                  onTap: () async {
                                    final picked = await showTimePicker(
                                      context: ctx,
                                      initialTime: _parseTimeOfDay(open),
                                    );
                                    if (picked != null) {
                                      setStateSheet(() {
                                        row['open'] =
                                            picked.format(ctx).padLeft(5, '0');
                                      });
                                    }
                                  },
                                ),
                                const Text(' - '),
                                TimeChip(
                                  label: close,
                                  enabled: enabled,
                                  onTap: () async {
                                    final picked = await showTimePicker(
                                      context: ctx,
                                      initialTime: _parseTimeOfDay(close),
                                    );
                                    if (picked != null) {
                                      setStateSheet(() {
                                        row['close'] =
                                            picked.format(ctx).padLeft(5, '0');
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final Map<String, dynamic> toSave = {};
                        for (final d in days) {
                          final row = local[d] as Map<String, dynamic>;
                          if (row['enabled'] == true) {
                            toSave[d] = {
                              'open': row['open'],
                              'close': row['close'],
                            };
                          }
                        }
                        try {
                          await ref
                              .read(chefFirebaseDataSourceProvider)
                              .setWorkingHours(chefId, toSave);
                          ref.invalidate(chefDocStreamProvider);
                          if (Navigator.canPop(ctx)) Navigator.pop(ctx);
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Generic error')),
                            );
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _C.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Save',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  TimeOfDay _parseTimeOfDay(String value) {
    try {
      final parts = value.split(':');
      if (parts.length != 2) return const TimeOfDay(hour: 9, minute: 0);
      final h = int.tryParse(parts[0]) ?? 9;
      final m = int.tryParse(parts[1]) ?? 0;
      return TimeOfDay(hour: h.clamp(0, 23), minute: m.clamp(0, 59));
    } catch (_) {
      return const TimeOfDay(hour: 9, minute: 0);
    }
  }

  Widget _buildProfileDetailsCard(BuildContext context, ChefDocModel chefDoc) {
    final bio = chefDoc.bio?.trim();
    final kitchenCity = chefDoc.kitchenCity?.trim();
    final bankIban = chefDoc.bankIban?.trim();
    final hasAny = (bio != null && bio.isNotEmpty) ||
        (kitchenCity != null && kitchenCity.isNotEmpty) ||
        (bankIban != null && bankIban.isNotEmpty);
    if (!hasAny) return const SizedBox.shrink();

    String maskIban(String? value) {
      if (value == null || value.length < 4) return value ?? '—';
      return '•••• ${value.substring(value.length - 4)}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (bio != null && bio.isNotEmpty) ...[
              const Text('About', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _C.textSub)),
              const SizedBox(height: 4),
              Text(bio, style: const TextStyle(fontSize: 14, color: _C.text)),
              const SizedBox(height: 12),
            ],
            if (kitchenCity != null && kitchenCity.isNotEmpty) ...[
              const Text('Kitchen city', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _C.textSub)),
              const SizedBox(height: 4),
              Text(kitchenCity, style: const TextStyle(fontSize: 14, color: _C.text)),
              const SizedBox(height: 12),
            ],
            if (bankIban != null && bankIban.isNotEmpty) ...[
              const Text('IBAN number', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: _C.textSub)),
              const SizedBox(height: 4),
              Text(maskIban(bankIban), style: const TextStyle(fontSize: 14, color: _C.text, fontFamily: 'monospace')),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOptions(
    BuildContext context,
    ChefDocModel? chefDoc,
    int warningCount,
    DateTime? freezeUntil,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _optionCard(
            icon: Icons.edit_outlined,
            title: 'Edit profile',
            subtitle: 'Name, kitchen, phone',
            onTap: () => Navigator.push<void>(context, MaterialPageRoute<void>(builder: (_) => const EditProfileScreen())),
          ),
          _optionCard(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            subtitle: 'Updates from the team',
            onTap: () => context.push(RouteNames.chefNotifications),
          ),
          _optionCard(
            icon: Icons.description_outlined,
            title: 'Documents',
            subtitle: 'ID, licenses, certificates',
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(builder: (_) => const DocumentsScreen()),
            ),
          ),
          _optionCard(
            icon: Icons.verified_user_outlined,
            title: 'Clean record',
            subtitle: 'Inspections & account standing',
            onTap: () {
              final wc = warningCount;
              final fu = freezeUntil;
              Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => CleanRecordScreen(
                    warningCount: wc,
                    freezeUntil: fu,
                  ),
                ),
              );
            },
          ),
          _optionCard(
            icon: Icons.account_balance_outlined,
            title: 'Bank account',
            subtitle: 'IBAN number',
            onTap: () => Navigator.push<void>(context, MaterialPageRoute<void>(builder: (_) => const BankAccountScreen())),
          ),
          _optionCard(
            icon: Icons.bar_chart_rounded,
            title: 'Earnings & Insights',
            subtitle: 'Revenue, charts',
            onTap: () => Navigator.push<void>(context, MaterialPageRoute<void>(builder: (_) => const EarningsScreen())),
          ),
          if (CookDevReview.simulationModeEnabled) ...[
            const SizedBox(height: 8),
            _buildDevSimulateSection(),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                await ref.read(authStateProvider.notifier).logout();
                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => LoginScreen()),
                  (route) => false,
                );
              },
              icon: const Icon(Icons.logout_rounded, color: AppDesignSystem.errorRed, size: 20),
              label: const Text('Log out', style: TextStyle(color: AppDesignSystem.errorRed, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppDesignSystem.errorRed),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _optionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: _C.primaryLight.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: _C.primary, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(subtitle, style: const TextStyle(color: _C.textSub, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_left, color: _C.textSub),
          ],
        ),
      ),
    );
  }
}

// ─── Edit Profile Screen ─────────────────────────────────────────────
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late TextEditingController _nameCtrl;
  late TextEditingController _kitchenCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _locationCtrl;
  late TextEditingController _bioCtrl;
  bool _loading = false;
  Uint8List? _avatarBytes;
  double? _kitchenLat;
  double? _kitchenLng;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _kitchenCtrl = TextEditingController();
    _phoneCtrl = TextEditingController();
    _locationCtrl = TextEditingController();
    _bioCtrl = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = ref.read(authStateProvider).valueOrNull;
    final chefDoc = ref.read(chefDocStreamProvider).valueOrNull;
    if (_nameCtrl.text.isEmpty && user != null) {
      _nameCtrl.text = user.name;
      _kitchenCtrl.text = chefDoc?.kitchenName ?? user.name;
      _phoneCtrl.text = user.phone ?? '';
      _locationCtrl.text = chefDoc?.kitchenCity ?? '';
      _bioCtrl.text = chefDoc?.bio ?? '';
      _kitchenLat = chefDoc?.kitchenLatitude;
      _kitchenLng = chefDoc?.kitchenLongitude;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _kitchenCtrl.dispose();
    _phoneCtrl.dispose();
    _locationCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _save(BuildContext context) async {
    final chefId = ref.read(authStateProvider).valueOrNull?.id;
    if (chefId == null || chefId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Auth error')));
      return;
    }
    setState(() => _loading = true);
    try {
      debugPrint('[CookProfile] Updating chef profile for id=$chefId');
      final client = SupabaseConfig.client;
      final profilesUpdates = <String, dynamic>{
        'full_name': _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        'bio': _bioCtrl.text.trim().isEmpty ? null : _bioCtrl.text.trim(),
      };
      await ref.read(chefFirebaseDataSourceProvider).updateChefProfile(
            chefId,
            kitchenName: _kitchenCtrl.text.trim().isEmpty ? null : _kitchenCtrl.text.trim(),
            bio: _bioCtrl.text.trim().isEmpty ? null : _bioCtrl.text.trim(),
            kitchenCity: _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
            kitchenLatitude: _kitchenLat,
            kitchenLongitude: _kitchenLng,
          );
      if (_avatarBytes != null) {
        final path = 'chef_avatars/$chefId.jpg';
        debugPrint('[CookProfile] Uploading avatar to $path');
        await client.storage.from('avatars').uploadBinary(
              path,
              _avatarBytes!,
              fileOptions: const FileOptions(
                upsert: true,
                contentType: 'image/jpeg',
              ),
            );
        profilesUpdates['avatar_url'] = client.storage.from('avatars').getPublicUrl(path);
      }
      await client.from('profiles').update(profilesUpdates).eq('id', chefId);
      ref.invalidate(chefDocStreamProvider);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      debugPrint('[CookProfile] Save error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generic error')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: _C.bg,
        body: Column(
          children: [
            Container(
              color: _C.primary,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 20, 20),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      ),
                      const Expanded(
                        child: Text(
                          'Edit profile',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16, 20, 16, MediaQuery.of(context).viewInsets.bottom + 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Stack(
                        children: [
                          Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _C.primaryLight.withValues(alpha: 0.5),
                              border: Border.all(color: _C.primary.withValues(alpha: 0.3), width: 3),
                            ),
                          child: const Center(child: Text('👩‍🍳', style: TextStyle(fontSize: 44))),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () async {
                                final picker = ImagePicker();
                                final picked = await picker.pickImage(
                                  source: ImageSource.gallery,
                                  imageQuality: 85,
                                );
                                if (picked == null || !mounted) return;
                                final bytes = await picked.readAsBytes();
                                setState(() {
                                  _avatarBytes = bytes;
                                });
                              },
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  size: 16,
                                  color: _C.primary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _FormCard(
                      title: 'Basic information',
                      icon: Icons.person_outline_rounded,
                      fields: [
                        _FormField(label: 'Cook name', controller: _nameCtrl),
                        _FormField(label: 'Kitchen name', controller: _kitchenCtrl),
                        _FormField(label: 'About the kitchen', controller: _bioCtrl, maxLines: 3),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _FormCard(
                      title: 'Contact',
                      icon: Icons.phone_outlined,
                      fields: [
                        _FormField(label: 'Phone number', controller: _phoneCtrl, keyboard: TextInputType.phone),
                        _FormField(label: 'Location (area label)', controller: _locationCtrl),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Material(
                      color: _C.surface,
                      borderRadius: BorderRadius.circular(16),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () async {
                          final initial = LatLng(
                            _kitchenLat ?? 24.7136,
                            _kitchenLng ?? 46.6753,
                          );
                          final result = await Navigator.of(context, rootNavigator: true).push<LatLng>(
                            MaterialPageRoute<LatLng>(
                              fullscreenDialog: true,
                              builder: (_) => MapPinPickerScreen(initial: initial),
                            ),
                          );
                          if (result != null && mounted) {
                            setState(() {
                              _kitchenLat = result.latitude;
                              _kitchenLng = result.longitude;
                            });
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(Icons.pin_drop_rounded, color: _C.primary, size: 28),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Pickup point on map',
                                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _kitchenLat != null && _kitchenLng != null
                                          ? '${_kitchenLat!.toStringAsFixed(5)}, ${_kitchenLng!.toStringAsFixed(5)}'
                                          : 'Tap to set. Customers use this pin for distance.',
                                      style: TextStyle(fontSize: 12, color: _C.textSub),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded, color: _C.textSub),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : () => _save(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _C.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _loading
                            ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Save changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> fields;

  const _FormCard({required this.title, required this.icon, required this.fields});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _C.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: _C.primary),
                const SizedBox(width: 8),
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _C.text)),
              ],
            ),
            const SizedBox(height: 16),
            ...fields.map((f) => Padding(padding: const EdgeInsets.only(bottom: 12), child: f)),
          ],
        ),
      );
}

class _FormField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final TextInputType? keyboard;
  final int maxLines;

  const _FormField({required this.label, required this.controller, this.keyboard, this.maxLines = 1});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _C.textSub)),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboard,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _C.text),
            decoration: InputDecoration(
              filled: true,
              fillColor: _C.bg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _C.primary, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ],
      );
}

class _StandingStage {
  final String label;
  final String emoji;
  const _StandingStage(this.label, this.emoji);
}

class CleanRecordScreen extends StatelessWidget {
  const CleanRecordScreen({
    super.key,
    required this.warningCount,
    required this.freezeUntil,
  });

  final int warningCount;
  final DateTime? freezeUntil;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    int activeIndex;
    int? daysRemaining;

    if (warningCount >= 3) {
      activeIndex = 5; // Blocked
    } else if (freezeUntil != null && warningCount >= 1) {
      final diff = freezeUntil!.difference(now).inDays + 1;
      daysRemaining = diff < 0 ? 0 : diff;
      if (daysRemaining <= 3) {
        activeIndex = 2;
      } else if (daysRemaining <= 7) {
        activeIndex = 3;
      } else {
        activeIndex = 4;
      }
    } else if (warningCount == 1) {
      activeIndex = 1;
    } else {
      activeIndex = 0;
    }

    final stages = const [
      _StandingStage('Clean (no violations)', '🟢'),
      _StandingStage('Warning (first notice)', '🟠'),
      _StandingStage('Frozen 3 days (second strike)', '🔵'),
      _StandingStage('Frozen 7 days (third strike)', '🔵'),
      _StandingStage('Frozen 14 days (fourth strike)', '🔵'),
      _StandingStage('Blocked (account closed)', '⚫'),
    ];

    final isBlocked = warningCount >= 3 && freezeUntil == null;

    final content = Scaffold(
      appBar: AppBar(
        title: const Text('Clean record'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your standing updates when admins run inspections. '
              'Missing a call or not meeting requirements moves you to the next stage.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            if (warningCount == 1 && freezeUntil == null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4E5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFF59E0B)),
                ),
                child: const Text(
                  'You received a warning',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF92400E),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            Expanded(
              child: ListView.separated(
                itemCount: stages.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final s = stages[index];
                  final isActive = index == activeIndex;
                  Color bg;
                  Color border;
                  Color textColor;
                  if (isActive) {
                    if (index == 0) {
                      bg = const Color(0xFFE6F4EA);
                      border = const Color(0xFF1E8E3E);
                      textColor = const Color(0xFF1E8E3E);
                    } else if (index == 1) {
                      bg = const Color(0xFFFFF4E5);
                      border = const Color(0xFFF59E0B);
                      textColor = const Color(0xFF92400E);
                    } else if (index >= 2 && index <= 4) {
                      bg = const Color(0xFFE0F2FE);
                      border = const Color(0xFF38BDF8);
                      textColor = const Color(0xFF0F172A);
                    } else {
                      bg = const Color(0xFF000000);
                      border = const Color(0xFF000000);
                      textColor = Colors.white;
                    }
                  } else {
                    bg = Colors.white;
                    border = const Color(0xFFE5E7EB);
                    textColor = const Color(0xFF374151);
                  }

                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: border),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.emoji,
                          style: const TextStyle(fontSize: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            s.label,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight:
                                  isActive ? FontWeight.w700 : FontWeight.w500,
                              color: textColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            if (freezeUntil != null && warningCount >= 1 && warningCount < 3)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Builder(
                  builder: (context) {
                    final diff = freezeUntil!.difference(now);
                    final totalSeconds = diff.inSeconds < 0 ? 0 : diff.inSeconds;
                    final days = totalSeconds ~/ (24 * 3600);
                    final hours = (totalSeconds % (24 * 3600)) ~/ 3600;
                    return Text(
                      '$days days, $hours hours remaining',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );

    final isFrozen = freezeUntil != null && warningCount >= 1 && warningCount < 3;

    if (!isBlocked && !isFrozen) return content;

    if (isBlocked) {
      return Stack(
        children: [
          content,
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.95),
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Account Blocked',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'You can no longer use this platform due to repeated violations.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        // Placeholder: could open support chat or email.
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Contact support coming soon.')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text('Contact Support'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Frozen overlay
    return Stack(
      children: [
        content,
        Positioned.fill(
          child: Container(
            color: const Color(0xFF0EA5E9).withOpacity(0.9),
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Account Frozen',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Builder(
                    builder: (context) {
                      final diff = freezeUntil!.difference(now);
                      final totalSeconds =
                          diff.inSeconds < 0 ? 0 : diff.inSeconds;
                      final days = totalSeconds ~/ (24 * 3600);
                      final hours = (totalSeconds % (24 * 3600)) ~/ 3600;
                      return Text(
                        '$days days, $hours hours remaining',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SimulateChefRejectReasonDialog extends StatefulWidget {
  const _SimulateChefRejectReasonDialog();

  @override
  State<_SimulateChefRejectReasonDialog> createState() => _SimulateChefRejectReasonDialogState();
}

class _SimulateChefRejectReasonDialogState extends State<_SimulateChefRejectReasonDialog> {
  final TextEditingController _reason = TextEditingController();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Simulate reject — reason'),
      content: TextField(
        controller: _reason,
        decoration: const InputDecoration(hintText: 'Reason (sent like real admin reject)'),
        maxLines: 3,
        autofocus: true,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final t = _reason.text.trim();
            if (t.isEmpty) {
              ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                const SnackBar(content: Text('Enter a reason.')),
              );
              return;
            }
            Navigator.pop(context, t);
          },
          child: const Text('Reject'),
        ),
      ],
    );
  }
}
