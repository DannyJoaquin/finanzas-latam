import { MigrationInterface, QueryRunner } from 'typeorm';

// Generalizes cash_accounts/cash_transactions into a unified accounts model
// that also covers checking/savings/locked-savings/pension accounts. Table
// renames preserve all existing rows, ids, and FK constraints untouched
// (Postgres RENAME TO carries constraints/indexes across automatically) —
// every pre-existing account becomes type='cash', which is factually correct
// for 100% of data created before this migration.
export class GeneralizeAccountsModel1776700000000 implements MigrationInterface {
  name = 'GeneralizeAccountsModel1776700000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // 1. Rename tables — ids, FKs (FK_36bcc7382992e4271085acf5d1e on user_id,
    // FK_05adf6524c0a3297125bdb5402a from expenses, FK_recurring_expenses_cash_account
    // from recurring_expenses), and indexes all survive the rename.
    await queryRunner.query(`ALTER TABLE "cash_accounts" RENAME TO "accounts"`);
    await queryRunner.query(
      `ALTER TABLE "cash_transactions" RENAME TO "account_transactions"`,
    );

    // 2. Rename the FK column on account_transactions to match the new
    // owning entity name (account_transactions.cash_account_id -> account_id).
    await queryRunner.query(
      `ALTER TABLE "account_transactions" RENAME COLUMN "cash_account_id" TO "account_id"`,
    );

    // 3. New account_type enum + column, defaulted to 'cash' for existing rows.
    await queryRunner.query(`
      CREATE TYPE "public"."accounts_type_enum"
      AS ENUM ('cash', 'checking', 'savings', 'locked_savings', 'pension', 'other')
    `);
    await queryRunner.query(`
      ALTER TABLE "accounts"
        ADD COLUMN "type" "public"."accounts_type_enum" NOT NULL DEFAULT 'cash'
    `);

    // 4. New nullable/defaulted columns for type-specific account properties.
    await queryRunner.query(`
      ALTER TABLE "accounts"
        ADD COLUMN "institution" character varying(100),
        ADD COLUMN "is_available_for_expenses" boolean NOT NULL DEFAULT true,
        ADD COLUMN "is_locked" boolean NOT NULL DEFAULT false,
        ADD COLUMN "locked_until" date,
        ADD COLUMN "interest_rate_annual" numeric(5,2),
        ADD COLUMN "opened_at" date
    `);

    // 5. Note: expenses.cash_account_id and recurring_expenses.cash_account_id
    // physical column names are intentionally left unchanged — only the
    // TypeORM entity property/relation type is repointed to Account. Their
    // existing FK constraints (FK_05adf6524c0a3297125bdb5402a,
    // FK_recurring_expenses_cash_account) already reference "accounts"("id")
    // automatically since the table rename above updates the FK target too.
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      ALTER TABLE "accounts"
        DROP COLUMN "opened_at",
        DROP COLUMN "interest_rate_annual",
        DROP COLUMN "locked_until",
        DROP COLUMN "is_locked",
        DROP COLUMN "is_available_for_expenses",
        DROP COLUMN "institution"
    `);
    await queryRunner.query(`ALTER TABLE "accounts" DROP COLUMN "type"`);
    await queryRunner.query(`DROP TYPE "public"."accounts_type_enum"`);

    await queryRunner.query(
      `ALTER TABLE "account_transactions" RENAME COLUMN "account_id" TO "cash_account_id"`,
    );
    await queryRunner.query(
      `ALTER TABLE "account_transactions" RENAME TO "cash_transactions"`,
    );
    await queryRunner.query(`ALTER TABLE "accounts" RENAME TO "cash_accounts"`);
  }
}
