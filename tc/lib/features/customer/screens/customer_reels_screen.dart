import 'package:flutter/material.dart';

import 'package:naham_cook_app/core/theme/app_design_system.dart';
import 'package:naham_cook_app/features/customer/screens/customer_reels_feed.dart';

/// Customer Reels tab (standalone scaffold + app bar). Feed logic: [CustomerReelsFeed].
class NahamCustomerReelsScreen extends StatelessWidget {
  const NahamCustomerReelsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: AppDesignSystem.primary,
        foregroundColor: Colors.white,
        title: const Text('Reels'),
      ),
      body: const CustomerReelsFeed(accentColor: AppDesignSystem.primary),
    );
  }
}
