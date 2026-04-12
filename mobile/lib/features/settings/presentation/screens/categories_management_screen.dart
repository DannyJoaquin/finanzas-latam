import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../../../expenses/providers/expenses_provider.dart';

class SettingsCategoryItem {
  const SettingsCategoryItem({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
    required this.isSystem,
    this.parentName,
  });

  final String id;
  final String name;
  final String type;
  final String icon;
  final String color;
  final bool isSystem;
  final String? parentName;

  factory SettingsCategoryItem.fromJson(Map<String, dynamic> j, {String? parentName}) {
    return SettingsCategoryItem(
      id: j['id'] as String,
      name: j['name'] as String? ?? '',
      type: j['type'] as String? ?? 'expense',
      icon: j['icon'] as String? ?? 'category',
      color: j['color'] as String? ?? '#9E9E9E',
      isSystem: j['isSystem'] as bool? ?? false,
      parentName: parentName,
    );
  }

  Color get colorValue {
    final hex = color.replaceAll('#', '').trim();
    if (hex.length != 6) return Colors.grey;
    return Color(int.parse('FF$hex', radix: 16));
  }
}

final settingsCategoriesProvider = FutureProvider.autoDispose<List<SettingsCategoryItem>>((ref) async {
  final dio = ref.watch(dioProvider);
  final resp = await dio.get(ApiConstants.categories);
  final raw = resp.data as List<dynamic>? ?? [];

  final result = <SettingsCategoryItem>[];
  for (final item in raw) {
    final parent = item as Map<String, dynamic>;
    final parentName = parent['name'] as String?;
    final children = parent['children'] as List<dynamic>? ?? [];

    if (children.isEmpty) {
      result.add(SettingsCategoryItem.fromJson(parent));
      continue;
    }

    for (final child in children) {
      result.add(
        SettingsCategoryItem.fromJson(
          child as Map<String, dynamic>,
          parentName: parentName,
        ),
      );
    }
  }

  result.sort((a, b) {
    if (a.isSystem != b.isSystem) return a.isSystem ? 1 : -1;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });

  return result;
});

class CategoriesManagementScreen extends ConsumerStatefulWidget {
  const CategoriesManagementScreen({super.key});

  @override
  ConsumerState<CategoriesManagementScreen> createState() => _CategoriesManagementScreenState();
}

class _CategoriesManagementScreenState extends ConsumerState<CategoriesManagementScreen> {
  String _typeFilter = 'expense';

  Future<void> _openUpsertSheet({SettingsCategoryItem? current}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _UpsertCategorySheet(
        current: current,
        defaultType: current?.type ?? _typeFilter,
      ),
    );
    if (!mounted) return;
    ref.invalidate(settingsCategoriesProvider);
    ref.invalidate(categoriesProvider);
  }

  Future<void> _deleteCategory(SettingsCategoryItem category) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar categoría'),
        content: Text('¿Deseas eliminar "${category.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      final dio = ref.read(dioProvider);
      await dio.delete('${ApiConstants.categories}/${category.id}');
      ref.invalidate(settingsCategoriesProvider);
      ref.invalidate(categoriesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Categoría eliminada')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final catsAsync = ref.watch(settingsCategoriesProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categorías'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Nueva categoría',
            onPressed: () => _openUpsertSheet(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openUpsertSheet(),
        icon: const Icon(Icons.add),
        label: const Text('Agregar'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'expense', label: Text('Gastos')),
                ButtonSegment(value: 'income', label: Text('Ingresos')),
              ],
              selected: {_typeFilter},
              onSelectionChanged: (v) => setState(() => _typeFilter = v.first),
            ),
          ),
          Expanded(
            child: catsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (cats) {
                final filtered = cats.where((c) => c.type == _typeFilter).toList();
                final custom = filtered.where((c) => !c.isSystem).toList();
                final system = filtered.where((c) => c.isSystem).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('Sin categorías para este tipo'));
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                  children: [
                    if (custom.isNotEmpty) ...[
                      Text('Personalizadas', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      ...custom.map((c) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Container(
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: Theme.of(context).shadowColor.withAlpha(14),
                                    blurRadius: 18,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: c.colorValue.withAlpha(40),
                                  child: Icon(materialIconFromString(c.icon), color: c.colorValue),
                                ),
                                title: Text(c.name),
                                subtitle: Text(c.parentName == null ? 'Sin grupo padre' : 'Grupo: ${c.parentName}'),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      _openUpsertSheet(current: c);
                                      return;
                                    }
                                    _deleteCategory(c);
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(value: 'edit', child: Text('Editar')),
                                    PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                                  ],
                                ),
                              ),
                            ),
                          )),
                      const SizedBox(height: 12),
                    ],
                    if (system.isNotEmpty) ...[
                      Text('Del sistema', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      ...system.map((c) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Container(
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: c.colorValue.withAlpha(30),
                                  child: Icon(materialIconFromString(c.icon), color: c.colorValue),
                                ),
                                title: Text(c.name),
                                subtitle: Text(c.parentName == null ? 'Sistema' : 'Grupo: ${c.parentName}'),
                                trailing: Icon(Icons.lock_outline, color: colorScheme.onSurfaceVariant),
                              ),
                            ),
                          )),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _UpsertCategorySheet extends ConsumerStatefulWidget {
  const _UpsertCategorySheet({required this.defaultType, this.current});

  final String defaultType;
  final SettingsCategoryItem? current;

  @override
  ConsumerState<_UpsertCategorySheet> createState() => _UpsertCategorySheetState();
}

