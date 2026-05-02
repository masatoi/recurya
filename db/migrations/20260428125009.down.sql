ALTER TABLE "users" DROP COLUMN "provider", DROP COLUMN "provider_uid";
ALTER TABLE "users" ALTER COLUMN "password_hash" TYPE character varying(255), ALTER COLUMN "password_hash" SET NOT NULL, ALTER COLUMN "password_salt" TYPE character varying(255), ALTER COLUMN "password_salt" SET NOT NULL;
