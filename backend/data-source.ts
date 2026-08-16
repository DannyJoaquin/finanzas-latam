import { DataSource } from 'typeorm';
import * as dotenv from 'dotenv';
import { requiredProductionValue } from './src/config/production-env';
dotenv.config();

export const AppDataSource = new DataSource({
  type: 'postgres',
  ...(process.env.DATABASE_URL
    ? { url: process.env.DATABASE_URL }
    : {
        host: requiredProductionValue('DB_HOST', 'localhost'),
        port: parseInt(process.env.DB_PORT ?? '5432', 10),
        username: requiredProductionValue('DB_USERNAME', 'postgres'),
        password: requiredProductionValue('DB_PASSWORD', 'postgres'),
        database: requiredProductionValue('DB_NAME', 'finanzas_latam'),
      }),
  ssl:
    process.env.DB_SSL === 'true' || !!process.env.DATABASE_URL
      ? { rejectUnauthorized: process.env.DB_SSL_REJECT_UNAUTHORIZED !== 'false' }
      : false,
  entities: [__dirname + '/src/**/*.entity{.ts,.js}'],
  migrations: [__dirname + '/src/database/migrations/*{.ts,.js}'],
  migrationsTableName: 'typeorm_migrations',
});
