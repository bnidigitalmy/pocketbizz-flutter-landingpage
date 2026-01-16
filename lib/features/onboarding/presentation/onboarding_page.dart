import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pocketbizz_logo.dart';
import '../data/onboarding_content.dart';
import '../services/onboarding_service.dart';
import 'screens/welcome_screen.dart';
import 'screens/step_screen.dart';
import 'screens/complete_screen.dart';

/// Main Onboarding Page - PageView with 6 screens
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  final OnboardingService _onboardingService = OnboardingService();
  int _currentPage = 0;
  final int _totalPages = 6;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToNextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToPreviousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _skipOnboarding() async {
    await _onboardingService.skipOnboarding();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  Future<void> _completeOnboarding() async {
    await _onboardingService.markOnboardingComplete();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  void _navigateToPage(String route) async {
    // Navigate to the specified page, then return to onboarding
    await Navigator.of(context).pushNamed(
      route,
      arguments: {'fromOnboarding': true},
    );
    // After returning, go to next page
    if (mounted) {
      _goToNextPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            _buildProgressIndicator(),
            
            // Page content
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                },
                physics: const NeverScrollableScrollPhysics(), // Disable swipe, use buttons
                children: [
                  // Screen 1: Welcome
                  WelcomeScreen(
                    content: OnboardingContent.welcome,
                    onStart: _goToNextPage,
                    onSkip: _skipOnboarding,
                  ),
                  
                  // Screen 2: Step 1 - Tambah Bahan
                  StepScreen(
                    content: OnboardingContent.stepStock,
                    onPrimary: () => _navigateToPage('/stock'),
                    onSecondary: _goToNextPage,
                    onBack: _goToPreviousPage,
                  ),
                  
                  // Screen 3: Step 2 - Cipta Produk
                  StepScreen(
                    content: OnboardingContent.stepProduct,
                    onPrimary: () => _navigateToPage('/products/add'),
                    onSecondary: _goToNextPage,
                    onBack: _goToPreviousPage,
                  ),
                  
                  // Screen 4: Step 3 - Rekod Pengeluaran
                  StepScreen(
                    content: OnboardingContent.stepProduction,
                    onPrimary: () => _navigateToPage('/production'),
                    onSecondary: _goToNextPage,
                    onBack: _goToPreviousPage,
                  ),
                  
                  // Screen 5: Step 4 - Rekod Jualan
                  StepScreen(
                    content: OnboardingContent.stepSales,
                    onPrimary: () => _navigateToPage('/sales/create'),
                    onSecondary: _goToNextPage,
                    onBack: _goToPreviousPage,
                  ),
                  
                  // Screen 6: Completion
                  CompleteScreen(
                    content: OnboardingContent.completion,
                    onComplete: _completeOnboarding,
                  ),
                ],
              ),
            ),
            
            // Page dots indicator
            _buildPageDots(),
            
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Row(
        children: [
          // Back button (hidden on first page)
          if (_currentPage > 0 && _currentPage < _totalPages - 1)
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: _goToPreviousPage,
              color: AppColors.textSecondary,
            )
          else
            const SizedBox(width: 48),
          
          // Progress bar
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (_currentPage + 1) / _totalPages,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                minHeight: 4,
              ),
            ),
          ),
          
          const SizedBox(width: 12),
          
          // Step indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_currentPage + 1}/$_totalPages',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_totalPages, (index) {
        final isActive = index == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : Colors.grey[300],
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
