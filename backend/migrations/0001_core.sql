-- NEAR ME core schema. Forward-only, applied in a transaction by scripts/migrate.ts
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS citext;

CREATE TYPE user_role AS ENUM ('customer','support','admin','owner');
CREATE TYPE account_status AS ENUM ('active','hidden','suspended','banned','deleted');

CREATE TABLE users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  member_code bigint GENERATED ALWAYS AS IDENTITY (START 20000000) UNIQUE NOT NULL,  -- permanent public member ID
  email citext UNIQUE,
  email_verified_at timestamptz,
  google_sub text UNIQUE,
  password_hash text,
  role user_role NOT NULL DEFAULT 'customer',
  status account_status NOT NULL DEFAULT 'active',
  is_anonymous_account boolean NOT NULL DEFAULT false,   -- only Owner may create
  display_name text NOT NULL CHECK (char_length(display_name) BETWEEN 2 AND 40),
  birthdate date NOT NULL CHECK (birthdate <= (CURRENT_DATE - INTERVAL '18 years')),
  gender text, bio text CHECK (char_length(bio) <= 500),
  country_code char(2), lat_cell double precision, lon_cell double precision,   -- coarse location only
  hidden_until timestamptz, last_seen_at timestamptz,
  trust_score smallint NOT NULL DEFAULT 50 CHECK (trust_score BETWEEN 0 AND 100),
  totp_secret_enc text, pin_hash text, decoy_pin_hash text,
  created_at timestamptz NOT NULL DEFAULT now(), deleted_at timestamptz,
  CHECK (email IS NOT NULL OR google_sub IS NOT NULL)
);
CREATE INDEX users_status_idx ON users(status);
CREATE INDEX users_geo_idx ON users(country_code, lat_cell, lon_cell) WHERE status='active';
-- exactly one owner can ever exist
CREATE UNIQUE INDEX one_owner ON users((role)) WHERE role='owner';

CREATE TABLE devices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  install_id_hash text NOT NULL,         -- hash of app-generated install id (no IMEI, no hardware serials)
  attestation_status text NOT NULL DEFAULT 'unverified' CHECK (attestation_status IN ('unverified','passed','failed')),
  platform text NOT NULL DEFAULT 'android', model text, app_version text, fcm_token text,
  revoked_at timestamptz, first_seen_at timestamptz NOT NULL DEFAULT now(), last_seen_at timestamptz
);
-- one ACTIVE account per device
CREATE UNIQUE INDEX one_account_per_device ON devices(install_id_hash) WHERE revoked_at IS NULL;
CREATE INDEX devices_user_idx ON devices(user_id);

CREATE TABLE device_transfers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  new_install_id_hash text NOT NULL, status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected')),
  decided_by uuid REFERENCES users(id), decided_at timestamptz, created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  device_id uuid REFERENCES devices(id) ON DELETE SET NULL,
  family_id uuid NOT NULL DEFAULT gen_random_uuid(),
  refresh_hash text NOT NULL UNIQUE, replaced_by uuid, expires_at timestamptz NOT NULL,
  revoked_at timestamptz, created_at timestamptz NOT NULL DEFAULT now(), ip inet
);
CREATE INDEX sessions_user_idx ON sessions(user_id) WHERE revoked_at IS NULL;

CREATE TABLE email_tokens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  purpose text NOT NULL CHECK (purpose IN ('verify_email','reset_password')), token_hash text NOT NULL UNIQUE,
  expires_at timestamptz NOT NULL, used_at timestamptz
);

CREATE TABLE staff_permissions (
  user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE, permission text NOT NULL,
  granted_by uuid NOT NULL REFERENCES users(id), granted_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY (user_id, permission),
  CHECK (permission NOT IN ('ownership.transfer','owner.credentials','identity.view_secrets','emergency.control','accounts.manage_staff'))
);

