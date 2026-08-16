import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import nodemailer, { Transporter } from 'nodemailer';

@Injectable()
export class EmailService {
  private readonly logger = new Logger(EmailService.name);
  private readonly transporter: Transporter | null;

  constructor(private readonly configService: ConfigService) {
    const host = this.configService.get<string>('mail.host');
    if (!host) {
      this.transporter = null;
      return;
    }

    const user = this.configService.get<string>('mail.user');
    const password = this.configService.get<string>('mail.password');
    this.transporter = nodemailer.createTransport({
      host,
      port: this.configService.get<number>('mail.port', 587),
      secure: this.configService.get<boolean>('mail.secure', false),
      auth: user ? { user, pass: password } : undefined,
    });
  }

  async sendPasswordReset(email: string, token: string): Promise<void> {
    const appUrl = this.configService
      .get<string>('mail.appUrl', 'http://localhost:8092')
      .replace(/\/$/, '');
    const resetUrl = `${appUrl}/#/reset-password?token=${encodeURIComponent(token)}`;

    if (!this.transporter) {
      if (this.configService.get<string>('app.nodeEnv') === 'production') {
        this.logger.error('Password reset email service is not configured');
        return;
      }
      this.logger.warn(`Password reset link for ${email}: ${resetUrl}`);
      return;
    }

    await this.transporter.sendMail({
      from: this.configService.get<string>('mail.from'),
      to: email,
      subject: 'Restablece tu contraseña de Zentri',
      text: [
        'Recibimos una solicitud para restablecer tu contraseña de Zentri.',
        '',
        `Abre este enlace para elegir una contraseña nueva: ${resetUrl}`,
        '',
        'El enlace vence en una hora. Si no solicitaste este cambio, puedes ignorar este mensaje.',
      ].join('\n'),
      html: `
        <p>Recibimos una solicitud para restablecer tu contraseña de Zentri.</p>
        <p><a href="${resetUrl}">Elegir una contraseña nueva</a></p>
        <p>El enlace vence en una hora. Si no solicitaste este cambio, puedes ignorar este mensaje.</p>
      `,
    });
  }
}
