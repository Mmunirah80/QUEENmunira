import 'package:flutter/material.dart';

/// Legacy cook auth screen (no longer used in the main flow).
///
/// Cooks should always use the unified `LoginScreen`. This screen is kept
/// only to avoid breaking existing routes that might still reference it.
class CookAuthScreen extends StatelessWidget {
  const CookAuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'Cook authentication is handled by the main Login screen.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
