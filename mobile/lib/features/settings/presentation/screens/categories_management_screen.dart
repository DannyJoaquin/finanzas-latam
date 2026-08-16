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

  factory SettingsCategoryItem.fromJson(Map<String, dynamic> j,
      {String? parentName}) {
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

final settingsCategoriesProvider =
    FutureProvider.autoDispose<List<SettingsCategoryItem>>((ref) async {
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
  ConsumerState<CategoriesManagementScreen> createState() =>
      _CategoriesManagementScreenState();
}

class _CategoriesManagementScreenState
    extends ConsumerState<CategoriesManagementScreen> {
  String _typeFilter = 'expense';

  Future<void> _openUpsertSheet({SettingsCategoryItem? current}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
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
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
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
                final filtered =
                    cats.where((c) => c.type == _typeFilter).toList();
                final custom = filtered.where((c) => !c.isSystem).toList();
                final system = filtered.where((c) => c.isSystem).toList();

                if (filtered.isEmpty) {
                  return const Center(
                      child: Text('Sin categorías para este tipo'));
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                  children: [
                    if (custom.isNotEmpty) ...[
                      Text('Personalizadas',
                          style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      ...custom.map((c) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Container(
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: Theme.of(context)
                                        .shadowColor
                                        .withAlpha(14),
                                    blurRadius: 18,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: c.colorValue.withAlpha(40),
                                  child: Icon(materialIconFromString(c.icon),
                                      color: c.colorValue),
                                ),
                                title: Text(c.name),
                                subtitle: Text(c.parentName == null
                                    ? 'Sin grupo padre'
                                    : 'Grupo: ${c.parentName}'),
                                trailing: PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      _openUpsertSheet(current: c);
                                      return;
                                    }
                                    _deleteCategory(c);
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                        value: 'edit', child: Text('Editar')),
                                    PopupMenuItem(
                                        value: 'delete',
                                        child: Text('Eliminar')),
                                  ],
                                ),
                              ),
                            ),
                          )),
                      const SizedBox(height: 12),
                    ],
                    if (system.isNotEmpty) ...[
                      Text('Del sistema',
                          style: Theme.of(context).textTheme.titleSmall),
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
                                  child: Icon(materialIconFromString(c.icon),
                                      color: c.colorValue),
                                ),
                                title: Text(c.name),
                                subtitle: Text(c.parentName == null
                                    ? 'Sistema'
                                    : 'Grupo: ${c.parentName}'),
                                trailing: Icon(Icons.lock_outline,
                                    color: colorScheme.onSurfaceVariant),
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
  ConsumerState<_UpsertCategorySheet> createState() =>
      _UpsertCategorySheetState();
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
    'restaurant',
    'local_cafe',
    'delivery_dining',
    'home',
    'house',
    'local_taxi',
    'directions_car',
    'local_gas_station',
    'directions_bus',
    'flight',
    'sports_esports',
    'movie',
    'music_note',
    'smartphone',
    'laptop',
    'hotel',
    'work',
    'business',
    'school',
    'medical_services',
    'local_hospital',
    'local_pharmacy',
    'fitness_center',
    'pets',
    'child_care',
    'savings',
    'account_balance',
    'receipt',
    'wifi',
    'phone',
    'water_drop',
    'bolt',
    'shopping_bag',
    'checkroom',
    'celebration',
    'card_giftcard',
    'volunteer_activism',
  ];

  static const _iconLabels = {
    'category': 'General',
    'shopping_cart': 'Supermercado',
    'local_restaurant': 'Restaurante',
    'restaurant': 'Comida',
    'local_cafe': 'Café',
    'delivery_dining': 'Delivery',
    'home': 'Hogar',
    'house': 'Casa',
    'local_taxi': 'Taxi',
    'directions_car': 'Auto',
    'local_gas_station': 'Combustible',
    'directions_bus': 'Transporte',
    'flight': 'Viajes',
    'sports_esports': 'Videojuegos',
    'movie': 'Cine',
    'music_note': 'Música',
    'smartphone': 'Teléfono',
    'laptop': 'Tecnología',
    'hotel': 'Hotel',
    'work': 'Trabajo',
    'business': 'Negocio',
    'school': 'Educación',
    'medical_services': 'Salud',
    'local_hospital': 'Hospital',
    'local_pharmacy': 'Farmacia',
    'fitness_center': 'Ejercicio',
    'pets': 'Mascotas',
    'child_care': 'Cuidado infantil',
    'savings': 'Ahorro',
    'account_balance': 'Banco',
    'receipt': 'Recibos',
    'wifi': 'Internet',
    'phone': 'Telefonía',
    'water_drop': 'Agua',
    'bolt': 'Electricidad',
    'shopping_bag': 'Compras',
    'checkroom': 'Ropa',
    'celebration': 'Celebración',
    'card_giftcard': 'Regalos',
    'volunteer_activism': 'Donaciones',
  };

  static const _colorOptions = [
    '#E57373',
    '#EF9A9A',
    '#FFB74D',
    '#81C784',
    '#66BB6A',
    '#4DB6AC',
    '#64B5F6',
    '#7986CB',
    '#BA68C8',
    '#A1887F',
  ];

  @override
  void initState() {
    super.initState();
    _type = widget.current?.type ?? widget.defaultType;
    _nameCtrl = TextEditingController(text: widget.current?.name ?? '');
    _iconCtrl = TextEditingController(text: widget.current?.icon ?? 'category');
    _colorCtrl = TextEditingController(
      text:
          widget.current?.color ?? (_type == 'expense' ? '#E57373' : '#66BB6A'),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _iconCtrl.dispose();
    _colorCtrl.dispose();
    super.dispose();
  }

  String _defaultColor(String type) =>
      type == 'expense' ? '#E57373' : '#66BB6A';

  Color _parseColor(String value) {
    final hex = value.replaceAll('#', '').trim();
    final parsed = hex.length == 6 ? int.tryParse('FF$hex', radix: 16) : null;
    return parsed == null ? const Color(0xFF9E9E9E) : Color(parsed);
  }

  void _selectType(String value) {
    setState(() {
      if (_colorCtrl.text.trim().toUpperCase() == _defaultColor(_type)) {
        _colorCtrl.text = _defaultColor(value);
      }
      _type = value;
    });
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
        await dio.patch('${ApiConstants.categories}/${widget.current!.id}',
            data: payload);
      }

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(widget.current == null
                ? 'Categoría creada'
                : 'Categoría actualizada')),
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
    final theme = Theme.of(context);
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final previewColor = _parseColor(_colorCtrl.text);
    final previewIcon =
        _iconCtrl.text.trim().isEmpty ? 'category' : _iconCtrl.text.trim();
    final isEditing = widget.current != null;

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .92,
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + bottom),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: previewColor.withAlpha(30),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        materialIconFromString(previewIcon),
                        color: previewColor,
                        size: 25,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing ? 'Editar categoría' : 'Nueva categoría',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            isEditing
                                ? 'Actualiza cómo se verá en tus movimientos'
                                : 'Personaliza cómo aparecerá en tus movimientos',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const _CategorySectionHeading(
                  icon: Icons.tune_outlined,
                  title: 'Información básica',
                  subtitle: 'Define el tipo y el nombre',
                ),
                const SizedBox(height: 12),
                if (!isEditing) ...[
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'expense',
                        icon: Icon(Icons.trending_down_outlined),
                        label: Text('Gasto'),
                      ),
                      ButtonSegment(
                        value: 'income',
                        icon: Icon(Icons.trending_up_outlined),
                        label: Text('Ingreso'),
                      ),
                    ],
                    selected: {_type},
                    onSelectionChanged: (values) => _selectType(values.first),
                    style: SegmentedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else
                  InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Tipo',
                      prefixIcon: Icon(
                        _type == 'expense'
                            ? Icons.trending_down_outlined
                            : Icons.trending_up_outlined,
                      ),
                    ),
                    child: Text(_type == 'expense' ? 'Gasto' : 'Ingreso'),
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Nombre',
                    hintText: 'Ej. Extrafinanciamiento',
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Ingresa un nombre';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                const _CategorySectionHeading(
                  icon: Icons.auto_awesome_outlined,
                  title: 'Icono',
                  subtitle: 'Elige una imagen para reconocerla rápido',
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: previewColor.withAlpha(18),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: previewColor.withAlpha(45)),
                  ),
                  child: Row(
                    children: [
                      Icon(materialIconFromString(previewIcon),
                          color: previewColor, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Vista previa de la categoría',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _iconOptions.map((icon) {
                    final selected = _iconCtrl.text.trim() == icon;
                    return Tooltip(
                      message: _iconLabels[icon] ?? 'Icono',
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: selected
                              ? previewColor.withAlpha(28)
                              : theme.colorScheme.surfaceContainerLow,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected
                                ? previewColor
                                : theme.colorScheme.outlineVariant,
                            width: selected ? 2 : 1,
                          ),
                        ),
                        child: IconButton(
                          tooltip: _iconLabels[icon] ?? 'Icono',
                          onPressed: () =>
                              setState(() => _iconCtrl.text = icon),
                          icon: Icon(
                            materialIconFromString(icon),
                            color: selected
                                ? previewColor
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                const _CategorySectionHeading(
                  icon: Icons.palette_outlined,
                  title: 'Color',
                  subtitle: 'Usa un tono para distinguirla',
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: previewColor,
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _colorCtrl,
                        onChanged: (_) => setState(() {}),
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Código de color',
                          hintText: '#E57373',
                          prefixIcon: Icon(Icons.tag_outlined),
                        ),
                        validator: (v) {
                          final value = v?.trim() ?? '';
                          final ok =
                              RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value);
                          if (!ok) return 'Usa formato #RRGGBB';
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _colorOptions.map((hex) {
                    final color = _parseColor(hex);
                    final selected =
                        _colorCtrl.text.trim().toUpperCase() == hex;
                    final foreground = color.computeLuminance() > .55
                        ? Colors.black87
                        : Colors.white;
                    return Semantics(
                      button: true,
                      selected: selected,
                      label: 'Color $hex',
                      child: InkWell(
                        onTap: () => setState(() => _colorCtrl.text = hex),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selected
                                  ? theme.colorScheme.onSurface
                                  : theme.colorScheme.outlineVariant,
                              width: selected ? 3 : 1,
                            ),
                          ),
                          child: selected
                              ? Icon(Icons.check, color: foreground, size: 20)
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(isEditing ? Icons.save_outlined : Icons.add),
                  label:
                      Text(isEditing ? 'Guardar cambios' : 'Crear categoría'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategorySectionHeading extends StatelessWidget {
  const _CategorySectionHeading({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(11),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: theme.colorScheme.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
