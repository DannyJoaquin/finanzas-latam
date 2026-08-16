import { UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { JwtService } from '@nestjs/jwt';
import { Repository } from 'typeorm';
import Redis from 'ioredis';
import * as bcrypt from 'bcrypt';

import { EmailService } from '../../common/services/email.service';
import { User } from '../users/user.entity';
import { AuthService } from './auth.service';

describe('AuthService password recovery and Google account rules', () => {
  let service: AuthService;
  let usersRepository: {
    findOne: jest.Mock;
    save: jest.Mock;
    create: jest.Mock;
  };
  let redis: {
    set: jest.Mock;
    getdel: jest.Mock;
    del: jest.Mock;
  };
  let emailService: { sendPasswordReset: jest.Mock };

  beforeEach(() => {
    usersRepository = {
      findOne: jest.fn(),
      save: jest.fn(),
      create: jest.fn(),
    };
    redis = {
      set: jest.fn(),
      getdel: jest.fn(),
      del: jest.fn(),
    };
    emailService = { sendPasswordReset: jest.fn() };

    service = new AuthService(
      usersRepository as unknown as Repository<User>,
      { sign: jest.fn(() => 'jwt') } as unknown as JwtService,
      {
        get: jest.fn(),
        getOrThrow: jest.fn(),
      } as unknown as ConfigService,
      redis as unknown as Redis,
      emailService as unknown as EmailService,
    );
  });

  it('does not issue a reset token for a Google-only account', async () => {
    usersRepository.findOne.mockResolvedValue({
      id: 'google-user',
      email: 'google@example.com',
      passwordHash: null,
      isActive: true,
    });

    await expect(service.requestPasswordReset('Google@Example.com')).resolves.toBeUndefined();

    expect(redis.set).not.toHaveBeenCalled();
    expect(emailService.sendPasswordReset).not.toHaveBeenCalled();
  });

  it('stores only a hashed, one-hour token and emails the raw token', async () => {
    usersRepository.findOne.mockResolvedValue({
      id: 'local-user',
      email: 'local@example.com',
      passwordHash: 'existing-hash',
      isActive: true,
    });

    await service.requestPasswordReset('LOCAL@example.com');

    expect(emailService.sendPasswordReset).toHaveBeenCalledWith(
      'local@example.com',
      expect.stringMatching(/^[a-f0-9]{64}$/),
    );
    const [key, userId, expiryFlag, ttl] = redis.set.mock.calls[0];
    expect(key).toMatch(/^password-reset:[a-f0-9]{64}$/);
    expect(key).not.toContain(emailService.sendPasswordReset.mock.calls[0][1]);
    expect(userId).toBe('local-user');
    expect(expiryFlag).toBe('EX');
    expect(ttl).toBe(3600);
  });

  it('updates the password and deletes a reset token after one successful use', async () => {
    const user = {
      id: 'local-user',
      passwordHash: 'old-hash',
      isActive: true,
    } as User;
    redis.getdel.mockResolvedValue('local-user');
    usersRepository.findOne.mockResolvedValue(user);
    usersRepository.save.mockImplementation(async (savedUser: User) => savedUser);

    await service.resetPassword('raw-reset-token', 'new-password');

    expect(usersRepository.save).toHaveBeenCalledWith(user);
    expect(user.passwordHash).not.toBe('old-hash');
    expect(redis.getdel).toHaveBeenCalledWith(
      expect.stringMatching(/^password-reset:[a-f0-9]{64}$/),
    );
  });

  it('rejects an expired or already-used reset token', async () => {
    redis.getdel.mockResolvedValue(null);

    await expect(
      service.resetPassword('expired-token', 'new-password'),
    ).rejects.toBeInstanceOf(UnauthorizedException);

    expect(usersRepository.save).not.toHaveBeenCalled();
  });

  it('changes a local password only after verifying the current password', async () => {
    const user = {
      id: 'local-user',
      passwordHash: await bcrypt.hash('old-password', 4),
      isActive: true,
    } as User;
    usersRepository.findOne.mockResolvedValue(user);
    usersRepository.save.mockImplementation(async (savedUser: User) => savedUser);

    await service.changePassword('local-user', 'old-password', 'new-password');

    expect(await bcrypt.compare('new-password', user.passwordHash!)).toBe(true);
    expect(usersRepository.save).toHaveBeenCalledWith(user);
  });

  it('rejects an incorrect current password', async () => {
    const user = {
      id: 'local-user',
      passwordHash: await bcrypt.hash('old-password', 4),
      isActive: true,
    } as User;
    usersRepository.findOne.mockResolvedValue(user);

    await expect(
      service.changePassword('local-user', 'wrong-password', 'new-password'),
    ).rejects.toBeInstanceOf(UnauthorizedException);
    expect(usersRepository.save).not.toHaveBeenCalled();
  });

  it('lets a Google-only account establish its first password', async () => {
    const user = {
      id: 'google-user',
      passwordHash: null,
      provider: 'google',
      isActive: true,
    } as User;
    usersRepository.findOne.mockResolvedValue(user);
    usersRepository.save.mockImplementation(async (savedUser: User) => savedUser);

    await service.changePassword('google-user', undefined, 'new-password');

    expect(user.passwordHash).toBeTruthy();
    expect(await bcrypt.compare('new-password', user.passwordHash!)).toBe(true);
    expect(usersRepository.save).toHaveBeenCalledWith(user);
  });

  it('links a local account to a verified Google identity by email', async () => {
    usersRepository.findOne
      .mockResolvedValueOnce(null)
      .mockResolvedValueOnce({
        id: 'local-user',
        email: 'local@example.com',
        fullName: 'Local User',
        passwordHash: 'local-hash',
        provider: null,
        providerId: null,
      });
    usersRepository.save.mockImplementation(async (user: User) => user);
    jest.spyOn(service as never, 'verifyGoogleToken' as never).mockResolvedValue({
      sub: 'google-sub',
      email: 'local@example.com',
      name: 'Local User',
      email_verified: true,
    } as never);

    const result = await service.googleLogin('verified-id-token');

    expect(result.user).toEqual({
      id: 'local-user',
      email: 'local@example.com',
      fullName: 'Local User',
      avatarUrl: undefined,
    });
    expect(usersRepository.save).toHaveBeenCalledWith(
      expect.objectContaining({
        provider: 'google',
        providerId: 'google-sub',
        emailVerified: true,
        passwordHash: 'local-hash',
      }),
    );
  });
});
