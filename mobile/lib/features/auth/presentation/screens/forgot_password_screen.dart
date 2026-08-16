import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../core/router/app_router.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _isLoading = false;
  bool _submitted = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(dioProvider).post(
        ApiConstants.forgotPassword,
        data: {'email': _emailCtrl.text.trim()},
      );
      if (mounted) setState(() => _submitted = true);
    } on DioException catch (error) {
      if (!mounted) return;
      final message = error.response?.statusCode == 429
          ? 'Demasiadas solicitudes. Espera un momento e inténtalo de nuevo.'
          : 'No pudimos procesar la solicitud. Inténtalo nuevamente.';
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
              child: _submitted ? _SuccessContent() : _RequestForm(
                formKey: _formKey,
                emailController: _emailCtrl,
                isLoading: _isLoading,
                onSubmit: _submit,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RequestForm extends StatelessWidget {
  const _RequestForm({
    required this.formKey,
    required this.emailController,
    required this.isLoading,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final bool isLoading;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Restablecer contraseña',
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Te enviaremos un enlace para elegir una contraseña nueva.',
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
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  onFieldSubmitted: (_) => onSubmit(),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Requerido';
                    }
                    if (!value.contains('@')) return 'Correo inválido';
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
                      : const Text('Enviar enlace'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const _GoogleAccountHint(),
        ],
      ),
    );
  }
}

class _SuccessContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.mark_email_read_outlined,
          size: 56,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 20),
        Text(
          'Revisa tu correo',
          style: Theme.of(context)
              .textTheme
              .headlineMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Si la cuenta permite contraseña, recibirás un enlace para restablecerla. El enlace vence en una hora.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 20),
        const _GoogleAccountHint(),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => context.go(AppRoutes.login),
            child: const Text('Volver al inicio de sesión'),
          ),
        ),
      ],
    );
  }
}

class _GoogleAccountHint extends StatelessWidget {
  const _GoogleAccountHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withAlpha(90),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '¿Te registraste con Google? No necesitas una contraseña. Vuelve al inicio y elige «Continuar con Google».',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
