import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Full-screen vertical pager (TikTok-style) for admin reel review.
class AdminReelsVerticalFeedScreen extends StatefulWidget {
  const AdminReelsVerticalFeedScreen({
    super.key,
    required this.rows,
    this.initialIndex = 0,
  });

  final List<Map<String, dynamic>> rows;
  final int initialIndex;

  @override
  State<AdminReelsVerticalFeedScreen> createState() => _AdminReelsVerticalFeedScreenState();
}

class _AdminReelsVerticalFeedScreenState extends State<AdminReelsVerticalFeedScreen> {
  late final PageController _pageController;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.rows.isEmpty ? 0 : widget.rows.length - 1);
    _pageController = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.rows.isEmpty) {
      return const Scaffold(body: Center(child: Text('No reels')));
    }
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        title: Text('${_index + 1} / ${widget.rows.length}'),
      ),
      body: PageView.builder(
        scrollDirection: Axis.vertical,
        controller: _pageController,
        itemCount: widget.rows.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) {
          final r = widget.rows[i];
          return _ReelVerticalPage(row: r);
        },
      ),
    );
  }
}

class _ReelVerticalPage extends StatefulWidget {
  const _ReelVerticalPage({required this.row});

  final Map<String, dynamic> row;

  @override
  State<_ReelVerticalPage> createState() => _ReelVerticalPageState();
}

class _ReelVerticalPageState extends State<_ReelVerticalPage> {
  VideoPlayerController? _video;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    final url = (widget.row['video_url'] ?? '').toString().trim();
    if (url.isNotEmpty) {
      _video = VideoPlayerController.networkUrl(Uri.parse(url))
        ..initialize().then((_) {
          if (mounted) {
            setState(() {});
            _video?.setLooping(true);
            _video?.play();
          }
        }).catchError((Object _, StackTrace __) {
          if (mounted) setState(() => _failed = true);
        });
    } else {
      _failed = true;
    }
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cook = (widget.row['_kitchen_name'] ?? widget.row['chef_id'] ?? 'Cook').toString();
    final cap = (widget.row['caption'] ?? '').toString();
    final reports = (widget.row['report_count'] as num?)?.toInt() ?? 0;
    final reason = (widget.row['report_reason_preview'] ?? '').toString().trim();
    final thumb = widget.row['thumbnail_url'] as String?;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (_video != null && _video!.value.isInitialized && !_failed)
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _video!.value.size.width,
              height: _video!.value.size.height,
              child: VideoPlayer(_video!),
            ),
          )
        else if (thumb != null && thumb.isNotEmpty)
          Image.network(
            thumb,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black87),
          )
        else
          const ColoredBox(color: Colors.black87),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.85),
                  Colors.transparent,
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 32, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    cook,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  if (reports > 0) ...[
                    const SizedBox(height: 6),
                    Text(
                      '$reports report(s)${reason.isNotEmpty ? ' · $reason' : ''}',
                      style: TextStyle(color: Colors.red.shade200, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                  if (cap.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      cap,
                      style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.3),
                    ),
                  ],
                  if (_failed)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Video unavailable — showing thumbnail or placeholder.',
                        style: TextStyle(color: Colors.amber.shade200, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
