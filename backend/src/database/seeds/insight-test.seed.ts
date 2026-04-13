/**
 * Insight Stress Test Seed
 * ─────────────────────────
 * Crea datos diseñados específicamente para disparar TODOS los tipos de insight:
 *   • ANOMALY           → gasto de delivery 5x mayor que promedio esta semana
 *   • BUDGET_WARNING    → presupuesto "Comida" al 75% en el día 3 del mes
 *   • PROJECTION        → riskLevel red: gasto diario > safeDailySpend
 *   • PATTERN           → viernes siempre es el día más caro
 *   • SAVINGS_OPPORTUNITY → delivery >20% del gasto total 3 semanas
 *   • STREAK            → 7 días consecutivos registrando gastos
 *   • ACHIEVEMENT       → primer registro / milestone
 *
 * Ejecutar:
 *   npx ts-node -r tsconfig-paths/register src/database/seeds/run-insight-test.ts
 */
import { DataSource } from 'typeorm';
import { AppDataSource } from '../../../data-source';
import { Category } from '../../modules/categories/category.entity';
import { Expense, PaymentMethod, ExpenseSource } from '../../modules/expenses/expense.entity';
import { Budget, BudgetPeriod } from '../../modules/budgets/budget.entity';
import { Insight, InsightType, InsightPriority } from '../../modules/insights/insight.entity';

// Use SEED_USER_ID env var to target a specific user, or fall back to demo user
const USER_ID = process.env.SEED_USER_ID ?? '5348f237-5040-49de-9381-dbbffa835586';

function daysAgo(n: number): string {
  const d = new Date();
  d.setDate(d.getDate() - n);
  return d.toISOString().split('T')[0];
}

function today(): string {
  return new Date().toISOString().split('T')[0];
}

function firstOfMonth(): string {
  const d = new Date();
  d.setDate(1);
  return d.toISOString().split('T')[0];
}

function lastOfMonth(): string {
  const d = new Date();
  d.setMonth(d.getMonth() + 1, 0);
  return d.toISOString().split('T')[0];
}

