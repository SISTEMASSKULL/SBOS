-- ================================================================
-- DDL IDEMPOTENTE: Integridad referencial framework_unified ↔ bauth
-- Puede ejecutarse N veces sin errores
-- ================================================================

-- ─── 1. json_path único global (requisito para FKs) ───────────
CREATE UNIQUE INDEX IF NOT EXISTS uq_json_path_global ON framework_unified (json_path);

-- ─── 2. FK autoreferencial ─────────────────────────────────────
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_parent_path') THEN
    ALTER TABLE framework_unified ADD CONSTRAINT fk_parent_path
      FOREIGN KEY (parent_path, source) REFERENCES framework_unified (json_path, source) NOT VALID;
  END IF;
END;
$$;

-- ─── 3. NOT NULL constraints ───────────────────────────────────
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'framework_unified' AND column_name = 'depth' AND is_nullable = 'YES') THEN
    ALTER TABLE framework_unified ALTER COLUMN depth SET NOT NULL;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'framework_unified' AND column_name = 'order_index' AND is_nullable = 'YES') THEN
    ALTER TABLE framework_unified ALTER COLUMN order_index SET NOT NULL;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'framework_unified' AND column_name = 'content_en' AND is_nullable = 'YES') THEN
    ALTER TABLE framework_unified ALTER COLUMN content_en SET NOT NULL;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'framework_unified' AND column_name = 'content_es' AND is_nullable = 'YES') THEN
    ALTER TABLE framework_unified ALTER COLUMN content_es SET NOT NULL;
  END IF;
END;
$$;

-- ─── 4. CHECK constraints ──────────────────────────────────────
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_depth_min') THEN
    ALTER TABLE framework_unified ADD CONSTRAINT chk_depth_min CHECK (depth >= 1);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_order_min') THEN
    ALTER TABLE framework_unified ADD CONSTRAINT chk_order_min CHECK (order_index >= 1);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_array_min') THEN
    ALTER TABLE framework_unified ADD CONSTRAINT chk_array_min CHECK (array_index >= 0);
  END IF;
END;
$$;

-- ─── 5. Índices de filtrado ────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_unified_semantic ON framework_unified (semantic_type);
CREATE INDEX IF NOT EXISTS idx_unified_enforcement ON framework_unified (enforcement);
CREATE INDEX IF NOT EXISTS idx_unified_risk ON framework_unified (risk_level);
CREATE INDEX IF NOT EXISTS idx_unified_assurance ON framework_unified (assurance_level);
CREATE INDEX IF NOT EXISTS idx_unified_lifecycle ON framework_unified (lifecycle);
CREATE INDEX IF NOT EXISTS idx_unified_mfa ON framework_unified (mfa_required);
CREATE INDEX IF NOT EXISTS idx_unified_phish ON framework_unified (phishing_resistant);

-- ─── 6. FK desde bauth a library ───────────────────────────────
-- ath_policy_d1
DO $$
BEGIN
  ALTER TABLE bauth.ath_policy_d1 ADD COLUMN IF NOT EXISTS library_path text;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_policy_d1_library') THEN
    ALTER TABLE bauth.ath_policy_d1 ADD CONSTRAINT fk_policy_d1_library
      FOREIGN KEY (library_path) REFERENCES framework_unified (json_path) NOT VALID;
  END IF;
END;
$$;

-- ath_policy_d5
DO $$
BEGIN
  ALTER TABLE bauth.ath_policy_d5 ADD COLUMN IF NOT EXISTS library_path text;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_policy_d5_library') THEN
    ALTER TABLE bauth.ath_policy_d5 ADD CONSTRAINT fk_policy_d5_library
      FOREIGN KEY (library_path) REFERENCES framework_unified (json_path) NOT VALID;
  END IF;
END;
$$;

-- ath_config_d1
DO $$
BEGIN
  ALTER TABLE bauth.ath_config_d1 ADD COLUMN IF NOT EXISTS library_path text;
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_config_d1_library') THEN
    ALTER TABLE bauth.ath_config_d1 ADD CONSTRAINT fk_config_d1_library
      FOREIGN KEY (library_path) REFERENCES framework_unified (json_path) NOT VALID;
  END IF;
END;
$$;

-- ─── 7. Validar constraints creadas ────────────────────────────
SELECT
  conname AS constraint_name,
  CASE contype WHEN 'p' THEN 'PRIMARY KEY' WHEN 'f' THEN 'FOREIGN KEY' WHEN 'c' THEN 'CHECK' WHEN 'n' THEN 'NOT NULL' END AS type,
  convalidated
FROM pg_constraint
WHERE conrelid = 'framework_unified'::regclass
ORDER BY conname;

SELECT indexname FROM pg_indexes WHERE tablename = 'framework_unified' ORDER BY indexname;
