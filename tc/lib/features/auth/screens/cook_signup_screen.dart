import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_design_system.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/snackbar_helper.dart';
import '../domain/entities/user_entity.dart';
import '../presentation/providers/auth_provider.dart';
import 'cook_pending_screen.dart';
import 'login_screen.dart';

/// Cook sign up: single-step account creation + document upload.
class CookSignupScreen extends ConsumerStatefulWidget {
  const CookSignupScreen({super.key});

  @override
  ConsumerState<CookSignupScreen> createState() => _CookSignupScreenState();
}

class _CookSignupScreenState extends ConsumerState<CookSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  File? _freelancerIdFile;
  File? _nationalIdFile;
  bool _isPicking = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickDocument(bool isFreelancerId) async {
    if (_isPicking) return;
    setState(() {
      _isPicking = true;
    });
    final picker = ImagePicker();
    try {
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(ctx, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: const Text('Gallery'),
                onTap: () => Navigator.pop(ctx, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );
      if (source == null || !mounted) {
        setState(() {
          _isPicking = false;
        });
        return;
      }
      final picked = await picker.pickImage(source: source, imageQuality: 85);
      if (picked == null || !mounted) {
        setState(() {
          _isPicking = false;
        });
        return;
      }
      setState(() {
        if (isFreelancerId) {
          _freelancerIdFile = File(picked.path);
        } else {
          _nationalIdFile = File(picked.path);
        }
        _isPicking = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPicking = false;
        });
        SnackbarHelper.error(context, 'Failed to pick image. Please try again.');
      }
    }
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_freelancerIdFile == null || _nationalIdFile == null) {
      SnackbarHelper.error(context, 'Please upload Freelancer ID and National ID.');
      return;
    }

    try {
      await ref.read(authStateProvider.notifier).signup(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            name: _nameController.text.trim(),
            phone: _phoneController.text.trim().isEmpty
                ? null
                : _phoneController.text.trim(),
            role: AppRole.chef,
          );

      if (!mounted) return;

      // TODO: Wire document upload to Supabase storage + chef_profiles when backend is ready.

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const CookPendingScreen()),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceAll('Exception: ', '').trim();
      SnackbarHelper.error(context, msg.isNotEmpty ? msg : 'Sign up failed.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final isLoading = authState.isLoading;

    return Scaffold(
      backgroundColor: AppDesignSystem.backgroundOffWhite,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDesignSystem.screenHorizontalPadding,
            vertical: AppDesignSystem.space24,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppDesignSystem.space24),
                Text(
                  'Create Cook Account',
                  style: Theme.of(context).textTheme.displaySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDesignSystem.space8),
                Text(
                  'Sign up to sell your homemade food',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color:
                            context.colorScheme.onSurface.withOpacity(0.6),
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppDesignSystem.space32),
                // Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name',
                    hintText: 'Enter your full name',
                    prefixIcon: Icon(Icons.person_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppDesignSystem.space20),
                // Email
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'Enter your email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your email';
                    }
                    if (!value.isValidEmail) {
                      return 'Please enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppDesignSystem.space20),
                // Phone
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone (Optional)',
                    hintText: 'Enter your phone number',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: AppDesignSystem.space20),
                // Password
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'Enter your password',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your password';
                    }
                    if (value.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppDesignSystem.space20),
                // Confirm password
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    hintText: 'Confirm your password',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword =
                              !_obscureConfirmPassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppDesignSystem.space32),
                // Document uploads
                Text(
                  'Required documents',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppDesignSystem.space12),
                _DocumentTile(
                  title: 'Freelancer ID',
                  uploaded: _freelancerIdFile != null,
                  onTap: () => _pickDocument(true),
                ),
                const SizedBox(height: AppDesignSystem.space12),
                _DocumentTile(
                  title: 'National ID',
                  uploaded: _nationalIdFile != null,
                  onTap: () => _pickDocument(false),
                ),
                const SizedBox(height: AppDesignSystem.space32),
                // Create Account button
                ElevatedButton(
                  onPressed: isLoading ? null : _handleSignup,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                  ),
                  child: isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create Account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DocumentTile extends StatelessWidget {
  final String title;
  final bool uploaded;
  final VoidCallback onTap;

  const _DocumentTile({
    required this.title,
    required this.uploaded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: uploaded ? null : onTap,
        borderRadius: BorderRadius.circular(AppDesignSystem.radiusMedium),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppDesignSystem.surfaceLight,
            borderRadius: BorderRadius.circular(AppDesignSystem.radiusMedium),
            border: Border.all(
              color: uploaded
                  ? Theme.of(context).colorScheme.primary
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(
                uploaded ? Icons.check_circle_rounded : Icons.upload_file_rounded,
                color: uploaded
                    ? Theme.of(context).colorScheme.primary
                    : AppDesignSystem.textSecondary,
                size: 28,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              ),
              Icon(
                uploaded
                    ? Icons.check_rounded
                    : Icons.add_circle_outline_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

