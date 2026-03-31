import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/route_names.dart';
import '../../../core/utils/quick_network_check.dart';
import '../../../core/theme/app_design_system.dart';
import '../../../core/theme/naham_theme.dart';
import '../data/chef_reg_draft_storage.dart';
import '../presentation/providers/auth_provider.dart';

/// Step 2: Upload national ID + certificate; optional expiry per file; then submit chef registration.
class ChefRegDocumentsScreen extends ConsumerStatefulWidget {
  const ChefRegDocumentsScreen({super.key});

  @override
  ConsumerState<ChefRegDocumentsScreen> createState() => _ChefRegDocumentsScreenState();
}

class _ChefRegDocumentsScreenState extends ConsumerState<ChefRegDocumentsScreen> {
  File? _nationalIdFile;
  File? _healthCertFile;
  DateTime? _nationalExpiry;
  DateTime? _certExpiry;
  bool _isLoading = false;
  String? _error;
  bool _gateChecked = false;

  static const Color _primary = NahamTheme.primary;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureDraftOrRedirect());
  }

  /// Step 2 requires in-memory [ChefRegDraft] (includes password). Persisted fields live on step 1 only.
  Future<void> _ensureDraftOrRedirect() async {
    if (_gateChecked) return;
    _gateChecked = true;
    final draft = ref.read(chefRegDraftProvider);
    if (draft != null) return;
    final saved = await ChefRegDraftStorage.loadFields();
    if (!mounted) return;
    if (saved != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Enter your password on step 1 to continue. Your name and email were restored.',
          ),
        ),
      );
      context.go(RouteNames.chefRegAccount);
      return;
    }
    setState(() => _error = 'Start from step 1 to create your account before uploading documents.');
  }

  Future<void> _pickExpiry({required bool forNational}) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Document expiry'),
        content: const Text(
          'If this document has an expiry date, set it. Otherwise choose “No expiry”.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'clear'),
            child: const Text('No expiry'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'pick'),
            child: const Text('Choose date'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (choice == 'clear') {
      setState(() {
        if (forNational) {
          _nationalExpiry = null;
        } else {
          _certExpiry = null;
        }
      });
      return;
    }
    if (choice != 'pick') return;
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 365)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 15)),
    );
    if (!mounted || d == null) return;
    setState(() {
      if (forNational) {
        _nationalExpiry = d;
      } else {
        _certExpiry = d;
      }
    });
  }

  Future<void> _pickDocument(bool isNationalId) async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    try {
      final x = await picker.pickImage(source: source, imageQuality: 85);
      if (x == null || !mounted) return;
      setState(() {
        _error = null;
        if (isNationalId) {
          _nationalIdFile = File(x.path);
        } else {
          _healthCertFile = File(x.path);
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Failed to pick image: ${e.toString()}');
      }
    }
  }

  Future<void> _submit() async {
    final draft = ref.read(chefRegDraftProvider);
    if (draft == null) {
      setState(() => _error = 'Account info missing. Go back to step 1.');
      return;
    }
    if (_nationalIdFile == null || _healthCertFile == null) {
      setState(() => _error = 'Please upload both documents.');
      return;
    }
    final offlineMsg = await quickNetworkCheckMessage();
    if (!mounted) return;
    if (offlineMsg != null) {
      setState(() => _error = offlineMsg);
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final ds = ref.read(chefRegistrationDataSourceProvider);
      final user = await ds.registerChef(
        email: draft.email,
        password: draft.password,
        name: draft.name,
        phone: draft.phone,
        nationalIdFile: _nationalIdFile!,
        healthCertFile: _healthCertFile!,
        nationalIdExpiry: _nationalExpiry,
        healthCertExpiry: _certExpiry,
      );
      if (!mounted) return;
      await ref.read(authStateProvider.notifier).setUser(user);
      ref.read(chefRegDraftProvider.notifier).state = null;
      await ChefRegDraftStorage.clear();
      if (!mounted) return;
      context.go(RouteNames.chefRegSuccess);
    } on SocketException catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'No network connection. Check Wi‑Fi or mobile data and try again.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  String _fmtExpiry(DateTime? d) {
    if (d == null) return 'Not set';
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.backgroundOffWhite,
      appBar: AppBar(
        title: const Text('Chef registration'),
        backgroundColor: AppDesignSystem.backgroundOffWhite,
        foregroundColor: AppDesignSystem.textPrimary,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDesignSystem.defaultPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Upload documents',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Step 2 of 2. National ID and permit / certificate (stored for admin review). '
                'Optional: add an expiry date for each file.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppDesignSystem.textSecondary,
                    ),
              ),
              const SizedBox(height: 24),
              _DocumentCard(
                title: 'National ID',
                subtitle: 'Required',
                uploaded: _nationalIdFile != null,
                expiryLabel: _fmtExpiry(_nationalExpiry),
                color: _primary,
                onTap: () => _pickDocument(true),
                onExpiryTap: _nationalIdFile != null ? () => _pickExpiry(forNational: true) : null,
              ),
              const SizedBox(height: AppDesignSystem.space16),
              _DocumentCard(
                title: 'Permit or health certificate',
                subtitle: 'Required (freelance permit, food certificate, etc.)',
                uploaded: _healthCertFile != null,
                expiryLabel: _fmtExpiry(_certExpiry),
                color: _primary,
                onTap: () => _pickDocument(false),
                onExpiryTap: _healthCertFile != null ? () => _pickExpiry(forNational: false) : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppDesignSystem.errorRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppDesignSystem.radiusMedium),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded, color: AppDesignSystem.errorRed, size: 22),
                      const SizedBox(width: 10),
                      Expanded(child: Text(_error!, style: TextStyle(color: AppDesignSystem.errorRed, fontSize: 14))),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppDesignSystem.space24),
              Card(
                margin: EdgeInsets.zero,
                color: AppDesignSystem.surfaceLight,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppDesignSystem.radiusMedium),
                  side: BorderSide(color: _primary.withValues(alpha: 0.25)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: _primary, size: 22),
                          const SizedBox(width: 8),
                          Text(
                            'بعد الإرسال',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'بتدخلين التطبيق مباشرة، لكن ما راح تقدرين تستخدمين الرئيسية والطلبات والقائمة والريلز إلا بعد ما يوافق الأدمن على المستندات. تقدرين تتابعين الشات (الدعم) وتعدلين الملفات من البروفايل → المستندات.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              height: 1.35,
                              color: AppDesignSystem.textSecondary,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'After you tap Submit, you enter the app, but main sections stay locked until an admin approves your uploads. Chat (Support) and Profile → Documents stay available; rejections arrive in chat and notifications.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              height: 1.35,
                              color: AppDesignSystem.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppDesignSystem.space24),
              FilledButton(
                onPressed: _isLoading ? null : _submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  backgroundColor: _primary,
                  foregroundColor: NahamTheme.textOnPurple,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Submit application'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool uploaded;
  final String expiryLabel;
  final Color color;
  final VoidCallback onTap;
  final VoidCallback? onExpiryTap;

  const _DocumentCard({
    required this.title,
    required this.subtitle,
    required this.uploaded,
    required this.expiryLabel,
    required this.color,
    required this.onTap,
    this.onExpiryTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: uploaded ? null : onTap,
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMedium),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppDesignSystem.surfaceLight,
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusMedium),
            border: Border.all(color: uploaded ? color : Colors.transparent, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    uploaded ? Icons.check_circle_rounded : Icons.upload_file_rounded,
                    color: uploaded ? color : AppDesignSystem.textSecondary,
                    size: 28,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                        Text(subtitle, style: TextStyle(color: AppDesignSystem.textSecondary, fontSize: 13)),
                      ],
                    ),
                  ),
                  if (uploaded)
                    Icon(Icons.check_rounded, color: color, size: 24)
                  else
                    Icon(Icons.add_circle_outline_rounded, color: color, size: 24),
                ],
              ),
              if (!uploaded) ...[
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
                  label: const Text('Choose file'),
                ),
              ],
              if (uploaded && onExpiryTap != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('Expiry: $expiryLabel', style: TextStyle(fontSize: 12, color: AppDesignSystem.textSecondary)),
                    const Spacer(),
                    TextButton(
                      onPressed: onExpiryTap,
                      child: const Text('Set expiry'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
