import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { UserNotificationPreferences } from './user-notification-preferences.entity';
import { UpdateNotificationPreferencesDto } from './dto/notification-preferences.dto';

@Injectable()
export class NotificationPreferencesService {
  constructor(
    @InjectRepository(UserNotificationPreferences)
    private prefsRepo: Repository<UserNotificationPreferences>,
  ) {}

  /**
   * Returns the user's notification preferences, creating default ones if
   * they don't exist yet (first-time access). This ensures every user always
   * has a preferences record.
   */
  async findOrCreateDefaults(userId: string): Promise<UserNotificationPreferences> {
    let prefs = await this.prefsRepo.findOne({ where: { userId } });
    if (!prefs) {
      prefs = this.prefsRepo.create({ userId });
      await this.prefsRepo.save(prefs);
    }
    return prefs;
  }

  /** Update user's notification preferences (partial update) */
  async update(
    userId: string,
    dto: UpdateNotificationPreferencesDto,
  ): Promise<UserNotificationPreferences> {
    let prefs = await this.prefsRepo.findOne({ where: { userId } });
    if (!prefs) {
      prefs = this.prefsRepo.create({ userId });
    }
    Object.assign(prefs, dto);
    await this.prefsRepo.save(prefs);
    // Re-fetch to return the full entity (TypeORM save() only returns updated columns)
    return this.findOrCreateDefaults(userId);
  }
}
