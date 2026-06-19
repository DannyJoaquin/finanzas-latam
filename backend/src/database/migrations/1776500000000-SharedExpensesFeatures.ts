import { MigrationInterface, QueryRunner } from 'typeorm';

export class SharedExpensesFeatures1776500000000 implements MigrationInterface {
  name = 'SharedExpensesFeatures1776500000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // ── shared_expenses: new columns ─────────────────────────────────────────
    await queryRunner.query(`
      ALTER TABLE "shared_expenses"
        ADD COLUMN "receipt_url"          TEXT,
        ADD COLUMN "is_recurring"         BOOLEAN NOT NULL DEFAULT FALSE,
        ADD COLUMN "recurring_day"        SMALLINT,
        ADD COLUMN "next_recurrence_at"   TIMESTAMPTZ
    `);

    await queryRunner.query(`
      CREATE TYPE "shared_expense_status_enum" AS ENUM ('approved', 'pending')
    `);
    await queryRunner.query(`
      ALTER TABLE "shared_expenses"
        ADD COLUMN "status" "shared_expense_status_enum" NOT NULL DEFAULT 'approved'
    `);

    await queryRunner.query(`
      CREATE TYPE "shared_expense_recurring_interval_enum" AS ENUM ('monthly', 'weekly')
    `);
    await queryRunner.query(`
      ALTER TABLE "shared_expenses"
        ADD COLUMN "recurring_interval" "shared_expense_recurring_interval_enum"
    `);

    // ── shared_group_settings ────────────────────────────────────────────────
    await queryRunner.query(`
      CREATE TABLE "shared_group_settings" (
        "id"                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        "group_id"          UUID NOT NULL UNIQUE REFERENCES "shared_groups"("id") ON DELETE CASCADE,
        "requires_approval" BOOLEAN NOT NULL DEFAULT FALSE,
        "created_at"        TIMESTAMPTZ NOT NULL DEFAULT now(),
        "updated_at"        TIMESTAMPTZ NOT NULL DEFAULT now()
      )
    `);

    // ── shared_expense_approvals ─────────────────────────────────────────────
    await queryRunner.query(`
      CREATE TYPE "shared_expense_approval_status_enum" AS ENUM ('pending', 'approved', 'rejected')
    `);
    await queryRunner.query(`
      CREATE TABLE "shared_expense_approvals" (
        "id"           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        "expense_id"   UUID NOT NULL UNIQUE REFERENCES "shared_expenses"("id") ON DELETE CASCADE,
        "reviewer_id"  UUID NOT NULL REFERENCES "users"("id"),
        "status"       "shared_expense_approval_status_enum" NOT NULL DEFAULT 'pending',
        "note"         TEXT,
        "created_at"   TIMESTAMPTZ NOT NULL DEFAULT now(),
        "updated_at"   TIMESTAMPTZ NOT NULL DEFAULT now()
      )
    `);

    // ── user_notification_preferences: new columns ───────────────────────────
    await queryRunner.query(`
      ALTER TABLE "user_notification_preferences"
        ADD COLUMN IF NOT EXISTS "push_shared_expense_changes" BOOLEAN NOT NULL DEFAULT TRUE,
        ADD COLUMN IF NOT EXISTS "debt_reminder_days" SMALLINT DEFAULT 7
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE IF EXISTS "shared_expense_approvals"`);
    await queryRunner.query(`DROP TYPE IF EXISTS "shared_expense_approval_status_enum"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "shared_group_settings"`);
    await queryRunner.query(`ALTER TABLE "shared_expenses" DROP COLUMN IF EXISTS "recurring_interval"`);
    await queryRunner.query(`DROP TYPE IF EXISTS "shared_expense_recurring_interval_enum"`);
    await queryRunner.query(`ALTER TABLE "shared_expenses" DROP COLUMN IF EXISTS "status"`);
    await queryRunner.query(`DROP TYPE IF EXISTS "shared_expense_status_enum"`);
    await queryRunner.query(`
      ALTER TABLE "shared_expenses"
        DROP COLUMN IF EXISTS "receipt_url",
        DROP COLUMN IF EXISTS "is_recurring",
        DROP COLUMN IF EXISTS "recurring_day",
        DROP COLUMN IF EXISTS "next_recurrence_at"
    `);
    await queryRunner.query(`
      ALTER TABLE "user_notification_preferences"
        DROP COLUMN IF EXISTS "push_shared_expense_changes",
        DROP COLUMN IF EXISTS "debt_reminder_days"
    `);
  }
}
