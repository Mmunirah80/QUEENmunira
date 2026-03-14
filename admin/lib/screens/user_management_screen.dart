import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/route_names.dart';
import '../core/theme/app_design_system.dart';
import '../core/theme/naham_theme.dart';
import '../core/widgets/loading_widget.dart';
import '../core/widgets/naham_screen_header.dart';
import '../core/widgets/naham_empty_screens.dart';
import '../data/models/user_model.dart';
import '../providers/admin_providers.dart';

class UserManagementScreen extends ConsumerStatefulWidget {
  const UserManagementScreen({super.key});

  @override
  ConsumerState<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends ConsumerState<UserManagementScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          const SliverToBoxAdapter(child: NahamScreenHeader(title: 'إدارة المستخدمين')),
          SliverToBoxAdapter(
            child: Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: TabBar(
                controller: _tabController,
                labelColor: NahamTheme.secondary,
                unselectedLabelColor: AppDesignSystem.textSecondary,
                indicatorColor: NahamTheme.secondary,
                tabs: const [
                  Tab(text: 'الطباخون'),
                  Tab(text: 'العملاء'),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _UserList(role: 'chef'),
            _CustomersList(),
          ],
        ),
      ),
    );
  }
}

class _UserList extends ConsumerWidget {
  final String role;

  const _UserList({required this.role});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(allChefsProvider);

    return async.when(
      data: (list) {
        if (list.isEmpty) {
          return const Center(
            child: NahamEmptyStateContent(
              title: 'لا يوجد طباخون',
              subtitle: 'سيظهر المسجلون هنا.',
              buttonLabel: 'تحديث',
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(AppDesignSystem.space16),
          itemCount: list.length,
          itemBuilder: (_, i) => _UserTile(
            user: list[i],
            onTap: () => context.push(RouteNames.chefDetail, extra: {'chefId': list[i].id}),
          ),
        );
      },
      loading: () => const LoadingWidget(),
      error: (e, st) => ErrorStateContent(message: e.toString()),
    );
  }
}

class _UserTile extends StatelessWidget {
  final UserModel user;
  final VoidCallback? onTap;

  const _UserTile({required this.user, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppDesignSystem.space12),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: NahamTheme.primary.withValues(alpha: 0.2),
          child: Text(
            (user.name.isNotEmpty ? user.name[0] : '?').toUpperCase(),
            style: const TextStyle(color: NahamTheme.primary, fontWeight: FontWeight.w600),
          ),
        ),
        title: Text(user.name),
        subtitle: Text(user.email, style: Theme.of(context).textTheme.bodySmall),
        trailing: Chip(
          label: Text(
            user.chefApprovalStatus?.name ?? '—',
            style: const TextStyle(fontSize: 12),
          ),
          backgroundColor: NahamTheme.cardBackground,
        ),
      ),
    );
  }
}

class _CustomersList extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(allCustomersProvider);

    return async.when(
      data: (list) {
        if (list.isEmpty) {
          return const Center(
            child: NahamEmptyStateContent(
              title: 'لا يوجد عملاء',
              subtitle: 'سيظهر العملاء المسجلون هنا.',
              buttonLabel: 'تحديث',
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(AppDesignSystem.space16),
          itemCount: list.length,
          itemBuilder: (_, i) => _UserTile(user: list[i]),
        );
      },
      loading: () => const LoadingWidget(),
      error: (e, st) => ErrorStateContent(message: e.toString()),
    );
  }
}

