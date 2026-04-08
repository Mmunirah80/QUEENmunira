import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/route_names.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

/// Spacing, radii, shadows, and surfaces for admin screens (8 / 12 / 16 / 24 grid).
abstract final class AdminPanelTokens {
  static const double space8 = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space20 = 20;
  static const double space24 = 24;

  /// Cards and large surfaces.
  static const double cardRadius = 18;
  static const double cardRadiusLarge = 20;

  /// Primary actions.
  static const double buttonRadius = 14;
  static const double buttonMinHeight = 48;

  /// Soft layered shadow — presentation-ready cards (not flat).
  static List<BoxShadow> cardShadow(BuildContext context) {
    final s = Theme.of(context).colorScheme.shadow.withValues(alpha: 0.10);
    return [
      BoxShadow(
        color: s,
        blurRadius: 24,
        offset: const Offset(0, 8),
        spreadRadius: -2,
      ),
      BoxShadow(
        color: Theme.of(context).colorScheme.shadow.withValues(alpha: 0.04),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ];
  }

  /// Soft elevation only — no strong outline.
  static BoxDecoration surfaceCard(BuildContext context, ColorScheme scheme) => BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(cardRadius),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.06)),
        boxShadow: cardShadow(context),
      );

  /// Use with [FilledButton.styleFrom] / [OutlinedButton.styleFrom] `shape`.
  static RoundedRectangleBorder roundedButtonShape() => RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(buttonRadius),
      );
}

/// Admin UI tokens: role and sender colors (food marketplace admin).
abstract final class AdminUiColors {
  /// Cook / kitchen — light purple surface.
  static const Color cookSurface = Color(0xFFEDE7F6);
  static const Color cookOnSurface = Color(0xFF4A148C);

  /// Customer — dark navy.
  static const Color customerSurface = Color(0xFF1A237E);
  static const Color customerOnSurface = Colors.white;

  /// Admin — neutral gray.
  static const Color adminSurface = Color(0xFFE0E0E0);
  static const Color adminOnSurface = Color(0xFF424242);
}

/// User directory: Customer / Cook / Admin.
enum AdminUserRoleLabel {
  customer,
  cook,
  admin,
}

extension AdminUserRoleLabelX on AdminUserRoleLabel {
  String get displayName => switch (this) {
        AdminUserRoleLabel.customer => 'Customer',
        AdminUserRoleLabel.cook => 'Cook',
        AdminUserRoleLabel.admin => 'Admin',
      };

  (Color bg, Color fg) get colors => switch (this) {
        AdminUserRoleLabel.cook => (AdminUiColors.cookSurface, AdminUiColors.cookOnSurface),
        AdminUserRoleLabel.customer => (AdminUiColors.customerSurface, AdminUiColors.customerOnSurface),
        AdminUserRoleLabel.admin => (AdminUiColors.adminSurface, AdminUiColors.adminOnSurface),
      };
}

AdminUserRoleLabel? adminUserRoleFromDbRole(String? role) {
  switch ((role ?? '').toLowerCase()) {
    case 'chef':
    case 'cook':
      return AdminUserRoleLabel.cook;
    case 'customer':
      return AdminUserRoleLabel.customer;
    case 'admin':
      return AdminUserRoleLabel.admin;
    default:
      return null;
  }
}

/// Single primary cook account state for admin lists (cooks only in UI copy).
enum CookAccountState {
  clean,
  warning,
  frozen,
  blocked,
}

class CookAccountStateDisplay {
  const CookAccountStateDisplay({
    required this.state,
    this.subtitle,
    this.frozenRemainingDays,
  });

  final CookAccountState state;
  /// e.g. soft/hard freeze details (secondary line under the badge title).
  final String? subtitle;
  /// Days left in freeze window (for Frozen tier colors and "Frozen • N days").
  final int? frozenRemainingDays;

  String get label => switch (state) {
        CookAccountState.clean => 'Clean',
        CookAccountState.warning => 'Warning',
        CookAccountState.frozen => 'Frozen',
        CookAccountState.blocked => 'Blocked',
      };

