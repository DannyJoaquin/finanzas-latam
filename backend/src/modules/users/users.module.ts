import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { User } from './user.entity';
import { UserNotificationPreferences } from './user-notification-preferences.entity';
import { UsersController } from './users.controller';
import { UsersService } from './users.service';
import { NotificationPreferencesService } from './notification-preferences.service';

@Module({
  imports: [TypeOrmModule.forFeature([User, UserNotificationPreferences])],
  controllers: [UsersController],
  providers: [UsersService, NotificationPreferencesService],
  exports: [UsersService, NotificationPreferencesService],
})
export class UsersModule {}
