import { registerAs } from '@nestjs/config';

export default registerAs('mail', () => ({
  host: process.env.MAIL_HOST ?? '',
  port: parseInt(process.env.MAIL_PORT ?? '587', 10),
  secure: process.env.MAIL_SECURE === 'true',
  user: process.env.MAIL_USER ?? '',
  password: process.env.MAIL_PASSWORD ?? '',
  from: process.env.MAIL_FROM ?? 'Zentri <no-reply@zentri.app>',
  appUrl: process.env.WEB_APP_URL ?? 'http://localhost:8092',
}));
