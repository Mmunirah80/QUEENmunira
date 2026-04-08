import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/supabase_error_message.dart';
import '../../reels/presentation/providers/reels_provider.dart';
import '../data/datasources/admin_supabase_datasource.dart';
import '../domain/admin_cook_document_validation.dart';
import '../presentation/providers/admin_monitor_chats_provider.dart';
import '../presentation/providers/admin_providers.dart';
import '../presentation/widgets/admin_pending_cook_documents_panel.dart';

/// Shared confirmations, logging, and cache invalidation for admin mutations (English-only strings).
class AdminActionsService {
  AdminActionsService(this._ref);

  final Ref _ref;

  AdminSupabaseDatasource get _ds => _ref.read(adminSupabaseDatasourceProvider);

  void invalidateReelCaches({String? cookId}) {
    _ref.invalidate(adminReelsListProvider);
    _ref.invalidate(adminDashboardReportedReelsProvider);
    if (cookId != null && cookId.isNotEmpty) {
      _ref.invalidate(adminCookReelsDetailProvider(cookId));
    }
  }

  void invalidateCookDetail(String cookId) {
    if (cookId.isEmpty) return;
    _ref.invalidate(adminUserDetailProvider(cookId));
    _ref.invalidate(adminCookActivityTimelineProvider(cookId));
    _ref.invalidate(adminCookDocumentsDetailProvider(cookId));
    _ref.invalidate(adminProfilesListProvider);
  }

  void invalidatePendingDocuments() {
    _ref.invalidate(adminPendingCookDocumentsNotifierProvider);
  }

  static Future<bool> confirmDestructive(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(confirmLabel)),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _log(String action, {String? targetTable, String? targetId, Map<String, dynamic>? payload}) async {
    try {
      await _ds.logAction(
        action: action,
        targetTable: targetTable,
        targetId: targetId,
        payload: payload ?? const {},
      );
    } catch (e, st) {
      debugPrint('[AdminActionsService] logAction $action: $e\n$st');
    }
  }

