import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/supabase/supabase_config.dart';
import '../../domain/entities/user_entity.dart';
import '../models/user_model.dart';

/// Full chef registration: Supabase Auth + profiles + chef_profiles + Storage + chef_documents.
///
/// Document uploads are rolled back (DB row + storage object) if a later step fails.
class ChefRegistrationDataSource {
  SupabaseClient get _sb => SupabaseConfig.client;

  static const _bucket = 'documents';

  Future<void> _rollbackDocumentSteps(
    List<({String? rowId, String? storagePath})> steps,
  ) async {
    for (final s in steps) {
      if (s.rowId != null && s.rowId!.isNotEmpty) {
        try {
          await _sb.from('chef_documents').delete().eq('id', s.rowId!);
        } catch (e, st) {
          debugPrint('[ChefReg] rollback delete row ${s.rowId}: $e\n$st');
        }
      }
      if (s.storagePath != null && s.storagePath!.isNotEmpty) {
        try {
          await _sb.storage.from(_bucket).remove([s.storagePath!]);
        } catch (e, st) {
          debugPrint('[ChefReg] rollback remove ${s.storagePath}: $e\n$st');
        }
      }
    }
  }

  /// Creates account, sets role chef + pending approval, uploads two documents (optional expiry per file).
  /// Second file is stored as [freelancer_id] so it matches app compliance (national + freelance permit).
  ///
  /// A global timeout may fire mid-flow; on timeout we [signOut] so a partial session does not trap the user.
  /// If auth already succeeded server-side, the cook may need to sign in and finish from support (rare edge case).
  Future<UserModel> registerChef({
    required String email,
    required String password,
    required String name,
    String? phone,
    required File nationalIdFile,
    required File healthCertFile,
    DateTime? nationalIdExpiry,
    DateTime? healthCertExpiry,
  }) async {
    try {
      return await _registerChefCore(
        email: email,
        password: password,
        name: name,
        phone: phone,
        nationalIdFile: nationalIdFile,
        healthCertFile: healthCertFile,
        nationalIdExpiry: nationalIdExpiry,
        healthCertExpiry: healthCertExpiry,
      ).timeout(
        const Duration(minutes: 3),
        onTimeout: () => throw TimeoutException('Chef registration timed out.'),
      );
    } on AuthException catch (e) {
      final m = e.message.toLowerCase();
      if (m.contains('already registered') || m.contains('already been registered')) {
        throw Exception('This email is already registered. Please sign in.');
      }
      throw Exception(e.message);
    } on SocketException {
      throw Exception('Network error. Check your connection and try again.');
    } on TimeoutException {
      try {
        await _sb.auth.signOut();
      } catch (_) {}
      throw Exception('Request timed out. Check your connection and try again.');
    }
  }

  Future<UserModel> _registerChefCore({
    required String email,
    required String password,
    required String name,
    String? phone,
    required File nationalIdFile,
    required File healthCertFile,
    DateTime? nationalIdExpiry,
    DateTime? healthCertExpiry,
  }) async {
    final signUpRes = await _sb.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': name},
    );

    User? authUser = signUpRes.user;
    if (authUser == null) {
      throw Exception('Sign up failed. Please try again.');
    }

    if (signUpRes.session == null) {
      try {
        final loginRes = await _sb.auth.signInWithPassword(
          email: email,
          password: password,
        );
        authUser = loginRes.user ?? authUser;
      } catch (e) {
        debugPrint('[ChefReg] Auto sign-in after signUp: $e');
        throw Exception(
          'Account created but sign-in failed. Confirm your email if required, then sign in.',
        );
      }
    }

    final uid = _sb.auth.currentUser?.id;
    if (uid == null || uid.isEmpty) {
      throw Exception('Could not establish session after registration.');
    }

    await _sb.from('profiles').update({
      'role': 'chef',
      'full_name': name,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
    }).eq('id', uid);

    await _sb.auth.updateUser(
      UserAttributes(data: {'role': 'cook'}),
    );

    await _sb.from('chef_profiles').upsert({
      'id': uid,
      'approval_status': 'pending',
    });

    final stamp = DateTime.now().millisecondsSinceEpoch;
    final steps = <({String? rowId, String? storagePath})>[];

