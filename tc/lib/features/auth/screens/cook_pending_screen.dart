import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_design_system.dart';
import '../../../core/theme/naham_theme.dart';
import '../../cook/data/cook_required_document_types.dart';
import '../../admin/domain/admin_application_review_logic.dart';
import '../presentation/providers/auth_provider.dart';

/// Gate screen until both verification documents are approved ([ChefAccessLevel.fullAccess]).
class CookPendingScreen extends ConsumerStatefulWidget {
  const CookPendingScreen({super.key});

  @override
  ConsumerState<CookPendingScreen> createState() => _CookPendingScreenState();
}

class _CookPendingScreenState extends ConsumerState<CookPendingScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _rows = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final uid = ref.read(authStateProvider).valueOrNull?.id;
    if (uid == null || uid.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await Supabase.instance.client
          .from('chef_documents')
          .select('id,document_type,status,rejection_reason,expiry_date,no_expiry,created_at')
          .eq('chef_id', uid)
          .order('created_at', ascending: false);
      final list = (raw as List?) ?? const <dynamic>[];
      if (!mounted) return;
      setState(() {
        _rows = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bySlot = latestRequiredDocumentRowsBySlot(_rows);
    final overall = computeApplicationOverallStatus(bySlot);
    final headline = switch (overall) {
      AdminApplicationOverallStatus.approved => 'Application approved',
      AdminApplicationOverallStatus.needsResubmission => 'Documents need an update',
      AdminApplicationOverallStatus.pending => 'Application in review',
    };
    final body = switch (overall) {
      AdminApplicationOverallStatus.approved =>
        'Your documents are approved. If you still see this screen, tap “Refresh status”.',
      AdminApplicationOverallStatus.needsResubmission =>
        'An admin rejected at least one document. Open Documents to see which file and the reason, then re-upload only what was rejected.',
      AdminApplicationOverallStatus.pending =>
        'Both required files must be approved before you can use the cook app. You can upload or replace files from Documents while you wait.',
    };

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppDesignSystem.space24),
              Icon(
                overall == AdminApplicationOverallStatus.needsResubmission
                    ? Icons.warning_amber_rounded
                    : Icons.verified_user_outlined,
                size: 72,
                color: NahamTheme.primary,
              ),
              const SizedBox(height: 20),
              Text(
                headline,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: NahamTheme.textOnLight,
                      fontWeight: FontWeight.w800,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                body,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: NahamTheme.textSecondary,
                      height: 1.35,
                    ),
                textAlign: TextAlign.center,
              ),
              if (_loading) ...[
                const SizedBox(height: 24),
                const Center(child: CircularProgressIndicator()),
              ] else if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  'Could not load document status.\n$_error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: Colors.redAccent),
                ),
              ] else ...[
                const SizedBox(height: 20),
                _slotSummary(context, 'ID document', bySlot[CookRequiredDocumentTypes.idDocument]),
                const SizedBox(height: 10),
                _slotSummary(
                  context,
                  'Health or kitchen document',
                  bySlot[CookRequiredDocumentTypes.healthOrKitchen],
                ),
              ],
              const Spacer(),
              FilledButton.icon(
                onPressed: _loading
                    ? null
                    : () {
                        context.push(RouteNames.chefVerificationDocuments);
                      },
                icon: const Icon(Icons.folder_open_outlined, size: 20),
                label: const Text('Open documents'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  backgroundColor: NahamTheme.primary,
                  foregroundColor: NahamTheme.textOnPurple,
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _loading
                    ? null
                    : () {
                        context.push(RouteNames.chefNotifications);
                      },
                icon: const Icon(Icons.notifications_outlined, size: 20),
                label: const Text('Notifications'),
                style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () async {
                  await _load();
                  await ref.read(authStateProvider.notifier).refreshUser();
                },
                child: const Text('Refresh status'),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () async {
                    await ref.read(authStateProvider.notifier).logout();
                    if (!context.mounted) return;
                    context.go(RouteNames.login);
                  },
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 52),
                  ),
                  child: const Text('Log out'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _slotSummary(BuildContext context, String title, Map<String, dynamic>? row) {
    final label = adminDocumentStatusChipLabel(row);
    final reason = (row?['rejection_reason'] ?? '').toString().trim();
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                ),
                Chip(
                  label: Text(label),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
            if (label == 'Needs resubmission' && reason.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Reason: $reason',
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
