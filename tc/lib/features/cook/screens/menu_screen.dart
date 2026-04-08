// ============================================================
// COOK MENU SCREEN — Naham App, Supabase-backed, RTL, TC theme
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/menu/naham_menu_categories.dart';
import '../../../core/theme/app_design_system.dart';
import '../../../core/widgets/loading_widget.dart';
import '../../../core/widgets/naham_empty_screens.dart';
import '../../../features/menu/domain/entities/dish_entity.dart';
import '../../../features/menu/presentation/mappers/dish_ui_mapper.dart';
import '../../../features/menu/presentation/providers/menu_provider.dart';
import '../../../features/menu/presentation/screens/add_menu_item_screen.dart';
import '../presentation/providers/chef_providers.dart';

class _NC {
  static const primary = AppDesignSystem.primary;
  static const primaryMid = AppDesignSystem.primaryMid;
  static const primaryLight = AppDesignSystem.primaryLight;
  static const bg = AppDesignSystem.backgroundOffWhite;
  static const surface = AppDesignSystem.cardWhite;
  static const text = AppDesignSystem.textPrimary;
  static const textSub = AppDesignSystem.textSecondary;
  static const border = Color(0xFFE8E0F5);
  static const error = AppDesignSystem.errorRed;
  static const warning = AppDesignSystem.warningOrange;
}

