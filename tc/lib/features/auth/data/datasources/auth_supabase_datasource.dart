import 'dart:convert';

// ============================================================
// Auth — Supabase Auth + profiles table.
// profiles: id (uuid, FK auth.users), role (text/enum: customer/chef/admin),
//           full_name, phone, avatar_url, profile_image_url, is_active, created_at
// Trigger handle_new_user may auto-create profiles; client also upserts on login/signup for safety.
// ============================================================

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/supabase/profiles_table_select.dart';
import '../../../../core/supabase/supabase_config.dart';
import '../../../../core/utils/supabase_error_message.dart';
import '../../domain/entities/user_entity.dart';
import '../models/user_model.dart';
import 'auth_remote_datasource.dart';

class AuthSupabaseDatasource implements AuthRemoteDataSource {
  SupabaseClient get _sb => SupabaseConfig.client;

  /// Creates or updates [profiles] for the signed-in user (RLS: own row only).
  Future<void> _upsertAuthProfileRow({
    required String userId,
    required String fullName,
    required AppRole role,
    String? phone,
  }) async {
    final payload = <String, dynamic>{
      'id': userId,
      'role': _roleToStr(role),
      'full_name': fullName,
      if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
    };
    debugPrint('[AUTH] profiles upsert id=$userId role=${_roleToStr(role)}');
    await _sb.from('profiles').upsert(payload, onConflict: 'id');
  }

  @override
  Future<UserModel> login(String email, String password, [AppRole? role]) async {
    final t0 = DateTime.now();
    try {
      debugPrint('[AUTH] signIn started email=$email selectedRole=$role');
      await _sb.auth.signInWithPassword(email: email, password: password);
      final sessionUser = _sb.auth.currentUser;
      if (sessionUser == null) {
        debugPrint('[AUTH] signIn FAIL currentUser null after sign-in');
        throw Exception('Failed to load user after sign in');
      }
      debugPrint(
        '[AUTH] signIn success uid=${sessionUser.id} '
        '${DateTime.now().difference(t0).inMilliseconds}ms',
      );

      try {
        debugPrint('[AUTH] login profileEnsure fetch uid=${sessionUser.id}');
        final existingProfile = await _fetchProfile(sessionUser.id);
        if (existingProfile == null) {
          debugPrint('[AUTH] no profile row; upserting minimal row');
          await _upsertAuthProfileRow(
            userId: sessionUser.id,
            fullName: sessionUser.userMetadata?['full_name'] as String? ??
                sessionUser.email ??
                'User',
            role: role ?? AppRole.customer,
          );
        } else {
          debugPrint('[AUTH] profile row present role=${existingProfile['role']}');
        }
      } catch (e, st) {
        debugPrint('[AUTH] profile ensure after signIn (non-fatal): $e\n$st');
      }

      debugPrint('[AUTH] login building UserModel');
      final user = await _getUserFromAuthUser(sessionUser);
      debugPrint('[AUTH] login done role=${user.role} isBlocked=${user.isBlocked}');
      return user;
    } on AuthException catch (e, st) {
      final raw = _extractAuthApiMessage(e.message);
      debugPrint(
        '[Auth] login: AuthException status=${e.statusCode} messageRaw=${e.message} extracted=$raw',
      );
      _logRawAuthError('signInWithPassword', e, st);
      if (kDebugMode) {
        rethrow;
      }
      throw Exception(_friendlyAuthError(e.message));
    } catch (e, st) {
      _logRawAuthError('login_post_auth', e, st);
      if (kDebugMode) {
        rethrow;
      }
      throw Exception(
        userFriendlyErrorMessage(e, fallback: 'Could not complete sign in. Please try again.'),
      );
    }
  }

  void _logRawAuthError(String where, Object e, StackTrace st) {
    debugPrint('[Auth] RAW ERROR ($where) TYPE: ${e.runtimeType}');
    debugPrint('[Auth] RAW ERROR MESSAGE: ${_rawErrorMessageForLogs(e)}');
    debugPrint('[Auth] STACK: $st');
  }

  String _rawErrorMessageForLogs(Object e) {
    if (e is AuthException) {
      return 'statusCode=${e.statusCode} message=${e.message}';
    }
    if (e is PostgrestException) {
      return 'code=${e.code} message=${e.message} details=${e.details} hint=${e.hint}';
    }
    return e.toString();
  }

