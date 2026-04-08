import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/naham_theme.dart';
import '../data/datasources/inspection_datasource.dart';
import 'chef_inspection_live_screen.dart';

/// Full-screen incoming call. Cook must explicitly accept before any camera access.
class ChefIncomingInspectionScreen extends ConsumerStatefulWidget {
  const ChefIncomingInspectionScreen({
    super.key,
    required this.callId,
    required this.channelName,
    required this.chefId,
  });

  final String callId;
  final String channelName;
  final String chefId;

  @override
  ConsumerState<ChefIncomingInspectionScreen> createState() => _ChefIncomingInspectionScreenState();
}

class _ChefIncomingInspectionScreenState extends ConsumerState<ChefIncomingInspectionScreen> {
  Timer? _timer;
  int _secondsLeft = 30;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        _timer?.cancel();
        unawaited(_onMissed());
        return;
      }
      setState(() => _secondsLeft--);
    });
  }

  Future<void> _onMissed() async {
    await ref.read(inspectionDataSourceProvider).missRequest(widget.chefId);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _decline() async {
    _timer?.cancel();
    await ref.read(inspectionDataSourceProvider).rejectRequest(widget.chefId);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _accept() async {
    _timer?.cancel();
    await ref.read(inspectionDataSourceProvider).acceptRequest(widget.chefId);
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ChefInspectionLiveScreen(
          callId: widget.callId,
          channelName: widget.channelName,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 24),
              Icon(Icons.fact_check_rounded, size: 72, color: NahamTheme.primary),
              const SizedBox(height: 24),
              const Text(
                'Kitchen inspection call',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'The platform is requesting a short live video of your kitchen. '
                'Your camera stays off until you tap Accept.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.45),
              ),
              const Spacer(),
              Text(
                '$_secondsLeft s',
                style: TextStyle(
                  color: _secondsLeft <= 10 ? Colors.orangeAccent : Colors.white54,
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'If you do not respond in time, this is logged as no answer.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white38, fontSize: 13),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _decline,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _accept,
                      style: FilledButton.styleFrom(
                        backgroundColor: NahamTheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Accept'),
                    ),
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