async function run() {
  await AppDataSource.initialize();
  console.log('\n🔧 Insight Stress Test Seed\n');

  const catRepo = AppDataSource.getRepository(Category);
  const expRepo = AppDataSource.getRepository(Expense);
  const budgetRepo = AppDataSource.getRepository(Budget);
  const insightRepo = AppDataSource.getRepository(Insight);

  const allCats = await catRepo.find({ where: { isSystem: true } });
  const cat = (name: string) => allCats.find(c => c.name === name);

  const catDelivery    = cat('Delivery');
  const catSuper       = cat('Supermercado');
  const catRest        = cat('Restaurante');
  const catCombust     = cat('Combustible');
  const catTaxi        = cat('Taxi / Uber');
  const catStreaming    = cat('Streaming');
  const catSalidas     = cat('Salidas');
  const catAlquiler    = cat('Alquiler');
  const catServicios   = cat('Servicios');

  if (!catDelivery || !catSuper || !catRest) {
    console.error('❌ Categories not found — run categories seed first');
    process.exit(1);
  }

  // ─── 1. STREAK: 7 días consecutivos con gastos (hoy incluido) ────────────
  console.log('[ 1 ] Creating streak data (7 consecutive days with expenses)...');
  for (let i = 6; i >= 0; i--) {
    await expRepo.save(expRepo.create({
      userId: USER_ID,
      categoryId: catSuper!.id,
      amount: 150 + Math.floor(Math.random() * 200),
      currency: 'HNL',
      description: `Compra pequeña día -${i}`,
      date: daysAgo(i) as unknown as Date,
      paymentMethod: PaymentMethod.CASH,
      source: ExpenseSource.MANUAL,
    }));
  }
  console.log('  ✓ 7 daily expenses created → should trigger STREAK insight');

  // ─── 2. ANOMALY: delivery esta semana 5x el promedio histórico ───────────
  console.log('\n[ 2 ] Creating anomaly data (delivery spike this week)...');
  // Historial "normal" de 4 semanas previas (aprox 200 HNL/semana delivery)
  for (let week = 4; week >= 1; week--) {
    await expRepo.save(expRepo.create({
      userId: USER_ID,
      categoryId: catDelivery!.id,
      amount: 180 + Math.floor(Math.random() * 60),
      currency: 'HNL',
      description: `Delivery semana -${week}`,
      date: daysAgo(week * 7 + 2) as unknown as Date,
      paymentMethod: PaymentMethod.CASH,
      source: ExpenseSource.MANUAL,
    }));
  }
  // Spike esta semana: 5 pedidos grandes (~1100 HNL total vs 200 promedio)
  const deliveryDates = [0, 1, 2, 3, 4];
  for (const dago of deliveryDates) {
    await expRepo.save(expRepo.create({
      userId: USER_ID,
      categoryId: catDelivery!.id,
      amount: 180 + Math.floor(Math.random() * 80),
      currency: 'HNL',
      description: `Delivery spike día -${dago}`,
      date: daysAgo(dago) as unknown as Date,
      paymentMethod: PaymentMethod.CASH,
      source: ExpenseSource.MANUAL,
    }));
  }
  console.log('  ✓ Delivery history + spike created → should trigger ANOMALY insight');

  // ─── 3. PATTERN: viernes es siempre el día más caro (últimas 4 semanas) ──
  console.log('\n[ 3 ] Creating pattern data (Fridays are most expensive)...');
  // Encontrar el viernes de las últimas 4 semanas
  const fridays: number[] = [];
  for (let i = 1; i <= 28; i++) {
    const d = new Date();
    d.setDate(d.getDate() - i);
    if (d.getDay() === 5) fridays.push(i); // 5 = viernes
    if (fridays.length === 4) break;
  }
  for (const dago of fridays) {
    await expRepo.save(expRepo.create({
      userId: USER_ID,
      categoryId: catSalidas?.id ?? catRest!.id,
      amount: 900 + Math.floor(Math.random() * 400),
      currency: 'HNL',
      description: `Salida viernes`,
      date: daysAgo(dago) as unknown as Date,
      paymentMethod: PaymentMethod.CASH,
      source: ExpenseSource.MANUAL,
    }));
    // También gastos moderate el resto de la semana para el contraste
    await expRepo.save(expRepo.create({
      userId: USER_ID,
      categoryId: catRest!.id,
      amount: 200 + Math.floor(Math.random() * 100),
      currency: 'HNL',
      description: `Almuerzo entre semana`,
      date: daysAgo(dago - 2) as unknown as Date,
      paymentMethod: PaymentMethod.CASH,
      source: ExpenseSource.MANUAL,
    }));
  }
  console.log('  ✓ Friday spending pattern created → should trigger PATTERN insight');

  // ─── 4. SAVINGS OPPORTUNITY: delivery >20% del gasto total ──────────────
  console.log('\n[ 4 ] Savings opportunity already covered by delivery spike above.');
  console.log('  ✓ Delivery is now a large % of weekly spend → SAVINGS_OPPORTUNITY likely');

  // ─── 5. BUDGET_WARNING: presupuesto al 65% a mitad de período ───────────
  console.log('\n[ 5 ] Creating budget + overspend to trigger BUDGET_WARNING...');
  // Crear presupuesto de comida para este mes con amount ajustado para que el
  // gasto actual lo supere por velocidad
  const existingBudget = await budgetRepo.findOne({
    where: { userId: USER_ID, name: 'Test Comida Budget' },
  });
  if (!existingBudget) {
    await budgetRepo.save(budgetRepo.create({
      userId: USER_ID,
      categoryId: catSuper!.id,
      name: 'Test Comida Budget',
      // High enough that pctSpent < 80% (so insight-generator handles it, not the alerts job)
      // but low enough that velocity > 1.3 (spending faster than budget allows)
      // Target: ~60% spent in first ~13 days → velocity ~1.4
      amount: 6000,
      periodType: BudgetPeriod.MONTHLY,
      periodStart: firstOfMonth() as unknown as Date,
      periodEnd: lastOfMonth() as unknown as Date,
      alert50Sent: false,
      alert80Sent: false,
    }));
    console.log('  ✓ Budget L3000 "Test Comida Budget" created');
  } else {
    console.log('  – Budget already exists, skipping');
  }
  // Agregar gastos de supermercado en los primeros 3 días para crear velocidad alta
  for (let i = 2; i >= 0; i--) {
    await expRepo.save(expRepo.create({
      userId: USER_ID,
      categoryId: catSuper!.id,
      amount: 650,
      currency: 'HNL',
      description: `Supermercado alta velocidad día ${3 - i}`,
      date: daysAgo(i) as unknown as Date,
      paymentMethod: PaymentMethod.CASH,
      source: ExpenseSource.MANUAL,
    }));
  }
  console.log('  ✓ L1950 spent in 3 days on L6000 budget → velocity ~1.4x → BUDGET_WARNING');

  // ─── 6. PROJECTION (riskLevel red): poco cash + alto gasto diario ────────
  console.log('\n[ 6 ] Cash + income context already drives projection — will be evaluated by generator.');
  console.log('  NOTE: PROJECTION depends on cash accounts & income vs expenses ratio.');
  console.log('        Run POST /insights/regenerate after seeding to generate all insights.');

  // ─── 7. Clear stale insight cooldowns so generator picks up fresh data ──
  console.log('\n[ 7 ] Clearing stale insight cooldowns (marking old insights as dismissed)...');
  const result = await insightRepo
    .createQueryBuilder()
    .update()
    .set({ isDismissed: true })
    .where('user_id = :userId', { userId: USER_ID })
    .andWhere('is_dismissed = false')
    .execute();
  console.log(`  ✓ Dismissed ${result.affected} existing active insights (cleared cooldowns)`);

  await AppDataSource.destroy();

  console.log('\n✅ Done! Now call POST /insights/regenerate with your user token to generate insights.\n');
  console.log('Expected insights after regenerate:');
  console.log('  📊 ANOMALY         — Delivery spike 5x promedio semanal');
  console.log('  ⚠️  BUDGET_WARNING  — "Test Comida Budget" va rápido (velocidad alta)');
  console.log('  💡 SAVINGS_OPP     — Delivery representando % alto del gasto');
  console.log('  📅 PATTERN         — Viernes es tu día más caro');
  console.log('  🔥 STREAK          — 7 días consecutivos registrando gastos');
  console.log('  🏆 ACHIEVEMENT     — Hitos de tu historial\n');
}

run().catch(err => {
  console.error('Seed failed:', err);
  process.exit(1);
});
