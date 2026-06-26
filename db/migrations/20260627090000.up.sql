-- Add novel_state table for per-reader novel progress (flags + scene index).
--
-- Per-(user, notebook) playthrough state for the novel engine:
--   * flags:       JSON object string of reader flags.
--   * scene_index: current scene position.

CREATE TABLE "novel_state" (
    "id" BIGSERIAL NOT NULL PRIMARY KEY,
    "user_id" UUID NOT NULL,
    "notebook_id" VARCHAR(64) NOT NULL,
    "flags" TEXT NOT NULL,
    "scene_index" INTEGER NOT NULL,
    "created_at" TIMESTAMPTZ,
    "updated_at" TIMESTAMPTZ
);
CREATE INDEX "key_novel_state_user_id_notebook_id" ON "novel_state" ("user_id", "notebook_id");
CREATE UNIQUE INDEX "unique_novel_state_user_id_notebook_id" ON "novel_state" ("user_id", "notebook_id");
