import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/supabase/supabase_config.dart';
import '../../../../core/theme/app_design_system.dart';
import '../../../../services/ai_service.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../cook/presentation/providers/chef_providers.dart';
import '../../data/datasources/seasons_supabase_datasource.dart';
import '../../data/models/season_model.dart';
import '../../domain/entities/dish_entity.dart';
import '../providers/menu_provider.dart';

/// Add / Edit Menu Item screen (chef side) with:
/// - basic info
/// - recipe builder (ingredients + servings)
/// - Analyze with AI button
/// - loading steps animation
/// - results view with cost breakdown
/// In edit mode [existingItem] is set; Save updates in Supabase instead of creating.
class AddMenuItemScreen extends ConsumerStatefulWidget {
  const AddMenuItemScreen({super.key, this.existingItem});

  final DishEntity? existingItem;

  @override
  ConsumerState<AddMenuItemScreen> createState() => _AddMenuItemScreenState();
}

class _AddMenuItemScreenState extends ConsumerState<AddMenuItemScreen> {
  final _formKey = GlobalKey<FormState>();

  // Step 1 – basic info
  final _nameCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  String _category = 'Najdi';
  File? _imageFile;
  Uint8List? _imageBytes;
  String? _imageUrl;

  // Step 2 – recipe / AI pricing
  final List<_IngredientRowData> _ingredients = [
    _IngredientRowData(),
  ];
  final _servingsCtrl = TextEditingController(text: '4');
  final _manualPriceCtrl = TextEditingController();
  final _profitCtrl = TextEditingController(text: '30');
  bool _profitIsPercent = true;

  _PricingMode _pricingMode = _PricingMode.none;

  // AI state
  bool _analyzing = false;
  int _currentStepIndex = 0;
  Map<String, dynamic>? _result;
  String? _error;
  double _recommendedPrice = 0;
  double _profitAmount = 0;

  final _aiService = AiService();
  final _seasonsDataSource = SeasonsSupabaseDataSource();
  List<SeasonModel> _seasons = const [];

  static const _categoryValues = [
    'Northern',
    'Southern',
    'Eastern',
    'Western',
    'Najdi',
    'Sweets',
    'Other',
  ];

  static const _steps = [
    'Calculating ingredient costs...',
    'Adding spices estimate (3%)...',
    'Adding operational costs (10%)...',
    'Adding your profit margin...',
    'Detecting current season...',
    'Calculating final price...',
    'Done!',
  ];

