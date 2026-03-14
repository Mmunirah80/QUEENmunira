import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_design_system.dart';
import '../core/theme/naham_theme.dart';
import '../core/constants/route_names.dart';
import '../core/widgets/loading_widget.dart';
import '../core/widgets/snackbar_helper.dart';
import '../data/models/user_model.dart';
import '../providers/admin_providers.dart';

/// Admin view: full chef profile, documents (National ID + Health/Freelancer cert), violation history, approve/reject.
class ChefDetailScreen extends ConsumerStatefulWidget {
  final String chefId;

  const ChefDetailScreen({super.key, required this.chefId});

  @override
  ConsumerState<ChefDetailScreen> createState() => _ChefDetailScreenState();
}

class _ChefDetailScreenState extends ConsumerState<ChefDetailScreen> {
  UserModel? _user;
  Map<String, dynamic>? _chefDoc;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final ds = ref.read(adminFirebaseDataSourceProvider);
      final user = await ds.getChefById(widget.chefId);
      final doc = await ds.getChefDoc(widget.chefId);
      if (mounted) setState(() {
        _user = user;
        _chefDoc = doc;
        _loading = false;
        _error = user == null ? 'الطاهي غير موجود' : null;
      });
    } catch (e) {
      if (mounted) setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _approve() async {
    if (_user == null) return;
    try {
      await ref.read(adminFirebaseDataSourceProvider).approveChef(_user!.id);
      if (mounted) {
        SnackbarHelper.success(context, 'تمت الموافقة على ${_user!.name}');
        context.pop();
      }
    } catch (e) {
      if (mounted) SnackbarHelper.error(context, e.toString());
    }
  }

  void _reject() {
    if (_user == null) return;
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('رفض الطلب'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'سبب الرفض',
            hintText: 'أدخل سبب الرفض',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) return;
              Navigator.pop(ctx);
              try {
                await ref.read(adminFirebaseDataSourceProvider).rejectChef(_user!.id, reason: reason);
                if (mounted) {
                  SnackbarHelper.success(context, 'تم رفض الطلب');
                  context.pop();
                }
              } catch (e) {
                if (mounted) SnackbarHelper.error(context, e.toString());
              }
            },
            child: const Text('رفض'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: Center(child: LoadingWidget())),
      );
    }
    if (_error != null || _user == null) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(backgroundColor: NahamTheme.headerBackground, foregroundColor: Colors.white, title: const Text('تفاصيل الطاهي')),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error ?? 'الطاهي غير موجود', style: const TextStyle(color: AppDesignSystem.errorRed)),
                const SizedBox(height: 16),
                TextButton(onPressed: _load, child: const Text('إعادة المحاولة')),
              ],
            ),
          ),
        ),
      );
    }
    final user = _user!;
    final docs = _chefDoc?['documents'] as Map<String, dynamic>? ?? {};
    final nationalIdUrl = docs['nationalId'] as String?;
    final healthCertUrl = docs['healthCert'] as String?;
    final isPending = user.chefApprovalStatus?.name == 'pending';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: NahamTheme.headerBackground,
          foregroundColor: Colors.white,
          title: Text(user.name),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => context.pop(),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDesignSystem.space16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppDesignSystem.space16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 32,
                            backgroundColor: NahamTheme.primary.withValues(alpha: 0.2),
                            child: Text(
                              (user.name.isNotEmpty ? user.name[0] : '?').toUpperCase(),
                              style: const TextStyle(color: NahamTheme.primary, fontWeight: FontWeight.w700, fontSize: 24),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(user.name, style: Theme.of(context).textTheme.titleLarge),
                                Text(user.email, style: Theme.of(context).textTheme.bodySmall),
                                if (user.phone != null) Text(user.phone!, style: Theme.of(context).textTheme.bodySmall),
                                const SizedBox(height: 4),
                                Chip(
                                  label: Text(user.chefApprovalStatus?.name ?? '—'),
                                  backgroundColor: NahamTheme.cardBackground,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('المستندات', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _DocTile(title: 'الهوية الوطنية', url: nationalIdUrl),
              _DocTile(title: 'شهادة العمل الحر / الصحة', url: healthCertUrl),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () => context.push(
                  RouteNames.chefViolation,
                  extra: {'chefId': user.id, 'chefName': user.name},
                ),
                icon: const Icon(Icons.warning_amber_rounded),
                label: const Text('سجل المخالفات'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppDesignSystem.warningOrange,
                  side: const BorderSide(color: AppDesignSystem.warningOrange),
                ),
              ),
              if (isPending) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _reject,
                        style: OutlinedButton.styleFrom(foregroundColor: AppDesignSystem.errorRed),
                        child: const Text('رفض'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _approve,
                        style: FilledButton.styleFrom(backgroundColor: AppDesignSystem.successGreen),
                        child: const Text('موافقة'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DocTile extends StatelessWidget {
  final String title;
  final String? url;

  const _DocTile({required this.title, this.url});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(title),
        subtitle: Text(url != null ? 'عرض المستند' : 'غير مرفق'),
        trailing: url != null
            ? IconButton(
                icon: const Icon(Icons.open_in_new_rounded),
                onPressed: () {
                  // Could use url_launcher to open in browser
                },
              )
            : null,
      ),
    );
  }
}
