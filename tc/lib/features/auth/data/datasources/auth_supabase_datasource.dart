// ============================================================
// Auth — Supabase Auth + profiles table.
// profiles: id (uuid, FK auth.users), role (text/enum: customer/chef/admin),
//           full_name, phone, avatar_url, profile_image_url, is_active, created_at
// Trigger handle_new_user auto-creates profile row on sign up; do NOT insert manually.
// ============================================================

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/supabase/supabase_config.dart';
import '../../domain/entities/user_entity.dart';
import '../models/user_model.dart';
import 'auth_remote_datasource.dart';

class AuthSupabaseDatasource implements AuthRemoteDataSource {
  SupabaseClient get _sb => SupabaseConfig.client;

  @override
  Future<UserModel> login(String email, String password, [AppRole? role]) async {
    try {
      debugPrint('[Auth] Login called: email=$email');
      await _sb.auth.signInWithPassword(email: email, password: password);
      final sessionUser = _sb.auth.currentUser;
      if (sessionUser == null) {
        throw Exception('Failed to load user after sign in');
      }

      // Ensure profile exists; if missing, try to create a basic one (non‑fatal on failure).
      try {
        final existingProfile = await _fetchProfile(sessionUser.id);
        if (existingProfile == null) {
          debugPrint('[Auth] No profile row found after signIn; creating minimal customer profile');
          await _sb.from('profiles').upsert({
            'id': sessionUser.id,
            'role': _roleToStr(role ?? AppRole.customer),
            'full_name': sessionUser.userMetadata?['full_name'] as String? ??
                sessionUser.email ??
                'User',
          });
        }
      } catch (e) {
        debugPrint('[Auth] Profile ensure after signIn (non-fatal): $e');
      }

      final user = await _getUserFromAuthUser(sessionUser);
      return user;
    } on AuthException catch (e) {
      debugPrint('[Auth] Login error: $e');
      throw Exception(_friendlyAuthError(e.message));
    }
  }

