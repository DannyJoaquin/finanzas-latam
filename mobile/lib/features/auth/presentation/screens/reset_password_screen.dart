import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/router/app_router.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({required this.token, super.key});

  final String? token;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordCtrl = TextEditingController();
  final _confirmationCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  bool _isLoading = false;
  bool _completed = false;

  bool get _hasToken => widget.token != null && widget.token!.isNotEmpty;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmationCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_hasToken || !_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(dioProvider).post(
        ApiConstants.resetPassword,
        data: {
          'token': widget.token,
          'password': _passwordCtrl.text,
        },
      );
      if (mounted) setState(() => _completed = true);
    } on DioException catch (error) {
      if (!mounted) return;
      final message = error.response?.statusCode == 401
          ? 'El enlace venció o ya fue utilizado. Solicita uno nuevo.'
          : 'No pudimos cambiar la contraseña. Inténtalo nuevamente.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go(AppRoutes.login)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: _completed
                  ? const _CompletedContent()
                  : _hasToken
                      ? _ResetForm(
                          formKey: _formKey,
                          passwordController: _passwordCtrl,
                          confirmationController: _confirmationCtrl,
                          obscurePassword: _obscurePassword,
                          obscureConfirmation: _obscureConfirmation,
                          isLoading: _isLoading,
                          onTogglePassword: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                          onToggleConfirmation: () => setState(
                            () => _obscureConfirmation = !_obscureConfirmation,
                          ),
                          onSubmit: _submit,
                        )
                      : const _InvalidLinkContent(),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResetForm extends StatelessWidget {
  const _ResetForm({
    required this.formKey,
    required this.passwordController,
    required this.confirmationController,
    required this.obscurePassword,
    required this.obscureConfirmation,
    required this.isLoading,
    required this.onTogglePassword,
    required this.onToggleConfirmation,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController passwordController;
  final TextEditingController confirmationController;
  final bool obscurePassword;
  final bool obscureConfirmation;
  final bool isLoading;
  final VoidCallback onTogglePassword;
  final VoidCallback onToggleConfirmation;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Elige una contraseña nueva',
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Usa al menos 8 caracteres para proteger tu cuenta.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).shadowColor.withAlpha(14),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'Nueva contraseña',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: onTogglePassword,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Requerido';
                    if (value.length < 8) return 'Mínimo 8 caracteres';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: confirmationController,
                  obscureText: obscureConfirmation,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => onSubmit(),
                  decoration: InputDecoration(
                    labelText: 'Repite la contraseña',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureConfirmation
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: onToggleConfirmation,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Requerido';
                    if (value != passwordController.text) {
                      return 'Las contraseñas no coinciden';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: isLoading ? null : onSubmit,
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Guardar contraseña'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletedContent extends StatelessWidget {
  const _CompletedContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.check_circle_outline,
          size: 56,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 20),
        Text(
          'Contraseña actualizada',
          style: Theme.of(context)
              .textTheme
              .headlineMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Ya puedes iniciar sesión con tu nueva contraseña.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => context.go(AppRoutes.login),
            child: const Text('Iniciar sesión'),
          ),
        ),
      ],
    );
  }
}

class _InvalidLinkContent extends StatelessWidget {
  const _InvalidLinkContent();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.link_off_outlined,
          size: 56,
          color: Theme.of(context).colorScheme.error,
        ),
        const SizedBox(height: 20),
        Text(
          'Enlace incompleto',
          style: Theme.of(context)
              .textTheme
              .headlineMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Solicita un nuevo enlace para restablecer tu contraseña.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () => context.go(AppRoutes.forgotPassword),
            child: const Text('Solicitar nuevo enlace'),
          ),
        ),
      ],
    );
  }
}
