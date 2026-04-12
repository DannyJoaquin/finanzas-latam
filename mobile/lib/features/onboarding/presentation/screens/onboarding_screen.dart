import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/theme/app_colors.dart';

/// Hive key that marks onboarding as completed.
const _kOnboardingDone = 'onboarding_done';

/// Returns true if the user has already completed onboarding.
bool hasCompletedOnboarding() {
  final box = Hive.box<String>(StorageKeys.preferencesBox);
  return box.get(_kOnboardingDone) == 'true';
}

/// Marks onboarding as completed in Hive.
Future<void> markOnboardingDone() async {
  final box = Hive.box<String>(StorageKeys.preferencesBox);
  await box.put(_kOnboardingDone, 'true');
}

// ─────────────────────────────────────────────────────────────────────────────

class _OnboardingSlide {
  const _OnboardingSlide({
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
  });
  final IconData icon;
  final String title;
  final String body;
  final Color color;
}

const _slides = [
  _OnboardingSlide(
    icon: Icons.savings_outlined,
    title: 'Control Total',
    body: 'Registra tus gastos e ingresos en segundos y mantén un control claro de tu dinero.',
    color: AppColors.primary,
  ),
  _OnboardingSlide(
    icon: Icons.account_balance_wallet_outlined,
    title: 'Presupuestos Inteligentes',
    body: 'Crea presupuestos por categoría y recibe alertas antes de que los excedas.',
    color: AppColors.secondary,
  ),
  _OnboardingSlide(
    icon: Icons.bar_chart_outlined,
    title: 'Análisis y Proyecciones',
    body: 'Descubre patrones en tus gastos y proyecta cuánto puedes ahorrar cada mes.',
    color: Color(0xFF9C27B0),
  ),
  _OnboardingSlide(
    icon: Icons.emoji_events_outlined,
    title: 'Logros y Rachas',
    body: 'Gana logros por buenos hábitos financieros y mantén rachas de ahorro.',
    color: Color(0xFFFF9800),
  ),
];

// ─────────────────────────────────────────────────────────────────────────────

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _current = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await markOnboardingDone();
    if (mounted) context.go(AppRoutes.home);
  }

  void _next() {
    if (_current < _slides.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _current == _slides.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Skip button
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: _finish,
                child: const Text('Saltar'),
              ),
            ),

            // Slides
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _current = i),
                itemBuilder: (context, i) => _SlidePage(slide: _slides[i]),
              ),
            ),

            // Dots indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _slides.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _current == i ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _current == i
                        ? _slides[_current].color
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // CTA button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _slides[_current].color,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _next,
                  child: Text(
                    isLast ? 'Empezar' : 'Siguiente',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SlidePage extends StatelessWidget {
  const _SlidePage({required this.slide});
  final _OnboardingSlide slide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: slide.color.withAlpha(28),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: slide.color.withAlpha(32),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(slide.icon, size: 60, color: slide.color),
          ),
          const SizedBox(height: 28),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: theme.shadowColor.withAlpha(14),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  slide.title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  slide.body,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(178),
                    height: 1.45,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
