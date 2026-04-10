import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddCreditCardsModule1775800000000 implements MigrationInterface {
  name = 'AddCreditCardsModule1775800000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // 1. Create card_network enum
    await queryRunner.query(`
      CREATE TYPE "public"."credit_cards_network_enum"
      AS ENUM ('visa', 'mastercard', 'amex', 'other')
    `);

    // 2. Create credit_cards table
    await queryRunner.query(`
      CREATE TABLE "credit_cards" (
        "id"               uuid                                     NOT NULL DEFAULT uuid_generate_v4(),
        "user_id"          uuid                                     NOT NULL,
        "name"             character varying(100)                   NOT NULL,
        "network"          "public"."credit_cards_network_enum"     NOT NULL DEFAULT 'other',
        "cut_off_day"      smallint                                 NOT NULL,
        "payment_due_days" smallint                                 NOT NULL DEFAULT 20,
        "credit_limit"     numeric(12,2),
        "color"            character varying(7),
        "is_active"        boolean                                  NOT NULL DEFAULT true,
        "created_at"       TIMESTAMP                                NOT NULL DEFAULT now(),
        CONSTRAINT "PK_credit_cards" PRIMARY KEY ("id")
      )
    `);

    // 3. FK credit_cards → users
    await queryRunner.query(`
      ALTER TABLE "credit_cards"
        ADD CONSTRAINT "FK_credit_cards_user"
        FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE
    `);

    // 4. Add credit_card_id column to expenses
    await queryRunner.query(`
      ALTER TABLE "expenses"
        ADD COLUMN IF NOT EXISTS "credit_card_id" uuid
    `);

    // 5. FK expenses → credit_cards
    await queryRunner.query(`
      ALTER TABLE "expenses"
        ADD CONSTRAINT "FK_expenses_credit_card"
        FOREIGN KEY ("credit_card_id") REFERENCES "credit_cards"("id") ON DELETE SET NULL
    `);

    // 6. Index for fast per-card queries
    await queryRunner.query(`
      CREATE INDEX "idx_expenses_credit_card" ON "expenses" ("credit_card_id")
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP INDEX IF EXISTS "idx_expenses_credit_card"`);
    await queryRunner.query(`ALTER TABLE "expenses" DROP CONSTRAINT IF EXISTS "FK_expenses_credit_card"`);
    await queryRunner.query(`ALTER TABLE "expenses" DROP COLUMN IF EXISTS "credit_card_id"`);
    await queryRunner.query(`ALTER TABLE "credit_cards" DROP CONSTRAINT IF EXISTS "FK_credit_cards_user"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "credit_cards"`);
    await queryRunner.query(`DROP TYPE IF EXISTS "public"."credit_cards_network_enum"`);
  }
}
