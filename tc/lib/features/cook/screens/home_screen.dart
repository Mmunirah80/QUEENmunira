// ============================================================
// COOK HOME — Naham App, Supabase-backed
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/domain/entities/user_entity.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_design_system.dart';
import '../../../core/utils/supabase_error_message.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../features/menu/data/datasources/seasons_supabase_datasource.dart';
import '../../../core/chef/chef_availability.dart';
import '../../../features/cook/data/models/chef_doc_model.dart';
import '../../../features/menu/domain/entities/dish_entity.dart';
import '../../../features/orders/domain/entities/chef_today_stats.dart';
import '../../../features/orders/presentation/orders_failure.dart';
import '../../../features/notifications/presentation/providers/notifications_provider.dart';
import '../../../features/orders/presentation/providers/orders_provider.dart';
import '../../../services/ai_service.dart';
import '../data/chef_documents_compliance.dart';
import '../data/chef_expired_documents_notify.dart';
import '../presentation/providers/chef_providers.dart';
import '../presentation/widgets/chef_inspection_compliance_banner.dart';
import '../presentation/widgets/cook_freeze_banner.dart';

class _NC {
  static const primary = AppDesignSystem.primary;
  static const primaryDark = AppDesignSystem.primaryDark;
  static const primaryLight = AppDesignSystem.primaryLight;
  static const primaryMid = AppDesignSystem.primaryMid;
  static const primaryGlow = Color(0x309B7EC8);
  static const bg = AppDesignSystem.backgroundOffWhite;
  static const surface = AppDesignSystem.cardWhite;
  static const text = AppDesignSystem.textPrimary;
  static const textSub = AppDesignSystem.textSecondary;
  static const border = Color(0xFFE8E0F5);
  static const error = Color(0xFFD93025);
  static const warning = Color(0xFFF59E0B);
  static const gold = Color(0xFFD97706);
  static const info = Color(0xFF0EA5E9);
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _delayedDismissed = false;
  bool _standingWarningDismissed = false;
  bool _availabilityGuardRunning = false;
  String? _lastPreOpenReminderKey;

