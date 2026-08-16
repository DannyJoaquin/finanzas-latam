import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddRecurringExpenses1776600000000 implements MigrationInterface {
  name = 'AddRecurringExpenses1776600000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TYPE "public"."recurring_expenses_frequency_enum"
      AS ENUM ('daily', 'weekly', 'biweekly', 'monthly', 'bimonthly', 'quarterly', 'semiannual', 'annual')
    `);

    await queryRunner.query(`
      CREATE TABLE "recurring_expenses" (
        "id" uuid NOT NULL DEFAULT uuid_generate_v4(),
        "user_id" uuid NOT NULL,
        "name" character varying(150) NOT NULL,
        "amount" numeric(12,2) NOT NULL,
        "currency" character(3) NOT NULL DEFAULT 'HNL',
        "category_id" uuid NOT NULL,
        "payment_method" "public"."expenses_payment_method_enum" NOT NULL DEFAULT 'cash',
        "cash_account_id" uuid,
        "credit_card_id" uuid,
        "notes" text,
        "frequency" "public"."recurring_expenses_frequency_enum" NOT NULL,
        "execution_day" smallint NOT NULL,
        "start_date" date NOT NULL,
        "next_run_date" date NOT NULL,
        "last_generated_date" date,
        "is_active" boolean NOT NULL DEFAULT true,
        "paused_at" TIMESTAMPTZ,
        "last_generation_attempt_at" TIMESTAMPTZ,
        "last_generation_error" text,
        "created_at" TIMESTAMP NOT NULL DEFAULT now(),
        "updated_at" TIMESTAMP NOT NULL DEFAULT now(),
        CONSTRAINT "PK_recurring_expenses" PRIMARY KEY ("id")
      )
    `);
    await queryRunner.query(`
      CREATE INDEX "idx_recurring_expenses_user_active_next"
      ON "recurring_expenses" ("user_id", "is_active", "next_run_date")
    `);

    await queryRunner.query(`
      ALTER TABLE "recurring_expenses"
        ADD CONSTRAINT "FK_recurring_expenses_user"
          FOREIGN KEY ("user_id") REFERENCES "users"("id"),
        ADD CONSTRAINT "FK_recurring_expenses_category"
          FOREIGN KEY ("category_id") REFERENCES "categories"("id"),
        ADD CONSTRAINT "FK_recurring_expenses_cash_account"
          FOREIGN KEY ("cash_account_id") REFERENCES "cash_accounts"("id") ON DELETE SET NULL,
        ADD CONSTRAINT "FK_recurring_expenses_credit_card"
          FOREIGN KEY ("credit_card_id") REFERENCES "credit_cards"("id") ON DELETE SET NULL
    `);

    await queryRunner.query(`
      ALTER TABLE "expenses"
        ADD COLUMN "recurring_expense_id" uuid,
        ADD COLUMN "recurring_scheduled_date" date
    `);
    await queryRunner.query(`
      CREATE UNIQUE INDEX "uq_expenses_recurring_schedule"
      ON "expenses" ("recurring_expense_id", "recurring_scheduled_date")
    `);
    await queryRunner.query(`
      ALTER TABLE "expenses"
        ADD CONSTRAINT "FK_expenses_recurring_expense"
        FOREIGN KEY ("recurring_expense_id") REFERENCES "recurring_expenses"("id") ON DELETE SET NULL
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`ALTER TABLE "expenses" DROP CONSTRAINT "FK_expenses_recurring_expense"`);
    await queryRunner.query(`DROP INDEX "public"."uq_expenses_recurring_schedule"`);
    await queryRunner.query(`
      ALTER TABLE "expenses"
        DROP COLUMN "recurring_scheduled_date",
        DROP COLUMN "recurring_expense_id"
    `);
    await queryRunner.query(`ALTER TABLE "recurring_expenses" DROP CONSTRAINT "FK_recurring_expenses_credit_card"`);
    await queryRunner.query(`ALTER TABLE "recurring_expenses" DROP CONSTRAINT "FK_recurring_expenses_cash_account"`);
    await queryRunner.query(`ALTER TABLE "recurring_expenses" DROP CONSTRAINT "FK_recurring_expenses_category"`);
    await queryRunner.query(`ALTER TABLE "recurring_expenses" DROP CONSTRAINT "FK_recurring_expenses_user"`);
    await queryRunner.query(`DROP INDEX "public"."idx_recurring_expenses_user_active_next"`);
    await queryRunner.query(`DROP TABLE "recurring_expenses"`);
    await queryRunner.query(`DROP TYPE "public"."recurring_expenses_frequency_enum"`);
  }
}