class _UpsertCategorySheetState extends ConsumerState<_UpsertCategorySheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _iconCtrl;
  late final TextEditingController _colorCtrl;
  late String _type;
  bool _saving = false;

  static const _iconOptions = [
    'category',
    'shopping_cart',
    'local_restaurant',
    'home',
    'local_taxi',
    'sports_esports',
    'work',
    'savings',
    'payments',
    'attach_money',
  ];

  @override
  void initState() {
    super.initState();
    _type = widget.current?.type ?? widget.defaultType;
    _nameCtrl = TextEditingController(text: widget.current?.name ?? '');
    _iconCtrl = TextEditingController(text: widget.current?.icon ?? 'category');
    _colorCtrl = TextEditingController(
      text: widget.current?.color ?? (_type == 'expense' ? '#E57373' : '#66BB6A'),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _iconCtrl.dispose();
    _colorCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final dio = ref.read(dioProvider);
      final payload = {
        'name': _nameCtrl.text.trim(),
        'icon': _iconCtrl.text.trim(),
        'color': _colorCtrl.text.trim(),
      };

      if (widget.current == null) {
        await dio.post(ApiConstants.categories, data: {
          ...payload,
          'type': _type,
        });
      } else {
        await dio.patch('${ApiConstants.categories}/${widget.current!.id}', data: payload);
      }

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.current == null ? 'Categoría creada' : 'Categoría actualizada')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.current == null ? 'Nueva categoría' : 'Editar categoría',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              if (widget.current == null) ...[
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: const [
                    DropdownMenuItem(value: 'expense', child: Text('Gasto')),
                    DropdownMenuItem(value: 'income', child: Text('Ingreso')),
                  ],
                  onChanged: (v) => setState(() => _type = v ?? 'expense'),
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Nombre'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Ingresa un nombre';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _iconCtrl,
                decoration: const InputDecoration(labelText: 'Ícono (nombre Material)'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Ingresa un ícono';
                  return null;
                },
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _iconOptions.map((icon) {
                  return ChoiceChip(
                    label: Text(icon),
                    selected: _iconCtrl.text.trim() == icon,
                    onSelected: (_) => setState(() => _iconCtrl.text = icon),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _colorCtrl,
                decoration: const InputDecoration(labelText: 'Color (#RRGGBB)'),
                validator: (v) {
                  final value = v?.trim() ?? '';
                  final ok = RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value);
                  if (!ok) return 'Usa formato #RRGGBB';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(widget.current == null ? 'Crear' : 'Guardar cambios'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