  /// Persists across app restarts so we do not duplicate DB rows for the same day/window.
  static const _preOpenReminderPrefsPrefix = 'chef_pre_open_reminder_sent_v1_';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final u = ref.read(authStateProvider).valueOrNull;
      if (u != null && u.isChef) {
        ref.read(selectedRoleProvider.notifier).state = AppRole.chef;
        unawaited(ChefExpiredDocumentsNotify.ping(Supabase.instance.client));
      }
    });
  }

  Future<void> _toggleOnline(
    bool currentIsOnline,
    String chefId, {
    required bool requireApprovedDocsForOnline,
  }) async {
    debugPrint('TOGGLE: chefId=$chefId current=$currentIsOnline');
    try {
      if (!currentIsOnline) {
        final frozen = ref.read(chefDocStreamProvider).valueOrNull?.isFreezeActive ?? false;
        if (frozen) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('You are frozen and cannot turn on availability until the freeze ends.'),
              ),
            );
          }
          return;
        }
      }
      // If switching offline while pending orders exist, ask for confirmation.
      if (!currentIsOnline && requireApprovedDocsForOnline) {
        final docRows = await Supabase.instance.client
            .from('chef_documents')
            .select('document_type,status,expiry_date,created_at')
            .eq('chef_id', chefId);
        final list = (docRows as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        final compliance = ChefDocumentsCompliance.evaluate(list);
        if (!compliance.canReceiveOrders) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Required documents must be approved and not expired. Open Profile → Documents to upload a new version.',
                ),
              ),
            );
          }
          return;
        }
      }
      if (currentIsOnline) {
        final pending = await Supabase.instance.client
            .from('orders')
            .select('id')
            .eq('chef_id', chefId)
            .inFilter('status', ['pending']);
        if ((pending as List).isNotEmpty && mounted) {
          final shouldProceed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Pending orders found'),
              content: const Text(
                'You have pending orders waiting for response. Going offline may affect customer experience. Continue?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Stay online'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Go offline'),
                ),
              ],
            ),
          );
          if (shouldProceed != true) return;
        }
      }
      final result = await Supabase.instance.client
          .from('chef_profiles')
          .update({'is_online': !currentIsOnline})
          .eq('id', chefId);
      debugPrint('TOGGLE RESULT: $result');
      ref.invalidate(chefDocStreamProvider);
    } catch (e) {
      debugPrint('TOGGLE ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Generic error')),
        );
      }
    }
  }

  int? _minutesUntilTodayOpen(String? opensAtLabel, DateTime now) {
    if (opensAtLabel == null) return null;
    final t = opensAtLabel.trim();
    if (t.isEmpty) return null;
    final p = t.split(':');
    if (p.length < 2) return null;
    final h = int.tryParse(p[0]);
    final m = int.tryParse(p[1]);
    if (h == null || m == null) return null;
    if (h < 0 || h > 23 || m < 0 || m > 59) return null;
    final openAt = DateTime(now.year, now.month, now.day, h, m);
    return openAt.difference(now).inMinutes;
  }

  Future<void> _runAvailabilityGuards({
    required String chefId,
    required bool isOnline,
    required ChefStorefrontEvaluation eval,
  }) async {
    if (_availabilityGuardRunning) return;
    _availabilityGuardRunning = true;
    try {
      if (kDebugChefAvailability) {
        debugPrint(
          '[CookHome availabilityGuard] chefId=$chefId dbIsOnline=$isOnline '
          'eval.accepting=${eval.isAcceptingOrders} eval.reason=${eval.reason}',
        );
      }

      // Admin freeze: force offline so storefront and RLS stay aligned.
      if (isOnline && eval.reason == ChefStorefrontReason.frozen) {
        await Supabase.instance.client
            .from('chef_profiles')
            .update({'is_online': false})
            .eq('id', chefId);
        if (mounted) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            const SnackBar(
              content: Text('Your account is frozen. You cannot turn on availability until the freeze ends.'),
            ),
          );
        }
        ref.invalidate(chefDocStreamProvider);
        return;
      }

      // Vacation mode always forces offline.
      if (isOnline && eval.reason == ChefStorefrontReason.vacation) {
        await Supabase.instance.client
            .from('chef_profiles')
            .update({'is_online': false})
            .eq('id', chefId);
        if (mounted) {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            const SnackBar(
              content: Text('Vacation mode is on. Turn it off to reopen your store.'),
            ),
          );
        }
        ref.invalidate(chefDocStreamProvider);
        return;
      }

      // End of working hours: force offline.
      if (isOnline && eval.reason == ChefStorefrontReason.outsideWorkingHours) {
        await Supabase.instance.client
            .from('chef_profiles')
            .update({'is_online': false})
            .eq('id', chefId);
        ref.invalidate(chefDocStreamProvider);
        return;
      }

      // Optional: 15-minute reminder before today's opening time (lightweight).
      if (!isOnline && eval.reason == ChefStorefrontReason.outsideWorkingHours) {
        final now = DateTime.now();
        final mins = _minutesUntilTodayOpen(eval.opensAtLabel, now);
        if (mins != null && mins >= 0 && mins <= 15 && eval.opensAtLabel != null) {
          final dayKey =
              '${now.year}-${now.month}-${now.day}-${eval.opensAtLabel}';
          if (_lastPreOpenReminderKey == dayKey) {
            return;
          }
          final prefs = await SharedPreferences.getInstance();
          if (prefs.getString('$_preOpenReminderPrefsPrefix$chefId') == dayKey) {
            _lastPreOpenReminderKey = dayKey;
            return;
          }
          await Supabase.instance.client.from('notifications').insert({
            'customer_id': chefId,
            'title': 'Working hours reminder',
            'body':
                'Your working hours will start in 15 minutes. Turn on Available Now to start receiving orders.',
            'is_read': false,
            'type': 'availability_reminder',
          });
          await prefs.setString('$_preOpenReminderPrefsPrefix$chefId', dayKey);
          _lastPreOpenReminderKey = dayKey;
          ref.invalidate(chefNotificationsProvider);
        }
      }
    } catch (_) {
      // Guard must be best-effort and never break home rendering.
    } finally {
      _availabilityGuardRunning = false;
    }
  }

  // Seasonal alerts (AI) state
  final AiService _aiService = AiService();
  final SeasonsSupabaseDataSource _seasonsDataSource =
      SeasonsSupabaseDataSource();
  Map<String, dynamic>? _seasonalAlerts;
  bool _seasonalAlertsLoading = false;
  String? _seasonalAlertsError;
  bool _seasonalAlertsRequested = false;

  @override
  Widget build(BuildContext context) {
    final chefDocAsync = ref.watch(chefDocStreamProvider);
    final delayedAsync = ref.watch(chefDelayedOrdersProvider);
    final dishesAsync = ref.watch(chefDishesStreamProvider);
    final user = ref.watch(authStateProvider).valueOrNull;
    final chefId = user?.id;
    final chefName = user?.name ?? 'My Kitchen';

    return Scaffold(
      backgroundColor: _NC.bg,
      body: chefDocAsync.when(
        data: (chefDoc) {
          final isOnline = chefDoc?.isOnline ?? false;
          final vacationMode = chefDoc?.vacationMode ?? false;
          final storefront = chefDoc?.storefrontEvaluation;
          final acceptingCustomers = storefront?.isAcceptingOrders ?? false;
          final workingHours = chefDoc?.workingHoursDisplay ?? '—';
          final kitchenName = chefDoc?.kitchenName ?? chefName;
          final warningCount = chefDoc?.warningCount ?? 0;
          final freezeUntil = chefDoc?.freezeUntil;
          final notifUnread = ref
                  .watch(chefNotificationsProvider)
                  .valueOrNull
                  ?.where((n) => !n.isRead)
                  .length ??
              0;

          if (chefId != null && chefId.isNotEmpty && storefront != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              _runAvailabilityGuards(
                chefId: chefId,
                isOnline: isOnline,
                eval: storefront,
              );
            });
          }

          return Stack(
            children: [
              if (!acceptingCustomers)
                // Semi-transparent overlay behind content only (not over header icons),
                // with IgnorePointer so the toggle remains tappable.
                Positioned.fill(
                  top: kToolbarHeight + MediaQuery.of(context).padding.top,
                  child: IgnorePointer(
                    child: Container(
                      color: Colors.black.withOpacity(0.3),
                    ),
                  ),
                ),
              RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(chefDocStreamProvider);
                  ref.invalidate(chefDishesStreamProvider);
                  ref.invalidate(chefDelayedOrdersProvider);
                  ref.invalidate(chefTodayStatsProvider);
                  ref.invalidate(chefNotificationsProvider);
                },
                child: CustomScrollView(
                  slivers: [
                  _buildHeader(context, kitchenName, notifUnread),
                  if (chefDoc == null) _buildProfileMissingBannerSliver(),
                  if (chefDoc != null && chefDoc.isFreezeActive)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
                        child: CookFreezeBanner(chefDoc: chefDoc),
                      ),
                    ),
                  if (chefDoc != null && chefDoc.inspectionViolationCount > 0 && !chefDoc.isFreezeActive)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
                        child: ChefInspectionComplianceBanner(chefDoc: chefDoc),
                      ),
                    ),
                  if (dishesAsync.maybeWhen(
                    data: (d) => d.isEmpty,
                    orElse: () => false,
                  ))
                    _buildNewKitchenHintSliver(context),
                  if (!_standingWarningDismissed &&
                      warningCount >= 1 &&
                      warningCount < 3 &&
                      freezeUntil == null)
                    _buildStandingWarningBanner(warningCount),
                  if (!_delayedDismissed)
                    delayedAsync.when(
                      data: (delayed) {
                        if (delayed.isEmpty) {
                          return const SliverToBoxAdapter(child: SizedBox.shrink());
                        }
                        return _buildDelayedBanner(context, delayed.length);
                      },
                      loading: () =>
                          const SliverToBoxAdapter(child: SizedBox.shrink()),
                      error: (_, __) =>
                          const SliverToBoxAdapter(child: SizedBox.shrink()),
                    ),
                  _buildStorefrontCard(
                    context,
                    chefId,
                    isOnline,
                    vacationMode,
                    chefDoc,
                    workingHours,
                  ),
                  SliverToBoxAdapter(
                    child: ref.watch(chefTodayStatsProvider).when(
                      data: _buildTodayStats,
                      loading: () => const Padding(
                        padding: EdgeInsets.fromLTRB(16, 24, 16, 0),
                        child: Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                      error: (e, _) => Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              resolveOrdersUiError(e),
                              style: const TextStyle(color: _NC.error, fontSize: 13),
                            ),
                            const SizedBox(height: 8),
                            _buildTodayStats(const ChefTodayStats(
                              completedRevenueToday: 0,
                              completedOrdersToday: 0,
                              inKitchenCountToday: 0,
                              pipelineOrderValueToday: 0,
                            )),
                          ],
                        ),
                      ),
                    ),
                  ),
                  _buildSeasonalAlerts(dishesAsync),
                  _buildDailyCapacity(dishesAsync),
                  const SliverToBoxAdapter(child: SizedBox(height: 16)),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              LoadingWidget(),
              SizedBox(height: 16),
              Text(
                'Loading profile…',
                style: TextStyle(color: _NC.textSub, fontSize: 14),
              ),
            ],
          ),
        ),
        error: (_, __) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Unable to load cook profile.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _NC.textSub),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => ref.invalidate(chefDocStreamProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  SliverToBoxAdapter _buildSeasonalAlerts(
    AsyncValue<List<DishEntity>> dishesAsync,
  ) {
    return dishesAsync.when(
      data: (dishes) {
        if (dishes.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }
        _requestSeasonalAlertsOnce(dishes);

        if (_seasonalAlertsLoading && _seasonalAlerts == null) {
          return SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _NC.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _NC.border),
              ),
              child: Row(
                children: const [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Seasonal check…',
                      style: TextStyle(fontSize: 12, color: _NC.textSub),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final seasonalErr = _seasonalAlertsError;
        if (seasonalErr != null) {
          return SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _NC.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _NC.error.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    seasonalErr,
                    style: const TextStyle(fontSize: 13, color: _NC.error),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _seasonalAlertsError = null;
                        _seasonalAlertsRequested = false;
                        _seasonalAlerts = null;
                      });
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        final alerts = (_seasonalAlerts?['alerts'] as List?) ?? const [];
        final summary = _seasonalAlerts?['summary'] as String? ??
            (alerts.isEmpty ? 'OK' : '${alerts.length} item(s) to review');

        if (alerts.isEmpty) {
          // Only show card if AI has responded at least once
          if (_seasonalAlerts == null) {
            return const SliverToBoxAdapter(child: SizedBox.shrink());
          }
        }

        return SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _NC.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _NC.info.withOpacity(0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.price_change_rounded, color: _NC.info, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    summary,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _NC.text),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: () => context.go(RouteNames.chefMenu),
                  child: const Text('Menu', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const SliverToBoxAdapter(child: SizedBox.shrink()),
      error: (_, __) => const SliverToBoxAdapter(child: SizedBox.shrink()),
    );
  }

  SliverToBoxAdapter _buildStandingWarningBanner(int warningCount) {
    final text = warningCount == 1
        ? 'Warning 1/2'
        : 'Warning 2/2 — freeze risk';
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _NC.warning.withOpacity(0.22),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _NC.warning.withOpacity(0.55)),
        ),
        child: Row(
          children: [
            const Text('⚠️', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _NC.text,
                ),
              ),
            ),
            IconButton(
              onPressed: () => setState(() => _standingWarningDismissed = true),
              icon: const Icon(Icons.close_rounded),
              color: _NC.text,
              iconSize: 18,
              tooltip: 'Dismiss',
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _requestSeasonalAlertsOnce(List<DishEntity> dishes) async {
    if (_seasonalAlertsRequested || dishes.isEmpty) return;
    _seasonalAlertsRequested = true;

    setState(() {
      _seasonalAlertsLoading = true;
      _seasonalAlertsError = null;
    });

    try {
      final menuItems = dishes
          .map<Map<String, dynamic>>(
            (d) => {
              'name': d.name,
              'price': d.price,
              'seasons': <String>[],
              'cost_per_serving': 0,
            },
          )
          .toList();

      Map<String, dynamic> seasonsConfig;
      try {
        seasonsConfig = await _seasonsDataSource.buildSeasonsConfig();
      } catch (_) {
        seasonsConfig = const {
          'ramadan': {'price_increase_pct': 15},
          'eid_fitr': {'price_increase_pct': 20},
          'eid_adha': {'price_increase_pct': 20},
          'winter': {'price_increase_pct': 10},
          'summer': {'price_increase_pct': 5},
          'celebrations': {'price_increase_pct': 25},
          'normal': {'price_increase_pct': 0},
        };
      }

      final res = await _aiService.getMenuSeasonalAlerts(
        menuItems: menuItems,
        currentSeason: 'normal',
        nextSeason: 'ramadan',
        daysToNext: 10,
        seasonsConfig: seasonsConfig,
      );

      if (!mounted) return;
      setState(() {
        _seasonalAlerts = res;
        _seasonalAlertsLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _seasonalAlertsLoading = false;
        final msg = AiService.friendlyAiErrorMessage(e);
        // Never show "session expired" UI to cooks; just treat it as "no alerts" silently.
        if (msg.toLowerCase().contains('session expired')) {
          _seasonalAlertsError = null;
          _seasonalAlerts = const {
            'alerts': <dynamic>[],
            'summary': 'All seasonal items look good.',
          };
        } else {
          _seasonalAlertsError = msg;
        }
      });
    }
  }

  /// Shown when realtime/REST returned no [chef_profiles] row (RLS, network, or parsing).
  SliverToBoxAdapter _buildProfileMissingBannerSliver() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Material(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, color: _NC.info, size: 22),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Kitchen profile data is not available yet (check connection or sign-in). '
                    'Controls below use safe defaults.',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: _NC.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNewKitchenHintSliver(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Material(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => context.go(RouteNames.chefMenu),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.restaurant_menu_rounded, color: _NC.info, size: 22),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Menu empty — add dishes in Menu',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _NC.text,
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: _NC.textSub, size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String kitchenName, int unreadNotifications) {
    return SliverToBoxAdapter(
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          left: 16,
          right: 16,
          bottom: 12,
        ),
        decoration: const BoxDecoration(
          color: _NC.primary,
          borderRadius: BorderRadius.only(
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                kitchenName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Spacer(),
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  onPressed: () => context.go(RouteNames.chefNotifications),
                  icon: const Icon(Icons.notifications_none_rounded, color: Colors.white),
                ),
                if (unreadNotifications > 0)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(minWidth: 18, minHeight: 16),
                      child: Text(
                        unreadNotifications > 9 ? '9+' : '$unreadNotifications',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDelayedBanner(BuildContext context, int delayedCount) {
    return SliverToBoxAdapter(
      child: GestureDetector(
        onTap: () {
          setState(() => _delayedDismissed = true);
          context.go(RouteNames.chefOrders);
        },
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _NC.warning.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: _NC.warning.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.warning_amber_rounded, color: _NC.warning, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Delayed orders',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _NC.text),
                    ),
                    Text(
                      '$delayedCount pending',
                      style: const TextStyle(fontSize: 12, color: _NC.textSub),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: _NC.textSub),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStorefrontCard(
    BuildContext context,
    String? chefId,
    bool isOnline,
    bool vacationMode,
    ChefDocModel? chefDoc,
    String workingHours,
  ) {
    final eval = chefDoc?.storefrontEvaluation ??
        const ChefStorefrontEvaluation(
          isAcceptingOrders: false,
          reason: ChefStorefrontReason.offline,
        );
    final toggleEnabled = eval.reason != ChefStorefrontReason.vacation &&
        eval.reason != ChefStorefrontReason.outsideWorkingHours &&
        eval.reason != ChefStorefrontReason.frozen;
    final openClosed = eval.isAcceptingOrders ? 'OPEN' : 'CLOSED';
    final statusColor = eval.isAcceptingOrders ? _NC.primaryMid : _NC.textSub;

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: _NC.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: eval.isAcceptingOrders ? _NC.primaryMid.withOpacity(0.22) : _NC.border,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x06000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: eval.isAcceptingOrders ? _NC.primaryLight : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.storefront_rounded,
                    color: eval.isAcceptingOrders ? _NC.primaryMid : _NC.textSub,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    openClosed,
                    key: ValueKey(openClosed),
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.2,
                      color: statusColor,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: chefId == null
                      ? null
                      : () async {
                          if (!toggleEnabled) {
                            final msg = switch (eval.reason) {
                              ChefStorefrontReason.frozen =>
                                'You are frozen and cannot turn on availability until the freeze ends.',
                              ChefStorefrontReason.vacation =>
                                'Vacation mode is on. Turn it off to reopen your store.',
                              _ =>
                                'Outside working hours. You can turn on Available Now during working hours only.',
                            };
                            ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                              SnackBar(content: Text(msg)),
                            );
                            return;
                          }
                          await _toggleOnline(
                            isOnline,
                            chefId,
                            requireApprovedDocsForOnline:
                                !(chefDoc?.documentsOperationalOk ?? false),
                          );
                        },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Available',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _NC.textSub,
                        ),
                      ),
                      const SizedBox(height: 4),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 52,
                        height: 30,
                        decoration: BoxDecoration(
                          color: toggleEnabled
                              ? (isOnline ? _NC.primaryMid : const Color(0xFFCCCCCC))
                              : const Color(0xFFDDDDDD),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: AnimatedAlign(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          alignment: isOnline ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            width: 26,
                            height: 26,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: Color(0x30000000), blurRadius: 4)],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(Icons.schedule_rounded, size: 16, color: _NC.textSub),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    workingHours,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _NC.text,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  vacationMode ? Icons.flight_takeoff_rounded : Icons.home_work_outlined,
                  size: 16,
                  color: vacationMode ? _NC.warning : _NC.textSub,
                ),
                const SizedBox(width: 8),
                const Text(
                  'Vacation',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _NC.text),
                ),
                const Spacer(),
                Text(
                  vacationMode ? 'On' : 'Off',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: vacationMode ? _NC.warning : _NC.textSub,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayStats(ChefTodayStats stats) {
    final completed = stats.completedOrdersToday < 0 ? 0 : stats.completedOrdersToday;
    final kitchen = stats.inKitchenCountToday < 0 ? 0 : stats.inKitchenCountToday;
    final touchpoints = completed + kitchen;
    final rev = stats.completedRevenueToday;
    final revLabel = (rev.isNaN || rev.isInfinite) ? '0' : rev.toStringAsFixed(0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Row(
        children: [
          _StatCard(
            '$touchpoints',
            'Orders today',
            Icons.receipt_long_rounded,
            _NC.primaryMid,
            _NC.primaryLight,
          ),
          const SizedBox(width: 12),
          _StatCard(
            revLabel,
            'SAR completed',
            Icons.payments_rounded,
            _NC.gold,
            const Color(0xFFFFF7ED),
          ),
        ],
      ),
    );
  }

  Widget _buildDailyCapacity(AsyncValue<List<DishEntity>> dishesAsync) {
    final dishes = dishesAsync.valueOrNull ?? [];
    final dishMap = {for (var d in dishes) d.id: d.name};

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: _NC.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _NC.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Portions today',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _NC.text,
              ),
            ),
            const SizedBox(height: 8),
            if (dishes.isEmpty)
              const Text(
                'No dishes yet.',
                style: TextStyle(fontSize: 12, color: _NC.textSub),
              )
            else
              ...dishes.map((d) {
                final daily = d.preparationTime < 0 ? 0 : d.preparationTime;
                final on = d.isAvailable;
                final name = dishMap[d.id] ?? d.name;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: _NC.text,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!on)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Off',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _NC.textSub),
                            ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                              icon: const Icon(Icons.add_rounded, size: 20),
                              color: _NC.primaryDark,
                              tooltip: 'Add portions',
                              onPressed: () => _adjustDailyPortions(d, delta: 1),
                            ),
                          ],
                        )
                      else ...[
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          icon: const Icon(Icons.remove_rounded, size: 20),
                          color: _NC.primaryDark,
                          onPressed: () => _adjustDailyPortions(d, delta: -1),
                        ),
                        SizedBox(
                          width: 28,
                          child: Text(
                            '$daily',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _NC.text,
                            ),
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          icon: const Icon(Icons.add_rounded, size: 20),
                          color: _NC.primaryDark,
                          onPressed: () => _adjustDailyPortions(d, delta: 1),
                        ),
                      ],
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Future<void> _adjustDailyPortions(DishEntity d, {required int delta}) async {
    final on = d.isAvailable;
    final daily = d.preparationTime < 0 ? 0 : d.preparationTime;
    if (delta > 0) {
      if (!on) {
        await _saveDailyCapacity({d.id: (on: true, daily: 1)});
        return;
      }
      await _saveDailyCapacity({d.id: (on: true, daily: daily + 1)});
      return;
    }
    if (delta < 0) {
      if (!on) return;
      if (daily > 0) {
        await _saveDailyCapacity({d.id: (on: true, daily: daily - 1)});
      } else {
        await _saveDailyCapacity({d.id: (on: false, daily: 0)});
      }
    }
  }

  Future<void> _saveDailyCapacity(
    Map<String, ({bool on, int daily})> updates,
  ) async {
    final client = Supabase.instance.client;
    final chefId = ref.read(authStateProvider).valueOrNull?.id ?? '';
    if (chefId.isEmpty) return;
    try {
      for (final entry in updates.entries) {
        final dishId = entry.key;
        final newOn = entry.value.on;
        final newDaily = entry.value.daily < 0 ? 0 : entry.value.daily;

        final row = await client
            .from('menu_items')
            .select('daily_quantity, remaining_quantity, is_available')
            .eq('id', dishId)
            .eq('chef_id', chefId)
            .maybeSingle();

        final oldDaily = (row?['daily_quantity'] as num?)?.toInt() ?? 0;
        final oldRem = (row?['remaining_quantity'] as num?)?.toInt() ?? oldDaily;
        final wasOn = row?['is_available'] == true;

        int newRem;
        if (!newOn) {
          newRem = 0;
        } else if (!wasOn) {
          newRem = newDaily;
        } else if (newDaily > oldDaily) {
          newRem = oldRem + (newDaily - oldDaily);
          if (newRem > newDaily) newRem = newDaily;
        } else {
          newRem = oldRem > newDaily ? newDaily : oldRem;
        }

        await client.from('menu_items').update({
          'is_available': newOn,
          'daily_quantity': newDaily,
          'remaining_quantity': newRem,
        }).eq('id', dishId).eq('chef_id', chefId);
      }

      ref.invalidate(chefDishesStreamProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(userFriendlyErrorMessage(e))),
      );
    }
  }

}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final Color bg;

  const _StatCard(this.value, this.label, this.icon, this.color, this.bg);

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _NC.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _NC.border),
            boxShadow: const [
              BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 17),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: color),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(fontSize: 10, color: _NC.textSub),
              ),
            ],
          ),
        ),
      );
}

