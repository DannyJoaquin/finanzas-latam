import { registerAs } from '@nestjs/config';
import { requiredSecret } from './production-env';

export default registerAs('jwt', () => ({
  secret: requiredSecret('JWT_SECRET', 'dev-jwt-secret-change-in-production'),
  expiresIn: process.env.JWT_EXPIRES_IN ?? '15m',
  refreshSecret: requiredSecret(
    'JWT_REFRESH_SECRET',
    'dev-refresh-secret-change-in-production',
  ),
  refreshExpiresIn: process.env.JWT_REFRESH_EXPIRES_IN ?? '30d',
}));