    try {
      Future<({String rowId, String path})> uploadAndInsert({
        required File file,
        required String docType,
        DateTime? expiry,
      }) async {
        final path = '$uid/$docType/reg_$stamp.jpg';
        await _sb.storage.from(_bucket).upload(
          path,
          file,
          fileOptions: const FileOptions(upsert: false, contentType: 'image/jpeg'),
        );
        final row = <String, dynamic>{
          'chef_id': uid,
          'document_type': docType,
          'file_url': path,
          'status': 'pending',
        };
        if (expiry != null) {
          row['expiry_date'] =
              '${expiry.year.toString().padLeft(4, '0')}-${expiry.month.toString().padLeft(2, '0')}-${expiry.day.toString().padLeft(2, '0')}';
        }
        final inserted = await _sb.from('chef_documents').insert(row).select('id').single();
        final id = (inserted['id'] ?? '').toString();
        if (id.isEmpty) {
          throw Exception('Document record was not created. Please try again.');
        }
        return (rowId: id, path: path);
      }

      final first = await uploadAndInsert(
        file: nationalIdFile,
        docType: 'national_id',
        expiry: nationalIdExpiry,
      );
      steps.add((rowId: first.rowId, storagePath: first.path));

      final second = await uploadAndInsert(
        file: healthCertFile,
        docType: 'freelancer_id',
        expiry: healthCertExpiry,
      );
      steps.add((rowId: second.rowId, storagePath: second.path));

      return await _loadUserModel(uid);
    } catch (e, st) {
      debugPrint('[ChefReg] Document pipeline failed, rolling back: $e\n$st');
      await _rollbackDocumentSteps(steps.reversed.toList());
      if (e is SocketException) {
        throw Exception('Network error. Check your connection and try again.');
      }
      if (e is TimeoutException) {
        throw Exception('Request timed out. Check your connection and try again.');
      }
      if (e is Exception) rethrow;
      throw Exception(e.toString());
    }
  }

  Future<UserModel> _loadUserModel(String uid) async {
    final authUser = _sb.auth.currentUser;
    if (authUser == null) {
      throw Exception('Session lost after registration.');
    }
    final profile = await _sb
        .from('profiles')
        .select(
          'id, role, full_name, phone, avatar_url, profile_image_url, is_blocked, '
          'chef_profiles!chef_profiles_id_fkey(approval_status, rejection_reason)',
        )
        .eq('id', uid)
        .maybeSingle();

    if (profile == null) {
      return UserModel(
        id: authUser.id,
        email: authUser.email ?? '',
        name: authUser.userMetadata?['full_name'] as String? ??
            authUser.email ??
            'User',
        isVerified: authUser.emailConfirmedAt != null,
        role: AppRole.chef,
        chefApprovalStatus: ChefApprovalStatus.pending,
      );
    }

    final p = profile;
    ChefApprovalStatus? chefStatus;
    String? rejectionReason;
    final chefRaw = p['chef_profiles'];
    if (chefRaw is List && chefRaw.isNotEmpty) {
      final row = chefRaw.first as Map<String, dynamic>;
      chefStatus = _chefApprovalFromStatus(row['approval_status'] as String?);
      rejectionReason = row['rejection_reason'] as String?;
    } else if (chefRaw is Map<String, dynamic>) {
      chefStatus = _chefApprovalFromStatus(chefRaw['approval_status'] as String?);
      rejectionReason = chefRaw['rejection_reason'] as String?;
    }
    if (chefStatus == null) {
      final row = await _sb
          .from('chef_profiles')
          .select('approval_status,rejection_reason')
          .eq('id', uid)
          .maybeSingle();
      if (row != null) {
        final m = row;
        chefStatus = _chefApprovalFromStatus(m['approval_status'] as String?);
        rejectionReason = m['rejection_reason'] as String?;
      }
    }

    return UserModel(
      id: uid,
      email: authUser.email ?? '',
      name: p['full_name'] as String? ?? authUser.email ?? 'User',
      phone: p['phone'] as String?,
      profileImageUrl:
          p['avatar_url'] as String? ?? p['profile_image_url'] as String?,
      isVerified: authUser.emailConfirmedAt != null,
      role: AppRole.chef,
      chefApprovalStatus: chefStatus ?? ChefApprovalStatus.pending,
      rejectionReason: rejectionReason,
      isBlocked: p['is_blocked'] as bool? ?? false,
    );
  }

  ChefApprovalStatus? _chefApprovalFromStatus(String? status) {
    if (status == null) return null;
    switch (status.toLowerCase()) {
      case 'pending':
        return ChefApprovalStatus.pending;
      case 'approved':
        return ChefApprovalStatus.approved;
      case 'rejected':
        return ChefApprovalStatus.rejected;
      default:
        return null;
    }
  }
}