  @override
  void initState() {
    super.initState();
    final existing = widget.existingItem;
    if (existing != null) {
      _nameCtrl.text = existing.name;
      _descriptionCtrl.text = existing.description;
      _category = existing.categories.isNotEmpty &&
              _categoryValues.contains(existing.categories.first)
          ? existing.categories.first
          : 'Najdi';
      _imageUrl = existing.imageUrl;
      _manualPriceCtrl.text = existing.price.toStringAsFixed(2);
      _pricingMode = _PricingMode.manual;
    }
    _loadSeasons();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descriptionCtrl.dispose();
    _servingsCtrl.dispose();
    _manualPriceCtrl.dispose();
    _profitCtrl.dispose();
    for (final i in _ingredients) {
      i.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existingItem != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Menu Item' : 'Add Menu Item'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_error != null)
              Container(
                width: double.infinity,
                color: Colors.red.withOpacity(0.06),
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(left: 16, right: 16, top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error!,
                      style: const TextStyle(color: Colors.red, fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _analyzing
                          ? null
                          : () {
                              setState(() => _error = null);
                              _onAnalyzePressed();
                            },
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPhotoPicker(context),
                      const SizedBox(height: 16),
                      const Text(
                        'Basic info',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Dish name',
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Please enter a name' : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _descriptionCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _category,
                        items: const [
                          DropdownMenuItem(value: 'Northern', child: Text('Northern')),
                          DropdownMenuItem(value: 'Southern', child: Text('Southern')),
                          DropdownMenuItem(value: 'Eastern', child: Text('Eastern')),
                          DropdownMenuItem(value: 'Western', child: Text('Western')),
                          DropdownMenuItem(value: 'Najdi', child: Text('Najdi')),
                          DropdownMenuItem(value: 'Sweets', child: Text('Sweets')),
                          DropdownMenuItem(value: 'Other', child: Text('Other')),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _category = v);
                          }
                        },
                        decoration: const InputDecoration(labelText: 'Category'),
                      ),
                      const SizedBox(height: 24),
                      _buildPricingStep(context),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoPicker(BuildContext context) {
    Widget content;
    if (kIsWeb && _imageBytes != null) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(_imageBytes!, width: double.infinity, height: 160, fit: BoxFit.cover),
      );
    } else if (_imageFile != null) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(_imageFile!, width: double.infinity, height: 160, fit: BoxFit.cover),
      );
    } else if (_imageUrl != null && _imageUrl!.isNotEmpty) {
      content = ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(_imageUrl!, width: double.infinity, height: 160, fit: BoxFit.cover),
      );
    } else {
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.add_photo_alternate_rounded, size: 40, color: Colors.grey),
          SizedBox(height: 8),
          Text('Upload dish photo', style: TextStyle(fontWeight: FontWeight.w600)),
          SizedBox(height: 4),
          Text('This will appear in your menu', style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      );
    }

    return GestureDetector(
      onTap: () async {
        final picker = ImagePicker();
        final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
        if (picked == null || !mounted) return;
        if (kIsWeb) {
          final bytes = await picked.readAsBytes();
          if (!mounted) return;
          setState(() {
            _imageBytes = bytes;
            _imageFile = null;
          });
        } else {
          setState(() {
            _imageFile = File(picked.path);
            _imageBytes = null;
          });
        }
      },
      child: Container(
        width: double.infinity,
        height: 170,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
          color: Colors.grey.shade100,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: content,
        ),
      ),
    );
  }

  Future<void> _loadSeasons() async {
    try {
      final seasons = await _seasonsDataSource.getSeasons();
      if (!mounted) return;
      setState(() {
        _seasons = seasons;
      });
    } catch (_) {
      // Fail silently – we fall back to 0% increase when seasons cannot be loaded.
    }
  }

  Widget _buildPricingStep(BuildContext context) {
    final hasResult = _result != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pricing',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    if (!_validateBasicInfo()) return;
                    setState(() => _pricingMode = _PricingMode.manual);
                  },
                  icon: const Text('💰', style: TextStyle(fontSize: 16)),
                  label: const Text('Set my own price'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(
                      color: _pricingMode == _PricingMode.manual
                          ? AppDesignSystem.primaryDark
                          : Colors.grey.shade300,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    if (!_validateBasicInfo()) return;
                    setState(() => _pricingMode = _PricingMode.ai);
                  },
                  icon: const Text('🤖', style: TextStyle(fontSize: 16)),
                  label: const Text('Use AI pricing'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_pricingMode == _PricingMode.manual) _buildManualPricing(context),
        if (_pricingMode == _PricingMode.ai) _buildAiPricing(context, hasResult),
        if (_analyzing) ...[
          const SizedBox(height: 24),
          _buildLoadingSteps(),
        ],
        if (hasResult) ...[
          const SizedBox(height: 24),
          _buildResultCard(),
        ],
      ],
    );
  }

  Widget _buildManualPricing(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _manualPriceCtrl,
          decoration: const InputDecoration(
            labelText: 'Price (SAR)',
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () async {
              if (!_validateBasicInfo()) return;
              final v = double.tryParse(_manualPriceCtrl.text.trim());
              if (v == null || v <= 0) {
                setState(() => _error = 'Please enter a valid price.');
                return;
              }
              await _saveWithPrice(v);
            },
            child: const Text('Publish dish'),
          ),
        ),
      ],
    );
  }

  Widget _buildAiPricing(BuildContext context, bool hasResult) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Enter all ingredients for your full batch. \nAdd how many servings it makes and your desired profit. \nWe\'ll calculate the best price.',
          style: TextStyle(fontSize: 13, color: Colors.grey),
        ),
        const SizedBox(height: 12),
        _buildIngredientsTable(),
        const SizedBox(height: 12),
        TextFormField(
          controller: _servingsCtrl,
          decoration: const InputDecoration(
            labelText: 'Number of servings from this batch',
            hintText: 'How many portions does this batch make? e.g. 6',
            helperText:
                'We\'ll divide the total cost by this number to get cost per serving',
          ),
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 16),
        const Text(
          "What's your desired profit?",
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            ChoiceChip(
              label: const Text('%'),
              selected: _profitIsPercent,
              onSelected: (v) {
                if (!v) return;
                setState(() => _profitIsPercent = true);
              },
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('SAR'),
              selected: !_profitIsPercent,
              onSelected: (v) {
                if (!v) return;
                setState(() => _profitIsPercent = false);
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: _profitCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: _profitIsPercent ? 'Profit (%)' : 'Profit (SAR)',
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _analyzing ? null : _onAnalyzePressed,
            icon: const Icon(Icons.auto_awesome),
            label: const Text('Analyze with AI'),
          ),
        ),
      ],
    );
  }

  bool _validateBasicInfo() {
    if (!_formKey.currentState!.validate()) return false;
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter a dish name.');
      return false;
    }
    return true;
  }

  Future<void> _saveWithPrice(double price) async {
    if (!_validateBasicInfo()) return;
    final name = _nameCtrl.text.trim();
    final description = _descriptionCtrl.text.trim();
    final chefId = ref.read(authStateProvider).valueOrNull?.id;
    if (chefId == null || chefId.isEmpty) {
      setState(() => _error = 'You must be logged in as a cook.');
      return;
    }

    String? imageUrl = _imageUrl;

    try {
      final client = SupabaseConfig.client;
      if (_imageFile != null || _imageBytes != null) {
        final path =
            'menu-images/$chefId/${DateTime.now().millisecondsSinceEpoch}.jpg';
        if (kIsWeb) {
          // Flutter web: use bytes + uploadBinary with explicit content type
          final bytes = _imageBytes ??
              await _imageFile!.readAsBytes();
          await client.storage
              .from('menu-images')
              .uploadBinary(
                path,
                bytes,
                fileOptions: const FileOptions(
                  upsert: true,
                  contentType: 'image/jpeg',
                ),
              );
        } else if (_imageFile != null) {
          // Mobile / desktop: use File upload
          await client.storage
              .from('menu-images')
              .upload(
                path,
                _imageFile!,
                fileOptions: const FileOptions(
                  upsert: true,
                  contentType: 'image/jpeg',
                ),
              );
        }
        final public = client.storage.from('menu-images').getPublicUrl(path);
        imageUrl = public;
      }

      final repo = ref.read(menuRepositoryProvider);
      final existing = widget.existingItem;
      final now = DateTime.now();

      if (existing != null) {
        final entity = DishEntity(
          id: existing.id,
          name: name,
          description: description,
          price: price,
          imageUrl: imageUrl ?? existing.imageUrl,
          categories: [_category],
          isAvailable: existing.isAvailable,
          preparationTime: existing.preparationTime,
          createdAt: existing.createdAt,
          updatedAt: now,
          chefId: existing.chefId,
        );
        await repo.updateDish(entity);
        ref.invalidate(chefDishesStreamProvider);
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Menu item updated')));
          Navigator.of(context).pop();
        }
      } else {
        final entity = DishEntity(
          id: '',
          name: name,
          description: description,
          price: price,
          imageUrl: imageUrl,
          categories: [_category],
          isAvailable: true,
          preparationTime: 30,
          createdAt: now,
          chefId: chefId,
        );
        await repo.createDish(entity);
        ref.invalidate(chefDishesStreamProvider);
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Menu item added')));
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Failed to save: ${e.toString()}');
      }
    }
  }

  Widget _buildIngredientsTable() {
    return Column(
      children: [
        for (int i = 0; i < _ingredients.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _IngredientRow(
              data: _ingredients[i],
              onRemove: _ingredients.length > 1
                  ? () {
                      setState(() {
                        final removed = _ingredients.removeAt(i);
                        removed.dispose();
                      });
                    }
                  : null,
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              setState(() {
                _ingredients.add(_IngredientRowData());
              });
            },
            icon: const Icon(Icons.add),
            label: const Text('Add ingredient'),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingSteps() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Analyzing with AI...',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(_steps.length, (index) {
            final active = index == _currentStepIndex;
            final done = index < _currentStepIndex;
            return Row(
              children: [
                Text(
                  done ? '✅' : '⏳',
                  style: TextStyle(
                    fontSize: 16,
                    color: done
                        ? Colors.green
                        : active
                            ? Colors.blue
                            : Colors.grey,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _steps[index],
                    style: TextStyle(
                      fontSize: 13,
                      color: done
                          ? Colors.green
                          : active
                              ? Colors.blue
                              : Colors.grey[700],
                    ),
                  ),
                ),
              ],
            );
          }),
        ),
      ],
    );
  }

  Widget _buildResultCard() {
    final r = _result!;

    double _v(String key) {
      final v = r[key];
      if (v is num) return v.toDouble();
      if (v is String) return double.tryParse(v) ?? 0;
      return 0;
    }

    final ingredientCost = _v('ingredient_cost');
    final spicesCost = _v('spices_cost');
    final operationalCost = _v('operational_cost');
    final totalCost = ingredientCost + spicesCost + operationalCost;
    final warning = r['warning'] as String?;
    final insight = r['insight'] as String?;
    final dishSeasons =
        (r['seasons'] as List?)?.map((e) => e.toString()).toList() ??
            const <String>[];

    final profitInput = double.tryParse(_profitCtrl.text.trim()) ?? 0;
    if (_profitIsPercent) {
      _profitAmount = totalCost * (profitInput / 100);
    } else {
      _profitAmount = profitInput;
    }
    _recommendedPrice = (totalCost + _profitAmount).clamp(0, double.infinity);

    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pricing breakdown',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            _resultRow('Ingredients', ingredientCost),
            _resultRow('Spices (3%)', spicesCost),
            _resultRow('Operational (10%)', operationalCost),
            const Divider(),
            _resultRow('Your profit', _profitAmount, bold: false),
            const Divider(),
            _resultRow('Recommended price', _recommendedPrice, bold: true),
            if (dishSeasons.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.calendar_today_rounded,
                      size: 16, color: Colors.blueGrey),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Season alert: ${dishSeasons.join(', ')}',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.blueGrey),
                    ),
                  ),
                ],
              ),
            ],
            if (warning != null && warning.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      warning,
                      style: const TextStyle(color: Colors.orange, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
            if (insight != null && insight.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.chat_bubble_outline, size: 18, color: Colors.blueGrey),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      insight,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      await _saveWithPrice(_recommendedPrice);
                    },
                    child: const Text('Apply this price'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      _showManualPriceSheet(context);
                    },
                    child: const Text('Set my own price'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showManualPriceSheet(BuildContext context) async {
    final initial = _recommendedPrice > 0 ? _recommendedPrice.toStringAsFixed(2) : '';
    final controller = TextEditingController(text: initial);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Set your own price',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Price (SAR)',
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final v = double.tryParse(controller.text.trim());
                    if (v == null || v <= 0) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text('Enter a valid price.'),
                        ),
                      );
                      return;
                    }
                    Navigator.of(ctx).pop();
                    await _saveWithPrice(v);
                  },
                  child: const Text('Save price'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _resultRow(String label, double value, {bool bold = false, String? trailingLabel}) {
    final style = TextStyle(
      fontSize: 14,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Row(
            children: [
              Text('${value.toStringAsFixed(2)} SAR', style: style),
              if (trailingLabel != null)
                Text(
                  trailingLabel,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _onAnalyzePressed() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_ingredients.any((i) => i.nameCtrl.text.trim().isEmpty)) {
      setState(() => _error = 'Please fill all ingredient names (or remove empty rows).');
      return;
    }
    final servings = int.tryParse(_servingsCtrl.text.trim()) ?? 0;
    if (servings <= 0) {
      setState(() => _error = 'Enter a positive number of servings.');
      return;
    }

    setState(() {
      _error = null;
    });

    final profitInput = double.tryParse(_profitCtrl.text.trim()) ?? 0;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => _AiPricingLoadingScreen(
          steps: _steps,
          runAnalysis: () => _runAiAnalysis(servings),
          onFinished: (result) {
            Navigator.of(ctx).pushReplacement(
              MaterialPageRoute(
                builder: (_) => _AiPricingResultScreen(
                  result: result,
                  profitIsPercent: _profitIsPercent,
                  profitInput: profitInput,
                  onApply: (price) => _saveWithPrice(price),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> _runAiAnalysis(int servings) async {
    final ingredients = _ingredients.map((i) => i.toJson()).toList();

    // First, ask AI to classify the dish into seasons.
    List<String> dishSeasons = const ['normal'];
    try {
      final seasonRes = await _aiService.classifyDishSeason(
        dishName: _nameCtrl.text.trim(),
        ingredients: ingredients,
        category: _category,
      );
      final fromAi =
          (seasonRes['seasons'] as List?)?.map((e) => e.toString()).toList() ??
              const <String>[];
      if (fromAi.isNotEmpty) {
        dishSeasons = fromAi;
      }
    } catch (_) {
      // If season classification fails, we fall back to normal.
    }

    // Resolve season increase percentage using seasons table when available.
    double seasonIncreasePct = 0;
    String currentSeason = 'normal';
    try {
      if (_seasons.isEmpty) {
        _seasons = await _seasonsDataSource.getSeasons();
      }
      if (_seasons.isNotEmpty) {
        final pct = _seasonsDataSource.resolveSeasonIncreasePct(
          dishSeasons: dishSeasons,
          allSeasons: _seasons,
        );
        seasonIncreasePct = pct;
        if (pct > 0) {
          for (final s in dishSeasons) {
            if (s.toLowerCase() != 'normal') {
              currentSeason = s;
              break;
            }
          }
        }
      }
    } catch (_) {
      // If seasons lookup fails, keep defaults (normal + 0%).
    }

    final result = await _aiService.analyzeRecipePricing(
      dishName: _nameCtrl.text.trim(),
      ingredients: ingredients,
      servings: servings,
      currentSeason: currentSeason,
      dishSeasons: dishSeasons,
      seasonIncreasePct: seasonIncreasePct,
    );

    if (!result.containsKey('seasons')) {
      result['seasons'] = dishSeasons;
    }
    return result;
  }
}

enum _PricingMode {
  none,
  manual,
  ai,
}

class _AiPricingLoadingScreen extends StatefulWidget {
  const _AiPricingLoadingScreen({
    required this.steps,
    required this.runAnalysis,
    required this.onFinished,
  });

  final List<String> steps;
  final Future<Map<String, dynamic>> Function() runAnalysis;
  final void Function(Map<String, dynamic> result) onFinished;

  @override
  State<_AiPricingLoadingScreen> createState() =>
      _AiPricingLoadingScreenState();
}

class _AiPricingLoadingScreenState extends State<_AiPricingLoadingScreen> {
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    for (int i = 0; i < widget.steps.length; i++) {
      if (!mounted) return;
      setState(() => _currentStep = i);
      await Future<void>.delayed(const Duration(milliseconds: 800));
    }
    try {
      final result = await widget.runAnalysis();
      if (!mounted) return;
      widget.onFinished(result);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AiService.friendlyAiErrorMessage(e))),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Analyzing with AI'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'We are calculating the best price for your dish.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 24),
            const Center(
              child: SizedBox(
                height: 32,
                width: 32,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
            ),
            const SizedBox(height: 24),
            ...List.generate(widget.steps.length, (index) {
              final active = index == _currentStep;
              final done = index < _currentStep;
              final prefix = done ? '✅' : active ? '⏳' : '⏳';
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Text(prefix),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.steps[index],
                        style: TextStyle(
                          fontSize: 13,
                          color: done
                              ? Colors.green
                              : active
                                  ? Colors.black
                                  : Colors.grey[700],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _AiPricingResultScreen extends StatefulWidget {
  const _AiPricingResultScreen({
    required this.result,
    required this.profitIsPercent,
    required this.profitInput,
    required this.onApply,
  });

  final Map<String, dynamic> result;
  final bool profitIsPercent;
  final double profitInput;
  final Future<void> Function(double price) onApply;

  @override
  State<_AiPricingResultScreen> createState() => _AiPricingResultScreenState();
}

class _AiPricingResultScreenState extends State<_AiPricingResultScreen> {
  bool _showCustom = false;
  final TextEditingController _customCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final rec = _computeRecommendedPrice();
    _customCtrl.text = rec.toStringAsFixed(2);
  }

  double _num(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0;
    return 0;
  }

  double _computeRecommendedPrice() {
    final r = widget.result;
    final ingredientCost = _num(r['ingredient_cost']);
    final spicesCost = _num(r['spices_cost']);
    final operationalCost = _num(r['operational_cost']);
    final totalCost = ingredientCost + spicesCost + operationalCost;
    final profitInput = widget.profitInput;
    final profitAmount = widget.profitIsPercent
        ? totalCost * (profitInput / 100)
        : profitInput;
    return (totalCost + profitAmount).clamp(0, double.infinity);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final ingredientCost = _num(r['ingredient_cost']);
    final spicesCost = _num(r['spices_cost']);
    final operationalCost = _num(r['operational_cost']);
    final costPerServing = _num(r['cost_per_serving']);
    final seasonalPrice = _num(r['seasonal_price']);
    final recommendedPrice = _computeRecommendedPrice();
    final effectiveSeasonPrice =
        seasonalPrice > 0 ? seasonalPrice : recommendedPrice;
    final warningNeeded = effectiveSeasonPrice < costPerServing;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Pricing Result'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (warningNeeded)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: const Text(
                  'Warning: this price is below your cost per serving.',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            _row('📦 Ingredients', ingredientCost),
            _row('🧂 Spices (3%)', spicesCost),
            _row('⚡ Operational (10%)', operationalCost),
            const Divider(),
            _row('💰 Your profit', recommendedPrice - ingredientCost - spicesCost - operationalCost),
            const Divider(),
            _row('✨ Recommended price', recommendedPrice, bold: true),
            if (seasonalPrice > 0) ...[
              const SizedBox(height: 8),
              _row('🌙 Season price', seasonalPrice, bold: true),
            ],
            const Spacer(),
            if (_showCustom)
              TextFormField(
                controller: _customCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Your price (SAR)',
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      await widget.onApply(effectiveSeasonPrice);
                    },
                    child: const Text('Apply this price'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _showCustom = true;
                      });
                    },
                    child: const Text('Set my own price'),
                  ),
                ),
              ],
            ),
            if (_showCustom) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    final v = double.tryParse(_customCtrl.text.trim());
                    if (v == null || v <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Enter a valid price.'),
                        ),
                      );
                      return;
                    }
                    await widget.onApply(v);
                  },
                  child: const Text('Save my price'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(String label, double value, {bool bold = false}) {
    final style = TextStyle(
      fontSize: 14,
      fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text('${value.toStringAsFixed(2)} SAR', style: style),
        ],
      ),
    );
  }
}

class _IngredientRowData {
  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController quantityCtrl = TextEditingController();
  final TextEditingController priceCtrl = TextEditingController();
  String unit = 'kg';

  Map<String, dynamic> toJson() {
    final quantity = double.tryParse(quantityCtrl.text.trim()) ?? 0;
    final price = double.tryParse(priceCtrl.text.trim()) ?? 0;
    return {
      'name': nameCtrl.text.trim(),
      'quantity': quantity,
      'unit': unit,
      'price': price,
    };
  }

  void dispose() {
    nameCtrl.dispose();
    quantityCtrl.dispose();
    priceCtrl.dispose();
  }
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({
    required this.data,
    this.onRemove,
  });

  final _IngredientRowData data;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppDesignSystem.cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppDesignSystem.surfaceLight),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            flex: 3,
            child: TextFormField(
              controller: data.nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Name',
                hintText: 'e.g. Chicken',
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: data.quantityCtrl,
              decoration: const InputDecoration(
                labelText: 'Qty',
                hintText: 'e.g. 2',
              ),
              keyboardType: TextInputType.number,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<String>(
              value: data.unit,
              items: const [
                DropdownMenuItem(value: 'kg', child: Text('kg')),
                DropdownMenuItem(value: 'g', child: Text('g')),
                DropdownMenuItem(value: 'piece', child: Text('piece')),
                DropdownMenuItem(value: 'bag', child: Text('bag')),
                DropdownMenuItem(value: 'cup', child: Text('cup')),
                DropdownMenuItem(value: 'liter', child: Text('liter')),
              ],
              onChanged: (v) {
                if (v != null) {
                  data.unit = v;
                }
              },
              decoration: const InputDecoration(
                labelText: 'Unit',
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextFormField(
              controller: data.priceCtrl,
              decoration: const InputDecoration(
                labelText: 'Price',
                hintText: 'e.g. 25 SAR',
              ),
              keyboardType: TextInputType.number,
            ),
          ),
          const SizedBox(width: 4),
          if (onRemove != null)
            IconButton(
              icon: const Icon(Icons.remove_circle_outline,
                  color: AppDesignSystem.errorRed),
              onPressed: onRemove,
            )
          else
            IconButton(
              icon: const Icon(Icons.add_circle_outline,
                  color: AppDesignSystem.primary),
              onPressed: () {
                // No-op here; add handled by parent "Add ingredient" button.
              },
            ),
        ],
      ),
    );
  }
}