  @override
  Future<UserModel> signup({
    required String email,
    required String password,
    required String name,
    String? phone,
    AppRole? role,
  }) async {
    print('[Auth] signUp called: email=$email, name=$name');
    try {
      final response = await _sb.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': name},
      );
      print('[Auth] signUp user: ${response.user?.id}');
      print('[Auth] SignUp session present: ${response.session != null}');

      // If email confirmation was previously required, session might be null even though user exists.
      // With email confirmation disabled, we try to sign in immediately if there is no session.
      if (response.session == null && response.user != null) {
        print('[Auth] No session after signUp; trying immediate signInWithPassword');
        try {
          final loginResponse = await _sb.auth.signInWithPassword(
            email: email,
            password: password,
          );
          if (loginResponse.session != null && loginResponse.user != null) {
            print('[Auth] Auto sign-in succeeded');
            final roleStr = _roleToStr(role ?? AppRole.customer);
            try {
              await _sb.from('profiles').update({
                'role': roleStr,
                'full_name': name,
                if (phone != null && phone.isNotEmpty) 'phone': phone,
              }).eq('id', loginResponse.user!.id);
              // Ensure cook metadata and chef profile for cooks.
              if (role == AppRole.chef) {
                await _sb.auth.updateUser(
                  UserAttributes(data: {'role': 'cook'}),
                );
                await _sb.from('chef_profiles').upsert({
                  'id': loginResponse.user!.id,
                  'approval_status': 'pending',
                });
              }
            } catch (e) {
              debugPrint('[Auth] Profile update after auto-login (non-fatal): $e');
            }
            return _getUserFromAuthUser(loginResponse.user!);
          }
        } catch (e) {
          debugPrint('[Auth] Auto sign-in failed: $e');
        }
      }
      if (response.user == null) {
        throw Exception('Sign up failed. Please try again.');
      }
      final authUser = response.user!;
      final roleStr = _roleToStr(role ?? AppRole.customer);
      try {
        print('[Auth] Updating profile row after signUp');
        await _sb.from('profiles').update({
          'role': roleStr,
          'full_name': name,
          if (phone != null && phone.isNotEmpty) 'phone': phone,
        }).eq('id', authUser.id);
        if (role == AppRole.chef) {
          await _sb.auth.updateUser(
            UserAttributes(data: {'role': 'cook'}),
          );
          await _sb.from('chef_profiles').upsert({
            'id': authUser.id,
            'approval_status': 'pending',
          });
        }
      } catch (e) {
        debugPrint('[Auth] Profile update after signUp (non-fatal): $e');
      }
      return _getUserFromAuthUser(authUser);
    } on AuthException catch (e) {
      debugPrint('[Auth] SignUp AuthException: $e');
      final msg = e.message.toLowerCase();
      if (msg.contains('rate limit') || msg.contains('429')) {
        throw Exception('Too many attempts. Please wait a few minutes and try again.');
      }
      if (msg.contains('already registered') || msg.contains('email already registered')) {
        throw Exception('This email is already registered. Please sign in.');
      }
      throw Exception(_friendlyAuthError(e.message));
    } catch (e, st) {
      debugPrint('[Auth] SignUp error: $e');
      debugPrint('[Auth] SignUp stackTrace: $st');
      rethrow;
    }
  }

  String _friendlyAuthError(String message) {
    final m = message.toLowerCase();
    if (m.contains('rate limit') || m.contains('429')) {
      return 'Too many attempts. Please wait a few minutes.';
    }
    if (m.contains('invalid login') || m.contains('invalid login credentials')) {
      return 'Incorrect email or password.';
    }
    if (m.contains('already registered') || m.contains('email already registered')) {
      return 'Email already registered. Please sign in.';
    }
    if (m.contains('invalid') && m.contains('email')) {
      return 'Please enter a valid email address.';
    }
    if (m.contains('weak_password') || m.contains('at least')) {
      return 'Password must be at least 6 characters.';
    }
    return message;
  }

  @override
  Future<void> logout() async {
    await _sb.auth.signOut();
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    final session = _sb.auth.currentSession;
    final authUser = session?.user;
    if (authUser == null) return null;
    return _getUserFromAuthUser(authUser);
  }

  Future<UserModel> _getUserFromAuthUser(User authUser) async {
    final profile = await _fetchProfile(authUser.id);
    if (profile != null) return await _userFromProfile(authUser, profile);
    return _userFromAuthOnly(authUser);
  }

  /// Stream of auth state changes. Subscribe to refetch user / clear state.
  Stream<AuthState> watchAuthState() {
    return _sb.auth.onAuthStateChange;
  }

  /// Send password reset email.
  Future<void> resetPassword(String email) async {
    await _sb.auth.resetPasswordForEmail(email);
  }

  Future<Map<String, dynamic>?> _fetchProfile(String userId) async {
    final row = await _sb
        .from('profiles')
        .select(
          'id, role, full_name, phone, avatar_url, profile_image_url, is_blocked, '
          'chef_profiles!chef_profiles_id_fkey(approval_status, rejection_reason)',
        )
        .eq('id', userId)
        .maybeSingle();
    return row as Map<String, dynamic>?;
  }

  UserModel _userFromAuthOnly(User user) {
    return UserModel(
      id: user.id,
      email: user.email ?? '',
      name: user.userMetadata?['full_name'] as String? ?? user.email ?? 'User',
      phone: null,
      profileImageUrl: user.userMetadata?['avatar_url'] as String?,
      isVerified: user.emailConfirmedAt != null,
      role: AppRole.customer,
      chefApprovalStatus: null,
      rejectionReason: null,
      isBlocked: false,
    );
  }

  Future<UserModel> _userFromProfile(User user, Map<String, dynamic> profile) async {
    final roleStr = profile['role'] as String?;
    final appRole = _strToRole(roleStr);
    final fullName = profile['full_name'] as String? ?? user.email ?? 'User';
    final avatarUrl = profile['avatar_url'] as String? ?? profile['profile_image_url'] as String?;

    ChefApprovalStatus? chefStatus;
    String? rejectionReason;
    final chefRaw = profile['chef_profiles'];
    if (chefRaw is List && chefRaw.isNotEmpty) {
      final row = chefRaw.first as Map<String, dynamic>;
      chefStatus = _chefApprovalFromStatus(row['approval_status'] as String?);
      rejectionReason = row['rejection_reason'] as String?;
    } else if (chefRaw is Map<String, dynamic>) {
      chefStatus = _chefApprovalFromStatus(chefRaw['approval_status'] as String?);
      rejectionReason = chefRaw['rejection_reason'] as String?;
    }

    // Fallback: if we don't have an embedded chef profile row (e.g. relation not configured),
    // explicitly query chef_profiles so cook routing works.
    if (appRole == AppRole.chef && chefStatus == null) {
      try {
        final chefProfileRow = await _sb
            .from('chef_profiles')
            .select('approval_status,rejection_reason')
            .eq('id', user.id)
            .maybeSingle();

        if (chefProfileRow != null) {
          final row = chefProfileRow as Map<String, dynamic>;
          chefStatus = _chefApprovalFromStatus(row['approval_status'] as String?);
          rejectionReason = row['rejection_reason'] as String?;
        }
      } catch (_) {
        // Leave chefStatus/rejectionReason as null -> caller will route to customer/login.
      }
    }

    return UserModel(
      id: user.id,
      email: user.email ?? '',
      name: fullName,
      phone: profile['phone'] as String?,
      profileImageUrl: avatarUrl,
      isVerified: user.emailConfirmedAt != null,
      role: appRole ?? AppRole.customer,
      chefApprovalStatus: chefStatus,
      rejectionReason: rejectionReason,
      isBlocked: profile['is_blocked'] as bool? ?? false,
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

  String _roleToStr(AppRole r) {
    switch (r) {
      case AppRole.chef:
        return 'chef';
      case AppRole.customer:
        return 'customer';
      case AppRole.admin:
        return 'admin';
    }
  }

  AppRole? _strToRole(String? s) {
    if (s == null) return null;
    switch (s.toLowerCase()) {
      case 'chef':
      case 'cook':
        return AppRole.chef;
      case 'customer':
        return AppRole.customer;
      case 'admin':
        return AppRole.admin;
      default:
        return null;
    }
  }
}
