import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:naham_cook_app/core/theme/app_design_system.dart';
import 'package:naham_cook_app/features/auth/presentation/providers/auth_provider.dart';
import 'package:naham_cook_app/features/customer/naham_customer_screens.dart'
    show
        NahamCustomerEditProfileScreen,
        NahamCustomerFavoritesScreen,
        NahamCustomerNotificationsScreen;

class NahamCustomerProfileScreen extends ConsumerWidget {
  const NahamCustomerProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authStateProvider);
    return authAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const Scaffold(
        body: Center(
          child: Text('Failed to load profile'),
        ),
      ),
      data: (user) {
        if (user == null) {
          return const Scaffold(
            body: Center(
              child: Text('Please sign in to view your profile'),
            ),
          );
        }
        return Scaffold(
          backgroundColor: AppDesignSystem.backgroundOffWhite,
          appBar: AppBar(
            backgroundColor: AppDesignSystem.primary,
            foregroundColor: Colors.white,
            title: const Text('Profile'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (user.isBlocked)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Your account is currently blocked. Please contact support.',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: const CircleAvatar(child: Icon(Icons.person_outline_rounded)),
                  title: Text(user.name),
                  subtitle: Text(user.email),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const NahamCustomerEditProfileScreen(),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.favorite_outline_rounded),
                      title: const Text('Favorites'),
                      subtitle: const Text('View saved dishes'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const NahamCustomerFavoritesScreen(),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.notifications_none_rounded),
                      title: const Text('Notifications'),
                      subtitle: const Text('Read and manage notifications'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const NahamCustomerNotificationsScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () async {
                  await ref.read(authStateProvider.notifier).logout();
                },
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sign out'),
              ),
            ],
          ),
        );
      },
    );
  }
}

