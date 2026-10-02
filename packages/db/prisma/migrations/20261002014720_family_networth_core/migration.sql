-- CreateEnum
CREATE TYPE "Currency" AS ENUM ('USD', 'INR');

-- CreateEnum
CREATE TYPE "CategoryKind" AS ENUM ('ASSET', 'LIABILITY');

-- CreateTable
CREATE TABLE "user" (
    "id" UUID NOT NULL,
    "auth_issuer" TEXT NOT NULL,
    "auth_subject" TEXT NOT NULL,
    "email" TEXT,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "user_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "households" (
    "id" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "reporting_currency" "Currency" NOT NULL,
    "time_zone" TEXT NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "households_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "household_members" (
    "id" UUID NOT NULL,
    "household_id" UUID NOT NULL,
    "user_id" UUID,
    "display_name" TEXT NOT NULL,
    "archived_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "household_members_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "categories" (
    "id" UUID NOT NULL,
    "code" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "kind" "CategoryKind" NOT NULL,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "is_active" BOOLEAN NOT NULL DEFAULT true,

    CONSTRAINT "categories_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "account_types" (
    "id" UUID NOT NULL,
    "category_id" UUID NOT NULL,
    "code" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "is_active" BOOLEAN NOT NULL DEFAULT true,

    CONSTRAINT "account_types_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "accounts" (
    "id" UUID NOT NULL,
    "household_id" UUID NOT NULL,
    "account_type_id" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "institution_name" TEXT,
    "identifier_last4" VARCHAR(4),
    "country_code" CHAR(2) NOT NULL,
    "currency" "Currency" NOT NULL,
    "balance" DECIMAL(19,2) NOT NULL,
    "balance_as_of" DATE NOT NULL,
    "notes" TEXT,
    "version" INTEGER NOT NULL DEFAULT 1,
    "archived_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "accounts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "account_ownerships" (
    "account_id" UUID NOT NULL,
    "member_id" UUID NOT NULL,
    "ownership_percent" DECIMAL(5,2) NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "account_ownerships_pkey" PRIMARY KEY ("account_id","member_id")
);

-- CreateTable
CREATE TABLE "exchange_rates" (
    "id" UUID NOT NULL,
    "household_id" UUID NOT NULL,
    "base_currency" "Currency" NOT NULL,
    "quote_currency" "Currency" NOT NULL,
    "rate" DECIMAL(24,12) NOT NULL,
    "effective_date" DATE NOT NULL,
    "source" TEXT NOT NULL DEFAULT 'MANUAL',
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "exchange_rates_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "net_worth_snapshots" (
    "id" UUID NOT NULL,
    "household_id" UUID NOT NULL,
    "snapshot_date" DATE NOT NULL,
    "reporting_currency" "Currency" NOT NULL,
    "calculation_version" INTEGER NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "net_worth_snapshots_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "snapshot_accounts" (
    "id" UUID NOT NULL,
    "snapshot_id" UUID NOT NULL,
    "account_id" UUID NOT NULL,
    "account_name" TEXT NOT NULL,
    "category_code" TEXT NOT NULL,
    "account_type_code" TEXT NOT NULL,
    "kind" "CategoryKind" NOT NULL,
    "country_code" CHAR(2) NOT NULL,
    "native_currency" "Currency" NOT NULL,
    "native_balance" DECIMAL(19,2) NOT NULL,
    "balance_as_of" DATE NOT NULL,
    "fx_rate_to_reporting" DECIMAL(24,12) NOT NULL,
    "fx_effective_date" DATE,
    "fx_source" TEXT NOT NULL,
    "reporting_balance" DECIMAL(19,2) NOT NULL,

    CONSTRAINT "snapshot_accounts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "snapshot_ownerships" (
    "snapshot_account_id" UUID NOT NULL,
    "member_id" UUID NOT NULL,
    "ownership_percent" DECIMAL(5,2) NOT NULL,
    "allocated_reporting_balance" DECIMAL(19,2) NOT NULL,

    CONSTRAINT "snapshot_ownerships_pkey" PRIMARY KEY ("snapshot_account_id","member_id")
);

-- CreateIndex
CREATE UNIQUE INDEX "user_auth_issuer_auth_subject_key" ON "user"("auth_issuer", "auth_subject");

-- CreateIndex
CREATE INDEX "household_members_household_id_archived_at_idx" ON "household_members"("household_id", "archived_at");

-- CreateIndex
CREATE INDEX "household_members_user_id_idx" ON "household_members"("user_id");

-- CreateIndex
CREATE UNIQUE INDEX "household_members_household_id_user_id_key" ON "household_members"("household_id", "user_id");

-- CreateIndex
CREATE UNIQUE INDEX "categories_code_key" ON "categories"("code");

-- CreateIndex
CREATE UNIQUE INDEX "account_types_code_key" ON "account_types"("code");

-- CreateIndex
CREATE INDEX "account_types_category_id_idx" ON "account_types"("category_id");

-- CreateIndex
CREATE INDEX "accounts_household_id_archived_at_idx" ON "accounts"("household_id", "archived_at");

-- CreateIndex
CREATE INDEX "accounts_account_type_id_idx" ON "accounts"("account_type_id");

-- CreateIndex
CREATE INDEX "account_ownerships_member_id_idx" ON "account_ownerships"("member_id");

-- CreateIndex
CREATE UNIQUE INDEX "exchange_rates_household_id_base_currency_quote_currency_ef_key" ON "exchange_rates"("household_id", "base_currency", "quote_currency", "effective_date");

-- CreateIndex
CREATE UNIQUE INDEX "net_worth_snapshots_household_id_snapshot_date_key" ON "net_worth_snapshots"("household_id", "snapshot_date");

-- CreateIndex
CREATE INDEX "snapshot_accounts_account_id_idx" ON "snapshot_accounts"("account_id");

-- CreateIndex
CREATE UNIQUE INDEX "snapshot_accounts_snapshot_id_account_id_key" ON "snapshot_accounts"("snapshot_id", "account_id");

-- CreateIndex
CREATE INDEX "snapshot_ownerships_member_id_idx" ON "snapshot_ownerships"("member_id");

-- AddForeignKey
ALTER TABLE "household_members" ADD CONSTRAINT "household_members_household_id_fkey" FOREIGN KEY ("household_id") REFERENCES "households"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "household_members" ADD CONSTRAINT "household_members_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "user"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "account_types" ADD CONSTRAINT "account_types_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "categories"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "accounts" ADD CONSTRAINT "accounts_household_id_fkey" FOREIGN KEY ("household_id") REFERENCES "households"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "accounts" ADD CONSTRAINT "accounts_account_type_id_fkey" FOREIGN KEY ("account_type_id") REFERENCES "account_types"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "account_ownerships" ADD CONSTRAINT "account_ownerships_account_id_fkey" FOREIGN KEY ("account_id") REFERENCES "accounts"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "account_ownerships" ADD CONSTRAINT "account_ownerships_member_id_fkey" FOREIGN KEY ("member_id") REFERENCES "household_members"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "exchange_rates" ADD CONSTRAINT "exchange_rates_household_id_fkey" FOREIGN KEY ("household_id") REFERENCES "households"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "net_worth_snapshots" ADD CONSTRAINT "net_worth_snapshots_household_id_fkey" FOREIGN KEY ("household_id") REFERENCES "households"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "snapshot_accounts" ADD CONSTRAINT "snapshot_accounts_snapshot_id_fkey" FOREIGN KEY ("snapshot_id") REFERENCES "net_worth_snapshots"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "snapshot_accounts" ADD CONSTRAINT "snapshot_accounts_account_id_fkey" FOREIGN KEY ("account_id") REFERENCES "accounts"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "snapshot_ownerships" ADD CONSTRAINT "snapshot_ownerships_snapshot_account_id_fkey" FOREIGN KEY ("snapshot_account_id") REFERENCES "snapshot_accounts"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "snapshot_ownerships" ADD CONSTRAINT "snapshot_ownerships_member_id_fkey" FOREIGN KEY ("member_id") REFERENCES "household_members"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- Financial ownership bounds
ALTER TABLE "account_ownerships"
  ADD CONSTRAINT "account_ownerships_percent_range"
  CHECK ("ownership_percent" > 0 AND "ownership_percent" <= 100);

ALTER TABLE "snapshot_ownerships"
  ADD CONSTRAINT "snapshot_ownerships_percent_range"
  CHECK ("ownership_percent" > 0 AND "ownership_percent" <= 100);

-- Account concurrency version
ALTER TABLE "accounts"
  ADD CONSTRAINT "accounts_version_positive"
  CHECK ("version" >= 1);

-- Canonical USD-to-INR exchange rates
ALTER TABLE "exchange_rates"
  ADD CONSTRAINT "exchange_rates_rate_positive"
  CHECK ("rate" > 0 AND "rate" <> 'NaN'::numeric),
  ADD CONSTRAINT "exchange_rates_currency_pair"
  CHECK ("base_currency" = 'USD' AND "quote_currency" = 'INR');

-- Snapshot calculation metadata
ALTER TABLE "net_worth_snapshots"
  ADD CONSTRAINT "snapshots_calculation_version_positive"
  CHECK ("calculation_version" >= 1);

ALTER TABLE "snapshot_accounts"
  ADD CONSTRAINT "snapshot_accounts_fx_rate_positive"
  CHECK (
    "fx_rate_to_reporting" > 0
    AND "fx_rate_to_reporting" <> 'NaN'::numeric
  );

-- Monetary values must be valid numbers; negative balances are allowed.
ALTER TABLE "accounts"
  ADD CONSTRAINT "accounts_balance_valid"
  CHECK ("balance" <> 'NaN'::numeric);

ALTER TABLE "snapshot_accounts"
  ADD CONSTRAINT "snapshot_accounts_balances_valid"
  CHECK (
    "native_balance" <> 'NaN'::numeric
    AND "reporting_balance" <> 'NaN'::numeric
  );

ALTER TABLE "snapshot_ownerships"
  ADD CONSTRAINT "snapshot_ownerships_amount_valid"
  CHECK ("allocated_reporting_balance" <> 'NaN'::numeric);