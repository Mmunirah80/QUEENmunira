// ============================================================
// DOCUMENTS — Supabase-backed, append-only history per type.
// Each upload inserts a new row; admins approve/reject by row id.
// ============================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_design_system.dart';
import '../../../core/utils/supabase_error_message.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../data/chef_documents_compliance.dart';

class _NC {
  static const primary = AppDesignSystem.primary;
  static const bg = AppDesignSystem.backgroundOffWhite;
  static const surface = AppDesignSystem.cardWhite;
  static const text = AppDesignSystem.textPrimary;
  static const textSub = AppDesignSystem.textSecondary;
}

class DocumentsScreen extends ConsumerStatefulWidget {
  const DocumentsScreen({super.key});

  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen> {
  /// All rows for this chef (newest-first from API).
  List<Map<String, dynamic>> _rows = [];

  bool _listFetchBusy = false;
  bool _uploadBusy = false;
  String? _statusLoadError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _kickoffLoad());
  }

  void _kickoffLoad() {
    if (!mounted) return;
    final auth = ref.read(authStateProvider);
    auth.when(
      data: (user) {
        final uid = user?.id;
        if (uid == null || uid.isEmpty) {
          setState(() {
            _listFetchBusy = false;
            _statusLoadError = 'Please sign in to load documents.';
          });
          return;
        }
        _loadStatus();
      },
      loading: () {
        Future<void>.delayed(const Duration(milliseconds: 150), () {
          if (mounted) _kickoffLoad();
        });
      },
      error: (_, __) {
        setState(() {
          _listFetchBusy = false;
          _statusLoadError = 'Could not verify your account. Sign in again.';
        });
      },
    );
  }

  Future<void> _loadStatus() async {
    final userId = ref.read(authStateProvider).valueOrNull?.id;
    if (userId == null || userId.isEmpty) {
      if (mounted) {
        setState(() {
          _listFetchBusy = false;
          _statusLoadError = 'Please sign in to load documents.';
        });
      }
      return;
    }
    setState(() {
      _listFetchBusy = true;
      _statusLoadError = null;
    });
    try {
      final client = Supabase.instance.client;
      final dynamic raw = await Future<dynamic>(() async {
        return client
            .from('chef_documents')
            .select(
              'id,document_type,file_url,status,rejection_reason,expiry_date,created_at',
            )
            .eq('chef_id', userId)
            .order('created_at', ascending: false);
      }).timeout(const Duration(seconds: 25));
      final list = (raw as List?) ?? const [];
      final next = list
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (!mounted) return;
      setState(() {
        _listFetchBusy = false;
        _rows = next;
        _statusLoadError = null;
      });
    } on TimeoutException catch (e, st) {
      debugPrint('[Documents] _loadStatus timeout=$e\n$st');
      if (!mounted) return;
      setState(() {
        _listFetchBusy = false;
        _statusLoadError =
            'Request timed out. Check your connection or try again.';
      });
    } catch (e, st) {
      debugPrint('[Documents] _loadStatus error=$e\n$st');
      if (!mounted) return;
      setState(() {
        _listFetchBusy = false;
        _statusLoadError = userFriendlyErrorMessage(e);
      });
    }
  }

  void _popOrGoProfile() {
    final nav = Navigator.maybeOf(context);
    if (nav != null && nav.canPop()) {
      nav.pop();
      return;
    }
    try {
      GoRouter.of(context).go(RouteNames.chefProfile);
    } catch (e) {
      debugPrint('[Documents] back navigation: $e');
      nav?.pop();
    }
  }

  static const _storageBucket = 'documents';

  ({Map<String, dynamic>? latest, int older}) _latestForType(String type) {
    final list =
        _rows.where((r) => (r['document_type'] ?? '').toString() == type).toList();
    list.sort((a, b) {
      final ca = _parseCreated(a['created_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final cb = _parseCreated(b['created_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return cb.compareTo(ca);
    });
    if (list.isEmpty) return (latest: null, older: 0);
    return (latest: list.first, older: list.length - 1);
  }

  DateTime? _parseCreated(Object? v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    if (v is String) return DateTime.tryParse(v);
    return null;
  }

  String _effectiveStatus(Map<String, dynamic>? latest) {
    if (latest == null) return 'not_uploaded';
    final s = (latest['status'] ?? 'pending').toString().toLowerCase();
    if (s == 'approved' &&
        ChefDocumentsCompliance.isDocumentExpired(latest['expiry_date'])) {
      return 'expired';
    }
    return s;
  }

  Future<String?> _previewImageUrl(String? storedPath) async {
    if (storedPath == null || storedPath.isEmpty) return null;
    try {
      return await Supabase.instance.client.storage
          .from(_storageBucket)
          .createSignedUrl(storedPath, 3600);
    } catch (_) {
      if (storedPath.startsWith('http://') ||
          storedPath.startsWith('https://')) {
        return storedPath;
      }
      return null;
    }
  }

  Future<DateTime?> _askExpiryOptional(BuildContext context) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Expiry date'),
        content: const Text(
          'If this document has an expiry date, set it so we can remind you before it lapses. You can skip if it does not expire.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'skip'),
            child: const Text('No expiry'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'pick'),
            child: const Text('Choose date'),
          ),
        ],
      ),
    );
    if (choice != 'pick') return null;
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 365)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 12)),
    );
  }

  Future<void> _uploadDocument(BuildContext context, String type) async {
    final userId = ref.read(authStateProvider).valueOrNull?.id;
    if (userId == null) return;
    final picker = ImagePicker();
    final picked =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    if (!mounted) return;
    final expiry = await _askExpiryOptional(context);
    if (!mounted) return;

    setState(() => _uploadBusy = true);
    try {
      final client = Supabase.instance.client;
      final stamp = DateTime.now().millisecondsSinceEpoch;
      final path = '$userId/$type/$stamp.jpg';

      final bytes = await picked.readAsBytes();
      await client.storage.from(_storageBucket).uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(upsert: false),
          );

      final insert = <String, dynamic>{
        'chef_id': userId,
        'document_type': type,
        'file_url': path,
        'status': 'pending',
      };
      if (expiry != null) {
        insert['expiry_date'] =
            '${expiry.year.toString().padLeft(4, '0')}-${expiry.month.toString().padLeft(2, '0')}-${expiry.day.toString().padLeft(2, '0')}';
      }

      await client.from('chef_documents').insert(insert);

      await _loadStatus();
      if (mounted) {
        final label = type == 'freelancer_id'
            ? 'Freelancer ID'
            : type == 'national_id'
                ? 'National ID'
                : type == 'license'
                    ? 'License'
                    : 'Document';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('New $label version submitted for review')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(userFriendlyErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final compliance = ChefDocumentsCompliance.evaluate(_rows);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: _NC.bg,
        appBar: AppBar(
          backgroundColor: _NC.primary,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: _popOrGoProfile,
          ),
          centerTitle: true,
          title: const Text(
            'Documents',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
        body: Column(
          children: [
            if (_listFetchBusy || _uploadBusy)
              const LinearProgressIndicator(minHeight: 3),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadStatus,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Each upload is kept as history. Use “Upload new version” for renewals — '
                        'admins review the latest pending row from the dashboard.',
                        style: TextStyle(fontSize: 14, color: _NC.textSub),
                      ),
                      if (compliance.expiringWithinDays.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Material(
                          color: Colors.orange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              _expiryWarningText(compliance.expiringWithinDays),
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.orange.shade900,
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (_statusLoadError != null) ...[
                        const SizedBox(height: 16),
                        Material(
                          color: AppDesignSystem.errorRed.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  _statusLoadError!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppDesignSystem.errorRed,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextButton.icon(
                                  onPressed: _loadStatus,
                                  icon: const Icon(Icons.refresh_rounded, size: 18),
                                  label: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      _buildUploadSection(context),
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

  String _expiryWarningText(Map<String, int> daysLeft) {
    final parts = <String>[];
    for (final e in daysLeft.entries) {
      final name = e.key == 'national_id'
          ? 'National ID'
          : e.key == 'freelancer_id'
              ? 'Freelancer ID'
              : e.key;
      parts.add(
        '$name expires in ${e.value} day${e.value == 1 ? '' : 's'}',
      );
    }
    return 'Soon: ${parts.join('; ')}. Upload a new version early.';
  }

  Widget _buildUploadSection(BuildContext context) {
    final userId = ref.watch(authStateProvider).valueOrNull?.id ?? '';
    return Column(
      children: [
        _documentSection(
          context: context,
          userId: userId,
          title: 'Freelancer ID',
          type: 'freelancer_id',
          requiredForOnline: true,
        ),
        const SizedBox(height: 16),
        _documentSection(
          context: context,
          userId: userId,
          title: 'National ID',
          type: 'national_id',
          requiredForOnline: true,
        ),
        const SizedBox(height: 16),
        _documentSection(
          context: context,
          userId: userId,
          title: 'License (optional)',
          type: 'license',
          requiredForOnline: false,
        ),
      ],
    );
  }

  Widget _documentSection({
    required BuildContext context,
    required String userId,
    required String title,
    required String type,
    required bool requiredForOnline,
  }) {
    final summary = _latestForType(type);
    final latest = summary.latest;
    final older = summary.older;
    final uploaded = latest != null;
    final status = _effectiveStatus(latest);
    final url = latest?['file_url']?.toString();
    final rejectionReason = latest?['rejection_reason']?.toString();
    final expiryRaw = latest?['expiry_date'];

    final isPdf = (url ?? '').toLowerCase().contains('.pdf');
    final hasPreview = uploaded && url != null && url.isNotEmpty;
    final buttonLabel = uploaded ? 'Upload new version' : 'Upload';
    final canUpload = userId.isNotEmpty && !_uploadBusy;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _NC.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: const [
          BoxShadow(color: Color(0x08000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.description_outlined, color: _NC.primary, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _NC.text,
                            ),
                          ),
                        ),
                        if (!requiredForOnline)
                          Text(
                            'optional',
                            style: TextStyle(fontSize: 11, color: _NC.textSub),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          uploaded ? 'Latest file on file' : 'Not uploaded yet',
                          style: TextStyle(
                            fontSize: 12,
                            color: uploaded ? Colors.green.shade700 : _NC.textSub,
                          ),
                        ),
                        if (uploaded) ...[
                          const SizedBox(width: 8),
                          _statusBadge(status),
                        ],
                      ],
                    ),
                    if (older > 0) ...[
                      const SizedBox(height: 4),
                      Text(
                        '$older older version(s) kept for audit',
                        style: TextStyle(fontSize: 11, color: _NC.textSub),
                      ),
                    ],
                    if (expiryRaw != null &&
                        status != 'not_uploaded' &&
                        status != 'expired') ...[
                      const SizedBox(height: 4),
                      Text(
                        'Expiry: $expiryRaw',
                        style: const TextStyle(fontSize: 11, color: _NC.textSub),
                      ),
                    ],
                    if ((rejectionReason ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Reason: ${rejectionReason!.trim()}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppDesignSystem.errorRed,
                        ),
                      ),
                    ],
                    if (hasPreview) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: Colors.grey.shade200,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: isPdf
                                ? const Icon(Icons.picture_as_pdf,
                                    color: Colors.red, size: 28)
                                : FutureBuilder<String?>(
                                    future: _previewImageUrl(url),
                                    builder: (context, snap) {
                                      final u = snap.data ?? url;
                                      if (u.isEmpty) {
                                        return const Icon(
                                          Icons.insert_drive_file_outlined,
                                          color: _NC.textSub,
                                        );
                                      }
                                      return Image.network(
                                        u,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const Icon(
                                          Icons.insert_drive_file_outlined,
                                          color: _NC.textSub,
                                        ),
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: canUpload ? () => _uploadDocument(context, type) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _NC.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(buttonLabel),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    final s = status.trim().toLowerCase();
    if (s == 'approved') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: const Text(
          'Approved',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.green,
          ),
        ),
      );
    }
    if (s == 'expired') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.deepOrange.withOpacity(0.15),
          borderRadius: BorderRadius.circular(999),
        ),
        child: const Text(
          'Expired',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.deepOrange,
          ),
        ),
      );
    }
    if (s == 'rejected') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: AppDesignSystem.errorRed.withOpacity(0.12),
          borderRadius: BorderRadius.circular(999),
        ),
        child: const Text(
          'Rejected',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppDesignSystem.errorRed,
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'Pending',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.orange,
        ),
      ),
    );
  }
}
