// ============================================================
// Single reel full screen — video, like, back, chef overlay. RTL, TC theme.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import 'package:naham_cook_app/core/theme/app_design_system.dart';
import 'package:naham_cook_app/features/reels/domain/entities/reel_entity.dart';
import 'package:naham_cook_app/features/reels/presentation/providers/reels_provider.dart';
import 'chef_profile_screen.dart';

class ReelFullScreenScreen extends ConsumerStatefulWidget {
  final ReelEntity reel;

  const ReelFullScreenScreen({super.key, required this.reel});

  @override
  ConsumerState<ReelFullScreenScreen> createState() => _ReelFullScreenScreenState();
}

class _ReelFullScreenScreenState extends ConsumerState<ReelFullScreenScreen> {
  late VideoPlayerController _controller;
  bool _liked = false;
  int _likesCount = 0;

  @override
  void initState() {
    super.initState();
    _liked = widget.reel.isLiked;
    _likesCount = widget.reel.likesCount;
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.reel.videoUrl))
      ..initialize().then((_) {
        if (mounted) {
          setState(() {});
          _controller.setLooping(true);
          _controller.play();
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
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
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (_controller.value.isInitialized)
              FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller.value.size.width,
                  height: _controller.value.size.height,
                  child: VideoPlayer(_controller),
                ),
              )
            else
              const Center(child: CircularProgressIndicator(color: Colors.white)),
            Positioned(
              top: MediaQuery.of(context).padding.top,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Positioned(
              bottom: 100,
              left: 16,
              right: 70,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => ChefProfileScreen(chefId: widget.reel.chefId),
                        ),
                      );
                    },
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
                ],
              ),
            ),
            Positioned(
              bottom: 100,
              right: 16,
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _toggleLike,
                    child: Column(
                      children: [
                        Icon(
                          _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: _liked ? Colors.red : Colors.white,
                          size: 32,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatLikes(_likesCount),
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
