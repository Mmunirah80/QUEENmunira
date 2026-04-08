/// Admin chef discipline ladder (matches `admin_chef_take_enforcement_action` in SQL).
abstract final class ChefEnforcement {
  ChefEnforcement._();

  /// Next action label for the single **Take Action** button (English UI copy).
  static String nextActionLabel({
    required int warningCount,
    required int freezeLevel,
    required bool profileBlocked,
  }) {
    if (profileBlocked) return '';
    if (warningCount == 0) return 'Issue Warning';
    if (freezeLevel == 0) return 'Freeze 3 days';
    if (freezeLevel == 1) return 'Freeze 7 days';
    if (freezeLevel == 2) return 'Freeze 14 days';
    if (freezeLevel == 3) return 'Block Chef';
    return '';
  }
}
