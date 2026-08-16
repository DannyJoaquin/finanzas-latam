import {
  BadRequestException,
  ConflictException,
  Injectable,
  Logger,
  UnauthorizedException,
} from '@nestjs/common';
import { createHash, randomBytes } from 'crypto';
import { JwtService } from '@nestjs/jwt';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import * as bcrypt from 'bcrypt';
import { ConfigService } from '@nestjs/config';
import { InjectRedis } from '@nestjs-modules/ioredis';
import Redis from 'ioredis';
import { OAuth2Client } from 'google-auth-library';
import { EmailService } from '../../common/services/email.service';
import { User } from '../users/user.entity';
import { RegisterDto } from './dto/register.dto';

const BCRYPT_ROUNDS = 12;
const REFRESH_KEY_PREFIX = 'refresh:';
const PASSWORD_RESET_KEY_PREFIX = 'password-reset:';
const PASSWORD_RESET_TTL_SECONDS = 60 * 60;

interface GoogleTokenPayload {
  sub: string;
  email: string;
  name: string;
  picture?: string;
  email_verified?: boolean;
}

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);

  constructor(
    @InjectRepository(User)
    private usersRepository: Repository<User>,
    private jwtService: JwtService,
    private configService: ConfigService,
    @InjectRedis() private redis: Redis,
    private emailService: EmailService,
  ) {}

  async register(dto: RegisterDto): Promise<{ accessToken: string; refreshToken: string }> {
    const email = dto.email.trim().toLowerCase();
    const existing = await this.usersRepository.findOne({ where: { email } });
    if (existing) throw new ConflictException('Email already registered');

    const passwordHash = await bcrypt.hash(dto.password, BCRYPT_ROUNDS);
    const user = this.usersRepository.create({
      email,
      fullName: dto.fullName,
      passwordHash,
    });
    await this.usersRepository.save(user);

    return this.generateTokens(user);
  }

  async validateUser(email: string, password: string): Promise<User | null> {
    const user = await this.usersRepository.findOne({
      where: { email: email.trim().toLowerCase(), isActive: true },
    });
    if (!user || !user.passwordHash) return null;
    const valid = await bcrypt.compare(password, user.passwordHash);
    return valid ? user : null;
  }

  async login(user: User): Promise<{ accessToken: string; refreshToken: string }> {
    return this.generateTokens(user);
  }

  async refresh(refreshToken: string): Promise<{ accessToken: string; refreshToken: string }> {
    let payload: { sub: string; email: string };
    try {
      payload = this.jwtService.verify<{ sub: string; email: string }>(refreshToken, {
        secret: this.configService.get<string>('jwt.refreshSecret'),
      });
    } catch {
      throw new UnauthorizedException('Invalid or expired refresh token');
    }

    // Check if token has been blacklisted
    const blacklisted = await this.redis.get(`${REFRESH_KEY_PREFIX}blacklist:${refreshToken}`);
    if (blacklisted) throw new UnauthorizedException('Token revoked');

    const user = await this.usersRepository.findOne({
      where: { id: payload.sub, isActive: true },
    });
    if (!user) throw new UnauthorizedException('User not found');

    // Invalidate old refresh token
    const expiresIn = this.configService.get<string>('jwt.refreshExpiresIn') ?? '30d';
    const ttlSeconds = this.parseTtl(expiresIn);
    await this.redis.set(`${REFRESH_KEY_PREFIX}blacklist:${refreshToken}`, '1', 'EX', ttlSeconds);

    return this.generateTokens(user);
  }

  async logout(refreshToken: string): Promise<void> {
    const expiresIn = this.configService.get<string>('jwt.refreshExpiresIn') ?? '30d';
    const ttlSeconds = this.parseTtl(expiresIn);
    await this.redis.set(`${REFRESH_KEY_PREFIX}blacklist:${refreshToken}`, '1', 'EX', ttlSeconds);
  }

  async requestPasswordReset(email: string): Promise<void> {
    const normalizedEmail = email.trim().toLowerCase();
    const user = await this.usersRepository.findOne({
      where: { email: normalizedEmail, isActive: true },
    });

    if (!user || !user.passwordHash) return;

    const token = randomBytes(32).toString('hex');
    const tokenHash = this.hashPasswordResetToken(token);
    const key = `${PASSWORD_RESET_KEY_PREFIX}${tokenHash}`;
    await this.redis.set(key, user.id, 'EX', PASSWORD_RESET_TTL_SECONDS);

    try {
      await this.emailService.sendPasswordReset(user.email, token);
    } catch (error) {
      await this.redis.del(key);
      this.logger.error(
        'Password reset email could not be sent',
        error instanceof Error ? error.stack : String(error),
      );
    }
  }

  async resetPassword(token: string, password: string): Promise<void> {
    const key = `${PASSWORD_RESET_KEY_PREFIX}${this.hashPasswordResetToken(token)}`;
    const userId = await this.redis.getdel(key);
    if (!userId) throw new UnauthorizedException('Invalid or expired reset token');

    const user = await this.usersRepository.findOne({
      where: { id: userId, isActive: true },
    });
    if (!user || !user.passwordHash) {
      throw new UnauthorizedException('Invalid or expired reset token');
    }

    user.passwordHash = await bcrypt.hash(password, BCRYPT_ROUNDS);
    await this.usersRepository.save(user);
  }

  async changePassword(
    userId: string,
    currentPassword: string | undefined,
    newPassword: string,
  ): Promise<void> {
    const user = await this.usersRepository.findOne({
      where: { id: userId, isActive: true },
    });
    if (!user) throw new UnauthorizedException('User not found');

    if (user.passwordHash) {
      if (!currentPassword || !(await bcrypt.compare(currentPassword, user.passwordHash))) {
        throw new UnauthorizedException('Current password is incorrect');
      }
    }

    user.passwordHash = await bcrypt.hash(newPassword, BCRYPT_ROUNDS);
    await this.usersRepository.save(user);
  }

  async googleLogin(idToken: string): Promise<{ accessToken: string; refreshToken: string; user: Partial<User> }> {
    const googleData = await this.verifyGoogleToken(idToken);
    const user = await this.validateOrCreateGoogleUser(googleData);
    const tokens = await this.generateTokens(user);
    return {
      ...tokens,
      user: {
        id: user.id,
        email: user.email,
        fullName: user.fullName,
        avatarUrl: user.avatarUrl,
      },
    };
  }

  private async verifyGoogleToken(idToken: string): Promise<GoogleTokenPayload> {
    const clientId = this.configService.getOrThrow<string>('google.clientId');
    const client = new OAuth2Client(clientId);
    try {
      const ticket = await client.verifyIdToken({
        idToken,
        audience: clientId,
      });
      const payload = ticket.getPayload();
      if (!payload || !payload.sub || !payload.email) {
        throw new UnauthorizedException('Invalid Google token payload');
      }
      if (payload.email_verified !== true) {
        throw new UnauthorizedException('Google email is not verified');
      }
      return {
        sub: payload.sub,
        email: payload.email.trim().toLowerCase(),
        name: payload.name ?? payload.email,
        picture: payload.picture,
        email_verified: payload.email_verified,
      };
    } catch (err) {
      if (err instanceof UnauthorizedException) throw err;
      throw new UnauthorizedException('Google token verification failed');
    }
  }

  private async validateOrCreateGoogleUser(googleData: GoogleTokenPayload): Promise<User> {
    // First: look up by provider + provider_id (most reliable)
    let user = await this.usersRepository.findOne({
      where: { provider: 'google', providerId: googleData.sub },
    });

    if (user) {
      // Update avatar and name if changed
      user.avatarUrl = googleData.picture ?? user.avatarUrl;
      user.fullName = googleData.name ?? user.fullName;
      return this.usersRepository.save(user);
    }

    user = await this.usersRepository.findOne({
      where: { email: googleData.email },
    });

    if (user) {
      // Google has already verified the email, so link it to the existing account.
      user.provider = 'google';
      user.providerId = googleData.sub;
      user.emailVerified = true;
      if (!user.avatarUrl && googleData.picture) user.avatarUrl = googleData.picture;
      return this.usersRepository.save(user);
    }

    // Create new user
    const newUser = this.usersRepository.create({
      email: googleData.email,
      fullName: googleData.name,
      avatarUrl: googleData.picture,
      provider: 'google',
      providerId: googleData.sub,
      emailVerified: googleData.email_verified ?? true,
      passwordHash: null,
    });
    return this.usersRepository.save(newUser);
  }

  private async generateTokens(user: User): Promise<{ accessToken: string; refreshToken: string }> {
    const payload = { sub: user.id, email: user.email };

    // Use string casting so @nestjs/jwt StringValue constraint is satisfied
    const accessToken = this.jwtService.sign(payload, {
      secret: this.configService.getOrThrow<string>('jwt.secret'),
      expiresIn: this.configService.getOrThrow<string>('jwt.expiresIn') as never,
    });

    const refreshToken = this.jwtService.sign(payload, {
      secret: this.configService.getOrThrow<string>('jwt.refreshSecret'),
      expiresIn: this.configService.getOrThrow<string>('jwt.refreshExpiresIn') as never,
    });

    return { accessToken, refreshToken };
  }

  private parseTtl(expiresIn: string): number {
    const match = expiresIn.match(/^(\d+)([smhd])$/);
    if (!match) throw new BadRequestException('Invalid JWT expiry format');
    const value = parseInt(match[1], 10);
    const unit = match[2];
    const multipliers: Record<string, number> = { s: 1, m: 60, h: 3600, d: 86400 };
    return value * (multipliers[unit] ?? 1);
  }

  private hashPasswordResetToken(token: string): string {
    return createHash('sha256').update(token).digest('hex');
  }
}