  Future<bool> deleteReel(BuildContext context, {required String reelId, String? chefId}) async {
    final ok = await confirmDestructive(
      context,
      title: 'Delete reel',
      message: 'Remove this reel from the app and storage?',
      confirmLabel: 'Delete',
    );
    if (ok != true || !context.mounted) return false;
    try {
      await _ref.read(reelsRepositoryProvider).deleteReel(reelId);
      await _log(
        'reel_removed',
        targetTable: 'reels',
        targetId: reelId,
        payload: {if (chefId != null) 'chef_id': chefId},
      );
      invalidateReelCaches(cookId: chefId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reel removed')));
      }
      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(userFriendlyErrorMessage(e))));
      }
      return false;
    }
  }

  Future<bool> setReelHidden(
    BuildContext context, {
    required String reelId,
    required bool hidden,
    String? chefId,
  }) async {
    final ok = await confirmDestructive(
      context,
      title: hidden ? 'Hide reel' : 'Unhide reel',
      message: hidden
          ? 'Hide this reel from customer feeds? (Does not delete files.)'
          : 'Show this reel in feeds again?',
      confirmLabel: hidden ? 'Hide' : 'Unhide',
    );
    if (ok != true || !context.mounted) return false;
    try {
      await _ds.setReelHiddenForAdmin(reelId: reelId, hidden: hidden);
      await _log(
        hidden ? 'reel_hidden' : 'reel_unhidden',
        targetTable: 'reels',
        targetId: reelId,
        payload: {if (chefId != null) 'chef_id': chefId},
      );
      invalidateReelCaches(cookId: chefId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(hidden ? 'Reel hidden' : 'Reel visible again')),
        );
      }
      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              userFriendlyErrorMessage(e),
            ),
          ),
        );
      }
      return false;
    }
  }

  Future<bool> approveCookDocument(
    BuildContext context, {
    required String documentId,
    required String chefId,
  }) async {
    try {
      await _ds.setChefDocumentStatus(documentId: documentId, status: 'approved');
      await _log(
        'cook_document_approved',
        targetTable: 'chef_documents',
        targetId: documentId,
        payload: {'chef_id': chefId},
      );
      await _ref.read(adminPendingCookDocumentsNotifierProvider.notifier).refreshChef(chefId);
      invalidateCookDetail(chefId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Document approved.')),
        );
      }
      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(userFriendlyErrorMessage(e))));
      }
      return false;
    }
  }

  Future<bool> rejectCookDocument(
    BuildContext context, {
    required String documentId,
    required String chefId,
  }) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => const AdminCookDocReasonDialog(title: 'Rejection reason', confirmLabel: 'Reject'),
    );
    if (reason == null || reason.isEmpty || !context.mounted) return false;
    return submitCookDocumentRejection(
      context,
      documentId: documentId,
      chefId: chefId,
      reason: reason,
    );
  }

  /// Reject or resubmit path after reason was collected in UI.
  Future<bool> submitCookDocumentRejection(
    BuildContext context, {
    required String documentId,
    required String chefId,
    required String reason,
  }) async {
    final trimmed = reason.trim();
    if (!isValidCookDocumentRejectionReason(reason)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rejection reason must be at least 5 characters.'),
          ),
        );
      }
      return false;
    }
    try {
      await _ds.setChefDocumentStatus(
        documentId: documentId,
        status: 'rejected',
        rejectionReason: trimmed,
      );
      await _log(
        'cook_document_rejected',
        targetTable: 'chef_documents',
        targetId: documentId,
        payload: {'chef_id': chefId, 'reason': reason},
      );
      await _ref.read(adminPendingCookDocumentsNotifierProvider.notifier).refreshChef(chefId);
      invalidateCookDetail(chefId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document updated.')));
      }
      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(userFriendlyErrorMessage(e))));
      }
      return false;
    }
  }

  /// General escalation from the user profile (next ladder step only). **Not** used for live kitchen
  /// inspections — those use [AdminSupabaseDatasource.finalizeInspectionOutcome] (outcome only; server
  /// applies warning/freeze). See `supabase_chef_enforcement_v1.sql` / `admin_chef_take_enforcement_action`.
  Future<bool> takeChefEnforcementAction(BuildContext context, {required String cookId}) async {
    try {
      final result = await _ds.adminChefTakeEnforcementAction(cookId);
      final action = (result['action'] ?? '').toString();
      await _log(
        'chef_enforcement',
        targetTable: 'chef_profiles',
        targetId: cookId,
        payload: result,
      );
      invalidateCookDetail(cookId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(action.isEmpty ? 'Action applied' : 'Applied: $action')),
        );
      }
      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(userFriendlyErrorMessage(e))));
      }
      return false;
    }
  }

  Future<bool> updateConversationModeration(
    BuildContext context, {
    required String conversationId,
    String? moderationState,
    bool markReviewedNow = false,
    bool clearReviewedAt = false,
  }) async {
    try {
      await _ds.updateConversationModerationForAdmin(
        conversationId: conversationId,
        moderationState: moderationState,
        markReviewedNow: markReviewedNow,
        clearReviewedAt: clearReviewedAt,
      );
      await _log(
        'conversation_moderation_updated',
        targetTable: 'conversations',
        targetId: conversationId,
        payload: {
          if (moderationState != null) 'admin_moderation_state': moderationState,
          'mark_reviewed': markReviewedNow,
          'clear_reviewed': clearReviewedAt,
        },
      );
      _ref.invalidate(adminOrderMonitorChatsStreamProvider);
      _ref.invalidate(adminChefSupportInboxStreamProvider);
      _ref.invalidate(adminCustomerSupportInboxStreamProvider);
      _ref.invalidate(adminConversationMetaProvider(conversationId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Conversation updated')));
      }
      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${userFriendlyErrorMessage(e)}\nIf this failed, apply supabase_admin_moderation_extensions.sql.',
            ),
          ),
        );
      }
      return false;
    }
  }
}

final adminActionsServiceProvider = Provider<AdminActionsService>((ref) => AdminActionsService(ref));
