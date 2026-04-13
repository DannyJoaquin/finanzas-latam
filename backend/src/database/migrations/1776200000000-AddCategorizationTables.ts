import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddCategorizationTables1776200000000 implements MigrationInterface {
  name = 'AddCategorizationTables1776200000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // ── Mapping match type enum ──────────────────────────────────────────
    await queryRunner.query(`
      CREATE TYPE "mapping_match_type_enum" AS ENUM ('exact', 'partial', 'learned')
    `);

    // ── user_category_mappings ───────────────────────────────────────────
    await queryRunner.query(`
      CREATE TABLE "user_category_mappings" (
        "id"              UUID          NOT NULL DEFAULT uuid_generate_v4(),
        "user_id"         UUID          NOT NULL,
        "normalized_text" VARCHAR(255)  NOT NULL,
        "original_text"   VARCHAR(255)  NOT NULL,
        "category_id"     UUID          NOT NULL,
        "match_type"      "mapping_match_type_enum" NOT NULL DEFAULT 'learned',
        "usage_count"     INTEGER       NOT NULL DEFAULT 1,
        "is_confirmed"    BOOLEAN       NOT NULL DEFAULT false,
        "last_used_at"    TIMESTAMP,
        "created_at"      TIMESTAMP     NOT NULL DEFAULT now(),
        "updated_at"      TIMESTAMP     NOT NULL DEFAULT now(),
        CONSTRAINT "PK_ucm" PRIMARY KEY ("id"),
        CONSTRAINT "FK_ucm_user"
          FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE,
        CONSTRAINT "FK_ucm_category"
          FOREIGN KEY ("category_id") REFERENCES "categories"("id") ON DELETE CASCADE
      )
    `);

    await queryRunner.query(`
      CREATE INDEX "idx_ucm_user_text"
        ON "user_category_mappings" ("user_id", "normalized_text")
    `);

    // ── categorization_audit_logs ────────────────────────────────────────
    await queryRunner.query(`
      CREATE TABLE "categorization_audit_logs" (
        "id"                    UUID        NOT NULL DEFAULT uuid_generate_v4(),
        "user_id"               UUID        NOT NULL,
        "expense_id"            UUID,
        "description"           TEXT,
        "suggested_category_id" UUID,
        "final_category_id"     UUID,
        "confidence"            VARCHAR(10) NOT NULL DEFAULT 'none',
        "source"                VARCHAR(30) NOT NULL DEFAULT 'none',
        "matched_keyword"       VARCHAR(100),
        "was_auto_assigned"     BOOLEAN     NOT NULL DEFAULT false,
        "was_corrected"         BOOLEAN     NOT NULL DEFAULT false,
        "created_at"            TIMESTAMP   NOT NULL DEFAULT now(),
        CONSTRAINT "PK_cal" PRIMARY KEY ("id"),
        CONSTRAINT "FK_cal_user"
          FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE,
        CONSTRAINT "FK_cal_suggested_cat"
          FOREIGN KEY ("suggested_category_id") REFERENCES "categories"("id") ON DELETE SET NULL,
        CONSTRAINT "FK_cal_final_cat"
          FOREIGN KEY ("final_category_id") REFERENCES "categories"("id") ON DELETE SET NULL
      )
    `);

    await queryRunner.query(`
      CREATE INDEX "idx_cal_user_created"
        ON "categorization_audit_logs" ("user_id", "created_at")
    `);

    await queryRunner.query(`
      CREATE INDEX "idx_cal_expense"
        ON "categorization_audit_logs" ("expense_id")
    `);
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP INDEX "idx_cal_expense"`);
    await queryRunner.query(`DROP INDEX "idx_cal_user_created"`);
    await queryRunner.query(`DROP TABLE "categorization_audit_logs"`);
    await queryRunner.query(`DROP INDEX "idx_ucm_user_text"`);
    await queryRunner.query(`DROP TABLE "user_category_mappings"`);
    await queryRunner.query(`DROP TYPE "mapping_match_type_enum"`);
  }
}
