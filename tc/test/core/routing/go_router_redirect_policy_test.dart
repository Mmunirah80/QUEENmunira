import 'package:flutter_test/flutter_test.dart';
import 'package:naham_cook_app/core/constants/route_names.dart';
import 'package:naham_cook_app/core/routing/go_router_redirect_policy.dart';
import 'package:naham_cook_app/features/auth/domain/entities/user_entity.dart';
import 'package:naham_cook_app/features/cook/data/models/chef_doc_model.dart';

UserEntity _u({
  required AppRole role,
  ChefAccessLevel? chefAccess,
  bool blocked = false,
}) {
  return UserEntity(
    id: 'u1',
    email: 'a@b.c',
    name: 'Test',
    role: role,
    chefAccessLevel: chefAccess,
    isBlocked: blocked,
  );
}

void main() {
  group('redirectForExpiredSession', () {
    test('expired session on protected path → login', () {
      expect(
        redirectForExpiredSession(path: RouteNames.customerRoot, sessionIsExpired: true),
        RouteNames.login,
      );
    });

    test('expired session may stay on login or splash', () {
      expect(redirectForExpiredSession(path: RouteNames.login, sessionIsExpired: true), isNull);
      expect(redirectForExpiredSession(path: RouteNames.splash, sessionIsExpired: true), isNull);
    });

    test('valid session → no redirect', () {
      expect(
        redirectForExpiredSession(path: RouteNames.customerRoot, sessionIsExpired: false),
        isNull,
      );
    });
  });

  group('computeSplashTarget', () {
    test('customer → customer root', () {
      expect(
        computeSplashTarget(
          hasValidSession: true,
          user: _u(role: AppRole.customer),
          chefDoc: null,
        ),
        RouteNames.customerRoot,
      );
    });

    test('admin → admin home', () {
      expect(
        computeSplashTarget(
          hasValidSession: true,
          user: _u(role: AppRole.admin),
          chefDoc: null,
        ),
        RouteNames.adminHome,
      );
    });

    test('chef full access → chef home', () {
      expect(
        computeSplashTarget(
          hasValidSession: true,
          user: _u(role: AppRole.chef, chefAccess: ChefAccessLevel.fullAccess),
          chefDoc: null,
        ),
        RouteNames.chefHome,
      );
    });

    test('chef partial access → cook onboarding gate (both docs must be approved)', () {
      expect(
        computeSplashTarget(
          hasValidSession: true,
          user: _u(role: AppRole.chef, chefAccess: ChefAccessLevel.partialAccess),
          chefDoc: null,
        ),
        RouteNames.cookPending,
      );
    });

    test('blocked user → account suspended', () {
      expect(
        computeSplashTarget(
          hasValidSession: true,
          user: _u(role: AppRole.customer, blocked: true),
          chefDoc: null,
        ),
        RouteNames.accountSuspended,
      );
    });

    test('chef with active freeze doc → frozen screen before shell', () {
      final doc = ChefDocModel(
        freezeUntil: DateTime.now().add(const Duration(days: 1)),
      );
      expect(
        computeSplashTarget(
          hasValidSession: true,
          user: _u(role: AppRole.chef, chefAccess: ChefAccessLevel.fullAccess),
          chefDoc: doc,
        ),
        RouteNames.chefFrozen,
      );
    });

    test('chef blocked access level → chef blocked route', () {
      expect(
        computeSplashTarget(
          hasValidSession: true,
          user: _u(role: AppRole.chef, chefAccess: ChefAccessLevel.blockedAccess),
          chefDoc: null,
        ),
        RouteNames.chefBlocked,
      );
    });

    test('invalid session → stay on splash (null)', () {
      expect(
        computeSplashTarget(hasValidSession: false, user: _u(role: AppRole.customer), chefDoc: null),
        isNull,
      );
    });
  });

  group('computeChefFrozenRedirect', () {
    final frozenDoc = ChefDocModel(
      freezeUntil: DateTime.now().add(const Duration(days: 1)),
    );

    test('non-chef → null', () {
      expect(
        computeChefFrozenRedirect(
          user: _u(role: AppRole.customer),
          chefDoc: frozenDoc,
          path: RouteNames.chefHome,
        ),
        isNull,
      );
    });

    test('chef not frozen → null', () {
      expect(
        computeChefFrozenRedirect(
          user: _u(role: AppRole.chef, chefAccess: ChefAccessLevel.fullAccess),
          chefDoc: ChefDocModel(freezeUntil: DateTime.now().subtract(const Duration(days: 1))),
          path: RouteNames.chefHome,
        ),
        isNull,
      );
    });

    test('frozen chef on /chef/home → frozen screen', () {
      expect(
        computeChefFrozenRedirect(
          user: _u(role: AppRole.chef, chefAccess: ChefAccessLevel.fullAccess),
          chefDoc: frozenDoc,
          path: RouteNames.chefHome,
        ),
        RouteNames.chefFrozen,
      );
    });

    test('frozen chef may open notifications and public auth paths', () {
      expect(
        computeChefFrozenRedirect(
          user: _u(role: AppRole.chef, chefAccess: ChefAccessLevel.fullAccess),
          chefDoc: frozenDoc,
          path: RouteNames.chefNotifications,
        ),
        isNull,
      );
      expect(
        computeChefFrozenRedirect(
          user: _u(role: AppRole.chef, chefAccess: ChefAccessLevel.fullAccess),
          chefDoc: frozenDoc,
          path: RouteNames.login,
        ),
        isNull,
      );
    });
  });

  group('computeAuthRedirect — role isolation', () {
    test('customer cannot open chef or admin top-level routes', () {
      final u = _u(role: AppRole.customer);
      expect(
        computeAuthRedirect(user: u, path: RouteNames.chefHome, sessionIsExpired: false),
        RouteNames.customerRoot,
      );
      expect(
        computeAuthRedirect(user: u, path: RouteNames.adminHome, sessionIsExpired: false),
        RouteNames.customerRoot,
      );
      expect(
        computeAuthRedirect(
          user: u,
          path: '${RouteNames.adminHome}/user/abc',
          sessionIsExpired: false,
        ),
        RouteNames.customerRoot,
      );
    });

    test('chef full access cannot open customer or admin shells', () {
      final u = _u(role: AppRole.chef, chefAccess: ChefAccessLevel.fullAccess);
      expect(
        computeAuthRedirect(user: u, path: RouteNames.customerRoot, sessionIsExpired: false),
        RouteNames.chefHome,
      );
      expect(
        computeAuthRedirect(user: u, path: RouteNames.adminHome, sessionIsExpired: false),
        RouteNames.chefHome,
      );
    });

    test('chef partial access stays on onboarding paths; blocked from chef shell', () {
      final u = _u(role: AppRole.chef, chefAccess: ChefAccessLevel.partialAccess);
      expect(
        computeAuthRedirect(user: u, path: RouteNames.cookPending, sessionIsExpired: false),
        isNull,
      );
      expect(
        computeAuthRedirect(user: u, path: RouteNames.chefVerificationDocuments, sessionIsExpired: false),
        isNull,
      );
      expect(
        computeAuthRedirect(user: u, path: RouteNames.chefHome, sessionIsExpired: false),
        RouteNames.cookPending,
      );
    });

    test('admin is redirected away from customer and chef shells', () {
      final u = _u(role: AppRole.admin);
      expect(
        computeAuthRedirect(user: u, path: RouteNames.customerRoot, sessionIsExpired: false),
        RouteNames.adminHome,
      );
      expect(
        computeAuthRedirect(user: u, path: RouteNames.chefHome, sessionIsExpired: false),
        RouteNames.adminHome,
      );
    });

    test('admin may open nested admin user detail', () {
      final u = _u(role: AppRole.admin);
      expect(
        computeAuthRedirect(
          user: u,
          path: '${RouteNames.adminHome}/user/x',
          sessionIsExpired: false,
        ),
        isNull,
      );
    });

    test('blocked user always sent to suspended unless already on blocked screens', () {
      final u = _u(role: AppRole.customer, blocked: true);
      expect(
        computeAuthRedirect(user: u, path: RouteNames.customerRoot, sessionIsExpired: false),
        RouteNames.accountSuspended,
      );
      expect(
        computeAuthRedirect(user: u, path: RouteNames.accountSuspended, sessionIsExpired: false),
        isNull,
      );
    });

    test('chef blocked access stuck on blocked route for /chef/*', () {
      final u = _u(role: AppRole.chef, chefAccess: ChefAccessLevel.blockedAccess);
      expect(
        computeAuthRedirect(user: u, path: RouteNames.chefHome, sessionIsExpired: false),
        RouteNames.chefBlocked,
      );
      expect(
        computeAuthRedirect(user: u, path: RouteNames.chefBlocked, sessionIsExpired: false),
        isNull,
      );
    });

    test('unauthenticated user on /customer → login', () {
      expect(
        computeAuthRedirect(user: null, path: RouteNames.customerRoot, sessionIsExpired: false),
        RouteNames.login,
      );
    });

    test('chef legacy rejection route redirects active chef to home', () {
      final u = _u(role: AppRole.chef, chefAccess: ChefAccessLevel.fullAccess);
      expect(
        computeAuthRedirect(user: u, path: RouteNames.chefRejection, sessionIsExpired: false),
        RouteNames.chefHome,
      );
    });
  });

  group('computeAuthRedirect — chef without resolved access level', () {
    test('treated as onboarding → cook pending', () {
      final u = UserEntity(
        id: 'c1',
        email: 'c@c.c',
        name: 'Chef',
        role: AppRole.chef,
        chefAccessLevel: null,
      );
      expect(
        computeAuthRedirect(user: u, path: RouteNames.chefHome, sessionIsExpired: false),
        RouteNames.cookPending,
      );
    });
  });

  group('isPublicAuthPath', () {
    test('registration paths are public', () {
      expect(isPublicAuthPath(RouteNames.chefRegAccount), isTrue);
    });
  });
}
