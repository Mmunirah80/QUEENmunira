import 'package:flutter/foundation.dart';

import '../../features/auth/domain/entities/user_entity.dart';
import '../../features/cook/data/models/chef_doc_model.dart';
import '../constants/route_names.dart';
import '../debug/debug_auth_bypass.dart';

/// Cook has not completed two-document approval — only [cookPending], verification docs, and notifications.
bool isChefOnboardingGatePath(String path) {
  return path == RouteNames.cookPending ||
      path == RouteNames.chefVerificationDocuments ||
      path == RouteNames.chefNotifications;
}

/// Partial access or unresolved access level: no main shell until both documents are approved.
bool isChefInDocumentOnboarding(UserEntity user) {
  if (!user.isChef) return false;
  if (user.isChefFullAccess) return false;
  if (user.isChefBlockedAccess) return false;
  return user.isChefPartialAccess || user.chefAccessLevel == null;
}

/// Public auth/onboarding paths that unauthenticated users may open without redirect to login.
bool isPublicAuthPath(String path) {
  return path == RouteNames.splash ||
      path == RouteNames.onboarding ||
      path == RouteNames.roleSelection ||
      path == RouteNames.login ||
      path == RouteNames.signup ||
      path == RouteNames.forgotPassword ||
      path == RouteNames.rootDecider ||
      path.startsWith('/chef-registration') ||
      path == RouteNames.chefRejection;
}

/// Expired Supabase session → force login (except staying on login/splash).
String? redirectForExpiredSession({
  required String path,
  required bool sessionIsExpired,
}) {
  if (authBypassIsOn) {
    return null;
  }
  if (sessionIsExpired && path != RouteNames.login && path != RouteNames.splash) {
    return RouteNames.login;
  }
  return null;
}

/// Splash route: where to go after session + profile resolve (null = stay on splash / handled by UI).
String? computeSplashTarget({
  required bool hasValidSession,
  required UserEntity? user,
  required ChefDocModel? chefDoc,
}) {
  String? inner() {
    if (!hasValidSession || user == null || user.role == null) return null;
    if (user.isBlocked) return RouteNames.accountSuspended;
    if (user.isChef && !user.isBlocked) {
      if (chefDoc?.isFreezeActive == true) return RouteNames.chefFrozen;
    }
    if (user.isChef && user.isChefBlockedAccess) return RouteNames.chefBlocked;
    if (user.isChef && user.isChefFullAccess) return RouteNames.chefHome;
    if (user.isChef && isChefInDocumentOnboarding(user)) return RouteNames.cookPending;
    if (user.isAdmin) return RouteNames.adminHome;
    if (user.isCustomer) return RouteNames.customerRoot;
    if (user.isChef) return RouteNames.cookPending;
    return RouteNames.login;
  }

  final target = inner();
  if (kDebugMode) {
    debugPrint(
      '[ROUTER] computeSplashTarget session=$hasValidSession uid=${user?.id} role=${user?.role} '
      'chefFreeze=${chefDoc?.isFreezeActive} -> ${target ?? "stay"}',
    );
  }
  return target;
}

/// Frozen chef: only frozen screen, login, splash, notifications, or public auth paths.
String? computeChefFrozenRedirect({
  required UserEntity? user,
  required ChefDocModel? chefDoc,
  required String path,
}) {
  if (user == null || !user.isChef || user.isBlocked) return null;
  if (chefDoc?.isFreezeActive != true) return null;
  if (path == RouteNames.chefFrozen) return null;
  if (path == RouteNames.login || path == RouteNames.splash) return null;
  if (path == RouteNames.chefNotifications) return null;
  if (isPublicAuthPath(path)) return null;
  return RouteNames.chefFrozen;
}

/// Role-based access for all non-splash routes (after optional frozen redirect).
String? computeAuthRedirect({
  required UserEntity? user,
  required String path,
  required bool sessionIsExpired,
}) {
  final sessionRedirect = redirectForExpiredSession(path: path, sessionIsExpired: sessionIsExpired);
  if (sessionRedirect != null) return sessionRedirect;

  if (user == null || user.role == null) {
    if (isPublicAuthPath(path)) return null;
    return RouteNames.login;
  }

  if (user.isBlocked) {
    if (path == RouteNames.accountSuspended || path == RouteNames.chefBlocked) return null;
    return RouteNames.accountSuspended;
  }

  if (path == RouteNames.chefRejection && user.isChef) {
    return user.isChefFullAccess ? RouteNames.chefHome : RouteNames.cookPending;
  }

  if (user.isChef && user.isChefBlockedAccess) {
    if (path == RouteNames.chefBlocked) return null;
    if (isPublicAuthPath(path) || path == RouteNames.splash) return RouteNames.chefBlocked;
    if (path.startsWith('/chef/')) return RouteNames.chefBlocked;
    return RouteNames.chefBlocked;
  }

  if (user.isChef && user.isChefFullAccess) {
    if (path.startsWith('/chef-registration')) return null;
    if (path == RouteNames.cookPending) return RouteNames.chefHome;
    if (path.startsWith('/chef/')) return null;
    if (path.startsWith('/customer') || path.startsWith(RouteNames.adminHome)) {
      return RouteNames.chefHome;
    }
    if (isPublicAuthPath(path) || path == RouteNames.splash) return RouteNames.chefHome;
    return RouteNames.chefHome;
  }

  if (user.isChef && isChefInDocumentOnboarding(user)) {
    if (path.startsWith('/chef-registration')) return null;
    if (isChefOnboardingGatePath(path)) return null;
    if (path == RouteNames.splash) return RouteNames.cookPending;
    if (isPublicAuthPath(path)) return null;
    return RouteNames.cookPending;
  }

  if (user.isAdmin) {
    if (path == RouteNames.adminHome || path.startsWith('${RouteNames.adminHome}/')) return null;
    if (isPublicAuthPath(path) || path == RouteNames.splash) return RouteNames.adminHome;
    if (path.startsWith('/customer') || path.startsWith('/chef')) return RouteNames.adminHome;
    return null;
  }

  if (user.isCustomer) {
    if (isPublicAuthPath(path) || path == RouteNames.splash) return RouteNames.customerRoot;
    if (path.startsWith('/chef') && !path.startsWith('/chef-registration')) {
      return RouteNames.customerRoot;
    }
    if (path.startsWith(RouteNames.adminHome)) return RouteNames.customerRoot;
    if (path.startsWith('/customer')) return null;
    return RouteNames.customerRoot;
  }

  if (isPublicAuthPath(path)) return null;
  return RouteNames.login;
}
