// ============================================================
// COOK REELS — Discover + My reels (both list this kitchen only); upload; delete own only.
// ============================================================

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../auth/presentation/providers/auth_provider.dart';
import '../../cook/presentation/providers/chef_providers.dart';
import '../../../core/theme/app_design_system.dart';
import '../../../core/utils/supabase_error_message.dart';
import '../../../core/theme/naham_theme.dart';
import '../../../core/widgets/naham_empty_screens.dart';
import '../../../features/customer/screens/reel_video_page.dart';
import '../../../features/reels/domain/entities/reel_entity.dart';
import '../../../features/reels/presentation/providers/reels_provider.dart';

class ReelsScreen extends ConsumerStatefulWidget {
  const ReelsScreen({super.key});

  @override
  ConsumerState<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends ConsumerState<ReelsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(authStateProvider).valueOrNull;
    final String userId = authUser?.id ?? '';
    final bool isChef = authUser?.isChef == true;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          leadingWidth: 56,
          leading: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                AppDesignSystem.logoAsset,
                width: 40,
                height: 40,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white24,
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'N',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
          ),
          centerTitle: true,
          title: const Text('Reels'),
          backgroundColor: NahamTheme.headerBackground,
          foregroundColor: NahamTheme.textOnPurple,
          elevation: 0,
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: NahamTheme.textOnPurple,
            labelColor: NahamTheme.textOnPurple,
            unselectedLabelColor: NahamTheme.textOnPurple.withValues(alpha: 0.55),
            tabs: const [
              Tab(text: 'Discover'),
              Tab(text: 'My reels'),
            ],
          ),
          actions: [
            if (isChef)
              IconButton(
                icon: const Icon(Icons.upload_rounded),
                onPressed: () => _pickAndUploadReel(context, ref),
              ),
          ],
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _ReelsDiscoverTab(userId: userId),
            _ReelsMyTab(
              userId: userId,
              onUpload: () => _pickAndUploadReel(context, ref),
            ),
          ],
        ),
        floatingActionButton: isChef
            ? FloatingActionButton.extended(
                onPressed: () => _pickAndUploadReel(context, ref),
                backgroundColor: NahamTheme.primary,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Upload reel'),
              )
            : null,
      ),
    );
  }

  Future<void> _pickAndUploadReel(BuildContext context, WidgetRef ref) async {
    final picker = ImagePicker();
    final file = await picker.pickVideo(source: ImageSource.gallery);
    if (!context.mounted || file == null) return;
    final path = file.path;
    if (path.isEmpty) return;
    if (!context.mounted) return;

    File? videoFile;
    Uint8List? videoBytes;
    try {
      if (kIsWeb) {
        videoBytes = await file.readAsBytes();
        if (videoBytes.isEmpty) {
          throw Exception('Empty file');
        }
      } else {
        videoFile = File(path);
        final controller = VideoPlayerController.file(videoFile);
        await controller.initialize();
        final duration = controller.value.duration;
        await controller.dispose();
        if (duration > const Duration(minutes: 2)) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Video must be under 2 minutes')),
            );
          }
          return;
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not read video: $e')),
        );
      }
      return;
    }

    if (!context.mounted) return;
    await _showUploadSheet(
      context,
      ref,
      file,
      videoFile: videoFile,
      videoBytes: videoBytes,
    );
  }

  Future<void> _showUploadSheet(
    BuildContext context,
    WidgetRef ref,
    XFile pickedFile, {
    File? videoFile,
    Uint8List? videoBytes,
  }
  ) async {
    final descriptionCtrl = TextEditingController();
    final tagsCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final dishSelection = <String?>[null];

    final uploaded = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Consumer(
        builder: (context, ref, _) {
          return Directionality(
            textDirection: TextDirection.ltr,
            child: Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: NahamTheme.cardBackground,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: StatefulBuilder(
                  builder: (ctx, setModalState) {
                    final dishesAsync = ref.watch(chefDishesStreamProvider);
                    return Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Reel details',
                            style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: NahamTheme.textOnLight,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Link a menu dish so customers can add it to the cart from your reel.',
                            style: TextStyle(
                              fontSize: 13,
                              color: NahamTheme.textOnLight.withValues(alpha: 0.75),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: descriptionCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Caption',
                              border: OutlineInputBorder(),
                              alignLabelWithHint: true,
                            ),
                            maxLines: 2,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: tagsCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Tags (e.g. dessert, mandi, shawarma)',
                              hintText: 'Separate with commas',
                              border: OutlineInputBorder(),
                              alignLabelWithHint: true,
                            ),
                          ),
                          const SizedBox(height: 12),
                          dishesAsync.when(
                            data: (dishes) {
                              if (dishes.isEmpty) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Text(
                                    'Add dishes to your menu to link a reel to a dish.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: NahamTheme.textOnLight.withValues(alpha: 0.75),
                                    ),
                                  ),
                                );
                              }
                              final items = dishes
                                  .map(
                                    (d) => DropdownMenuItem<String?>(
                                      value: d.id,
                                      child: Text(d.name, overflow: TextOverflow.ellipsis),
                                    ),
                                  )
                                  .toList();
                              return InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Featured dish (optional)',
                                  border: OutlineInputBorder(),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String?>(
                                    isExpanded: true,
                                    value: dishSelection[0],
                                    hint: const Text('No linked dish'),
                                    items: items,
                                    onChanged: (v) => setModalState(() => dishSelection[0] = v),
                                  ),
                                ),
                              );
                            },
                            loading: () => const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: LinearProgressIndicator(),
                            ),
                            error: (_, __) => const SizedBox.shrink(),
                          ),
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => Navigator.of(ctx).pop(false),
                                  child: const Text('Cancel'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 2,
                                child: FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: NahamTheme.primary,
                                    foregroundColor: NahamTheme.textOnPurple,
                                  ),
                                  onPressed: () async {
                                    final description = descriptionCtrl.text.trim();
                                    final tagsStr = tagsCtrl.text.trim();
                                    final tags = tagsStr
                                        .split(RegExp(r'[,\s]+'))
                                        .map((e) => e.trim())
                                        .where((e) => e.isNotEmpty)
                                        .toList();
                                    try {
                                      if (kIsWeb) {
                                        final bytes = videoBytes ?? await pickedFile.readAsBytes();
                                        await ref.read(reelsRepositoryProvider).uploadReelFromBytes(
                                              bytes,
                                              filename: pickedFile.name,
                                              description: description.isEmpty ? 'Reel' : description,
                                              tags: tags,
                                              dishId: dishSelection[0],
                                            );
                                      } else {
                                        final fileToUpload = videoFile ?? File(pickedFile.path);
                                        await ref.read(reelsRepositoryProvider).uploadReelFromFile(
                                              fileToUpload,
                                              description: description.isEmpty ? 'Reel' : description,
                                              tags: tags,
                                              dishId: dishSelection[0],
                                            );
                                      }
                                      final uid = ref.read(authStateProvider).valueOrNull?.id;
                                      if (uid != null && uid.isNotEmpty) {
                                        ref.invalidate(myReelsStreamProvider(uid));
                                      }
                                      if (ctx.mounted) Navigator.of(ctx).pop(true);
                                    } catch (e) {
                                      if (ctx.mounted) {
                                        ScaffoldMessenger.of(ctx).showSnackBar(
                                          SnackBar(content: Text('Failed to upload: ${e.toString()}')),
                                        );
                                      }
                                    }
                                  },
                                  child: const Text('Upload'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
    descriptionCtrl.dispose();
    tagsCtrl.dispose();
    if (context.mounted && uploaded == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Reel uploaded successfully')),
      );
    }
  }
}

