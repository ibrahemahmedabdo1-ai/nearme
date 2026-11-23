-- Intro limit applies while the request is pending; accepted conversations (incl. matches) are unrestricted.
CREATE OR REPLACE FUNCTION enforce_intro_limit() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE streak int := 0; r record;
BEGIN
  IF (SELECT intro_status FROM conversations WHERE id = NEW.conversation_id) = 'pending' THEN
    FOR r IN SELECT sender_id FROM messages WHERE conversation_id = NEW.conversation_id ORDER BY sent_at DESC, id LOOP
      EXIT WHEN r.sender_id <> NEW.sender_id; streak := streak + 1;
    END LOOP;
    IF streak >= 3 THEN RAISE EXCEPTION 'intro_limit_reached' USING ERRCODE = 'P0001'; END IF;
  END IF;
  RETURN NEW;
END $$;
CREATE INDEX IF NOT EXISTS reports_status_idx ON reports(status, created_at);
CREATE INDEX IF NOT EXISTS tickets_status_idx ON tickets(status, created_at DESC);
INSERT INTO app_config(key,value) VALUES ('intro.rule','"anyone"'),('messages.delete_for_both_minutes','10'),('messages.max_file_mb','10'),('pin.allowed_timeouts_sec','[0,60,300,900]'),('support.allow_anonymous_identity','false') ON CONFLICT DO NOTHING;
