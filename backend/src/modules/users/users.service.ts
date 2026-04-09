import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from './user.entity';
import { UpdateUserDto } from './dto/update-user.dto';

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User)
    private usersRepository: Repository<User>,
  ) {}

  async findById(id: string): Promise<User> {
    const user = await this.usersRepository.findOne({ where: { id } });
    if (!user) throw new NotFoundException('User not found');
    return user;
  }

  async update(id: string, dto: UpdateUserDto): Promise<User> {
    await this.usersRepository.update(id, dto);
    return this.findById(id);
  }

  async softDelete(id: string): Promise<void> {
    await this.usersRepository.softDelete(id);
  }

  async updateAvatar(id: string, avatarUrl: string): Promise<User> {
    await this.usersRepository.update(id, { avatarUrl });
    return this.findById(id);
  }
}
