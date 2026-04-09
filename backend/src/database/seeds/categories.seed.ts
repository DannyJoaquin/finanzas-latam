import { DataSource } from 'typeorm';
import { Category, CategoryType } from '../../modules/categories/category.entity';

interface CategorySeed {
  name: string;
  icon: string;
  color: string;
  type: CategoryType;
  sortOrder: number;
  children?: { name: string; icon: string; color: string }[];
}

const SYSTEM_CATEGORIES: CategorySeed[] = [
  // ── EXPENSES ──────────────────────────────────────────────────────────────
  {
    name: 'Comida',
    icon: 'restaurant',
    color: '#FF6B35',
    type: CategoryType.EXPENSE,
    sortOrder: 1,
    children: [
      { name: 'Delivery', icon: 'delivery_dining', color: '#FF6B35' },
      { name: 'Supermercado', icon: 'shopping_cart', color: '#FF8A50' },
      { name: 'Restaurante', icon: 'local_restaurant', color: '#FFA07A' },
      { name: 'Cafetería', icon: 'local_cafe', color: '#FFB347' },
    ],
  },
  {
    name: 'Transporte',
    icon: 'directions_car',
    color: '#4A90D9',
    type: CategoryType.EXPENSE,
    sortOrder: 2,
    children: [
      { name: 'Taxi / Uber', icon: 'local_taxi', color: '#4A90D9' },
      { name: 'Bus / Colectivo', icon: 'directions_bus', color: '#5BA8F5' },
      { name: 'Combustible', icon: 'local_gas_station', color: '#3A7BC8' },
      { name: 'Parqueo', icon: 'local_parking', color: '#6BA3CC' },
    ],
  },
  {
    name: 'Vivienda',
    icon: 'home',
    color: '#6B4E9B',
    type: CategoryType.EXPENSE,
    sortOrder: 3,
    children: [
      { name: 'Alquiler', icon: 'house', color: '#6B4E9B' },
      { name: 'Servicios', icon: 'electrical_services', color: '#8B6BB5' },
      { name: 'Agua', icon: 'water_drop', color: '#7A5EAA' },
      { name: 'Internet / Cable', icon: 'wifi', color: '#9B7EC8' },
    ],
  },
  {
    name: 'Salud',
    icon: 'local_hospital',
    color: '#E74C3C',
    type: CategoryType.EXPENSE,
    sortOrder: 4,
    children: [
      { name: 'Medicamentos', icon: 'medication', color: '#E74C3C' },
      { name: 'Consulta médica', icon: 'stethoscope', color: '#FF6B6B' },
      { name: 'Seguro médico', icon: 'health_and_safety', color: '#C0392B' },
    ],
  },
  {
    name: 'Educación',
    icon: 'school',
    color: '#27AE60',
    type: CategoryType.EXPENSE,
    sortOrder: 5,
    children: [
      { name: 'Colegiaturas', icon: 'class', color: '#27AE60' },
      { name: 'Útiles', icon: 'edit', color: '#2ECC71' },
      { name: 'Cursos', icon: 'laptop', color: '#1E8449' },
    ],
  },
  {
    name: 'Entretenimiento',
    icon: 'sports_esports',
    color: '#F39C12',
    type: CategoryType.EXPENSE,
    sortOrder: 6,
    children: [
      { name: 'Streaming', icon: 'live_tv', color: '#F39C12' },
      { name: 'Salidas', icon: 'night_life', color: '#F5A623' },
      { name: 'Juegos', icon: 'sports_esports', color: '#E67E22' },
    ],
  },
  {
    name: 'Ropa',
    icon: 'checkroom',
    color: '#E91E63',
    type: CategoryType.EXPENSE,
    sortOrder: 7,
  },
  {
    name: 'Cuidado personal',
    icon: 'spa',
    color: '#9C27B0',
    type: CategoryType.EXPENSE,
    sortOrder: 8,
  },
  {
    name: 'Deudas',
    icon: 'credit_card',
    color: '#F44336',
    type: CategoryType.EXPENSE,
    sortOrder: 9,
    children: [
      { name: 'Tarjeta de crédito', icon: 'credit_card', color: '#F44336' },
      { name: 'Préstamo personal', icon: 'account_balance', color: '#EF5350' },
    ],
  },
  {
    name: 'Ahorros',
    icon: 'savings',
    color: '#00BCD4',
    type: CategoryType.EXPENSE,
    sortOrder: 10,
  },
  {
    name: 'Mascotas',
    icon: 'pets',
    color: '#795548',
    type: CategoryType.EXPENSE,
    sortOrder: 11,
  },
  {
    name: 'Otros gastos',
    icon: 'more_horiz',
    color: '#9E9E9E',
    type: CategoryType.EXPENSE,
    sortOrder: 99,
  },
  // ── INCOMES ───────────────────────────────────────────────────────────────
  {
    name: 'Salario',
    icon: 'work',
    color: '#4CAF50',
    type: CategoryType.INCOME,
    sortOrder: 1,
  },
  {
    name: 'Freelance',
    icon: 'laptop_mac',
    color: '#8BC34A',
    type: CategoryType.INCOME,
    sortOrder: 2,
  },
  {
    name: 'Remesa',
    icon: 'send',
    color: '#00BCD4',
    type: CategoryType.INCOME,
    sortOrder: 3,
  },
  {
    name: 'Negocio propio',
    icon: 'store',
    color: '#FF9800',
    type: CategoryType.INCOME,
    sortOrder: 4,
  },
  {
    name: 'Otros ingresos',
    icon: 'attach_money',
    color: '#9E9E9E',
    type: CategoryType.INCOME,
    sortOrder: 99,
  },
];

export async function seedCategories(dataSource: DataSource): Promise<void> {
  const categoryRepo = dataSource.getRepository(Category);

  const existingCount = await categoryRepo.count({ where: { isSystem: true } });
  if (existingCount > 0) {
    console.log('Categories already seeded, skipping.');
    return;
  }

  for (const seed of SYSTEM_CATEGORIES) {
    const parent = categoryRepo.create({
      name: seed.name,
      icon: seed.icon,
      color: seed.color,
      type: seed.type,
      isSystem: true,
      sortOrder: seed.sortOrder,
      userId: undefined,
    });
    const savedParent = await categoryRepo.save(parent);

    if (seed.children) {
      for (const child of seed.children) {
        const childEntity = categoryRepo.create({
          name: child.name,
          icon: child.icon,
          color: child.color,
          type: seed.type,
          isSystem: true,
          sortOrder: 0,
          parentId: savedParent.id,
          userId: undefined,
        });
        await categoryRepo.save(childEntity);
      }
    }
  }

  console.log('System categories seeded successfully.');
}
