// ============================================================
// COOK HOME — Naham App, Supabase-backed
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
import '../presentation/providers/chef_providers.dart';

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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final u = ref.read(authStateProvider).valueOrNull;
      if (u != null && u.isChef) {
        ref.read(selectedRoleProvider.notifier).state = AppRole.chef;
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
      // Highest priority: vacation mode always forces offline.
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
          final key =
              '${now.year}-${now.month}-${now.day}-${eval.opensAtLabel}';
          if (_lastPreOpenReminderKey != key) {
            _lastPreOpenReminderKey = key;
            await Supabase.instance.client.from('notifications').insert({
              'customer_id': chefId,
              'title': 'Working hours reminder',
              'body':
                  'Your working hours will start in 15 minutes. Turn on Available Now to start receiving orders.',
              'is_read': false,
              'type': 'availability_reminder',
            });
            ref.invalidate(chefNotificationsProvider);
          }
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
                  _buildOnlineCard(
                    context,
                    chefId,
                    chefName,
                    isOnline,
                    kitchenName,
                    vacationMode,
                    chefDoc,
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
                        child: Text(
                          resolveOrdersUiError(e),
                          style: const TextStyle(color: _NC.error, fontSize: 13),
                        ),
                      ),
                    ),
                  ),
                  _buildSeasonalAlerts(dishesAsync),
                  _buildTodayWorkHours(context, workingHours),
                  _buildDailyCapacity(dishesAsync),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: LoadingWidget()),
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
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _NC.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _NC.border),
              ),
              child: Row(
                children: const [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Checking seasonal price suggestions...',
                      style: TextStyle(fontSize: 13, color: _NC.textSub),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (_seasonalAlertsError != null) {
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
                    _seasonalAlertsError!,
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
            (alerts.isEmpty
                ? 'All seasonal items look good.'
                : 'You have ${alerts.length} item(s) that may need a price review.');

        if (alerts.isEmpty) {
          // Only show card if AI has responded at least once
          if (_seasonalAlerts == null) {
            return const SliverToBoxAdapter(child: SizedBox.shrink());
          }
        }

        return SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _NC.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _NC.info.withOpacity(0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _NC.info.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.price_change_rounded,
                    color: _NC.info,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Seasonal alerts',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _NC.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        summary,
                        style: const TextStyle(fontSize: 12, color: _NC.textSub),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => context.go(RouteNames.chefMenu),
                  child: const Text(
                    'Review menu',
                    style: TextStyle(fontSize: 12),
                  ),
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
        ? 'Warning 1 of 2: Keep your clean record to avoid suspension'
        : 'Warning 2 of 2: Next strike freezes your account for 3 days';
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        padding: const EdgeInsets.all(12),
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
            'alerts': [],
            'summary': 'All seasonal items look good.',
          };
        } else {
          _seasonalAlertsError = msg;
        }
      });
    }
  }

  Widget _buildNewKitchenHintSliver(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Material(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => context.go(RouteNames.chefMenu),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _NC.info.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.restaurant_menu_rounded, color: _NC.info, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your menu is empty',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _NC.text,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'New kitchen: add dishes from the Menu tab. Orders and earnings stay at 0 until you publish items.',
                          style: TextStyle(fontSize: 12, color: _NC.textSub),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: _NC.textSub),
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
          top: MediaQuery.of(context).padding.top + 12,
          left: 16,
          right: 16,
          bottom: 16,
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome back',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  kitchenName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
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
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF7ED),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _NC.warning.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _NC.warning.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.warning_amber_rounded, color: _NC.warning, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Delayed Orders',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _NC.text),
                    ),
                    Text(
                      '$delayedCount order(s) need attention',
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

  Widget _buildOnlineCard(
    BuildContext context,
    String? chefId,
    String chefName,
    bool isOnline,
    String kitchenName,
    bool vacationMode,
    ChefDocModel? chefDoc,
  ) {
    final eval = chefDoc?.storefrontEvaluation ??
        const ChefStorefrontEvaluation(
          isAcceptingOrders: false,
          reason: ChefStorefrontReason.offline,
        );
    final toggleEnabled = eval.reason != ChefStorefrontReason.vacation &&
        eval.reason != ChefStorefrontReason.outsideWorkingHours;
    final statusText = () {
      switch (eval.reason) {
        case ChefStorefrontReason.vacation:
          return 'Vacation mode is on. Customers cannot place orders. Open Profile to turn it off.';
        case ChefStorefrontReason.outsideWorkingHours:
          if (eval.opensAtLabel != null) {
            return 'Outside working hours. Customers see you as closed. Opens today at ${eval.opensAtLabel}.';
          }
          return 'Closed today.';
        case ChefStorefrontReason.offline:
          return 'Available now is off. Turn it on to start accepting orders during working hours.';
        case ChefStorefrontReason.accepting:
          return 'You are open and accepting orders.';
      }
    }();
    final headline = eval.reason == ChefStorefrontReason.vacation
        ? '🌴 On vacation'
        : eval.reason == ChefStorefrontReason.outsideWorkingHours
            ? '🔴 Outside working hours'
            : eval.isAcceptingOrders
                ? '🟢 Open, accepting orders'
                : '⚪ Temporarily closed';
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _NC.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: eval.isAcceptingOrders ? _NC.primaryMid.withOpacity(0.3) : _NC.border,
          ),
          boxShadow: [
            BoxShadow(
              color: eval.isAcceptingOrders ? _NC.primaryGlow : const Color(0x08000000),
              blurRadius: eval.isAcceptingOrders ? 16 : 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: eval.isAcceptingOrders ? _NC.primaryLight : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.storefront_rounded,
                color: eval.isAcceptingOrders ? _NC.primaryMid : _NC.textSub,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    kitchenName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _NC.text,
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      headline,
                      key: ValueKey(headline),
                      style: TextStyle(
                        fontSize: 12,
                        color: eval.isAcceptingOrders
                            ? _NC.primaryMid
                            : vacationMode
                                ? _NC.warning
                                : _NC.textSub,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: 12,
                      color: eval.reason == ChefStorefrontReason.vacation
                          ? _NC.warning
                          : eval.reason == ChefStorefrontReason.outsideWorkingHours
                              ? _NC.info
                              : _NC.textSub,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: chefId == null
                  ? null
                  : () async {
                      if (!toggleEnabled) {
                        final msg = eval.reason == ChefStorefrontReason.vacation
                            ? 'Vacation mode is on. Turn it off to reopen your store.'
                            : 'Outside working hours. You can turn on Available Now during working hours only.';
                        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                          SnackBar(content: Text(msg)),
                        );
                        return;
                      }
                      await _toggleOnline(
                        isOnline,
                        chefId,
                        requireApprovedDocsForOnline:
                            (chefDoc?.approvalStatus?.toLowerCase() != 'approved'),
                      );
                    },
              child: AnimatedContainer(
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayStats(ChefTodayStats stats) {
    final touchpoints = stats.completedOrdersToday + stats.inKitchenCountToday;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
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
            stats.completedRevenueToday.toStringAsFixed(0),
            'SAR completed',
            Icons.payments_rounded,
            _NC.gold,
            const Color(0xFFFFF7ED),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayWorkHours(BuildContext context, String workingHours) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _NC.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _NC.border),
          boxShadow: const [
            BoxShadow(color: Color(0x08000000), blurRadius: 12, offset: Offset(0, 4)),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: _NC.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.schedule_rounded, color: _NC.primaryMid, size: 18),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Today's Hours",
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _NC.text),
                      ),
                      Text(
                        'Working hours',
                        style: TextStyle(fontSize: 12, color: _NC.textSub),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: _NC.primaryLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.access_time_rounded, size: 16, color: _NC.primaryMid),
                  const SizedBox(width: 8),
                  Text(
                    workingHours,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _NC.primaryMid),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDailyCapacity(AsyncValue<List<DishEntity>> dishesAsync) {
    final dishes = dishesAsync.valueOrNull ?? [];
    final dishMap = {for (var d in dishes) d.id: d.name};

    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _NC.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _NC.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Text(
                    'Daily capacity',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _NC.text,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: dishes.isEmpty
                      ? null
                      : () => _openDailyCapacitySheet(context),
                  child: const Text('Edit plan'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Plan how many portions you will cook today.',
              style: const TextStyle(fontSize: 13, color: _NC.textSub),
            ),
            const SizedBox(height: 12),
            if (dishes.isEmpty)
              const Text(
                'No dishes in your menu yet.',
                style: TextStyle(fontSize: 13, color: _NC.textSub),
              )
            else
              ...dishes.map((d) {
                // Source of truth: menu_items daily_quantity / remaining_quantity (stream).
                final total = d.preparationTime;
                final remaining = d.remainingQuantity;
                final soldOut = total > 0 && remaining <= 0;
                final name = dishMap[d.id] ?? d.name;
                return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          fontSize: 13,
                          color: soldOut ? _NC.textSub : _NC.text,
                          decoration: soldOut ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _editDishRemainingQuantity(
                        context,
                        dishId: d.id,
                        currentRemaining: remaining,
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: soldOut ? _NC.textSub.withOpacity(0.1) : _NC.primaryLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          total == 0
                              ? 'Not set'
                              : soldOut
                                  ? 'Sold out • Tap to restock'
                                  : '$remaining / $total',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: soldOut ? _NC.textSub : _NC.primaryMid,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Future<void> _openDailyCapacitySheet(BuildContext context) async {
    final dishesAsync = ref.read(chefDishesStreamProvider);
    final dishes = dishesAsync.valueOrNull ?? [];
    if (dishes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have no menu items yet.')),
      );
      return;
    }

    final quantities = <String, int>{};
    final originalQuantities = <String, int>{};
    try {
      final dishIds = dishes.map((d) => d.id).where((id) => id.isNotEmpty).toList();
      final rows = dishIds.isEmpty
          ? const <dynamic>[]
          : await Supabase.instance.client
              .from('menu_items')
              .select('id,daily_quantity')
              .inFilter('id', dishIds);
      final qtyById = <String, int>{};
      for (final row in (rows as List)) {
        final m = row as Map<String, dynamic>;
        final id = (m['id'] ?? '').toString();
        final raw = m['daily_quantity'];
        final qty = raw is num ? raw.toInt() : int.tryParse('$raw') ?? 0;
        if (id.isNotEmpty) qtyById[id] = qty < 0 ? 0 : qty;
      }
      for (final d in dishes) {
        final current = qtyById[d.id] ?? (d.preparationTime < 0 ? 0 : d.preparationTime);
        quantities[d.id] = current;
        originalQuantities[d.id] = current;
      }
    } catch (e) {
      // Fallback safely to existing dish snapshot values.
      debugPrint('[CookHome] load daily quantity error=$e');
      for (final d in dishes) {
        final current = d.preparationTime < 0 ? 0 : d.preparationTime;
        quantities[d.id] = current;
        originalQuantities[d.id] = current;
      }
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Set today\'s capacity',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Choose how many portions of each dish you will prepare today.',
                    style: TextStyle(fontSize: 13, color: _NC.textSub),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 320,
                    child: ListView.separated(
                      itemCount: dishes.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final d = dishes[index];
                        final current = quantities[d.id] ?? 0;
                        return ListTile(
                          title: Text(d.name),
                          subtitle: const Text(
                            'Today\'s portions',
                            style: TextStyle(fontSize: 12, color: _NC.textSub),
                          ),
                          trailing: SizedBox(
                            width: 150,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline),
                                  color: _NC.primaryDark,
                                  onPressed: () {
                                    final newValue = (quantities[d.id] ?? 0) - 1;
                                    final clamped = newValue < 0 ? 0 : newValue;
                                    setModalState(() {
                                      quantities[d.id] = clamped;
                                    });
                                  },
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  child: Text(
                                    '$current',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline),
                                  color: _NC.primaryDark,
                                  onPressed: () {
                                    final newValue = (quantities[d.id] ?? 0) + 1;
                                    setModalState(() {
                                      quantities[d.id] = newValue;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final changed = <String, int>{};
                        for (final entry in quantities.entries) {
                          final before = originalQuantities[entry.key] ?? 0;
                          if (entry.value != before) {
                            changed[entry.key] = entry.value;
                          }
                        }
                        if (changed.isEmpty) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('No capacity changes to save.')),
                            );
                          }
                          return;
                        }
                        Navigator.pop(context);
                        await _saveDailyCapacity(context, changed);
                      },
                      child: const Text('Save for today'),
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

  Future<void> _saveDailyCapacity(
    BuildContext context,
    Map<String, int> quantities,
  ) async {
    final client = Supabase.instance.client;
    final chefId = ref.read(authStateProvider).valueOrNull?.id ?? '';
    try {
      for (final entry in quantities.entries) {
        final dishId = entry.key;
        final newDaily = entry.value;
        if (newDaily < 0) continue;
        if (chefId.isEmpty) continue;

        final row = await client
            .from('menu_items')
            .select('daily_quantity, remaining_quantity')
            .eq('id', dishId)
            .eq('chef_id', chefId)
            .maybeSingle();

        final oldDaily = (row?['daily_quantity'] as num?)?.toInt() ?? 0;
        final oldRem = (row?['remaining_quantity'] as num?)?.toInt() ?? oldDaily;

        int newRem;
        if (newDaily > oldDaily) {
          newRem = oldRem + (newDaily - oldDaily);
          if (newRem > newDaily) newRem = newDaily;
        } else {
          newRem = oldRem > newDaily ? newDaily : oldRem;
        }

        await client.from('menu_items').update({
          'daily_quantity': newDaily,
          'remaining_quantity': newRem,
        }).eq('id', dishId).eq('chef_id', chefId);
      }

      ref.invalidate(chefDishesStreamProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Today\'s capacity saved.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFriendlyErrorMessage(e))),
        );
      }
    }
  }

  Future<void> _editDishRemainingQuantity(
    BuildContext context, {
    required String dishId,
    required int currentRemaining,
  }) async {
    final ctrl = TextEditingController(text: currentRemaining.toString());
    final next = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Update remaining quantity'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Remaining quantity'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.pop(ctx, int.tryParse(ctrl.text.trim()) ?? currentRemaining),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (next == null) return;
    try {
      final chefId = ref.read(authStateProvider).valueOrNull?.id ?? '';
      var query = Supabase.instance.client
          .from('menu_items')
          .update({'remaining_quantity': next < 0 ? 0 : next})
          .eq('id', dishId);
      if (chefId.isNotEmpty) {
        query = query.eq('chef_id', chefId);
      }
      await query;
      ref.invalidate(chefDishesStreamProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFriendlyErrorMessage(e))),
        );
      }
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
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _NC.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _NC.border),
            boxShadow: const [
              BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 3)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color),
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

