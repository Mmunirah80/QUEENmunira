// ============================================================
// COOK PROFILE — Supabase-backed, RTL, TC theme. Vacation + working hours.
// ============================================================

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/chef/chef_availability.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/validation/naham_validators.dart';
import '../../../core/theme/app_design_system.dart';
import '../../auth/domain/entities/user_entity.dart';
import '../../auth/screens/login_screen.dart';
import '../../../core/supabase/supabase_config.dart';
import '../../../core/utils/supabase_error_message.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../data/models/chef_doc_model.dart';
import '../presentation/providers/chef_providers.dart';
import '../presentation/widgets/cook_freeze_banner.dart';
import 'bank_account_screen.dart';
import '_time_chip.dart';
import 'earnings_screen.dart';
import 'documents_screen.dart';
import '../../customer/screens/map_pin_picker_screen.dart';
import 'package:latlong2/latlong.dart';

class _C {
  static const primary = AppDesignSystem.primary;
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

            return Column(
              children: [
                _buildHeader(context, user?.name ?? '—', kitchenName),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildRejectionReasonNotices(context, user, chefDoc),
                        _buildVerificationCard(context, chefId, isOnline),
                        if (chefDoc != null && !chefDoc.hasKitchenMapPin) ...[
                          const SizedBox(height: 16),
                          _buildKitchenLocationRequiredBanner(context),
                        ],
                        if (chefDoc != null && chefDoc.isFreezeActive) ...[
                          const SizedBox(height: 16),
                          CookFreezeBanner(chefDoc: chefDoc),
                        ],
                        const SizedBox(height: 16),
                        _buildWorkingHoursCard(workingHours),
                        const SizedBox(height: 16),
                        if (chefDoc != null) _buildProfileDetailsCard(context, chefDoc),
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
        ],
      ),
    );
  }

  /// Shows admin rejection reasons from [chef_profiles] (account or document suspension).
  Widget _buildRejectionReasonNotices(
    BuildContext context,
    UserEntity? user,
    ChefDocModel? chefDoc,
  ) {
    final accountReason = (user?.rejectionReason ?? '').trim();
    final suspensionReason = (chefDoc?.suspensionReason ?? '').trim();
    final showAccount = user != null &&
        user.isChef &&
        user.isChefPartialAccess &&
        accountReason.isNotEmpty;
    final showSuspension =
        chefDoc != null && chefDoc.suspended && suspensionReason.isNotEmpty;

    if (!showAccount && !showSuspension) {
      return const SizedBox.shrink();
    }

    void openDocuments() {
      Navigator.push<void>(
        context,
        MaterialPageRoute<void>(builder: (_) => const DocumentsScreen()),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showAccount) ...[
            _rejectionNoticeCard(
              title: 'Application update',
              body: accountReason,
              onOpenDocuments: openDocuments,
            ),
            if (showSuspension) const SizedBox(height: 12),
          ],
          if (showSuspension)
            _rejectionNoticeCard(
              title: 'Document review',
              body: suspensionReason,
              onOpenDocuments: openDocuments,
            ),
        ],
      ),
    );
  }

  Widget _rejectionNoticeCard({
    required String title,
    required String body,
    required VoidCallback onOpenDocuments,
  }) {
    return Material(
      color: AppDesignSystem.errorRed.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14,
                color: AppDesignSystem.errorRed,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: const TextStyle(fontSize: 13, height: 1.35, color: _C.text),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                onPressed: onOpenDocuments,
                child: const Text('Open Documents'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKitchenLocationRequiredBanner(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.pin_drop_rounded, color: Colors.orange.shade800, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Set your kitchen location',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.orange.shade900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Add a map pin in Edit profile so customers can discover your kitchen by distance.',
                      style: TextStyle(fontSize: 13, height: 1.35, color: _C.text),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () => Navigator.push<void>(
                        context,
                        MaterialPageRoute<void>(builder: (_) => const EditProfileScreen()),
                      ),
                      child: const Text('Open Edit profile'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(userFriendlyErrorMessage(e)),
                            ),
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
                                        row['open'] = _timeOfDayToHHmm(picked);
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
                                        row['close'] = _timeOfDayToHHmm(picked);
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
                            final open = (row['open'] as String?)?.trim() ?? '';
                            final close = (row['close'] as String?)?.trim() ?? '';
                            final openErr = NahamValidators.timeHHmm(open);
                            final closeErr = NahamValidators.timeHHmm(close);
                            if (openErr != null || closeErr != null) {
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '${friendly[d] ?? d}: ${openErr ?? closeErr}',
                                    ),
                                  ),
                                );
                              }
                              return;
                            }
                            toSave[d] = {
                              'open': open,
                              'close': close,
                            };
                          }
                        }
                        try {
                          final doc = ref.read(chefDocStreamProvider).valueOrNull;
                          final currentOnline = doc?.isOnline ?? false;
                          await ref
                              .read(chefFirebaseDataSourceProvider)
                              .setWorkingHours(chefId, toSave);
                          final eval = evaluateChefStorefront(
                            vacationMode: doc?.vacationMode ?? false,
                            isOnline: currentOnline,
                            workingHoursStart: doc?.workingHoursStart,
                            workingHoursEnd: doc?.workingHoursEnd,
                            workingHoursJson: toSave,
                            vacationRangeStart: doc?.vacationStart,
                            vacationRangeEnd: doc?.vacationEnd,
                            freezeUntil: doc?.freezeUntil,
                            freezeType: doc?.freezeType,
                          );
                          if (!eval.isAcceptingOrders && currentOnline) {
                            await Supabase.instance.client
                                .from('chef_profiles')
                                .update({'is_online': false})
                                .eq('id', chefId);
                          }
                          ref.invalidate(chefDocStreamProvider);
                          if (Navigator.canPop(ctx)) Navigator.pop(ctx);
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(userFriendlyErrorMessage(e)),
                              ),
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

  /// Persisted + parsed working times are strict 24h `HH:mm` (availability engine).
  static String _timeOfDayToHHmm(TimeOfDay t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  TimeOfDay _parseTimeOfDay(String value) {
    try {
      final trimmed = value.trim();
      // Strict 24h H:mm or HH:mm
      final h24 = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(trimmed);
      if (h24 != null) {
        final h = int.tryParse(h24.group(1)!) ?? 9;
        final m = int.tryParse(h24.group(2)!) ?? 0;
        return TimeOfDay(hour: h.clamp(0, 23), minute: m.clamp(0, 59));
      }
      // Legacy rows: locale picker strings e.g. "9:00 AM"
      final h12 = RegExp(
        r'^(\d{1,2}):(\d{2})\s*([AaPp][Mm])',
      ).firstMatch(trimmed.replaceAll('\u202f', ' '));
      if (h12 != null) {
        var h = int.tryParse(h12.group(1)!) ?? 9;
        final m = int.tryParse(h12.group(2)!) ?? 0;
        final ap = h12.group(3)!.toUpperCase();
        if (ap == 'PM' && h < 12) h += 12;
        if (ap == 'AM' && h == 12) h = 0;
        return TimeOfDay(hour: h.clamp(0, 23), minute: m.clamp(0, 59));
      }
      return const TimeOfDay(hour: 9, minute: 0);
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
            icon: Icons.fact_check_outlined,
            title: 'Kitchen inspections',
            subtitle: 'History & compliance',
            onTap: () => context.push(RouteNames.chefComplianceHistory),
          ),
          _optionCard(
            icon: Icons.description_outlined,
            title: 'Documents',
            subtitle: () {
              final iv = chefDoc?.inspectionViolationCount ?? 0;
              if (iv > 0) {
                return 'ID, licenses… · $iv inspection violation${iv == 1 ? '' : 's'} on record';
              }
              return 'ID, licenses, certificates';
            }(),
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(builder: (_) => const DocumentsScreen()),
            ),
          ),
          _optionCard(
            icon: Icons.verified_user_outlined,
            title: 'Clean record',
            subtitle: 'Standing & compliance',
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
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                await ref.read(authStateProvider.notifier).logout();
                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
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

enum _RecordStanding { clean, warning, frozen, blocked }

class CleanRecordScreen extends StatelessWidget {
  const CleanRecordScreen({
    super.key,
    required this.warningCount,
    required this.freezeUntil,
  });

  final int warningCount;
  final DateTime? freezeUntil;

  static _RecordStanding _computeStanding(DateTime now, int warningCount, DateTime? freezeUntil) {
    if (warningCount >= 3) return _RecordStanding.blocked;
    if (freezeUntil != null && freezeUntil.isAfter(now) && warningCount >= 1) {
      return _RecordStanding.frozen;
    }
    if (warningCount >= 1) return _RecordStanding.warning;
    return _RecordStanding.clean;
  }

  static Widget _standingRow({
    required String title,
    required String badge,
    required Color badgeColor,
    required bool active,
  }) {
    final border = active ? badgeColor : const Color(0xFFE5E7EB);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: active ? badgeColor.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border, width: active ? 1.5 : 1),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: const Color(0xFF111827),
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              badge,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: badgeColor,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final standing = _computeStanding(now, warningCount, freezeUntil);
    final isBlocked = warningCount >= 3 && freezeUntil == null;

    final content = Scaffold(
      appBar: AppBar(
        title: const Text('Clean record'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _standingRow(
            title: 'Clean',
            badge: 'Clean',
            badgeColor: const Color(0xFF1E8E3E),
            active: standing == _RecordStanding.clean,
          ),
          const SizedBox(height: 8),
          _standingRow(
            title: 'Warning',
            badge: 'Warning',
            badgeColor: const Color(0xFFD97706),
            active: standing == _RecordStanding.warning,
          ),
          const SizedBox(height: 8),
          _standingRow(
            title: 'Frozen',
            badge: 'Frozen',
            badgeColor: const Color(0xFF0284C7),
            active: standing == _RecordStanding.frozen,
          ),
          const SizedBox(height: 8),
          _standingRow(
            title: 'Blocked',
            badge: 'Blocked',
            badgeColor: const Color(0xFFB91C1C),
            active: standing == _RecordStanding.blocked,
          ),
          if (freezeUntil != null && warningCount >= 1 && warningCount < 3) ...[
            const SizedBox(height: 12),
            Builder(
              builder: (context) {
                final diff = freezeUntil!.difference(now);
                final totalSeconds = diff.inSeconds < 0 ? 0 : diff.inSeconds;
                final days = totalSeconds ~/ (24 * 3600);
                final hours = (totalSeconds % (24 * 3600)) ~/ 3600;
                return Text(
                  'Freeze: $days d, $hours h left',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                );
              },
            ),
          ],
        ],
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
