// ============================================================
// SETTINGS — RTL, TC theme. Logout from auth session.
// ============================================================

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/theme/app_design_system.dart';
import '../../../core/widgets/snackbar_helper.dart';
import '../../auth/presentation/providers/auth_provider.dart';
import '../../auth/screens/login_screen.dart';

class _NC {
  static const primary = AppDesignSystem.primary;
  static const bg = AppDesignSystem.backgroundOffWhite;
  static const surface = AppDesignSystem.cardWhite;
  static const textSub = AppDesignSystem.textSecondary;
}

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _orderSounds = true;
  static const _notificationsKey = 'cook_settings_notifications_enabled';
  static const _orderSoundsKey = 'cook_settings_order_sounds_enabled';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _notificationsEnabled =
          prefs.getBool(_notificationsKey) ?? _notificationsEnabled;
      _orderSounds = prefs.getBool(_orderSoundsKey) ?? _orderSounds;
    });
  }

  Future<void> _setNotificationsEnabled(bool value) async {
    setState(() => _notificationsEnabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsKey, value);
  }

  Future<void> _setOrderSounds(bool value) async {
    setState(() => _orderSounds = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_orderSoundsKey, value);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        backgroundColor: _NC.bg,
        body: Column(
          children: [
            _buildAppBar(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _sectionTitle('Notifications'),
                    _switchTile(
                      icon: Icons.notifications_outlined,
                      title: 'Order notifications',
                      subtitle: 'New orders, messages, reminders',
                      value: _notificationsEnabled,
                      onChanged: _setNotificationsEnabled,
                    ),
                    _switchTile(
                      icon: Icons.volume_up_outlined,
                      title: 'Order sound',
                      subtitle: 'Play a sound when a new order arrives',
                      value: _orderSounds,
                      onChanged: _setOrderSounds,
                    ),
                    const SizedBox(height: 24),
                    _sectionTitle('Support'),
                    _listTile(
                      icon: Icons.help_outline_rounded,
                      title: 'Help & FAQ',
                      onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coming soon'))),
                    ),
                    _listTile(
                      icon: Icons.mail_outline_rounded,
                      title: 'Contact support',
                      onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('support@naham.app'))),
                    ),
                    _listTile(
                      icon: Icons.info_outline_rounded,
                      title: 'About Naham',
                      onTap: () => showAboutDialog(
                        context: context,
                        applicationName: 'Naham Cook',
                        applicationVersion: '1.0.0',
                        applicationLegalese: '© Naham — Home cooks marketplace',
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          try {
                            await ref.read(authStateProvider.notifier).logout();
                            if (!context.mounted) return;
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (ctx) => LoginScreen()),
                              (route) => false,
                            );
                          } catch (e) {
                            if (context.mounted) {
                              SnackbarHelper.error(context, 'Could not log out. Please try again.');
                            }
                          }
                        },
                        icon: const Icon(Icons.logout_rounded, color: AppDesignSystem.errorRed, size: 20),
                        label: const Text('Log out', style: TextStyle(color: AppDesignSystem.errorRed, fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppDesignSystem.errorRed),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 8, bottom: 20, left: 8, right: 16),
      decoration: const BoxDecoration(
        color: _NC.primary,
        borderRadius: BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
      ),
      child: Row(
        children: [
          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_rounded, color: Colors.white)),
          const Expanded(child: Text('Settings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white))),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _NC.textSub)),
    );
  }

  Widget _switchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _NC.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Icon(icon, size: 22, color: _NC.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: _NC.textSub)),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged, activeColor: _NC.primary),
        ],
      ),
    );
  }

  Widget _listTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, size: 22, color: _NC.primary),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: subtitle != null && subtitle.isNotEmpty
          ? Text(subtitle, style: const TextStyle(fontSize: 12, color: _NC.textSub))
          : null,
      trailing: const Icon(Icons.chevron_left, color: _NC.textSub),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
