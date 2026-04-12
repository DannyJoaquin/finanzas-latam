import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddCreditCardPayments1776000000000 implements MigrationInterface {
  name = 'AddCreditCardPayments1776000000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`
      CREATE TABLE "credit_card_payments" (
        "id"           UUID              NOT NULL DEFAULT uuid_generate_v4(),
        "card_id"      UUID              NOT NULL,
        "user_id"      UUID              NOT NULL,
        "amount"       NUMERIC(12,2)     NOT NULL,
        "cycle_start"  DATE              NOT NULL,
        "cycle_end"    DATE              NOT NULL,
        "payment_date" DATE              NOT NULL,
        "notes"        TEXT,
        "created_at"   TIMESTAMP         NOT NULL DEFAULT now(),
        CONSTRAINT "PK_credit_card_payments" PRIMARY KEY ("id"),
        CONSTRAINT "FK_ccp_card"
          FOREIGN KEY ("card_id")
          REFERENCES "credit_cards"("id")
          ON DELETE CASCADE,
        CONSTRAINT "FK_ccp_user"
          FOREIGN KEY ("user_id")
          REFERENCES "users"("id")
          ON DELETE CASCADE
      )
    `);

    await queryRunner.query(
      `CREATE INDEX "idx_ccp_card_cycle" ON "credit_card_payments" ("card_id", "cycle_start", "cycle_end")`
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP INDEX "idx_ccp_card_cycle"`);
    await queryRunner.query(`DROP TABLE "credit_card_payments"`);
  }
}