// ─── Menu Screen ─────────────────────────────────────────────
class MenuScreen extends ConsumerStatefulWidget {
  const MenuScreen({super.key});

  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen> {
  int _selectedCategory = 0;

  List<String> get _categories => NahamMenuCategories.filterChipsWithAll;

  static List<Map<String, dynamic>> _filter(
    List<Map<String, dynamic>> dishes,
    int selectedCategory,
    List<String> categories,
  ) {
    if (selectedCategory == 0) {
      return dishes;
    }
    final cat = categories[selectedCategory];
    return dishes
        .where(
          (d) => NahamMenuCategories.dishMatchesFilter(
                d['category'] as String?,
                cat,
              ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final dishesAsync = ref.watch(chefDishesStreamProvider);

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: _NC.bg,
        appBar: AppBar(
          title: const Text('Cook Menu'),
          centerTitle: true,
          backgroundColor: _NC.primary,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Column(
          children: [
            _buildCategories(),
            Expanded(
              child: dishesAsync.when(
                data: (entities) {
                  final dishes = DishUiMapper.toMenuMaps(entities);
                  final filtered = _filter(dishes, _selectedCategory, _categories);
                  if (filtered.isEmpty) {
                    return _buildEmpty(
                      brandNewKitchen: entities.isEmpty && _selectedCategory == 0,
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async => ref.invalidate(chefDishesStreamProvider),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                      itemCount: filtered.length,
                      itemBuilder: (ctx, i) {
                      final dishMap = filtered[i];
                      final entity = entities.firstWhere((e) => e.id == dishMap['id']);
                      return _DishCard(
                        dish: dishMap,
                        onToggle: () => _toggleAvailability(dishMap['id'] as String),
                        onEdit: () => _openAddMenuItemScreen(context, entity),
                        onDelete: () => _showDeleteDialog(context, dishMap),
                      );
                      },
                    ),
                  );
                },
                loading: () => const Center(child: LoadingWidget()),
                error: (err, _) => Center(
                  child: ErrorStateContent(
                    message: err.toString().replaceFirst('Exception: ', ''),
                    onRetry: () => ref.invalidate(chefDishesStreamProvider),
                  ),
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: _buildFAB(),
      ),
    );
  }

  Future<void> _toggleAvailability(String dishId) async {
    try {
      await ref.read(menuRepositoryProvider).toggleDishAvailability(dishId);
      ref.invalidate(chefDishesStreamProvider);
    } catch (e) {
      debugPrint('[CookMenu] toggle availability error=$e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Generic error')),
        );
      }
    }
  }

  Widget _buildCategories() {
    return Container(
      color: _NC.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: SizedBox(
        height: 40,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _categories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (ctx, i) {
            final label = _categories[i];
            final isSelected = i == _selectedCategory;
            final asset = NahamMenuCategories.chipImageAssetById[label];
            final icon = NahamMenuCategories.iconForChip(label);
            return GestureDetector(
              onTap: () => setState(() => _selectedCategory = i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: isSelected ? _NC.primaryMid : _NC.bg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected ? _NC.primaryMid : _NC.border,
                  ),
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (asset != null)
                        CircleAvatar(
                          radius: 11,
                          backgroundColor:
                              isSelected ? Colors.white.withValues(alpha: 0.35) : _NC.surface,
                          backgroundImage: AssetImage(asset),
                        )
                      else
                        Icon(
                          icon,
                          size: 17,
                          color: isSelected ? Colors.white : _NC.textSub,
                        ),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? Colors.white : _NC.textSub,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmpty({required bool brandNewKitchen}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _NC.primaryLight,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(Icons.restaurant_menu_rounded,
                size: 40, color: _NC.primaryMid),
          ),
          const SizedBox(height: 16),
          Text(
            brandNewKitchen ? 'Your menu is empty' : 'No dishes in this category',
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600, color: _NC.text),
          ),
          const SizedBox(height: 6),
          Text(
            brandNewKitchen
                ? 'New kitchen: tap + to add your first dish.'
                : 'Tap + to add a new dish',
            style: const TextStyle(fontSize: 13, color: _NC.textSub),
          ),
        ],
      ),
    );
  }

  Widget _buildFAB() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_NC.primary, _NC.primaryMid],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _NC.primaryMid.withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showAddSheet(context),
          borderRadius: BorderRadius.circular(16),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text(
                  'Add Dish',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddSheet(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const AddMenuItemScreen(),
      ),
    );
  }

  void _openAddMenuItemScreen(BuildContext context, DishEntity entity) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AddMenuItemScreen(existingItem: entity),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, Map<String, dynamic> dish) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete dish',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text(
            'Are you sure you want to delete "${dish['name']}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final id = dish['id'] as String;
              try {
                final client = Supabase.instance.client;
                final activeOrders = await client
                    .from('order_items')
                    .select('order_id,orders!inner(status)')
                    .eq('menu_item_id', id)
                    .inFilter('orders.status', ['accepted', 'preparing', 'ready']);
                if ((activeOrders as List).isNotEmpty) {
                  if (context.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Cannot delete this dish because it exists in active orders.'),
                      ),
                    );
                  }
                  return;
                }
                // Delete recipe ingredients first, then the dish itself.
                await client
                    .from('recipe_ingredients')
                    .delete()
                    .eq('menu_item_id', id);
                await client.from('menu_items').delete().eq('id', id);
                ref.invalidate(chefDishesStreamProvider);
                if (context.mounted) Navigator.pop(ctx);
              } catch (e) {
                debugPrint('[CookMenu] delete dish error=$e');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Generic error')),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _NC.error,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ─── Dish Card ────────────────────────────────────────────────
class _DishCard extends StatelessWidget {
  final Map<String, dynamic> dish;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _DishCard({
    required this.dish,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isAvailable = dish['available'] as bool;
    final badge = dish['badge'] as String;

    return GestureDetector(
      onLongPress: onDelete,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: _NC.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Left: dish image (60x60, rounded)
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: dish['color'] as Color,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: (dish['imageUrl'] as String?)?.isNotEmpty == true
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(
                          dish['imageUrl'] as String,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Text(
                            dish['emoji'] as String,
                            style: const TextStyle(fontSize: 28),
                          ),
                        ),
                      )
                    : Text(
                        dish['emoji'] as String,
                        style: const TextStyle(fontSize: 28),
                      ),
              ),
              const SizedBox(width: 12),
              // Middle: dish name + price + category (Expanded)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      dish['name'] as String,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isAvailable ? _NC.text : _NC.textSub,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '${(dish['price'] as num).toStringAsFixed(0)} SAR',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: isAvailable ? _NC.primaryMid : _NC.textSub,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          dish['category'] as String? ?? 'Other',
                          style: const TextStyle(
                            fontSize: 12,
                            color: _NC.textSub,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (badge.isNotEmpty) ...[
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: _NC.warning.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              badge,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _NC.warning,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Remaining: ${(dish['remainingQuantity'] ?? 0)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: _NC.textSub,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              // Right: availability toggle + edit/delete
              Column(
                children: [
                  Switch(
                    value: isAvailable,
                    onChanged: (_) => onToggle(),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: onEdit,
                        color: _NC.primaryMid,
                        tooltip: 'Edit',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: onDelete,
                        color: _NC.error,
                        tooltip: 'Delete',
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
