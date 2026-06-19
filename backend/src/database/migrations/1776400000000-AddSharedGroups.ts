import { MigrationInterface, QueryRunner } from 'typeorm';

export class AddSharedGroups1776400000000 implements MigrationInterface {
  name = 'AddSharedGroups1776400000000';

  public async up(queryRunner: QueryRunner): Promise<void> {
    // ── shared_groups ────────────────────────────────────────────────────────
    await queryRunner.query(`
      CREATE TABLE "shared_groups" (
        "id"          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        "owner_id"    UUID NOT NULL REFERENCES "users"("id") ON DELETE CASCADE,
        "name"        VARCHAR(120) NOT NULL,
        "description" VARCHAR(300),
        "currency"    CHAR(3) NOT NULL DEFAULT 'HNL',
        "invite_code" VARCHAR(8) NOT NULL UNIQUE,
        "is_active"   BOOLEAN NOT NULL DEFAULT TRUE,
        "created_at"  TIMESTAMPTZ NOT NULL DEFAULT now(),
        "updated_at"  TIMESTAMPTZ NOT NULL DEFAULT now()
      )
    `);
    await queryRunner.query(
      `CREATE INDEX "idx_shared_groups_owner" ON "shared_groups" ("owner_id")`
    );

    // ── shared_group_members ─────────────────────────────────────────────────
    await queryRunner.query(`
      CREATE TYPE "shared_group_member_status_enum" AS ENUM ('active', 'removed', 'left')
    `);
    await queryRunner.query(`
      CREATE TABLE "shared_group_members" (
        "id"         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        "group_id"   UUID NOT NULL REFERENCES "shared_groups"("id") ON DELETE CASCADE,
        "user_id"    UUID NOT NULL REFERENCES "users"("id") ON DELETE CASCADE,
        "status"     "shared_group_member_status_enum" NOT NULL DEFAULT 'active',
        "joined_at"  TIMESTAMPTZ NOT NULL DEFAULT now(),
        UNIQUE ("group_id", "user_id")
      )
    `);
    await queryRunner.query(
      `CREATE INDEX "idx_shared_group_members_user" ON "shared_group_members" ("user_id")`
    );

    // ── shared_group_invites ─────────────────────────────────────────────────
    await queryRunner.query(`
      CREATE TABLE "shared_group_invites" (
        "id"         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        "group_id"   UUID NOT NULL REFERENCES "shared_groups"("id") ON DELETE CASCADE,
        "code"       VARCHAR(8) NOT NULL,
        "max_uses"   INTEGER NOT NULL DEFAULT 50,
        "uses"       INTEGER NOT NULL DEFAULT 0,
        "expires_at" TIMESTAMPTZ,
        "is_active"  BOOLEAN NOT NULL DEFAULT TRUE,
        "created_at" TIMESTAMPTZ NOT NULL DEFAULT now()
      )
    `);

    // ── shared_expenses ──────────────────────────────────────────────────────
    await queryRunner.query(`
      CREATE TYPE "shared_expense_payment_method_enum" AS ENUM ('cash', 'card_credit', 'card_debit', 'transfer', 'other')
    `);
    await queryRunner.query(`
      CREATE TABLE "shared_expenses" (
        "id"             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        "group_id"       UUID NOT NULL REFERENCES "shared_groups"("id") ON DELETE CASCADE,
        "payer_id"       UUID NOT NULL REFERENCES "users"("id"),
        "total_amount"   NUMERIC(12,2) NOT NULL,
        "currency"       CHAR(3) NOT NULL DEFAULT 'HNL',
        "description"    VARCHAR(255) NOT NULL,
        "category_label" VARCHAR(100),
        "payment_method" "shared_expense_payment_method_enum" NOT NULL DEFAULT 'cash',
        "note"           TEXT,
        "date"           DATE NOT NULL,
        "created_at"     TIMESTAMPTZ NOT NULL DEFAULT now()
      )
    `);
    await queryRunner.query(
      `CREATE INDEX "idx_shared_expenses_group" ON "shared_expenses" ("group_id")`
    );
    await queryRunner.query(
      `CREATE INDEX "idx_shared_expenses_payer" ON "shared_expenses" ("payer_id")`
    );

    // ── shared_expense_participants ──────────────────────────────────────────
    await queryRunner.query(`
      CREATE TABLE "shared_expense_participants" (
        "id"           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        "expense_id"   UUID NOT NULL REFERENCES "shared_expenses"("id") ON DELETE CASCADE,
        "user_id"      UUID NOT NULL REFERENCES "users"("id"),
        "share_amount" NUMERIC(12,2) NOT NULL,
        "is_settled"   BOOLEAN NOT NULL DEFAULT FALSE,
        UNIQUE ("expense_id", "user_id")
      )
    `);
    await queryRunner.query(
      `CREATE INDEX "idx_sep_user" ON "shared_expense_participants" ("user_id")`
    );

    // ── shared_settlements ───────────────────────────────────────────────────
    await queryRunner.query(`
      CREATE TYPE "shared_settlement_payment_method_enum" AS ENUM ('cash', 'transfer', 'other')
    `);
    await queryRunner.query(`
      CREATE TABLE "shared_settlements" (
        "id"             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        "group_id"       UUID NOT NULL REFERENCES "shared_groups"("id") ON DELETE CASCADE,
        "payer_id"       UUID NOT NULL REFERENCES "users"("id"),
        "receiver_id"    UUID NOT NULL REFERENCES "users"("id"),
        "amount"         NUMERIC(12,2) NOT NULL,
        "payment_method" "shared_settlement_payment_method_enum" NOT NULL DEFAULT 'cash',
        "note"           TEXT,
        "date"           DATE NOT NULL,
        "created_at"     TIMESTAMPTZ NOT NULL DEFAULT now()
      )
    `);
    await queryRunner.query(
      `CREATE INDEX "idx_shared_settlements_group" ON "shared_settlements" ("group_id")`
    );
  }

  public async down(queryRunner: QueryRunner): Promise<void> {
    await queryRunner.query(`DROP TABLE IF EXISTS "shared_settlements"`);
    await queryRunner.query(`DROP TYPE IF EXISTS "shared_settlement_payment_method_enum"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "shared_expense_participants"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "shared_expenses"`);
    await queryRunner.query(`DROP TYPE IF EXISTS "shared_expense_payment_method_enum"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "shared_group_invites"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "shared_group_members"`);
    await queryRunner.query(`DROP TYPE IF EXISTS "shared_group_member_status_enum"`);
    await queryRunner.query(`DROP TABLE IF EXISTS "shared_groups"`);
  }
}
