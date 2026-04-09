import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/storage/token_storage.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _rememberMe = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authStateProvider.notifier).login(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
    // Read state after the await to catch errors.  The router's refreshListenable
    // will handle navigation on success, so we only need to act on errors here.
    if (!mounted) return;
    final authAsync = ref.read(authStateProvider);
    if (authAsync.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(authAsync.error))),
      );
    } else if (!_rememberMe) {
      // User doesn't want to stay signed in: remove the refresh token
      // so the session expires when the access token does.
      await ref.read(tokenStorageProvider).deleteRefreshToken();
    }
  }

  Future<void> _signInWithGoogle() async {
    await ref.read(authStateProvider.notifier).loginWithGoogle();
    if (!mounted) return;
    final authAsync = ref.read(authStateProvider);
    if (authAsync.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyGoogleError(authAsync.error))),
      );
    }
  }

  String _friendlyGoogleError(Object? err) {
    if (err == null) return 'Error desconocido';
    final msg = err.toString().toLowerCase();
    if (msg.contains('network') || msg.contains('connection')) {
      return 'Sin conexión. Verifica tu internet.';
    }
    if (msg.contains('401') || msg.contains('unauthorized')) {
      return 'Token de Google inválido. Intenta nuevamente.';
    }
    return 'Error con Google. Intenta nuevamente.';
  }

  String _friendlyError(Object? err) {
    if (err == null) return 'Error desconocido';
    final msg = err.toString().toLowerCase();
    if (msg.contains('401') || msg.contains('invalid credentials')) {
      return 'Correo o contraseña incorrectos';
    }
    if (msg.contains('network') || msg.contains('connection')) {
      return 'Sin conexión. Verifica tu internet.';
    }
    return 'Error al iniciar sesión. Intenta nuevamente.';
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authStateProvider).isLoading;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                Icon(
                  Icons.account_balance_wallet,
                  size: 56,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'Bienvenido',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Inicia sesión para continuar',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 40),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Correo electrónico',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Requerido';
                    if (!v.contains('@')) return 'Correo inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscure,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Requerido';
                    if (v.length < 6) return 'Mínimo 6 caracteres';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                // Remember me
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Mantener sesión iniciada'),
                  value: _rememberMe,
                  onChanged: (v) => setState(() => _rememberMe = v),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: isLoading ? null : _submit,
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Iniciar sesión'),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '¿No tienes cuenta? ',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    GestureDetector(
                      onTap: () => context.go(AppRoutes.register),
                      child: Text(
                        'Regístrate',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'o continúa con',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 16),
                _GoogleSignInButton(
                  isLoading: isLoading,
                  onPressed: _signInWithGoogle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleSignInButton extends StatelessWidget {
  const _GoogleSignInButton({required this.isLoading, required this.onPressed});

  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return OutlinedButton(
      onPressed: isLoading ? null : onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: BorderSide(color: colorScheme.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        minimumSize: const Size(double.infinity, 52),
      ),
      child: isLoading
          ? SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.primary),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Simple "G" logo using text styling — avoids needing an SVG asset
                Text(
                  'G',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Continuar con Google',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: colorScheme.onSurface,
                      ),
                ),
              ],
            ),
    );
  }
}
