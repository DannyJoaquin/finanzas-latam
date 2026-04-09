import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/dio_client.dart';
import '../../../../core/constants/api_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/providers/auth_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).valueOrNull?.user;
    final themeMode = ref.watch(themeNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        children: [
          // Profile header
          if (user != null)
            ListTile(
              contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              leading: CircleAvatar(
                radius: 26,
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Text(
                  user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              title: Text(user.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(user.email),
              trailing: IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => _showEditProfileSheet(context, ref, user),
                tooltip: 'Editar perfil',
              ),
            ),
          const Divider(),

          // Appearance
          _SectionHeader(title: 'Apariencia'),
          SwitchListTile(
            title: const Text('Modo oscuro'),
            secondary: const Icon(Icons.dark_mode_outlined),
            value: themeMode == ThemeMode.dark,
            onChanged: (_) => ref.read(themeNotifierProvider.notifier).toggle(),
          ),
          const Divider(),

          // Account
          _SectionHeader(title: 'Cuenta'),
          ListTile(
            leading: const Icon(Icons.person_outlined),
            title: const Text('Editar perfil'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showEditProfileSheet(context, ref, user),
          ),
          ListTile(
            leading: const Icon(Icons.lock_outlined),
            title: const Text('Cambiar contraseña'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showChangePasswordDialog(context, ref),
          ),
          const Divider(),

          // Preferences
          _SectionHeader(title: 'Preferencias'),
          ListTile(
            leading: const Icon(Icons.currency_exchange),
            title: const Text('Moneda'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  user?.currency ?? 'HNL',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () => _showCurrencyPicker(context, ref, user?.currency ?? 'HNL'),
          ),
          ListTile(
            leading: const Icon(Icons.calendar_today_outlined),
            title: const Text('Ciclo de pago'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _cycleLabel(user?.payCycle ?? 'monthly'),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () => _showCyclePicker(context, ref, user?.payCycle ?? 'monthly'),
          ),
          if (user?.payCycle == 'biweekly')
            ListTile(
              leading: const Icon(Icons.event_outlined),
              title: const Text('Días de corte'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Día ${user?.payDay1 ?? 15} y ${user?.payDay2 ?? 30}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right),
                ],
              ),
              onTap: () => _showPayDayPicker(
                context, ref, user?.payDay1 ?? 15, user?.payDay2 ?? 30),
            ),
          const Divider(),

          // Danger zone
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Cerrar sesión', style: TextStyle(color: Colors.red)),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Cerrar sesión'),
                  content: const Text('¿Seguro que deseas cerrar sesión?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
                    TextButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Salir', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await ref.read(authStateProvider.notifier).logout();
              }
            },
          ),
          const SizedBox(height: 40),

          // Version
          const Center(
            child: Text(
              'Finanzas LATAM v1.0.0',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  static String _cycleLabel(String cycle) => switch (cycle) {
        'weekly' => 'Semanal',
        'biweekly' => 'Quincenal',
        _ => 'Mensual',
      };

  void _showEditProfileSheet(BuildContext context, WidgetRef ref, dynamic user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _EditProfileSheet(
        currentName: user?.fullName ?? '',
        currentCurrency: user?.currency ?? 'HNL',
        onSaved: () => ref.invalidate(authStateProvider),
      ),
    );
  }

  void _showCurrencyPicker(BuildContext context, WidgetRef ref, String current) {
    const currencies = ['HNL', 'USD', 'GTQ', 'MXN', 'CRC', 'NIO'];
    const labels = {
      'HNL': 'Lempira hondureño',
      'USD': 'Dólar estadounidense',
      'GTQ': 'Quetzal guatemalteco',
      'MXN': 'Peso mexicano',
      'CRC': 'Colón costarricense',
      'NIO': 'Córdoba nicaragüense',
    };
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Seleccionar moneda'),
        children: currencies.map((c) {
          final isSelected = c == current;
          return SimpleDialogOption(
            onPressed: () async {
              Navigator.pop(ctx);
              if (c == current) return;
              try {
                final dio = ref.read(dioProvider);
                await dio.patch(ApiConstants.me, data: {'currency': c});
                ref.invalidate(authStateProvider);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Theme.of(context).colorScheme.primary : null,
                        ),
                      ),
                      Text(
                        labels[c] ?? c,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showCyclePicker(BuildContext context, WidgetRef ref, String current) {
    const cycles = ['weekly', 'biweekly', 'monthly'];
    const cycleLabels = {
      'weekly': 'Semanal',
      'biweekly': 'Quincenal',
      'monthly': 'Mensual',
    };
    const cycleDescriptions = {
      'weekly': 'Se resetea cada semana',
      'biweekly': 'Se resetea cada 15 días',
      'monthly': 'Se resetea cada mes',
    };
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Ciclo de pago'),
        children: cycles.map((c) {
          final isSelected = c == current;
          return SimpleDialogOption(
            onPressed: () async {
              Navigator.pop(ctx);
              if (c == current) return;
              try {
                final dio = ref.read(dioProvider);
                await dio.patch(ApiConstants.me, data: {'payCycle': c});
                ref.invalidate(authStateProvider);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cycleLabels[c] ?? c,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Theme.of(context).colorScheme.primary : null,
                        ),
                      ),
                      Text(
                        cycleDescriptions[c] ?? '',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showPayDayPicker(BuildContext context, WidgetRef ref, int currentDay1, int currentDay2) {
    // Common LATAM quincena configurations: [payDay1, payDay2]
    const options = [
      [15, 30],
      [14, 28],
      [10, 25],
      [5, 20],
    ];
    final optionLabels = options.map((o) => 'Día ${o[0]} y día ${o[1]}').toList();

    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Días de corte'),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Text(
              'Define en qué días del mes termina cada quincena.',
              style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 8),
          ...options.asMap().entries.map((e) {
            final d1 = e.value[0];
            final d2 = e.value[1];
            final isSelected = d1 == currentDay1 && d2 == currentDay2;
            return SimpleDialogOption(
              onPressed: () async {
                Navigator.pop(ctx);
                if (isSelected) return;
                try {
                  final dio = ref.read(dioProvider);
                  await dio.patch(ApiConstants.me, data: {'payDay1': d1, 'payDay2': d2});
                  ref.invalidate(authStateProvider);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                      color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          optionLabels[e.key],
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Theme.of(context).colorScheme.primary : null,
                          ),
                        ),
                        Text(
                          'Períodos: 1–${d1}  y  ${d1 + 1}–$d2',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context, WidgetRef ref) {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cambiar contraseña'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Contraseña actual'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Nueva contraseña'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirmar contraseña'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              if (newCtrl.text != confirmCtrl.text) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Las contraseñas no coinciden')));
                }
                return;
              }
              try {
                final dio = ref.read(dioProvider);
                await dio.patch(ApiConstants.me, data: {
                  'currentPassword': currentCtrl.text,
                  'newPassword': newCtrl.text,
                });
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Contraseña actualizada')));
                }
              } catch (e) {
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}

// ── Edit Profile Sheet ──────────────────────────────────────────────

class _EditProfileSheet extends ConsumerStatefulWidget {
  const _EditProfileSheet({
    required this.currentName,
    required this.currentCurrency,
    required this.onSaved,
  });
  final String currentName;
  final String currentCurrency;
  final VoidCallback onSaved;

  @override
  ConsumerState<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends ConsumerState<_EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late String _currency;
  bool _saving = false;

  static const _currencies = ['HNL', 'USD', 'GTQ', 'MXN', 'CRC', 'NIO'];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.currentName);
    _currency = _currencies.contains(widget.currentCurrency) ? widget.currentCurrency : 'HNL';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final dio = ref.read(dioProvider);
      await dio.patch(ApiConstants.me, data: {
        'fullName': _nameCtrl.text.trim(),
        'currency': _currency,
      });
      widget.onSaved();
      if (mounted) Navigator.pop(context);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Perfil actualizado')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottom + 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Editar perfil', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre completo',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _currency,
              decoration: const InputDecoration(labelText: 'Moneda'),
              items: _currencies
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _currency = v!),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Guardar cambios'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section Header ──────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

}