CREATE TABLE interests (id serial PRIMARY KEY, slug text UNIQUE NOT NULL, name_en text NOT NULL, name_ar text NOT NULL);
CREATE TABLE user_interests (user_id uuid REFERENCES users(id) ON DELETE CASCADE, interest_id int REFERENCES interests(id), PRIMARY KEY (user_id, interest_id));
CREATE TABLE preferences (
  user_id uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  radius_km int CHECK (radius_km IN (1,5,10,25,50,100)) DEFAULT 25,   -- NULL = all distances
  min_age smallint NOT NULL DEFAULT 18 CHECK (min_age >= 18), max_age smallint NOT NULL DEFAULT 99,
  genders text[] NOT NULL DEFAULT '{}', verified_only boolean NOT NULL DEFAULT false,
  show_last_seen boolean NOT NULL DEFAULT true, read_receipts boolean NOT NULL DEFAULT true, show_online boolean NOT NULL DEFAULT true,
  temp_messages text NOT NULL DEFAULT 'off' CHECK (temp_messages IN ('off','24h','7d','30d')),
  pin_timeout_sec int, language text NOT NULL DEFAULT 'ar', theme_mode text NOT NULL DEFAULT 'system',
  push_enabled boolean NOT NULL DEFAULT true, occasion_push_enabled boolean NOT NULL DEFAULT true,
  CHECK (max_age >= min_age)
);

CREATE TABLE swipes (
  from_user uuid REFERENCES users(id) ON DELETE CASCADE, to_user uuid REFERENCES users(id) ON DELETE CASCADE,
  kind text NOT NULL CHECK (kind IN ('like','super_like','pass','favorite')), created_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (from_user, to_user, kind), CHECK (from_user <> to_user)
);
CREATE INDEX swipes_to_idx ON swipes(to_user, kind);
CREATE TABLE matches (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_a uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  user_b uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE, compat_score smallint, created_at timestamptz NOT NULL DEFAULT now(),
  CHECK (user_a < user_b), UNIQUE (user_a, user_b)
);
CREATE TABLE blocks (blocker uuid REFERENCES users(id) ON DELETE CASCADE, blocked uuid REFERENCES users(id) ON DELETE CASCADE, created_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY (blocker, blocked), CHECK (blocker <> blocked));

CREATE TABLE conversations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_a uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  user_b uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE, kind text NOT NULL DEFAULT 'intro' CHECK (kind IN ('intro','match')),
  intro_status text NOT NULL DEFAULT 'pending' CHECK (intro_status IN ('pending','accepted','rejected')),
  initiator uuid NOT NULL REFERENCES users(id), created_at timestamptz NOT NULL DEFAULT now(),
  CHECK (user_a < user_b), UNIQUE (user_a, user_b)     -- one conversation per pair: a new request can never reset the intro counter
);
CREATE TABLE messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), conversation_id uuid NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  sender_id uuid NOT NULL REFERENCES users(id), kind text NOT NULL CHECK (kind IN ('text','image','gif','sticker','file','location')),
  body text CHECK (char_length(body) <= 4000), attachment_id uuid, reply_to uuid REFERENCES messages(id),
  sent_at timestamptz NOT NULL DEFAULT now(), delivered_at timestamptz, read_at timestamptz, expires_at timestamptz,
  deleted_for_all_at timestamptz, pinned boolean NOT NULL DEFAULT false
);
CREATE INDEX messages_conv_idx ON messages(conversation_id, sent_at DESC);
CREATE INDEX messages_expiry_idx ON messages(expires_at) WHERE expires_at IS NOT NULL;
CREATE TABLE message_deletions (message_id uuid REFERENCES messages(id) ON DELETE CASCADE, user_id uuid REFERENCES users(id) ON DELETE CASCADE, PRIMARY KEY (message_id, user_id));
CREATE TABLE message_reactions (message_id uuid REFERENCES messages(id) ON DELETE CASCADE, user_id uuid REFERENCES users(id) ON DELETE CASCADE, emoji text NOT NULL, PRIMARY KEY (message_id, user_id));

CREATE TABLE attachments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), owner_id uuid NOT NULL REFERENCES users(id), storage_key text NOT NULL UNIQUE,   -- object storage key; bytes never in Postgres
  mime text NOT NULL, size_bytes bigint NOT NULL CHECK (size_bytes > 0), sha256 text NOT NULL,
  scan_status text NOT NULL DEFAULT 'pending' CHECK (scan_status IN ('pending','clean','infected','error')), created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE messages ADD FOREIGN KEY (attachment_id) REFERENCES attachments(id);

