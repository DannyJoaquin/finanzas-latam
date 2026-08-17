import { AppDataSource } from '../../../data-source';
import { seedCategories } from './categories.seed';

async function seedProduction() {
  await AppDataSource.initialize();
  await seedCategories(AppDataSource);
  await AppDataSource.destroy();
  console.log('Production seed completed.');
}

seedProduction().catch(async (error) => {
  console.error('Production seed failed:', error);
  if (AppDataSource.isInitialized) await AppDataSource.destroy();
  process.exit(1);
});
