DROP INDEX "users_provider_uid_unique";
CREATE TABLE "user_notebook" (
    "id" UUID NOT NULL PRIMARY KEY,
    "slug" VARCHAR(255) NOT NULL,
    "title" VARCHAR(255) NOT NULL,
    "summary" VARCHAR(500),
    "body_md" TEXT NOT NULL,
    "cells" JSONB NOT NULL,
    "status" VARCHAR(32) NOT NULL,
    "published_at" TIMESTAMPTZ,
    "author_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ,
    "updated_at" TIMESTAMPTZ
);
CREATE UNIQUE INDEX "unique_user_notebook_slug" ON "user_notebook" ("slug");
CREATE INDEX "key_user_notebook_status_created_at" ON "user_notebook" ("status", "created_at");
CREATE INDEX "key_user_notebook_author_id_created_at" ON "user_notebook" ("author_id", "created_at");
