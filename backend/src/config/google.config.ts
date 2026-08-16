import { registerAs } from '@nestjs/config';
import { isProduction } from './production-env';

export default registerAs('google', () => ({
  clientId: (() => {
    const value = process.env.GOOGLE_CLIENT_ID ?? '';
    if (isProduction && !value) {
      throw new Error('GOOGLE_CLIENT_ID must be configured in production');
    }
    return value;
  })(),
}));