  /// Icon + text (not color-only); used on cook directory cards.
  String get primaryBadgeLine {
    switch (state) {
      case CookAccountState.clean:
        return '✅ Clean';
      case CookAccountState.warning:
        return '⚠️ Warning';
      case CookAccountState.frozen:
        final d = frozenRemainingDays ?? 1;
        final unit = d == 1 ? 'day' : 'days';
        return '❄️ Frozen • $d $unit';
      case CookAccountState.blocked:
        return '⛔ Blocked';
    }
  }

  Color accentColor(BuildContext context) {
    return switch (state) {
      CookAccountState.clean => const Color(0xFF2E7D32),
      CookAccountState.warning => const Color(0xFFF9A825),
      CookAccountState.frozen => _frozenAccentColor(frozenRemainingDays ?? 1),
      CookAccountState.blocked => const Color(0xFF212121),
    };
  }
}

/// Blue shades by remaining freeze length: longer freeze → darker blue.
Color _frozenAccentColor(int daysRemaining) {
  final d = daysRemaining.clamp(1, 365);
  if (d >= 10) return const Color(0xFF0D47A1); // ~14d tier — very dark blue
  if (d >= 4) return const Color(0xFF1565C0); // ~7d — medium blue
  return const Color(0xFF64B5F6); // ~3d — light blue
}

/// Derive one state: blocked → Blocked; active freeze → Frozen; warnings → Warning; else Clean.
CookAccountStateDisplay cookAccountStateForProfile({
  required bool isBlocked,
  required int warningCount,
  required DateTime? freezeUntil,
  String? freezeType,
}) {
  final now = DateTime.now();
  if (isBlocked) {
    return const CookAccountStateDisplay(state: CookAccountState.blocked, subtitle: 'Account blocked');
  }
  if (freezeUntil != null && freezeUntil.isAfter(now)) {
    final diff = freezeUntil.difference(now);
    final daysLeft = (diff.inHours / 24.0).ceil().clamp(1, 9999);
    final formatted = DateFormat.yMMMd().format(freezeUntil.toLocal());
    final mode =
        (freezeType ?? 'soft').toLowerCase().trim() == 'hard' ? 'Hard freeze' : 'Soft freeze';
    final sub = '$mode · until $formatted';
    return CookAccountStateDisplay(
      state: CookAccountState.frozen,
      frozenRemainingDays: daysLeft,
      subtitle: sub,
    );
  }
  if (warningCount > 0) {
    return CookAccountStateDisplay(
      state: CookAccountState.warning,
      subtitle: warningCount == 1 ? '1 warning on record' : '$warningCount warnings on record',
    );
  }
  return const CookAccountStateDisplay(state: CookAccountState.clean);
}

class AdminRoleBadge extends StatelessWidget {
  const AdminRoleBadge({super.key, required this.role});

  final AdminUserRoleLabel role;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = role.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        role.displayName,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
      ),
    );
  }
}

class CookAccountStateBadge extends StatelessWidget {
  const CookAccountStateBadge({super.key, required this.display});

  final CookAccountStateDisplay display;

  @override
  Widget build(BuildContext context) {
    final c = display.accentColor(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AdminPanelTokens.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            display.primaryBadgeLine,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: c,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                  height: 1.25,
                ),
          ),
          if (display.subtitle != null && display.subtitle!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              display.subtitle!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class AdminStatCard extends StatelessWidget {
  const AdminStatCard({
    super.key,
    required this.title,
    required this.value,
    this.onTap,
  });

  final String title;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(AdminPanelTokens.cardRadius);
    final inner = Padding(
      padding: const EdgeInsets.all(AdminPanelTokens.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 24,
                  height: 1.1,
                  color: scheme.onSurface,
                ),
          ),
          const SizedBox(height: AdminPanelTokens.space8),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                  fontSize: 12.5,
                  height: 1.2,
                ),
          ),
        ],
      ),
    );
    if (onTap == null) {
      return DecoratedBox(
        decoration: AdminPanelTokens.surfaceCard(context, scheme),
        child: inner,
      );
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Ink(
          decoration: AdminPanelTokens.surfaceCard(context, scheme),
          child: inner,
        ),
      ),
    );
  }
}

