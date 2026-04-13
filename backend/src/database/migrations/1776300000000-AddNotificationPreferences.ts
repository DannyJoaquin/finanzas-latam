import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddNotificationPreferences1776300000000 implements MigrationInterface {
  name = 'AddNotificationPreferences1776300000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE "user_notification_preferences" (
        "id"                          UUID NOT NULL DEFAULT uuid_generate_v4(),
        "user_id"                     UUID NOT NULL,
        "push_budget_alerts"          BOOLEAN NOT NULL DEFAULT true,
        "push_daily_reminder"         BOOLEAN NOT NULL DEFAULT true,
        "push_weekly_summary"         BOOLEAN NOT NULL DEFAULT true,
        "push_important_insights"     BOOLEAN NOT NULL DEFAULT true,
        "push_critical_financial_alerts" BOOLEAN NOT NULL DEFAULT true,
        "push_motivation"             BOOLEAN NOT NULL DEFAULT false,
        "local_card_cutoff_alerts"    BOOLEAN NOT NULL DEFAULT true,
        "local_card_due_5d"           BOOLEAN NOT NULL DEFAULT true,
        "local_card_due_1d"           BOOLEAN NOT NULL DEFAULT true,
        "local_card_pending_balance"  BOOLEAN NOT NULL DEFAULT true,
        "inapp_savings_opportunities" BOOLEAN NOT NULL DEFAULT true,
        "inapp_patterns"              BOOLEAN NOT NULL DEFAULT true,
        "inapp_motivation"            BOOLEAN NOT NULL DEFAULT true,
        "created_at"                  TIMESTAMP NOT NULL DEFAULT NOW(),
        "updated_at"                  TIMESTAMP NOT NULL DEFAULT NOW(),
        CONSTRAINT "PK_unp" PRIMARY KEY ("id"),
        CONSTRAINT "UQ_unp_user" UNIQUE ("user_id"),
        CONSTRAINT "FK_unp_user"
          FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE
      )
    `);

    await queryRunner.query(`
      CREATE INDEX "idx_unp_user" ON "user_notification_preferences" ("user_id")
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP INDEX IF EXISTS "idx_unp_user"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "user_notification_preferences"`);
  }
}
