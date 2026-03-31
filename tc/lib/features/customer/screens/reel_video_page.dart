// ============================================================
// Single reel page for vertical feed — video_player, play when [isActive]. RTL, TC theme.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import 'package:naham_cook_app/core/theme/app_design_system.dart';
import 'package:naham_cook_app/features/reels/domain/entities/reel_entity.dart';
import 'package:naham_cook_app/features/reels/presentation/providers/reels_provider.dart';

class ReelVideoPage extends ConsumerStatefulWidget {
  final ReelEntity reel;
  final bool isActive;
  final void Function(String chefId)? onTapChef;
  /// When set and reel is owned by current user (e.g. chef), show delete and call on delete.
  final VoidCallback? onDelete;
  /// Customer flow: add featured dish to cart (shown when [ReelEntity.dishId] is set).
  final void Function(BuildContext context, ReelEntity reel)? onOrderDish;

  const ReelVideoPage({
    super.key,
    required this.reel,
    required this.isActive,
    this.onTapChef,
    this.onDelete,
    this.onOrderDish,
  });

  @override
  ConsumerState<ReelVideoPage> createState() => _ReelVideoPageState();
}

class _ReelVideoPageState extends ConsumerState<ReelVideoPage> {
  VideoPlayerController? _controller;
  bool _liked = false;
  int _likesCount = 0;
  bool _initFailed = false;

  @override
  void initState() {
    super.initState();
    _liked = widget.reel.isLiked;
    _likesCount = widget.reel.likesCount;
    final url = widget.reel.videoUrl.trim();
    if (url.isEmpty) {
      _initFailed = true;
    } else {
      final c = VideoPlayerController.networkUrl(Uri.parse(url));
      _controller = c;
      c.initialize().then((_) {
        if (mounted) {
          setState(() {});
          c.setLooping(true);
          if (widget.isActive) c.play();
        }
      }).catchError((Object _) {
        if (mounted) setState(() => _initFailed = true);
      });
    }
  }

  @override
  void didUpdateWidget(ReelVideoPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final c = _controller;
    if (c == null || _initFailed || !c.value.isInitialized) return;
    if (widget.isActive && !c.value.isPlaying) {
      c.play();
    } else if (!widget.isActive && c.value.isPlaying) {
      c.pause();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _toggleLike() async {
    final repo = ref.read(reelsRepositoryProvider);
    if (_liked) {
      await repo.unlikeReel(widget.reel.id);
      if (mounted) setState(() { _liked = false; _likesCount = (_likesCount - 1).clamp(0, 1 << 30); });
    } else {
      await repo.likeReel(widget.reel.id);
      if (mounted) setState(() { _liked = true; _likesCount++; });
    }
  }

  static String _formatLikes(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toString();
  }

  @override
  Widget build(BuildContext context) {
    final showOrder = widget.reel.dishId != null &&
        widget.reel.dishId!.isNotEmpty &&
        widget.onOrderDish != null;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (!_initFailed && _controller != null && _controller!.value.isInitialized)
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _controller!.value.size.width,
              height: _controller!.value.size.height,
              child: VideoPlayer(_controller!),
            ),
          )
        else if (_initFailed)
          Container(
            color: Colors.black,
            padding: const EdgeInsets.all(24),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.broken_image_outlined, color: Colors.white54, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    widget.reel.videoUrl.trim().isEmpty
                        ? 'Video unavailable'
                        : 'Could not load video',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
          )
        else
          Container(
            color: Colors.black,
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white54),
            ),
          ),
        Positioned(
          bottom: 100,
          left: 16,
          right: 70,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.onTapChef != null)
                InkWell(
                  onTap: () => widget.onTapChef!(widget.reel.chefId),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppDesignSystem.primaryLight,
                        child: const Icon(Icons.person, color: AppDesignSystem.primaryDark),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.reel.chefName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            if (widget.reel.kitchenName != null && widget.reel.kitchenName!.isNotEmpty)
                              Text(
                                widget.reel.kitchenName!,
                                style: const TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              else
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppDesignSystem.primaryLight,
                      child: const Icon(Icons.person, color: AppDesignSystem.primaryDark),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.reel.chefName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          if (widget.reel.kitchenName != null && widget.reel.kitchenName!.isNotEmpty)
                            Text(
                              widget.reel.kitchenName!,
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              if (widget.reel.description != null && widget.reel.description!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  widget.reel.description!,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (showOrder) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => widget.onOrderDish!(context, widget.reel),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppDesignSystem.primary,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.shopping_bag_outlined, size: 20),
                  label: Text(
                    widget.reel.dishName != null && widget.reel.dishName!.isNotEmpty
                        ? 'Order: ${widget.reel.dishName}'
                        : 'Add dish to cart',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
        Positioned(
          bottom: 100,
          right: 16,
          child: Column(
            children: [
              if (widget.onDelete != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 28),
                    onPressed: widget.onDelete,
                  ),
                ),
              GestureDetector(
                onTap: _toggleLike,
                child: Column(
                  children: [
                    Icon(
                      _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      color: _liked ? Colors.red : Colors.white,
                      size: 28,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatLikes(_likesCount),
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
