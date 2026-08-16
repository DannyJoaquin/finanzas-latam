import { registerAs } from '@nestjs/config';
import { requiredProductionValue } from './production-env';

export default registerAs('redis', () => ({
  url: process.env.REDIS_URL ?? '',
  host: process.env.REDIS_HOST ??
    (process.env.REDIS_URL ? '' : requiredProductionValue('REDIS_HOST', 'localhost')),
  port: parseInt(process.env.REDIS_PORT ?? '6379', 10),
  password: process.env.REDIS_PASSWORD ?? undefined,
  tls: process.env.REDIS_TLS === 'true',
}));
