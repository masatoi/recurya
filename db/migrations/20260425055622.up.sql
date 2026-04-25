CREATE TABLE "learn_submission" (
    "id" BIGSERIAL NOT NULL PRIMARY KEY,
    "user_id" UUID NOT NULL,
    "notebook_id" VARCHAR(64) NOT NULL,
    "cell_id" VARCHAR(64) NOT NULL,
    "code" TEXT NOT NULL,
    "status" VARCHAR(16) NOT NULL,
    "created_at" TIMESTAMPTZ,
    "updated_at" TIMESTAMPTZ
);
CREATE INDEX "key_learn_submission_user_id_notebook_id_cell_id" ON "learn_submission" ("user_id", "notebook_id", "cell_id");
CREATE TABLE "learn_cell_code" (
    "id" BIGSERIAL NOT NULL PRIMARY KEY,
    "user_id" UUID NOT NULL,
    "notebook_id" VARCHAR(64) NOT NULL,
    "cell_id" VARCHAR(64) NOT NULL,
    "code" TEXT NOT NULL,
    "created_at" TIMESTAMPTZ,
    "updated_at" TIMESTAMPTZ
);
CREATE UNIQUE INDEX "unique_learn_cell_code_user_id_notebook_id_cell_id" ON "learn_cell_code" ("user_id", "notebook_id", "cell_id");
CREATE INDEX "key_learn_cell_code_user_id_notebook_id" ON "learn_cell_code" ("user_id", "notebook_id");
CREATE TABLE "learn_progress" (
    "id" BIGSERIAL NOT NULL PRIMARY KEY,
    "user_id" UUID NOT NULL,
    "notebook_id" VARCHAR(64) NOT NULL,
    "cell_id" VARCHAR(64) NOT NULL,
    "passed_at" TIMESTAMPTZ NOT NULL,
    "created_at" TIMESTAMPTZ,
    "updated_at" TIMESTAMPTZ
);
CREATE UNIQUE INDEX "unique_learn_progress_user_id_notebook_id_cell_id" ON "learn_progress" ("user_id", "notebook_id", "cell_id");
CREATE INDEX "key_learn_progress_user_id_notebook_id" ON "learn_progress" ("user_id", "notebook_id");
