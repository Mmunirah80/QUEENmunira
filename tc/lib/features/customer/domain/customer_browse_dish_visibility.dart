/// Pure rules for whether a `menu_items` row may appear in customer browse streams
/// ([CustomerBrowseSupabaseDatasource.watchAvailableDishes] / [watchChefDishes]).
bool menuItemRowVisibleInCustomerBrowse({
  required bool isAvailable,
  required String? moderationStatus,
  required int remainingQuantity,
}) {
  final isModeratedIn = moderationStatus == null || moderationStatus == 'approved';
  return isAvailable && remainingQuantity > 0 && isModeratedIn;
}
