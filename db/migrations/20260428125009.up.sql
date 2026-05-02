ALTER TABLE "users" ADD COLUMN "provider" character varying(16), ADD COLUMN "provider_uid" character varying(64);
ALTER TABLE "users" ALTER COLUMN "password_hash" TYPE character varying(255), ALTER COLUMN "password_hash" DROP NOT NULL, ALTER COLUMN "password_salt" TYPE character varying(255), ALTER COLUMN "password_salt" DROP NOT NULL;