class _ReelsDiscoverTab extends ConsumerWidget {
  const _ReelsDiscoverTab({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reelsAsync = userId.isEmpty
        ? const AsyncValue<List<ReelEntity>>.data(<ReelEntity>[])
        : ref.watch(myReelsStreamProvider(userId));
    return _ReelsVerticalFeed(
      reelsAsync: reelsAsync,
      userId: userId,
      emptyTitle: 'No reels yet',
      emptySubtitle: 'Upload a short video in My reels to showcase your kitchen.',
      onEmptyPressed: () {
        if (userId.isNotEmpty) ref.invalidate(myReelsStreamProvider(userId));
      },
      onRefresh: () async {
        if (userId.isNotEmpty) ref.invalidate(myReelsStreamProvider(userId));
      },
    );
  }
}

class _ReelsMyTab extends ConsumerWidget {
  const _ReelsMyTab({
    required this.userId,
    required this.onUpload,
  });

  final String userId;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (userId.isEmpty) {
      return const Center(
        child: Text(
          'Sign in as a cook to manage your reels.',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }
    final reelsAsync = ref.watch(myReelsStreamProvider(userId));
    return _ReelsVerticalFeed(
      reelsAsync: reelsAsync,
      userId: userId,
      emptyTitle: 'You have no reels yet',
      emptySubtitle: 'Upload a short video to showcase your dishes.',
      emptyButtonLabel: 'Upload reel',
      onEmptyPressed: onUpload,
      onRefresh: () async {
        ref.invalidate(myReelsStreamProvider(userId));
      },
      onDeleteReel: (reel) => _confirmDeleteReel(context, ref, reel, userId),
    );
  }

  Future<void> _confirmDeleteReel(
    BuildContext context,
    WidgetRef ref,
    ReelEntity reel,
    String myChefId,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete reel'),
        content: const Text('Are you sure you want to delete this reel?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppDesignSystem.errorRed),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !context.mounted) return;
    try {
      await ref.read(reelsRepositoryProvider).deleteReel(reel.id);
      if (myChefId.isNotEmpty) {
        ref.invalidate(myReelsStreamProvider(myChefId));
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reel deleted')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: ${e.toString()}')),
        );
      }
    }
  }
}