  @override
  Future<UserModel> signup({
    required String email,
    required String password,
    required String name,
    String? phone,
    AppRole? role,
  }) async {
    final resolvedRole = role ?? AppRole.customer;
    final roleStr = _roleToStr(resolvedRole);
    debugPrint('[AUTH] signup started email=$email name=$name role=$roleStr');
    try {
      final response = await _sb.auth.signUp(
        email: email,
        password: password,
        data: {
          'full_name': name,
          'role': roleStr,
        },
      );
      debugPrint(
        '[AUTH] signup auth ok user=${response.user?.id} session=${response.session != null}',
      );

      if (response.user == null) {
        throw Exception('Sign up failed. Please try again.');
      }

      if (response.session == null) {
        debugPrint('[AUTH] signup no session; trying signInWithPassword');
        try {
          final loginResponse = await _sb.auth.signInWithPassword(
            email: email,
            password: password,
          );
          if (loginResponse.session != null) {
            debugPrint('[AUTH] signup auto sign-in ok uid=${loginResponse.user?.id}');
          }
        } on AuthException catch (e) {
          debugPrint('[AUTH] signup auto sign-in AuthException: ${e.message}');
          final em = e.message.toLowerCase();
          if (em.contains('email') &&
              (em.contains('confirm') ||
                  em.contains('verified') ||
                  em.contains('not confirmed'))) {
            throw Exception(
              'Please confirm your email from the link we sent, then sign in.',
            );
          }
          rethrow;
        } catch (e) {
          debugPrint('[AUTH] signup auto sign-in failed: $e');
        }
      }

      if (_sb.auth.currentSession == null || _sb.auth.currentUser == null) {
        debugPrint(
          '[AUTH] signup abandoned: no active session (email confirmation likely)',
        );
        throw Exception(
          'Account created. If email confirmation is enabled, check your inbox and confirm, then sign in.',
        );
      }

      final sessionUser = _sb.auth.currentUser!;

      try {
        await _upsertAuthProfileRow(
          userId: sessionUser.id,
          fullName: name,
          role: resolvedRole,
          phone: phone,
        );
        if (resolvedRole == AppRole.chef) {
          await _sb.auth.updateUser(
            UserAttributes(data: {'role': 'cook'}),
          );
          await _sb.from('chef_profiles').upsert({
            'id': sessionUser.id,
            'approval_status': 'pending',
          });
        }
      } catch (e, st) {
        debugPrint('[AUTH] signup profile/chef upsert error: $e\n$st');
        throw Exception(
          'Account was created but your profile could not be saved. '
          'Sign in again, or contact support if this continues.',
        );
      }

      final userModel = await _getUserFromAuthUser(sessionUser);
      debugPrint('[AUTH] signup complete uid=${userModel.id} role=${userModel.role}');
      return userModel;
    } on AuthException catch (e) {
      debugPrint('[AUTH] signup AuthException: $e');
      final msg = e.message.toLowerCase();
      if (msg.contains('rate limit') || msg.contains('429')) {
        throw Exception('Too many attempts. Please wait a few minutes and try again.');
      }
      if (msg.contains('already registered') || msg.contains('email already registered')) {
        throw Exception('This email is already registered. Please sign in.');
      }
      throw Exception(_friendlyAuthError(e.message));
    } catch (e, st) {
      debugPrint('[AUTH] signup error: $e');
      debugPrint('[AUTH] signup stackTrace: $st');
      rethrow;
    }
  }

  /// GoTrue often puts the API JSON body in [AuthException.message], e.g.
  /// `{"code":"unexpected_failure","message":"Database error querying schema"}`.
  String _extractAuthApiMessage(String raw) {
    final t = raw.trim();
    if (t.startsWith('{') && t.contains('"message"')) {
      try {
        final decoded = jsonDecode(t);
        if (decoded is Map && decoded['message'] is String) {
          final inner = (decoded['message'] as String).trim();
          if (inner.isNotEmpty) return inner;
        }
      } catch (_) {}
    }
    return raw;
  }

