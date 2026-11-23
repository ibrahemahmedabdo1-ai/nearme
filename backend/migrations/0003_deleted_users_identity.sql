-- Account deletion nulls email/google_sub, so the "has an identity" rule must not apply to deleted accounts.
DO $$ DECLARE c text; BEGIN
  SELECT conname INTO c FROM pg_constraint WHERE conrelid='users'::regclass AND contype='c' AND pg_get_constraintdef(oid) LIKE '%google_sub IS NOT NULL%';
  IF c IS NOT NULL THEN EXECUTE format('ALTER TABLE users DROP CONSTRAINT %I', c); END IF;
END $$;
ALTER TABLE users ADD CONSTRAINT users_identity_present CHECK (status = 'deleted' OR email IS NOT NULL OR google_sub IS NOT NULL);