class AdminSectionHeader extends StatelessWidget {
  const AdminSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, AdminPanelTokens.space24, 0, AdminPanelTokens.space12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        height: 1.25,
                      ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AdminPanelTokens.space8),
                    child: Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 12.5,
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w400,
                          ),
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Chat thread: who sent the message (admin monitor).
enum AdminMessageSenderRole {
  customer,
  cook,
  admin,
  unknown,
}

extension AdminMessageSenderRoleX on AdminMessageSenderRole {
  String get label => switch (this) {
        AdminMessageSenderRole.customer => 'Customer',
        AdminMessageSenderRole.cook => 'Cook',
        AdminMessageSenderRole.admin => 'Admin',
        AdminMessageSenderRole.unknown => 'Participant',
      };

  (Color bg, Color fg) get bubbleColors => switch (this) {
        AdminMessageSenderRole.cook => (AdminUiColors.cookSurface, AdminUiColors.cookOnSurface),
        AdminMessageSenderRole.customer => (AdminUiColors.customerSurface, AdminUiColors.customerOnSurface),
        AdminMessageSenderRole.admin => (AdminUiColors.adminSurface, AdminUiColors.adminOnSurface),
        AdminMessageSenderRole.unknown => (const Color(0xFFF5F5F5), const Color(0xFF616161)),
      };
}

AdminMessageSenderRole resolveAdminMessageSenderRole({
  required String senderId,
  required String adminId,
  required String? conversationType,
  required String customerId,
  required String chefId,
}) {
  final s = senderId.trim();
  final a = adminId.trim();
  if (s.isEmpty) return AdminMessageSenderRole.unknown;
  if (a.isNotEmpty && s == a) return AdminMessageSenderRole.admin;

  final t = (conversationType ?? '').toLowerCase();
  if (t == 'chef-admin') {
    // Only admin and cook participate; non-admin senders are the cook.
    return AdminMessageSenderRole.cook;
  }
  if (t == 'customer-support') {
    if (customerId.isNotEmpty && s == customerId) return AdminMessageSenderRole.customer;
    return AdminMessageSenderRole.unknown;
  }
  // customer–chef order chat
  if (chefId.isNotEmpty && s == chefId) return AdminMessageSenderRole.cook;
  if (customerId.isNotEmpty && s == customerId) return AdminMessageSenderRole.customer;
  return AdminMessageSenderRole.unknown;
}

class AdminMessageSenderChip extends StatelessWidget {
  const AdminMessageSenderChip({super.key, required this.role, this.displayName});

  final AdminMessageSenderRole role;
  /// Resolved participant name (customer / cook / admin) when known.
  final String? displayName;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = role.bubbleColors;
    final n = displayName?.trim();
    final text = (n != null && n.isNotEmpty) ? n : role.label;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
      ),
    );
  }
}

// --- SaaS-style dashboard KPIs & shared chrome --------------------------------

/// Accent for [AdminKpiCard] (subtle tinted surface + icon).
enum AdminKpiAccent {
  orders,
  cooks,
  risk,
  reports,
  activePipeline,
  pending,
}

extension AdminKpiAccentX on AdminKpiAccent {
  (Color bg, Color fg, IconData icon) resolve(ColorScheme scheme) {
    return switch (this) {
      AdminKpiAccent.orders => (
          const Color(0xFFE8F5E9),
          const Color(0xFF1B5E20),
          Icons.receipt_long_rounded,
        ),
      AdminKpiAccent.cooks => (
          const Color(0xFFE3F2FD),
          const Color(0xFF0D47A1),
          Icons.restaurant_rounded,
        ),
      AdminKpiAccent.risk => (
          const Color(0xFFFFEBEE),
          const Color(0xFFC62828),
          Icons.shield_outlined,
        ),
      AdminKpiAccent.reports => (
          const Color(0xFFFFF3E0),
          const Color(0xFFE65100),
          Icons.flag_outlined,
        ),
      AdminKpiAccent.activePipeline => (
          const Color(0xFFE0F2F1),
          const Color(0xFF00695C),
          Icons.local_shipping_outlined,
        ),
      AdminKpiAccent.pending => (
          const Color(0xFFF3E5F5),
          const Color(0xFF6A1B9A),
          Icons.pending_actions_rounded,
        ),
    };
  }
}

