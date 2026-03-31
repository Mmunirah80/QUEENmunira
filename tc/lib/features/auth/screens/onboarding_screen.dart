import 'package:flutter/material.dart';

import '../../../core/theme/app_design_system.dart';
import '../../../core/theme/naham_theme.dart';
import '../../../core/storage/onboarding_storage.dart';
import 'login_screen.dart';

/// Onboarding shown on first launch only. Purple theme, logo at top, 3 slides, same button style as customer.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const List<_OnboardingSlide> _slides = [
    _OnboardingSlide(
      title: 'Welcome to Naham',
      body: 'Order home-cooked meals from local cooks. Discover regional dishes and support home kitchens in your area.',
      icon: Icons.restaurant_rounded,
    ),
    _OnboardingSlide(
      title: 'Browse & Order',
      body: 'Explore dishes by region, watch reels from cooks, and add items to your cart. Track your order until delivery.',
      icon: Icons.explore_rounded,
    ),
    _OnboardingSlide(
      title: 'Sign in or Register',
      body: 'Create an account to place orders, chat with cooks, and save your favorites. Sign in to continue.',
      icon: Icons.login_rounded,
    ),
  ];

  Future<void> _onGetStarted() async {
    await OnboardingStorage.setOnboardingCompleted();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _onSkip() async {
    await OnboardingStorage.setOnboardingCompleted();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primary = NahamTheme.primary;

    return Scaffold(
      backgroundColor: NahamTheme.cardBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Purple header with logo at top
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
              decoration: const BoxDecoration(
                color: NahamTheme.primary,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Column(
                children: [
                  if (_currentPage < _slides.length - 1)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _onSkip,
                        child: Text(
                          'Skip',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.95),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      NahamTheme.logoAsset,
                      width: 80,
                      height: 80,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.restaurant_rounded,
                        size: 56,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Naham',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _slides.length,
                itemBuilder: (context, i) => _SlidePage(
                  slide: _slides[i],
                  primary: primary,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_slides.length, (i) {
                  final isActive = i == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: isActive ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isActive ? primary : primary.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _currentPage == _slides.length - 1
                      ? _onGetStarted
                      : () => _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                          ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDesignSystem.radiusButton),
                    ),
                  ),
                  child: Text(
                    _currentPage == _slides.length - 1 ? 'Get Started' : 'Next',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingSlide {
  final String title;
  final String body;
  final IconData icon;

  const _OnboardingSlide({
    required this.title,
    required this.body,
    required this.icon,
  });
}

class _SlidePage extends StatelessWidget {
  final _OnboardingSlide slide;
  final Color primary;

  const _SlidePage({required this.slide, required this.primary});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(slide.icon, size: 40, color: primary),
          ),
          const SizedBox(height: 32),
          Text(
            slide.title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppDesignSystem.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            slide.body,
            style: const TextStyle(
              fontSize: 16,
              height: 1.5,
              color: AppDesignSystem.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