  String _friendlyAuthError(String message) {
    final extracted = _extractAuthApiMessage(message);
    final m = extracted.toLowerCase();
    if (m.contains('rate limit') || m.contains('429')) {
      return 'Too many attempts. Please wait a few minutes.';
    }
    if (m.contains('invalid login') || m.contains('invalid login credentials')) {
      return 'Incorrect email or password.';
    }
    if (m.contains('email not confirmed') ||
        (m.contains('email') && m.contains('not confirmed'))) {
      return 'Please confirm your email, then sign in.';
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
    // Only show the PostgREST hint when the server actually said so (avoid blaming schema when it is not).
    if (m.contains('querying schema') || m.contains('database error querying schema')) {
      final hint = 'Try in SQL: NOTIFY pgrst, \'reload schema\'; or restart the project API.';
      if (kDebugMode) {
        return 'Auth server (PostgREST): $extracted\n$hint';
      }
      return 'Sign-in failed: server schema/cache issue. $hint';
    }
    if (kDebugMode) {
      return 'Auth server: $extracted';
    }
    return extracted;
  }

  @override
  Future<void> logout() async {
    await _sb.auth.signOut();
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    final session = _sb.auth.currentSession;
    final authUser = session?.user;
    if (authUser == null) {
      debugPrint('[AUTH] getCurrentUser: no session');
      return null;
    }
    debugPrint('[AUTH] getCurrentUser: session ok uid=${authUser.id}');
    return _getUserFromAuthUser(authUser);
  }

  Future<UserModel> _getUserFromAuthUser(User authUser) async {
    final profile = await _fetchProfile(authUser.id);
    if (profile != null) return await _userFromProfile(authUser, profile);
    return _userFromAuthWithFallbacks(authUser);
  }

  /// When [profiles] cannot be read (e.g. PostgREST "querying schema"), still allow login
  /// using [chef_profiles] and/or JWT metadata so cooks are not forced to customer.
  Future<UserModel> _userFromAuthWithFallbacks(User user) async {
    final metaRole = user.userMetadata?['role'] ?? user.appMetadata['role'];
    final jwtRole = _strToRole(metaRole?.toString());
    if (jwtRole == AppRole.admin) {
      return UserModel(
        id: user.id,
        email: user.email ?? '',
        name: user.userMetadata?['full_name'] as String? ?? user.email ?? 'User',
        phone: null,
        profileImageUrl: user.userMetadata?['avatar_url'] as String?,
        isVerified: user.emailConfirmedAt != null,
        role: AppRole.admin,
        chefAccessLevel: null,
        chefApprovalStatus: null,
        rejectionReason: null,
        isBlocked: false,
      );
    }

    try {
      debugPrint('[Auth] chef_profiles lookup start id=${user.id}');
      final chefRow = await _sb
          .from('chef_profiles')
          .select('approval_status,rejection_reason,access_level')
          .eq('id', user.id)
          .maybeSingle();
      debugPrint('[Auth] chef_profiles lookup success row=${chefRow != null}');
      if (chefRow != null) {
        final row = Map<String, dynamic>.from(chefRow as Map);
        final chefStatus = _chefApprovalFromStatus(row['approval_status'] as String?);
        final rejectionReason = row['rejection_reason'] as String?;
        var chefAccess = _chefAccessLevelFromChefRow(row);
        chefAccess ??= _inferChefAccessFromLegacy(approval: chefStatus, profileBlocked: false);
        return UserModel(
          id: user.id,
          email: user.email ?? '',
          name: user.userMetadata?['full_name'] as String? ?? user.email ?? 'User',
          phone: null,
          profileImageUrl: user.userMetadata?['avatar_url'] as String?,
          isVerified: user.emailConfirmedAt != null,
          role: AppRole.chef,
          chefAccessLevel: chefAccess,
          chefApprovalStatus: chefStatus,
          rejectionReason: rejectionReason,
          isBlocked: false,
        );
      }
    } catch (e, st) {
      debugPrint('[Auth] chef_profiles fallback: $e\n$st');
    }

    if (jwtRole == AppRole.customer) {
      return UserModel(
        id: user.id,
        email: user.email ?? '',
        name: user.userMetadata?['full_name'] as String? ?? user.email ?? 'User',
        phone: null,
        profileImageUrl: user.userMetadata?['avatar_url'] as String?,
        isVerified: user.emailConfirmedAt != null,
        role: AppRole.customer,
        chefAccessLevel: null,
        chefApprovalStatus: null,
        rejectionReason: null,
        isBlocked: false,
      );
    }

    return _userFromAuthOnly(user);
  }

  static bool _isProfilesReadSchemaFailure(PostgrestException e) {
    final combined = '${e.message} ${e.details} ${e.hint}'.toLowerCase();
    return combined.contains('querying schema') ||
        combined.contains('database error querying schema');
  }

  /// Stream of auth state changes. Subscribe to refetch user / clear state.
  Stream<AuthState> watchAuthState() {
    return _sb.auth.onAuthStateChange;
  }

  /// Send password reset email via Supabase Auth (`resetPasswordForEmail`).
  /// Configure **Site URL** and **Redirect URLs** in Supabase Dashboard → Auth → URL Configuration
  /// so recovery links work on web / deep links if you use them.
  Future<void> resetPassword(String email) async {
    final e = email.trim();
    if (e.isEmpty) {
      throw AuthException('Email is required');
    }
    try {
      await _sb.auth.resetPasswordForEmail(e);
    } on AuthException catch (err, st) {
      debugPrint('[Auth] resetPasswordForEmail: $err\n$st');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> _fetchProfile(String userId) async {
    // See [kAuthProfilesSelectColumns] — `*` avoids schema/column-list mismatches.
    final sel = await resolveProfilesSelectForAuth(_sb);
    try {
      debugPrint('[AUTH] fetchProfile start select=$sel id=$userId');
      final row = await _sb.from('profiles').select(sel).eq('id', userId).maybeSingle();
      debugPrint('[AUTH] fetchProfile ok present=${row != null}');
      return row as Map<String, dynamic>?;
    } on PostgrestException catch (e, st) {
      debugPrint(
        '[AUTH] fetchProfile PostgrestException code=${e.code} message=${e.message} details=${e.details} hint=${e.hint}\n$st',
      );
      if (_isProfilesReadSchemaFailure(e)) {
        debugPrint('[AUTH] fetchProfile schema/cache issue; using auth fallbacks');
        return null;
      }
      final code = (e.code ?? '').trim();
      final combined = '${e.message} ${e.details}'.toLowerCase();
      if (code == '42501' ||
          code == 'PGRST301' ||
          combined.contains('permission denied') ||
          combined.contains('jwt')) {
        debugPrint('[AUTH] fetchProfile access/auth error; using auth fallbacks');
        return null;
      }
      debugPrint('[Auth] RAW ERROR TYPE: ${e.runtimeType}');
      debugPrint('[Auth] RAW ERROR MESSAGE: ${_rawErrorMessageForLogs(e)}');
      debugPrint('[Auth] STACK: $st');
      if (kDebugMode) {
        rethrow;
      }
      throw Exception(
        userFriendlyErrorMessage(e, fallback: 'Could not load your profile. Please try again.'),
      );
    }
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
      chefAccessLevel: null,
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
    ChefAccessLevel? chefAccess;
    String? rejectionReason;
    final chefRaw = profile['chef_profiles'];
    if (chefRaw is List && chefRaw.isNotEmpty) {
      final row = chefRaw.first as Map<String, dynamic>;
      chefStatus = _chefApprovalFromStatus(row['approval_status'] as String?);
      rejectionReason = row['rejection_reason'] as String?;
      chefAccess = _chefAccessLevelFromChefRow(row);
    } else if (chefRaw is Map<String, dynamic>) {
      chefStatus = _chefApprovalFromStatus(chefRaw['approval_status'] as String?);
      rejectionReason = chefRaw['rejection_reason'] as String?;
      chefAccess = _chefAccessLevelFromChefRow(chefRaw);
    }

    // Fallback: if we don't have an embedded chef profile row (e.g. relation not configured),
    // explicitly query chef_profiles so cook routing works.
    if (appRole == AppRole.chef && (chefStatus == null || chefAccess == null)) {
      try {
        debugPrint('[Auth] chef_profiles lookup start id=${user.id} (embedded row missing)');
        final chefProfileRow = await _sb
            .from('chef_profiles')
            .select('approval_status,rejection_reason,access_level')
            .eq('id', user.id)
            .maybeSingle();
        debugPrint('[Auth] chef_profiles lookup success row=${chefProfileRow != null}');

        if (chefProfileRow != null) {
          final row = chefProfileRow as Map<String, dynamic>;
          chefStatus ??= _chefApprovalFromStatus(row['approval_status'] as String?);
          rejectionReason ??= row['rejection_reason'] as String?;
          chefAccess ??= _chefAccessLevelFromChefRow(row);
        }
      } catch (_) {
        // Leave chefStatus/rejectionReason as null -> caller will route to customer/login.
      }
    }

    final blocked = profile['is_blocked'] as bool? ?? false;
    if (appRole == AppRole.chef) {
      chefAccess ??= _inferChefAccessFromLegacy(approval: chefStatus, profileBlocked: blocked);
      if (blocked) {
        chefAccess = ChefAccessLevel.blockedAccess;
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
      chefAccessLevel: appRole == AppRole.chef ? chefAccess : null,
      chefApprovalStatus: chefStatus,
      rejectionReason: rejectionReason,
      isBlocked: blocked,
    );
  }

  ChefAccessLevel? _chefAccessLevelFromChefRow(Map<String, dynamic> row) {
    final raw = (row['access_level'] ?? '').toString().toLowerCase().trim();
    switch (raw) {
      case 'full_access':
        return ChefAccessLevel.fullAccess;
      case 'partial_access':
        return ChefAccessLevel.partialAccess;
      case 'blocked_access':
        return ChefAccessLevel.blockedAccess;
      default:
        return null;
    }
  }

  /// When [access_level] column is absent (pre-migration DB).
  ChefAccessLevel _inferChefAccessFromLegacy({
    required ChefApprovalStatus? approval,
    required bool profileBlocked,
  }) {
    if (profileBlocked) return ChefAccessLevel.blockedAccess;
    switch (approval) {
      case ChefApprovalStatus.approved:
        return ChefAccessLevel.fullAccess;
      case ChefApprovalStatus.rejected:
      case ChefApprovalStatus.pending:
      case null:
        return ChefAccessLevel.partialAccess;
    }
  }

  ChefApprovalStatus? _chefApprovalFromStatus(String? status) {
    if (status == null) return null;
    switch (status.toLowerCase()) {
      case 'pending':
      case 'waiting':
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