CREATE TABLE ratings (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), rater uuid NOT NULL REFERENCES users(id), ratee uuid NOT NULL REFERENCES users(id), conversation_id uuid NOT NULL REFERENCES conversations(id), stars smallint NOT NULL CHECK (stars BETWEEN 1 AND 5), comment text, created_at timestamptz NOT NULL DEFAULT now(), UNIQUE (rater, ratee, conversation_id), CHECK (rater <> ratee));

CREATE TABLE reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), reporter uuid NOT NULL REFERENCES users(id), target_user uuid NOT NULL REFERENCES users(id),
  message_id uuid REFERENCES messages(id), category text NOT NULL, details text, status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','reviewing','actioned','dismissed')),
  assigned_to uuid REFERENCES users(id), created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE punishments (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL REFERENCES users(id), kind text NOT NULL CHECK (kind IN ('warning','message_restriction','like_restriction','suspension','ban')),
  points smallint NOT NULL DEFAULT 0, reason text NOT NULL, starts_at timestamptz NOT NULL DEFAULT now(), ends_at timestamptz,
  issued_by uuid NOT NULL REFERENCES users(id), report_id uuid REFERENCES reports(id), revoked_at timestamptz
);
CREATE TABLE appeals (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), punishment_id uuid NOT NULL REFERENCES punishments(id), user_id uuid NOT NULL REFERENCES users(id), text text NOT NULL, status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','upheld','overturned')), reviewed_by uuid REFERENCES users(id), owner_final boolean NOT NULL DEFAULT false, created_at timestamptz NOT NULL DEFAULT now());

CREATE TABLE verifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL REFERENCES users(id), method text NOT NULL CHECK (method IN ('profile_image','live_selfie','id_document')),
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','support_reviewed','approved','rejected','appealed')),
  ai_confidence numeric(4,3), ai_reason_codes text[], evidence_storage_key text, evidence_delete_after timestamptz,
  reviewed_by uuid REFERENCES users(id), approved_by uuid REFERENCES users(id), created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE ai_findings (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid REFERENCES users(id), kind text NOT NULL, confidence numeric(4,3) NOT NULL, reason_codes text[] NOT NULL, evidence jsonb NOT NULL DEFAULT '{}', status text NOT NULL DEFAULT 'needs_review' CHECK (status IN ('needs_review','confirmed','dismissed')), reviewed_by uuid REFERENCES users(id), created_at timestamptz NOT NULL DEFAULT now());

CREATE TABLE tickets (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid REFERENCES users(id), subject text NOT NULL, status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','pending','escalated','closed')), assigned_to uuid REFERENCES users(id), created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE ticket_messages (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), ticket_id uuid NOT NULL REFERENCES tickets(id) ON DELETE CASCADE, author uuid REFERENCES users(id), identity text NOT NULL DEFAULT 'support' CHECK (identity IN ('support','admin','anonymous','customer')), internal_note boolean NOT NULL DEFAULT false, body text NOT NULL, created_at timestamptz NOT NULL DEFAULT now());

CREATE TABLE app_config (key text PRIMARY KEY, value jsonb NOT NULL, updated_by uuid REFERENCES users(id), updated_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE config_versions (id bigserial PRIMARY KEY, scope text NOT NULL, state text NOT NULL CHECK (state IN ('draft','published','rolled_back')), payload jsonb NOT NULL, created_by uuid NOT NULL REFERENCES users(id), created_at timestamptz NOT NULL DEFAULT now(), published_at timestamptz);
CREATE TABLE themes (id text PRIMARY KEY, name text NOT NULL, tokens jsonb NOT NULL, is_seasonal boolean NOT NULL DEFAULT false, active_from timestamptz, active_to timestamptz, countries char(2)[]);
CREATE TABLE occasions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), name text NOT NULL, starts_at timestamptz NOT NULL, ends_at timestamptz, recurrence text NOT NULL DEFAULT 'none' CHECK (recurrence IN ('none','yearly')),
  countries char(2)[], languages text[], image_key text, message jsonb NOT NULL, send_push boolean NOT NULL DEFAULT false, send_in_app boolean NOT NULL DEFAULT true, theme_id text REFERENCES themes(id), audience jsonb NOT NULL DEFAULT '{}', created_by uuid NOT NULL REFERENCES users(id)
);
CREATE TABLE occasion_sends (occasion_id uuid REFERENCES occasions(id) ON DELETE CASCADE, user_id uuid REFERENCES users(id) ON DELETE CASCADE, occurrence_year int NOT NULL, channel text NOT NULL, sent_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY (occasion_id, user_id, occurrence_year, channel));  -- PK prevents duplicate sends

