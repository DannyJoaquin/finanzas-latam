import { registerAs } from '@nestjs/config';
import { TypeOrmModuleOptions } from '@nestjs/typeorm';
import { isProduction, requiredProductionValue } from './production-env';

export default registerAs(
  'database',
  (): TypeOrmModuleOptions => ({
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
      process.env.DB_SSL === 'true' || (isProduction && !!process.env.DATABASE_URL)
        ? {
            rejectUnauthorized: process.env.DB_SSL_REJECT_UNAUTHORIZED !== 'false',
          }
        : false,
    entities: [__dirname + '/../**/*.entity{.ts,.js}'],
    migrations: [__dirname + '/../database/migrations/*{.ts,.js}'],
    migrationsRun: false,
    synchronize: false,
    logging: process.env.NODE_ENV === 'development',
  }),
);
