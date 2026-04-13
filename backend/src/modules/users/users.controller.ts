import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Patch,
  SerializeOptions,
  UseInterceptors,
  ClassSerializerInterceptor,
} from '@nestjs/common';
import { UsersService } from './users.service';
import { NotificationPreferencesService } from './notification-preferences.service';
import { UpdateUserDto } from './dto/update-user.dto';
import { UpdateNotificationPreferencesDto } from './dto/notification-preferences.dto';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { User } from './user.entity';

@UseInterceptors(ClassSerializerInterceptor)
@SerializeOptions({ excludeExtraneousValues: false })
@Controller('users')
export class UsersController {
  constructor(
    private usersService: UsersService,
    private notificationPrefsService: NotificationPreferencesService,
  ) {}

  @Get('me')
  getMe(@CurrentUser() user: User) {
    return user;
  }

  @Patch('me')
  updateMe(@CurrentUser() user: User, @Body() dto: UpdateUserDto) {
    return this.usersService.update(user.id, dto);
  }

  @Delete('me')
  @HttpCode(HttpStatus.NO_CONTENT)
  deleteMe(@CurrentUser() user: User) {
    return this.usersService.softDelete(user.id);
  }

  @Get('me/notification-preferences')
  getNotificationPrefs(@CurrentUser() user: User) {
    return this.notificationPrefsService.findOrCreateDefaults(user.id);
  }

  @Patch('me/notification-preferences')
  updateNotificationPrefs(
    @CurrentUser() user: User,
    @Body() dto: UpdateNotificationPreferencesDto,
  ) {
    return this.notificationPrefsService.update(user.id, dto);
  }
}
