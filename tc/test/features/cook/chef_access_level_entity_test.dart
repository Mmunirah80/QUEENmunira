import 'package:flutter_test/flutter_test.dart';
import 'package:naham_cook_app/features/auth/domain/entities/user_entity.dart';

/// Routing / shell flags derived from [UserEntity] + [ChefAccessLevel].
void main() {
  UserEntity chef({ChefAccessLevel? level}) {
    return UserEntity(
      id: 'c1',
      email: 'c@x.y',
      name: 'Cook',
      role: AppRole.chef,
      chefAccessLevel: level,
    );
  }

  group('Chef access level helpers', () {
    test('full access', () {
      final u = chef(level: ChefAccessLevel.fullAccess);
      expect(u.isChefFullAccess, isTrue);
      expect(u.isChefPartialAccess, isFalse);
      expect(u.isChefBlockedAccess, isFalse);
    });

    test('partial access (limited shell in product)', () {
      final u = chef(level: ChefAccessLevel.partialAccess);
      expect(u.isChefPartialAccess, isTrue);
      expect(u.isChefFullAccess, isFalse);
    });

    test('blocked access (chef blocked route)', () {
      final u = chef(level: ChefAccessLevel.blockedAccess);
      expect(u.isChefBlockedAccess, isTrue);
      expect(u.isChefFullAccess, isFalse);
    });

    test('null access level — no partial/full flags', () {
      final u = chef(level: null);
      expect(u.isChefFullAccess, isFalse);
      expect(u.isChefPartialAccess, isFalse);
      expect(u.isChefBlockedAccess, isFalse);
    });
  });
}
