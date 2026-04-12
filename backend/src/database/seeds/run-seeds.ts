import { AppDataSource } from '../../../data-source';
import { seedCategories } from './categories.seed';
import { seedDemoData } from './demo-data.seed';

async function runSeeds() {
  await AppDataSource.initialize();
  console.log('Database connection established.');

  await seedCategories(AppDataSource);
  await seedDemoData(AppDataSource);

  await AppDataSource.destroy();
  console.log('Seeding completed.');
  process.exit(0);
}

runSeeds().catch((err) => {
  console.error('Seeding failed:', err);
  process.exit(1);
});
