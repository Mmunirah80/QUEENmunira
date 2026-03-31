import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_names.dart';
import '../../../core/theme/app_design_system.dart';
import '../../../core/theme/naham_theme.dart';
import '../data/chef_reg_draft_storage.dart';

/// Submission success: enter limited chef shell until admin approves documents.
class ChefRegSuccessScreen extends StatefulWidget {
  const ChefRegSuccessScreen({super.key});

  @override
  State<ChefRegSuccessScreen> createState() => _ChefRegSuccessScreenState();
}

class _ChefRegSuccessScreenState extends State<ChefRegSuccessScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ChefRegDraftStorage.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDesignSystem.defaultPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.check_circle_rounded,
                size: 80,
                color: NahamTheme.primary,
              ),
              const SizedBox(height: AppDesignSystem.space24),
              Text(
                'Application submitted',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: NahamTheme.textOnLight,
                      fontWeight: FontWeight.w700,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDesignSystem.space16),
              Text(
                'You can open the chef app now. Home, Orders, Menu and Reels stay locked until an admin approves your documents. Use Chat (Support) and Profile → Documents in the meantime—we may message you there.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppDesignSystem.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDesignSystem.space48),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => context.go(RouteNames.chefHome),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    backgroundColor: NahamTheme.primary,
                    foregroundColor: NahamTheme.textOnPurple,
                  ),
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