CREATE TABLE app_releases (id serial PRIMARY KEY, version_name text NOT NULL, version_code int NOT NULL UNIQUE, min_required boolean NOT NULL DEFAULT false, forced_security boolean NOT NULL DEFAULT false, rollout_percent smallint NOT NULL DEFAULT 0 CHECK (rollout_percent BETWEEN 0 AND 100), notes text, created_by uuid NOT NULL REFERENCES users(id), created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE backups (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), scope text NOT NULL CHECK (scope IN ('database','files','settings','full')), status text NOT NULL, requested_by uuid NOT NULL REFERENCES users(id), storage_key text, checksum text, created_at timestamptz NOT NULL DEFAULT now(), restored_at timestamptz);
CREATE TABLE emergency_state (id boolean PRIMARY KEY DEFAULT true CHECK (id), mode text NOT NULL DEFAULT 'normal', changed_by uuid REFERENCES users(id), changed_at timestamptz NOT NULL DEFAULT now());
INSERT INTO emergency_state(id) VALUES (true);

CREATE TABLE social_accounts (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), platform text NOT NULL CHECK (platform IN ('facebook','instagram','tiktok','x')), external_id text NOT NULL, token_enc text NOT NULL, status text NOT NULL DEFAULT 'linked', UNIQUE (platform, external_id));
CREATE TABLE social_posts (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), account_id uuid NOT NULL REFERENCES social_accounts(id), body jsonb NOT NULL, scheduled_at timestamptz, status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','pending_approval','approved','published','failed','blocked_no_api_access')), approved_by uuid REFERENCES users(id), external_post_id text, error text);

CREATE TABLE ad_config (placement text PRIMARY KEY, format text NOT NULL, enabled boolean NOT NULL DEFAULT false, min_gap_sec int NOT NULL DEFAULT 120, max_per_session smallint NOT NULL DEFAULT 3);
CREATE TABLE security_events (id bigserial PRIMARY KEY, user_id uuid REFERENCES users(id), kind text NOT NULL, detail jsonb NOT NULL DEFAULT '{}', ip inet, created_at timestamptz NOT NULL DEFAULT now());
CREATE INDEX security_events_user_idx ON security_events(user_id, created_at DESC);

-- Immutable audit log
CREATE TABLE audit_log (id bigserial PRIMARY KEY, actor_id uuid REFERENCES users(id), actor_role user_role, action text NOT NULL, target_type text, target_id text, detail jsonb NOT NULL DEFAULT '{}', ip inet, created_at timestamptz NOT NULL DEFAULT now());
CREATE FUNCTION audit_immutable() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'audit_log is append-only'; END $$;
CREATE TRIGGER audit_no_update BEFORE UPDATE OR DELETE ON audit_log FOR EACH ROW EXECUTE FUNCTION audit_immutable();

-- Intro limit enforced in the database too (defense in depth): max 3 consecutive unanswered messages per sender
CREATE FUNCTION enforce_intro_limit() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE streak int := 0; r record;
BEGIN
  FOR r IN SELECT sender_id FROM messages WHERE conversation_id = NEW.conversation_id ORDER BY sent_at DESC, id LOOP
    EXIT WHEN r.sender_id <> NEW.sender_id; streak := streak + 1;
  END LOOP;
  IF (SELECT kind FROM conversations WHERE id = NEW.conversation_id) = 'intro' AND streak >= 3 THEN
    RAISE EXCEPTION 'intro_limit_reached' USING ERRCODE = 'P0001';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER messages_intro_limit BEFORE INSERT ON messages FOR EACH ROW EXECUTE FUNCTION enforce_intro_limit();
