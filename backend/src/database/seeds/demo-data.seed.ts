/**
 * Demo Data Seed
 * Genera 4 meses de datos (Enero–Abril 2026) para el usuario existente.
 * Incluye: gastos variados, pagos de TC, presupuestos, metas, contribuciones.
 */
import { DataSource } from 'typeorm';
import { Category } from '../../modules/categories/category.entity';
import { Expense, PaymentMethod, ExpenseSource } from '../../modules/expenses/expense.entity';
import { Budget, BudgetPeriod } from '../../modules/budgets/budget.entity';
import { Goal, GoalStatus } from '../../modules/goals/goal.entity';
import { GoalContribution, ContributionSource } from '../../modules/goals/goal-contribution.entity';
import { CreditCard, CardNetwork } from '../../modules/credit-cards/credit-card.entity';
import { CreditCardPayment } from '../../modules/credit-cards/credit-card-payment.entity';
import { Insight, InsightType, InsightPriority } from '../../modules/insights/insight.entity';

const USER_ID = '5348f237-5040-49de-9381-dbbffa835586';

function d(year: number, month: number, day: number): string {
  return `${year}-${String(month).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
}

function rand(min: number, max: number, decimals = 2): number {
  const v = Math.random() * (max - min) + min;
  return parseFloat(v.toFixed(decimals));
}

export async function seedDemoData(ds: DataSource): Promise<void> {
  const catRepo = ds.getRepository(Category);
  const expRepo = ds.getRepository(Expense);
  const budgetRepo = ds.getRepository(Budget);
  const goalRepo = ds.getRepository(Goal);
  const contribRepo = ds.getRepository(GoalContribution);
  const cardRepo = ds.getRepository(CreditCard);
  const cardPaymentRepo = ds.getRepository(CreditCardPayment);
  const insightRepo = ds.getRepository(Insight);

  // ─── Fetch categories by name ──────────────────────────────────────────────
  const allCats = await catRepo.find({ where: { isSystem: true } });
  const cat = (name: string) => allCats.find(c => c.name === name);

  const catSuper = cat('Supermercado');
  const catRest = cat('Restaurante');
  const catDelivery = cat('Delivery');
  const catCafe = cat('Cafetería');
  const catTaxi = cat('Taxi / Uber');
  const catBus = cat('Bus / Colectivo');
  const catCombust = cat('Combustible');
  const catAlquiler = cat('Alquiler');
  const catServicios = cat('Servicios');
  const catInternet = cat('Internet / Cable');
  const catMedic = cat('Medicamentos');
  const catConsulta = cat('Consulta médica');
  const catStreaming = cat('Streaming');
  const catSalidas = cat('Salidas');
  const catRopa = cat('Ropa');
  const catEduCurso = cat('Cursos');
  const catCuidado = cat('Cuidado personal');
  const catMascotas = cat('Mascotas');
  const catAhorro = allCats.find(c => c.name === 'Ahorro' || c.name === 'Inversiones');

  // ─── Credit Cards ──────────────────────────────────────────────────────────
  console.log('  Creating credit cards...');

  // Check existing cards
  const existingCards = await cardRepo.find({ where: { userId: USER_ID } });
  let visaCard = existingCards.find(c => c.network === 'visa');
  let masterCard = existingCards.find(c => c.network === 'mastercard');

  if (!visaCard) {
    visaCard = await cardRepo.save(cardRepo.create({
      userId: USER_ID,
      name: 'Visa BAC',
      network: CardNetwork.VISA,
      cutOffDay: 15,
      paymentDueDays: 20,
      creditLimit: 50000,
      limitCurrency: 'HNL',
      color: '#1A1F71',
      isActive: true,
    }));
  }

  if (!masterCard) {
    masterCard = await cardRepo.save(cardRepo.create({
      userId: USER_ID,
      name: 'Mastercard Ficohsa',
      network: CardNetwork.MASTERCARD,
      cutOffDay: 25,
      paymentDueDays: 20,
      creditLimit: 30000,
      limitCurrency: 'HNL',
      color: '#EB001B',
      isActive: true,
    }));
  }

  // ─── Gastos por mes ────────────────────────────────────────────────────────
  console.log('  Creating expenses (4 months)...');

  type ExpenseDef = {
    amount: number; cat: Category | undefined; desc: string;
    date: string; method: PaymentMethod; cardId?: string;
  };

  const expenses: ExpenseDef[] = [
    // ── ENERO 2026 ────────────────────────────────────────────────────────
    // Vivienda (fijos)
    { amount: 8500, cat: catAlquiler, desc: 'Alquiler enero', date: d(2026,1,1), method: PaymentMethod.TRANSFER },
    { amount: 890, cat: catServicios, desc: 'Luz ENEE enero', date: d(2026,1,5), method: PaymentMethod.CASH },
    { amount: 320, cat: catInternet, desc: 'Tigo Internet enero', date: d(2026,1,7), method: PaymentMethod.CARD_DEBIT },
    // Comida
    { amount: 1850, cat: catSuper, desc: 'Super compra quincenal', date: d(2026,1,3), method: PaymentMethod.CARD_DEBIT },
    { amount: 1920, cat: catSuper, desc: 'Super compra quincenal', date: d(2026,1,18), method: PaymentMethod.CARD_DEBIT },
    { amount: 320, cat: catRest, desc: 'Almuerzo Pollo Rico', date: d(2026,1,8), method: PaymentMethod.CASH },
    { amount: 480, cat: catRest, desc: 'Cena familiar', date: d(2026,1,20), method: PaymentMethod.CARD_CREDIT, cardId: visaCard.id },
    { amount: 230, cat: catDelivery, desc: 'Uber Eats pizza', date: d(2026,1,12), method: PaymentMethod.CARD_CREDIT, cardId: visaCard.id },
    { amount: 155, cat: catCafe, desc: 'Café Juan Valdez', date: d(2026,1,15), method: PaymentMethod.CASH },
    // Transporte
    { amount: 280, cat: catTaxi, desc: 'Uber al trabajo', date: d(2026,1,4), method: PaymentMethod.CARD_CREDIT, cardId: masterCard.id },
    { amount: 420, cat: catCombust, desc: 'Gasolina Toyota', date: d(2026,1,10), method: PaymentMethod.CASH },
    { amount: 420, cat: catCombust, desc: 'Gasolina Toyota', date: d(2026,1,25), method: PaymentMethod.CASH },
    // Salud
    { amount: 680, cat: catConsulta, desc: 'Dermatólogo', date: d(2026,1,14), method: PaymentMethod.CARD_CREDIT, cardId: visaCard.id },
    { amount: 350, cat: catMedic, desc: 'Farmacia Kielsa', date: d(2026,1,15), method: PaymentMethod.CASH },
    // Entretenimiento
    { amount: 580, cat: catSalidas, desc: 'Cine + botanas', date: d(2026,1,17), method: PaymentMethod.CARD_CREDIT, cardId: masterCard.id },
    { amount: 219, cat: catStreaming, desc: 'Netflix mes', date: d(2026,1,1), method: PaymentMethod.CARD_CREDIT, cardId: visaCard.id },
    { amount: 89, cat: catStreaming, desc: 'Spotify mes', date: d(2026,1,1), method: PaymentMethod.CARD_CREDIT, cardId: visaCard.id },
    // Ropa
    { amount: 1200, cat: catRopa, desc: 'Ropa Multiplaza', date: d(2026,1,22), method: PaymentMethod.CARD_CREDIT, cardId: visaCard.id },
    // Cuidado personal
    { amount: 380, cat: catCuidado, desc: 'Barbería + productos', date: d(2026,1,9), method: PaymentMethod.CASH },

    // ── FEBRERO 2026 ─────────────────────────────────────────────────────
    { amount: 8500, cat: catAlquiler, desc: 'Alquiler febrero', date: d(2026,2,1), method: PaymentMethod.TRANSFER },
    { amount: 870, cat: catServicios, desc: 'Luz ENEE febrero', date: d(2026,2,5), method: PaymentMethod.CASH },
    { amount: 320, cat: catInternet, desc: 'Tigo Internet febrero', date: d(2026,2,7), method: PaymentMethod.CARD_DEBIT },
    // Comida - febrero es mes de San Valentín, gasto mayor en restaurantes
    { amount: 1780, cat: catSuper, desc: 'Super compra quincenal', date: d(2026,2,2), method: PaymentMethod.CARD_DEBIT },
    { amount: 1650, cat: catSuper, desc: 'Super compra quincenal', date: d(2026,2,17), method: PaymentMethod.CARD_DEBIT },
    { amount: 1850, cat: catRest, desc: 'Cena San Valentín La Cumbre', date: d(2026,2,14), method: PaymentMethod.CARD_CREDIT, cardId: visaCard.id },
    { amount: 420, cat: catRest, desc: 'Almuerzo ejecutivo', date: d(2026,2,20), method: PaymentMethod.CASH },
    { amount: 185, cat: catDelivery, desc: 'Hugo´s Pizza delivery', date: d(2026,2,8), method: PaymentMethod.CARD_CREDIT, cardId: masterCard.id },
    { amount: 290, cat: catDelivery, desc: 'Pollo Campero delivery', date: d(2026,2,22), method: PaymentMethod.CARD_CREDIT, cardId: masterCard.id },
    // Transporte
    { amount: 350, cat: catTaxi, desc: 'Ubers semana', date: d(2026,2,6), method: PaymentMethod.CARD_CREDIT, cardId: masterCard.id },
    { amount: 420, cat: catCombust, desc: 'Gasolina', date: d(2026,2,12), method: PaymentMethod.CASH },
    // Salud
    { amount: 280, cat: catMedic, desc: 'Farmacia vitaminas', date: d(2026,2,18), method: PaymentMethod.CASH },
    // Entretenimiento
    { amount: 219, cat: catStreaming, desc: 'Netflix mes', date: d(2026,2,1), method: PaymentMethod.CARD_CREDIT, cardId: visaCard.id },
    { amount: 89, cat: catStreaming, desc: 'Spotify mes', date: d(2026,2,1), method: PaymentMethod.CARD_CREDIT, cardId: visaCard.id },
    { amount: 950, cat: catSalidas, desc: 'Bar con amigos', date: d(2026,2,28), method: PaymentMethod.CARD_CREDIT, cardId: visaCard.id },
    // Ropa San Valentín
    { amount: 880, cat: catRopa, desc: 'Ropa ocasión especial', date: d(2026,2,13), method: PaymentMethod.CARD_CREDIT, cardId: visaCard.id },
    // Educación
    { amount: 3200, cat: catEduCurso, desc: 'Curso React Native Udemy', date: d(2026,2,10), method: PaymentMethod.CARD_CREDIT, cardId: masterCard.id },
    // Mascotas
    { amount: 850, cat: catMascotas, desc: 'Veterinario vacunas perro', date: d(2026,2,25), method: PaymentMethod.CASH },

    // ── MARZO 2026 ────────────────────────────────────────────────────────
    { amount: 8500, cat: catAlquiler, desc: 'Alquiler marzo', date: d(2026,3,1), method: PaymentMethod.TRANSFER },
    { amount: 1150, cat: catServicios, desc: 'Luz ENEE marzo (verano=más)', date: d(2026,3,5), method: PaymentMethod.CASH },
    { amount: 320, cat: catInternet, desc: 'Tigo Internet marzo', date: d(2026,3,7), method: PaymentMethod.CARD_DEBIT },
    // Comida
    { amount: 2100, cat: catSuper, desc: 'Super quincenal', date: d(2026,3,3), method: PaymentMethod.CARD_DEBIT },
    { amount: 2050, cat: catSuper, desc: 'Super quincenal', date: d(2026,3,18), method: PaymentMethod.CARD_DEBIT },
    { amount: 520, cat: catRest, desc: 'Almuerzo cumpleaños', date: d(2026,3,12), method: PaymentMethod.CARD_CREDIT, cardId: visaCard.id },
    { amount: 340, cat: catRest, desc: 'Almuerzo trabajo', date: d(2026,3,25), method: PaymentMethod.CASH },
    { amount: 310, cat: catDelivery, desc: 'Dominos Pizza', date: d(2026,3,7), method: PaymentMethod.CARD_CREDIT, cardId: masterCard.id },
    { amount: 195, cat: catDelivery, desc: 'Subway delivery', date: d(2026,3,19), method: PaymentMethod.CARD_CREDIT, cardId: masterCard.id },
    { amount: 175, cat: catDelivery, desc: 'Popeyes', date: d(2026,3,28), method: PaymentMethod.CARD_CREDIT, cardId: masterCard.id },
    // ANOMALÍA: gasto inusual en delivery este mes (3x el promedio)
    { amount: 680, cat: catDelivery, desc: 'Pedidos semana de lluvia', date: d(2026,3,15), method: PaymentMethod.CARD_CREDIT, cardId: visaCard.id },
    // Transporte (más en verano por calor)
    { amount: 520, cat: catTaxi, desc: 'Ubers semana', date: d(2026,3,10), method: PaymentMethod.CARD_CREDIT, cardId: masterCard.id },
    { amount: 480, cat: catCombust, desc: 'Gasolina', date: d(2026,3,8), method: PaymentMethod.CASH },
    { amount: 480, cat: catCombust, desc: 'Gasolina', date: d(2026,3,23), method: PaymentMethod.CASH },
    // Salud - vacaciones Semana Santa
    { amount: 450, cat: catMedic, desc: 'Medicamentos viaje', date: d(2026,3,29), method: PaymentMethod.CASH },
    // Entretenimiento - Semana Santa
    { amount: 219, cat: catStreaming, desc: 'Netflix mes', date: d(2026,3,1), method: PaymentMethod.CARD_CREDIT, cardId: visaCard.id },
    { amount: 89, cat: catStreaming, desc: 'Spotify mes', date: d(2026,3,1), method: PaymentMethod.CARD_CREDIT, cardId: visaCard.id },
    { amount: 4500, cat: catSalidas, desc: 'Semana Santa playa Roatán', date: d(2026,3,30), method: PaymentMethod.CARD_CREDIT, cardId: visaCard.id },
    // Ropa verano
    { amount: 2200, cat: catRopa, desc: 'Ropa verano CityMall', date: d(2026,3,16), method: PaymentMethod.CARD_CREDIT, cardId: masterCard.id },
    // Cuidado personal
    { amount: 650, cat: catCuidado, desc: 'Gym mensualidad', date: d(2026,3,2), method: PaymentMethod.TRANSFER },

    // ── ABRIL 2026 (mes actual, parcial) ─────────────────────────────────
    { amount: 8500, cat: catAlquiler, desc: 'Alquiler abril', date: d(2026,4,1), method: PaymentMethod.TRANSFER },
    { amount: 980, cat: catServicios, desc: 'Luz ENEE abril', date: d(2026,4,5), method: PaymentMethod.CASH },
    { amount: 320, cat: catInternet, desc: 'Tigo Internet abril', date: d(2026,4,7), method: PaymentMethod.CARD_DEBIT },
    { amount: 1950, cat: catSuper, desc: 'Super quincenal', date: d(2026,4,2), method: PaymentMethod.CARD_DEBIT },
    { amount: 330, cat: catRest, desc: 'Restaurante actual', date: d(2026,4,9), method: PaymentMethod.CARD_CREDIT, cardId: visaCard.id },
    { amount: 219, cat: catStreaming, desc: 'Netflix mes', date: d(2026,4,1), method: PaymentMethod.CARD_CREDIT, cardId: visaCard.id },
    { amount: 89, cat: catStreaming, desc: 'Spotify mes', date: d(2026,4,1), method: PaymentMethod.CARD_CREDIT, cardId: visaCard.id },
    { amount: 420, cat: catCombust, desc: 'Gasolina', date: d(2026,4,6), method: PaymentMethod.CASH },
    { amount: 280, cat: catTaxi, desc: 'Uber reunión', date: d(2026,4,8), method: PaymentMethod.CARD_CREDIT, cardId: masterCard.id },
    { amount: 650, cat: catCuidado, desc: 'Gym mensualidad', date: d(2026,4,2), method: PaymentMethod.TRANSFER },
  ];

  let created = 0;
  for (const e of expenses) {
    if (!e.cat) continue;
    await expRepo.save(expRepo.create({
      userId: USER_ID,
      categoryId: e.cat.id,
      amount: e.amount,
      currency: 'HNL',
      description: e.desc,
      date: e.date as unknown as Date,
      paymentMethod: e.method,
      creditCardId: e.cardId ?? null,
      source: ExpenseSource.MANUAL,
    }));
    created++;
  }
  console.log(`  ✓ ${created} expenses created`);

  // ─── Pagos de Tarjeta de Crédito ──────────────────────────────────────────
  console.log('  Creating credit card payments...');

  // Visa BAC payments (cut-off day 15)
  await cardPaymentRepo.save([
    cardPaymentRepo.create({ userId: USER_ID, cardId: visaCard.id, amount: 4200, cycleStart: d(2025,12,16), cycleEnd: d(2026,1,15), paymentDate: d(2026,2,4), notes: 'Pago total ciclo diciembre' }),
    cardPaymentRepo.create({ userId: USER_ID, cardId: visaCard.id, amount: 5100, cycleStart: d(2026,1,16), cycleEnd: d(2026,2,15), paymentDate: d(2026,3,5), notes: 'Pago total ciclo enero' }),
    cardPaymentRepo.create({ userId: USER_ID, cardId: visaCard.id, amount: 6800, cycleStart: d(2026,2,16), cycleEnd: d(2026,3,15), paymentDate: d(2026,4,4), notes: 'Pago total ciclo febrero' }),
  ]);

  // Mastercard Ficohsa payments (cut-off day 25) — pago mínimo en marzo
  await cardPaymentRepo.save([
    cardPaymentRepo.create({ userId: USER_ID, cardId: masterCard.id, amount: 2800, cycleStart: d(2025,12,26), cycleEnd: d(2026,1,25), paymentDate: d(2026,2,12), notes: 'Pago total ciclo enero' }),
    cardPaymentRepo.create({ userId: USER_ID, cardId: masterCard.id, amount: 3400, cycleStart: d(2026,1,26), cycleEnd: d(2026,2,25), paymentDate: d(2026,3,14), notes: 'Pago total ciclo febrero' }),
    cardPaymentRepo.create({ userId: USER_ID, cardId: masterCard.id, amount: 1200, cycleStart: d(2026,2,26), cycleEnd: d(2026,3,25), paymentDate: d(2026,4,10), notes: 'Pago mínimo ciclo marzo' }),
  ]);

  console.log('  ✓ 6 credit card payments created');

  // ─── Presupuestos ─────────────────────────────────────────────────────────
  console.log('  Creating budgets...');

  const budgets = [
    // Mes actual (abril)
    { name: 'Comida abril', catName: 'Comida', amount: 8000, start: d(2026,4,1), end: d(2026,4,30) },
    { name: 'Transporte abril', catName: 'Transporte', amount: 3000, start: d(2026,4,1), end: d(2026,4,30) },
    { name: 'Entretenimiento abril', catName: 'Entretenimiento', amount: 2000, start: d(2026,4,1), end: d(2026,4,30) },
    { name: 'Salud abril', catName: 'Salud', amount: 1500, start: d(2026,4,1), end: d(2026,4,30) },
    // Mes anterior (marzo) — ya vencidos
    { name: 'Comida marzo', catName: 'Comida', amount: 8000, start: d(2026,3,1), end: d(2026,3,31) },
    { name: 'Transporte marzo', catName: 'Transporte', amount: 3000, start: d(2026,3,1), end: d(2026,3,31) },
    { name: 'Entretenimiento marzo', catName: 'Entretenimiento', amount: 3000, start: d(2026,3,1), end: d(2026,3,31) },
    // Febrero
    { name: 'Comida febrero', catName: 'Comida', amount: 7500, start: d(2026,2,1), end: d(2026,2,28) },
    { name: 'Restaurantes febrero', catName: 'Restaurante', amount: 2000, start: d(2026,2,1), end: d(2026,2,28) },
  ];

  for (const b of budgets) {
    const parentCat = allCats.find(c => c.name === b.catName) ?? allCats.find(c => c.name === b.catName.split(' ')[0]);
    if (!parentCat) continue;
    await budgetRepo.save(budgetRepo.create({
      userId: USER_ID,
      categoryId: parentCat.id,
      name: b.name,
      amount: b.amount,
      periodType: BudgetPeriod.MONTHLY,
      periodStart: b.start as unknown as Date,
      periodEnd: b.end as unknown as Date,
      alert50Sent: false,
      alert80Sent: false,
    }));
  }
  console.log(`  ✓ ${budgets.length} budgets created`);

  // ─── Metas de ahorro ──────────────────────────────────────────────────────
  console.log('  Creating savings goals...');

  const goalVehiculo = await goalRepo.save(goalRepo.create({
    userId: USER_ID,
    name: 'Enganche vehículo',
    description: 'Ahorro para el enganche de una Toyota Hilux',
    targetAmount: 120000,
    currentAmount: 32000,
    currency: 'HNL',
    targetDate: new Date('2026-12-31'),
    icon: 'directions_car',
    color: '#4A90D9',
    status: GoalStatus.ACTIVE,
  }));

  const goalEmergencia = await goalRepo.save(goalRepo.create({
    userId: USER_ID,
    name: 'Fondo de emergencia',
    description: '3 meses de gastos fijos cubiertos',
    targetAmount: 50000,
    currentAmount: 38500,
    currency: 'HNL',
    targetDate: new Date('2026-09-30'),
    icon: 'shield',
    color: '#27AE60',
    status: GoalStatus.ACTIVE,
  }));

  const goalViaje = await goalRepo.save(goalRepo.create({
    userId: USER_ID,
    name: 'Viaje a México',
    description: 'Vuelos + hotel + gastos Ciudad de México',
    targetAmount: 45000,
    currentAmount: 12500,
    currency: 'HNL',
    targetDate: new Date('2026-11-15'),
    icon: 'flight',
    color: '#E67E22',
    status: GoalStatus.ACTIVE,
  }));

  const goalLaptop = await goalRepo.save(goalRepo.create({
    userId: USER_ID,
    name: 'Laptop nueva',
    description: 'MacBook Pro M4',
    targetAmount: 55000,
    currentAmount: 55000,
    currency: 'HNL',
    targetDate: new Date('2026-03-01'),
    icon: 'laptop_mac',
    color: '#8E44AD',
    status: GoalStatus.COMPLETED,
  }));

  console.log('  ✓ 4 goals created');

  // ─── Contribuciones a metas ───────────────────────────────────────────────
  console.log('  Creating goal contributions...');

  const contributions = [
    // Enganche vehículo — aportes mensuales
    { goalId: goalVehiculo.id, amount: 8000, date: d(2026,1,31), source: ContributionSource.MANUAL, notes: 'Aporte enero' },
    { goalId: goalVehiculo.id, amount: 8000, date: d(2026,2,28), source: ContributionSource.MANUAL, notes: 'Aporte febrero' },
    { goalId: goalVehiculo.id, amount: 8000, date: d(2026,3,31), source: ContributionSource.MANUAL, notes: 'Aporte marzo' },
    { goalId: goalVehiculo.id, amount: 8000, date: d(2026,4,5), source: ContributionSource.INCOME, notes: 'Aporte quincena' },
    // Fondo de emergencia
    { goalId: goalEmergencia.id, amount: 5000, date: d(2026,1,31), source: ContributionSource.MANUAL, notes: 'Aporte enero' },
    { goalId: goalEmergencia.id, amount: 5000, date: d(2026,2,28), source: ContributionSource.MANUAL, notes: 'Aporte febrero' },
    { goalId: goalEmergencia.id, amount: 8000, date: d(2026,3,31), source: ContributionSource.INCOME, notes: 'Bono vacacional' },
    { goalId: goalEmergencia.id, amount: 7000, date: d(2026,4,3), source: ContributionSource.MANUAL, notes: 'Extra abril' },
    // Viaje México
    { goalId: goalViaje.id, amount: 3000, date: d(2026,2,28), source: ContributionSource.MANUAL, notes: 'Inicio ahorro viaje' },
    { goalId: goalViaje.id, amount: 3000, date: d(2026,3,31), source: ContributionSource.MANUAL, notes: 'Aporte marzo' },
    { goalId: goalViaje.id, amount: 3500, date: d(2026,4,5), source: ContributionSource.MANUAL, notes: 'Aporte abril' },
    // Laptop - historial de cómo llegó a meta
    { goalId: goalLaptop.id, amount: 15000, date: d(2025,12,31), source: ContributionSource.MANUAL, notes: 'Ahorro diciembre' },
    { goalId: goalLaptop.id, amount: 20000, date: d(2026,1,31), source: ContributionSource.INCOME, notes: 'Aguinaldo' },
    { goalId: goalLaptop.id, amount: 20000, date: d(2026,2,28), source: ContributionSource.MANUAL, notes: 'Completando meta' },
  ];

  for (const c of contributions) {
    await contribRepo.save(contribRepo.create({
      userId: USER_ID,
      goalId: c.goalId,
      amount: c.amount,
      source: c.source,
      date: c.date as unknown as Date,
      notes: c.notes,
    }));
  }
  console.log(`  ✓ ${contributions.length} contributions created`);

  // ─── Insights de muestra ──────────────────────────────────────────────────
  console.log('  Creating sample insights...');

  // Delete stale projection insight first
  await insightRepo.update(
    { userId: USER_ID, type: InsightType.PROJECTION, isDismissed: false },
    { isDismissed: true },
  );

  const sampleInsights = [
    {
      type: InsightType.ANOMALY,
      priority: InsightPriority.HIGH,
      title: 'Gasto inusual en Delivery',
      body: 'En marzo gastaste 3.2x más de lo normal en Delivery. Promedio mensual: L 370, marzo: L 1,360.',
      metadata: { categoryName: 'Delivery', multiplier: 3.2, month: 'marzo' },
      expiresAt: new Date('2026-05-01'),
    },
    {
      type: InsightType.SAVINGS_OPPORTUNITY,
      priority: InsightPriority.MEDIUM,
      title: 'Oportunidad en Entretenimiento',
      body: 'Gastaste L 5,450 en Entretenimiento en los últimos 3 meses. Reducir un 20% liberaría L 1,090 para tus metas.',
      metadata: { category: 'Entretenimiento', total3m: 5450, saving20pct: 1090 },
      expiresAt: new Date('2026-05-01'),
    },
    {
      type: InsightType.PATTERN,
      priority: InsightPriority.LOW,
      title: 'Gastas más los viernes',
      body: 'Los viernes concentran el 28% de tus gastos semanales. Planificar un presupuesto de fin de semana podría ayudarte.',
      metadata: { dayOfWeek: 'viernes', pct: 28 },
      expiresAt: new Date('2026-05-15'),
    },
  ];

  for (const ins of sampleInsights) {
    const existing = await insightRepo.findOne({ where: { userId: USER_ID, type: ins.type, isDismissed: false } });
    if (existing) continue;
    await insightRepo.save(insightRepo.create({ userId: USER_ID, ...ins }));
  }
  console.log('  ✓ Sample insights created');

  console.log('\n✅ Demo data seed complete!');
  console.log(`   Expenses: ${created}`);
  console.log(`   TC payments: 6 (Visa BAC x3, Mastercard x3)`);
  console.log(`   Budgets: ${budgets.length}`);
  console.log(`   Goals: 4  |  Contributions: ${contributions.length}`);
}
