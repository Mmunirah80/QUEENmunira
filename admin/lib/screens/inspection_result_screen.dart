import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme/app_design_system.dart';
import '../core/theme/naham_theme.dart';
import '../core/constants/route_names.dart';

/// Shown after video call ends. Two options: all good, or issue warning (opens ChefViolationHistoryScreen).
class InspectionResultScreen extends StatelessWidget {
  final String chefId;
  final String chefName;

  const InspectionResultScreen({super.key, required this.chefId, required this.chefName});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: NahamTheme.headerBackground,
          foregroundColor: Colors.white,
          title: const Text('نتيجة التفتيش'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => context.go(RouteNames.dashboard),
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(AppDesignSystem.space24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              Text(
                'كيف كانت نتيجة التفتيش؟',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppDesignSystem.space16),
                  child: Column(
                    children: [
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: NahamTheme.primary.withValues(alpha: 0.2),
                          child: const Icon(Icons.person_rounded, color: NahamTheme.primary),
                        ),
                        title: Text(chefName),
                        subtitle: Text('الطباخ'),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => context.go(RouteNames.dashboard),
                style: FilledButton.styleFrom(
                  backgroundColor: AppDesignSystem.successGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: AppDesignSystem.space16),
                ),
                child: const Text('كل شيء تمام'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () {
                  context.push(
                    RouteNames.chefViolation,
                    extra: {'chefId': chefId, 'chefName': chefName},
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppDesignSystem.warningOrange,
                  side: const BorderSide(color: AppDesignSystem.warningOrange),
                  padding: const EdgeInsets.symmetric(vertical: AppDesignSystem.space16),
                ),
                child: const Text('إصدار تحذير'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
