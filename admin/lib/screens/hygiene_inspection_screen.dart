import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/constants/route_names.dart';
import '../core/services/inspection_service.dart';
import '../core/theme/app_design_system.dart';
import '../core/theme/naham_theme.dart';
import '../core/widgets/naham_screen_header.dart';
import '../core/widgets/snackbar_helper.dart';

/// Hygiene inspection: random video call via Agora to an online Chef.
/// Writes to chefs/{chefId}/inspection_requests/current and joins channel.
class HygieneInspectionScreen extends StatelessWidget {
  const HygieneInspectionScreen({super.key});

  Future<void> _startInspection(BuildContext context) async {
    final result = await InspectionService().startRandomInspection();
    if (!context.mounted) return;
    if (result == null) {
      SnackbarHelper.error(context, 'لا يوجد طباخون متصلون حالياً.');
      return;
    }
    context.push(
      RouteNames.videoCall,
      extra: {
        'channelName': result.channelName,
        'chefId': result.chefId,
        'chefName': result.chefName,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: NahamScreenHeader(title: 'التفتيش الصحي')),
          SliverPadding(
            padding: const EdgeInsets.all(AppDesignSystem.space24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDesignSystem.space24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'مكالمة فيديو عشوائية',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'اتصل بأحد الطباخين المتصلين للتحقق من معايير النظافة في المطبخ عبر Agora.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppDesignSystem.textSecondary),
                        ),
                        const SizedBox(height: 24),
                        ListTile(
                          leading: CircleAvatar(
                            backgroundColor: NahamTheme.primary.withOpacity(0.2),
                            child: const Icon(Icons.person_rounded, color: NahamTheme.primary),
                          ),
                          title: const Text('طباخ عشوائي متصل'),
                          subtitle: const Text('يتم اختيار طباخ متصل الآن (isOnline = true)'),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => _startInspection(context),
                            icon: const Icon(Icons.video_call_rounded),
                            label: const Text('بدء مكالمة الفيديو'),
                            style: FilledButton.styleFrom(
                              backgroundColor: NahamTheme.primary,
                              padding: const EdgeInsets.symmetric(vertical: AppDesignSystem.space16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
