import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/route_names.dart';
import '../../../core/utils/quick_network_check.dart';
import '../../../core/theme/app_design_system.dart';
import '../../../core/theme/naham_theme.dart';
import '../../../core/utils/extensions.dart';
import '../data/chef_reg_draft_storage.dart';
import '../data/models/chef_reg_draft.dart';
import '../presentation/providers/auth_provider.dart';

/// Step 1: Account info for chef registration (name, email, phone, password).
class ChefRegAccountScreen extends ConsumerStatefulWidget {
  const ChefRegAccountScreen({super.key});

  @override
  ConsumerState<ChefRegAccountScreen> createState() => _ChefRegAccountScreenState();
}

class _ChefRegAccountScreenState extends ConsumerState<ChefRegAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _prefsLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreFieldsFromStorage());
  }

  Future<void> _restoreFieldsFromStorage() async {
    final saved = await ChefRegDraftStorage.loadFields();
    if (!mounted) return;
    if (saved != null) {
      if (_nameController.text.isEmpty && saved.name.isNotEmpty) {
        _nameController.text = saved.name;
      }
      if (_emailController.text.isEmpty) {
        _emailController.text = saved.email;
      }
      if (_phoneController.text.isEmpty && saved.phone != null && saved.phone!.isNotEmpty) {
        _phoneController.text = saved.phone!;
      }
    }
    setState(() => _prefsLoading = false);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (!_formKey.currentState!.validate()) return;
    final offlineMsg = await quickNetworkCheckMessage();
    if (!mounted) return;
    if (offlineMsg != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(offlineMsg)));
      return;
    }
    final phone = _phoneController.text.trim();
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    await ChefRegDraftStorage.saveFields(
      name: name,
      email: email,
      phone: phone.isEmpty ? null : phone,
    );
    ref.read(chefRegDraftProvider.notifier).state = ChefRegDraft(
      name: name,
      email: email,
      phone: phone.isEmpty ? null : phone,
      password: _passwordController.text,
    );
    if (!mounted) return;
    context.go(RouteNames.chefRegDocuments);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppDesignSystem.backgroundOffWhite,
      appBar: AppBar(
        title: const Text('Chef registration'),
        backgroundColor: AppDesignSystem.backgroundOffWhite,
      ),
      body: SafeArea(
        child: _prefsLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(AppDesignSystem.defaultPadding),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Account info',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Step 1 of 2. Create your account. Your name and email are saved on this device (securely on phone/desktop; browser storage on web) until you finish or submit. Your password is never stored.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppDesignSystem.textSecondary,
                            ),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Full name',
                          hintText: 'Your name',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          hintText: 'you@example.com',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          if (!v.isValidEmail) return 'Invalid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Phone (optional)',
                          hintText: '+1234567890',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          hintText: 'At least 6 characters',
                          prefixIcon: const Icon(Icons.lock_outlined),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            ),
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          if (v.length < 6) return 'At least 6 characters';
                          return null;
                        },
                      ),
                      const SizedBox(height: AppDesignSystem.space16),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        decoration: InputDecoration(
                          labelText: 'Confirm Password',
                          hintText: 'Repeat password',
                          prefixIcon: const Icon(Icons.lock_outlined),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            ),
                            onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Required';
                          if (v != _passwordController.text) return 'Passwords do not match';
                          return null;
                        },
                      ),
                      const SizedBox(height: AppDesignSystem.space32),
                      FilledButton(
                        onPressed: _next,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(double.infinity, 56),
                          backgroundColor: NahamTheme.primary,
                          foregroundColor: NahamTheme.textOnPurple,
                        ),
                        child: const Text('Continue'),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
