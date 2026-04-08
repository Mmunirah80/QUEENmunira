import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/data/models/user_model.dart';
import '../../features/auth/domain/entities/user_entity.dart';
import '../constants/route_names.dart';

/// Seeded demo UUIDs — keep in sync with Supabase seed SQL (`profiles`, RLS tests).
const String kDebugBypassChefUserId = 'e0a00001-0000-4000-8de0-00000000c001';
const String kDebugBypassCustomerUserId = 'e0a00001-0000-4000-8de0-00000000c003';
const String kDebugBypassAdminUserId = 'e0a00001-0000-4000-8de0-00000000a001';

/// Maps [SupabaseClient.auth] to the user id used for inserts/RLS checks.
/// In debug bypass, uses the active mock persona ([userModel]); otherwise the real session.
String? effectiveSupabaseAuthUserId(SupabaseClient client) {
  if (authBypassIsOn) {
    return DebugAuthBypass.userModel().id;
  }
  final raw = client.auth.currentUser?.id;
  if (raw == null || raw.isEmpty) return null;
  return raw.trim();
}

// =============================================================================
// DEBUG ONLY — temporary bypass for Supabase Auth (signInWithPassword / session).
// Release builds ignore this path (kDebugMode is false).
//
// Note: PostgREST/Realtime still use the anon JWT. RLS policies that require
// auth.uid() may return no rows until real sign-in works or policies are relaxed
// for local dev. Navigation and in-app [authStateProvider] use the UUIDs below.
// =============================================================================

/// **Mock auth (debug only):** skip real sign-in; use seeded UUIDs below.
/// Set to `false` for real Supabase Auth while debugging (mobile & web).
///
/// Or run without editing code:
/// `flutter run --dart-define=NAHAM_MOCK_AUTH=false` forces real auth in debug.
const bool kBypassAuth = true;

const bool _nahamMockAuthFromEnv = bool.fromEnvironment(
  'NAHAM_MOCK_AUTH',
  defaultValue: true,
);

/// True in debug when mock auth is on ([kBypassAuth] or dart-define, default mock on).
bool get authBypassIsOn =>
    kDebugMode &&
    kBypassAuth &&
    _nahamMockAuthFromEnv;

/// Switch mock persona without touching the database (debug bypass only).
enum DebugRole {
  chef,
  customer,
  admin,
}

/// Tracks the active [DebugRole] for [AuthBypassDatasource] (no Riverpod inside DS).
class DebugAuthBypass {
  DebugAuthBypass._();

  static DebugRole currentRole = DebugRole.chef;

  static void setRole(DebugRole role) {
    currentRole = role;
  }

  static UserModel userModel([DebugRole? role]) {
    final r = role ?? currentRole;
    switch (r) {
      case DebugRole.chef:
        return const UserModel(
          id: kDebugBypassChefUserId,
          email: 'cook_demo@naham.demo',
          name: 'Debug Cook',
          phone: '+966501000001',
          isVerified: true,
          role: AppRole.chef,
          chefAccessLevel: ChefAccessLevel.fullAccess,
          chefApprovalStatus: ChefApprovalStatus.approved,
        );
      case DebugRole.customer:
        return const UserModel(
          id: kDebugBypassCustomerUserId,
          email: 'customer_demo@naham.demo',
          name: 'Debug Customer',
          phone: '+966501000003',
          isVerified: true,
          role: AppRole.customer,
        );
      case DebugRole.admin:
        return const UserModel(
          id: kDebugBypassAdminUserId,
          email: 'admin2@naham.com',
          name: 'Debug Admin',
          phone: '+966500000001',
          isVerified: true,
          role: AppRole.admin,
        );
    }
  }

  static String homeRouteFor(DebugRole role) {
    switch (role) {
      case DebugRole.chef:
        return RouteNames.chefHome;
      case DebugRole.customer:
        return RouteNames.customerRoot;
      case DebugRole.admin:
        return RouteNames.adminHome;
    }
  }
}