class _ReelsVerticalFeed extends ConsumerStatefulWidget {
  const _ReelsVerticalFeed({
    required this.reelsAsync,
    required this.userId,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.onRefresh,
    this.emptyButtonLabel = 'Refresh',
    this.onEmptyPressed,
    this.onDeleteReel,
  });

  final AsyncValue<List<ReelEntity>> reelsAsync;
  final String userId;
  final String emptyTitle;
  final String emptySubtitle;
  final Future<void> Function() onRefresh;
  final String emptyButtonLabel;
  final VoidCallback? onEmptyPressed;
  final Future<void> Function(ReelEntity reel)? onDeleteReel;

  @override
  ConsumerState<_ReelsVerticalFeed> createState() => _ReelsVerticalFeedState();
}

class _ReelsVerticalFeedState extends ConsumerState<_ReelsVerticalFeed> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.reelsAsync.when(
      data: (reels) {
        if (reels.isEmpty) {
          return Center(
            child: NahamEmptyStateContent(
              title: widget.emptyTitle,
              subtitle: widget.emptySubtitle,
              buttonLabel: widget.emptyButtonLabel,
              onPressed: widget.onEmptyPressed,
              fallbackIcon: Icons.videocam_rounded,
            ),
          );
        }
        return RefreshIndicator(
          color: NahamTheme.primary,
          onRefresh: widget.onRefresh,
          child: PageView.builder(
            controller: _pageController,
            physics: const AlwaysScrollableScrollPhysics(),
            scrollDirection: Axis.vertical,
            itemCount: reels.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              final reel = reels[index];
              final isOwner = reel.chefId == widget.userId;
              return ReelVideoPage(
                key: ValueKey(reel.id),
                reel: reel,
                isActive: index == _currentPage,
                onDelete: isOwner && widget.onDeleteReel != null
                    ? () => widget.onDeleteReel!(reel)
                    : null,
              );
            },
          ),
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: NahamTheme.primary),
      ),
      error: (err, _) => Center(
        child: ErrorStateContent(
          message: userFriendlyErrorMessage(err),
          onRetry: () => widget.onRefresh(),
        ),
      ),
    );
  }
}