/// Large KPI with icon and tinted card — use on dashboard stat grid.
class AdminKpiCard extends StatelessWidget {
  const AdminKpiCard({
    super.key,
    required this.title,
    required this.value,
    required this.accent,
    this.onTap,
  });

  final String title;
  final String value;
  final AdminKpiAccent accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg, icon) = accent.resolve(scheme);
    final radius = BorderRadius.circular(AdminPanelTokens.cardRadiusLarge);
    final inner = Padding(
      padding: const EdgeInsets.all(AdminPanelTokens.space16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: fg.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: fg, size: 20),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 28,
                    height: 1.05,
                    letterSpacing: -0.5,
                    color: fg,
                  ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                  fontSize: 12.5,
                  height: 1.2,
                ),
          ),
        ],
      ),
    );

    final decoration = BoxDecoration(
      color: Color.alphaBlend(bg.withValues(alpha: 0.85), scheme.surfaceContainerLowest),
      borderRadius: radius,
      border: Border.all(color: scheme.outline.withValues(alpha: 0.07)),
      boxShadow: AdminPanelTokens.cardShadow(context),
    );

    if (onTap == null) {
      return DecoratedBox(decoration: decoration, child: inner);
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        overlayColor: WidgetStateProperty.resolveWith(
          (s) => scheme.primary.withValues(alpha: s.contains(WidgetState.pressed) ? 0.14 : 0.06),
        ),
        child: Ink(decoration: decoration, child: inner),
      ),
    );
  }
}

/// Friendly empty list / tab placeholder.
class AdminEmptyState extends StatelessWidget {
  const AdminEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AdminPanelTokens.space24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.65),
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Icon(icon, size: 40, color: scheme.primary.withValues(alpha: 0.85)),
                ),
              ),
              const SizedBox(height: AdminPanelTokens.space16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: AdminPanelTokens.space8),
                Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: AdminPanelTokens.space20),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Two-line app bar title (bold + muted subtitle).
class AdminAppBarTitle extends StatelessWidget {
  const AdminAppBarTitle({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 21,
                letterSpacing: -0.35,
              ),
        ),
        if (subtitle != null && subtitle!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w400,
                    fontSize: 12.5,
                  ),
            ),
          ),
      ],
    );
  }
}

/// Placeholder grid while dashboard stats load.
class AdminDashboardGridSkeleton extends StatelessWidget {
  const AdminDashboardGridSkeleton({super.key, this.crossAxisCount = 2});

  final int crossAxisCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, c) {
        final cross = c.maxWidth >= 720 ? 3 : crossAxisCount;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cross,
            crossAxisSpacing: AdminPanelTokens.space16,
            mainAxisSpacing: AdminPanelTokens.space16,
            childAspectRatio: cross >= 3 ? 1.42 : 1.48,
          ),
          itemCount: 6,
          itemBuilder: (_, __) => Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AdminPanelTokens.cardRadiusLarge),
            ),
            child: const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Generic status pill: active / pending / blocked style.
class AdminStatusPill extends StatelessWidget {
  const AdminStatusPill({super.key, required this.label, required this.variant});

  final String label;
  final AdminStatusVariant variant;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg) = switch (variant) {
      AdminStatusVariant.active => (
          const Color(0xFFE8F5E9),
          const Color(0xFF2E7D32),
        ),
      AdminStatusVariant.pending => (
          const Color(0xFFFFF8E1),
          const Color(0xFFF57F17),
        ),
      AdminStatusVariant.blocked => (
          scheme.errorContainer,
          scheme.onErrorContainer,
        ),
      AdminStatusVariant.neutral => (
          scheme.surfaceContainerHigh,
          scheme.onSurfaceVariant,
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 0.2,
            ),
      ),
    );
  }
}

enum AdminStatusVariant { active, pending, blocked, neutral }

/// Icon-only sign-out for admin toolbars (avoids bulky “Sign out” text in the shell).
class AdminSignOutIconButton extends ConsumerWidget {
  const AdminSignOutIconButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: 'Sign out',
      icon: const Icon(Icons.logout_rounded),
      onPressed: () async {
        await ref.read(authStateProvider.notifier).logout();
        if (context.mounted) context.go(RouteNames.login);
      },
    );
  }
}
