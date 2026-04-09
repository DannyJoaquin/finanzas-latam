import {
  BadRequestException,
  ConflictException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import * as bcrypt from 'bcrypt';
import { ConfigService } from '@nestjs/config';
import { InjectRedis } from '@nestjs-modules/ioredis';
import Redis from 'ioredis';
import { User } from '../users/user.entity';
import { RegisterDto } from './dto/register.dto';

const BCRYPT_ROUNDS = 12;
const REFRESH_KEY_PREFIX = 'refresh:';

@Injectable()
export class AuthService {
  constructor(
    @InjectRepository(User)
    private usersRepository: Repository<User>,
    private jwtService: JwtService,
    private configService: ConfigService,
    @InjectRedis() private redis: Redis,
  ) {}

  async register(dto: RegisterDto): Promise<{ accessToken: string; refreshToken: string }> {
    const existing = await this.usersRepository.findOne({ where: { email: dto.email } });
    if (existing) throw new ConflictException('Email already registered');

    const passwordHash = await bcrypt.hash(dto.password, BCRYPT_ROUNDS);
    const user = this.usersRepository.create({
      email: dto.email,
      fullName: dto.fullName,
      passwordHash,
    });
    await this.usersRepository.save(user);

    return this.generateTokens(user);
  }

  async validateUser(email: string, password: string): Promise<User | null> {
    const user = await this.usersRepository.findOne({
      where: { email, isActive: true },
    });
    if (!user) return null;
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
}
