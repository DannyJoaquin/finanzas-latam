import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/tutorial_service.dart';
import '../../../auth/providers/auth_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public helpers used by the router redirect (must stay in this file).
// Onboarding completion is tracked per-user-id so a returning user never
// sees it again after logging out, while a different account still does.
// ─────────────────────────────────────────────────────────────────────────────

bool hasCompletedOnboarding({String? userId}) =>
    TutorialService().isOnboardingDone(userId: userId);
Future<void> markOnboardingDone({String? userId}) =>
    TutorialService().markOnboardingDone(userId: userId);

// ─────────────────────────────────────────────────────────────────────────────
// Slide data model
// ─────────────────────────────────────────────────────────────────────────────

class _OnboardingSlide {
  const _OnboardingSlide({
    required this.icon,
    required this.title,
    required this.body,
    required this.color,
    this.chips = const [],
  });
  final IconData icon;
  final String title;
  final String body;
  final Color color;
  final List<String> chips;
}

const _slides = [
  _OnboardingSlide(
    icon: Icons.trending_up_rounded,
    title: 'Controla tu dinero\nde verdad',
    body: 'Registrá, entendé y mejorá tus finanzas personales sin complicarte.',
    color: AppColors.primary,
  ),
  _OnboardingSlide(
    icon: Icons.receipt_long_outlined,
    title: 'Registrá en segundos',
    body: 'Gastos, ingresos y efectivo. La IA categoriza automáticamente para vos.',
    color: AppColors.secondary,
    chips: ['💸 Gastos', '📈 Ingresos', '🤖 Auto-categoría'],
  ),
  _OnboardingSlide(
    icon: Icons.auto_awesome_outlined,
    title: 'La app piensa por vos',
    body: 'Alertas personalizadas, detección de gastos inusuales y proyecciones en tiempo real.',
    color: Color(0xFF7B61FF),
    chips: ['🔔 Alertas', '📊 Patrones', '💡 Proyecciones'],
  ),
  _OnboardingSlide(
    icon: Icons.account_balance_wallet_outlined,
    title: 'Todo en un solo lugar',
    body: 'Efectivo y tarjetas de crédito bajo control. Sin perder claridad.',
    color: Color(0xFF2196F3),
    chips: ['💵 Efectivo', '💳 Tarjetas', '📋 Resumen claro'],
  ),
  _OnboardingSlide(
    icon: Icons.group_outlined,
    title: 'Compartí sin dramas',
    body: 'Dividí gastos con amigos o familia. La app calcula quién debe qué automáticamente.',
    color: Color(0xFFFF6B35),
    chips: ['👥 Grupos', '⚖️ Balance real', '✅ Liquidación fácil'],
  ),
  _OnboardingSlide(
    icon: Icons.check_circle_outline_rounded,
    title: '¡Todo listo!',
    body: 'Empezá a tomar mejores decisiones financieras hoy mismo.',
    color: AppColors.primary,
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// Screen
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
    final userId = ref.read(authStateProvider).valueOrNull?.user?.id;
    await TutorialService().markOnboardingDone(userId: userId);
    if (mounted) context.go(AppRoutes.home);
  }

  void _next() {
    if (_current < _slides.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _finish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_current];
    final isLast = _current == _slides.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar: segmented progress + skip ─────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      children: List.generate(_slides.length, (i) => Expanded(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          height: 4,
                          decoration: BoxDecoration(
                            color: i <= _current
                                ? slide.color
                                : Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      )),
                    ),
                  ),
                  if (!isLast)
                    TextButton(
                      onPressed: _finish,
                      child: const Text('Saltar'),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── Slides ────────────────────────────────────────────────────────────
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _current = i),
                itemBuilder: (_, i) => _SlidePage(slide: _slides[i]),
              ),
            ),

            // ── CTA button ───────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 32),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: slide.color,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _next,
                  child: Text(
                    isLast ? 'Comenzar' : 'Siguiente',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
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

// ─────────────────────────────────────────────────────────────────────────────
// Slide page widget
// ─────────────────────────────────────────────────────────────────────────────

class _SlidePage extends StatelessWidget {
  const _SlidePage({required this.slide});
  final _OnboardingSlide slide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSimple = slide.chips.isEmpty; // intro + closing slides

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon with glow halo
          Container(
            width: isSimple ? 140 : 120,
            height: isSimple ? 140 : 120,
            decoration: BoxDecoration(
              color: slide.color.withAlpha(24),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: slide.color.withAlpha(60),
                  blurRadius: 36,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Icon(
              slide.icon,
              size: isSimple ? 68 : 56,
              color: slide.color,
            ),
          ),

          const SizedBox(height: 32),

          // Content card
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(22, 22, 22, isSimple ? 28 : 20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: theme.shadowColor.withAlpha(14),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  slide.title,
                  style: (isSimple
                          ? theme.textTheme.headlineMedium
                          : theme.textTheme.headlineSmall)
                      ?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  slide.body,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withAlpha(178),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),

                // Feature chips (only for feature slides)
                if (slide.chips.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: slide.chips.map((chip) => _ChipBadge(
                      label: chip,
                      color: slide.color,
                    )).toList(),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _ChipBadge extends StatelessWidget {
  const _ChipBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(65)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
