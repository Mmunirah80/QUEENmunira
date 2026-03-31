import 'package:flutter/material.dart';

import '../theme/app_design_system.dart';

/// Purple header (#9B7EC8) with Naham logo left, title center, optional actions right.
/// Matches Customer header; use for Cook screens (Orders, Menu, Profile, etc.).
class NahamScreenHeader extends StatelessWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;

  const NahamScreenHeader({
    super.key,
    required this.title,
    this.actions,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        bottom: 16,
        left: 20,
        right: 20,
      ),
      decoration: const BoxDecoration(
        color: AppDesignSystem.headerBackground,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            if (leading != null) leading!,
            if (leading == null)
              SizedBox(
                width: 120,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        AppDesignSystem.logoAsset,
                        width: 32,
                        height: 32,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(Icons.restaurant_rounded, color: Colors.white, size: 28),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Naham',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            SizedBox(
              width: 120,
              child: Align(
                alignment: Alignment.centerRight,
                child: actions != null && actions!.isNotEmpty
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: actions!,
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
