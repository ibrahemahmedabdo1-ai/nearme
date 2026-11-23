-- Profile, presence, cosmetics, challenges, notifications, moderation recommendations, recovery codes, marketing
ALTER TABLE users ADD COLUMN boost_until timestamptz, ADD COLUMN avatar_key text, ADD COLUMN cover_key text,
  ADD COLUMN equipped jsonb NOT NULL DEFAULT '{}', ADD COLUMN disabled_by_owner boolean NOT NULL DEFAULT false;
CREATE TABLE boosts (id bigserial PRIMARY KEY, user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE, started_at timestamptz NOT NULL DEFAULT now(), ends_at timestamptz NOT NULL);
CREATE INDEX boosts_user_idx ON boosts(user_id, started_at DESC);
CREATE TABLE typing_state (conversation_id uuid REFERENCES conversations(id) ON DELETE CASCADE, user_id uuid REFERENCES users(id) ON DELETE CASCADE, until timestamptz NOT NULL, PRIMARY KEY (conversation_id, user_id));

CREATE TABLE cosmetic_items (
  id text PRIMARY KEY, kind text NOT NULL CHECK (kind IN ('frame','cover','name_color','gift','badge','effect','sticker')),
  name_en text NOT NULL, name_ar text NOT NULL, payload jsonb NOT NULL DEFAULT '{}', animated boolean NOT NULL DEFAULT false,
  behavioral boolean NOT NULL DEFAULT false, active boolean NOT NULL DEFAULT true
);
CREATE TABLE user_items (user_id uuid REFERENCES users(id) ON DELETE CASCADE, item_id text REFERENCES cosmetic_items(id), source text NOT NULL, acquired_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY (user_id, item_id));
CREATE TABLE gifts_sent (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), from_user uuid NOT NULL REFERENCES users(id), to_user uuid NOT NULL REFERENCES users(id), item_id text NOT NULL REFERENCES cosmetic_items(id), created_at timestamptz NOT NULL DEFAULT now(), CHECK (from_user <> to_user));

CREATE TABLE daily_challenges (id text PRIMARY KEY, metric text NOT NULL CHECK (metric IN ('likes_sent','messages_sent','profile_bio_set','daily_login')), target int NOT NULL CHECK (target > 0), title_en text NOT NULL, title_ar text NOT NULL, reward_item text REFERENCES cosmetic_items(id), active boolean NOT NULL DEFAULT true);
CREATE TABLE challenge_claims (user_id uuid REFERENCES users(id) ON DELETE CASCADE, challenge_id text REFERENCES daily_challenges(id), day date NOT NULL, claimed_at timestamptz NOT NULL DEFAULT now(), PRIMARY KEY (user_id, challenge_id, day));
CREATE TABLE rewarded_ad_claims (id bigserial PRIMARY KEY, user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE, day date NOT NULL DEFAULT CURRENT_DATE, item_id text REFERENCES cosmetic_items(id), verified boolean NOT NULL DEFAULT false, created_at timestamptz NOT NULL DEFAULT now());

CREATE TABLE notifications (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE, kind text NOT NULL, title text NOT NULL, body text, data jsonb NOT NULL DEFAULT '{}', created_at timestamptz NOT NULL DEFAULT now(), read_at timestamptz);
CREATE INDEX notifications_user_idx ON notifications(user_id, created_at DESC);

CREATE TABLE moderation_recommendations (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), ticket_id uuid REFERENCES tickets(id) ON DELETE SET NULL, user_id uuid NOT NULL REFERENCES users(id), recommended text NOT NULL CHECK (recommended IN ('warning','message_restriction','like_restriction','suspension','ban','no_action')), note text NOT NULL, status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','accepted','declined')), created_by uuid NOT NULL REFERENCES users(id), decided_by uuid REFERENCES users(id), created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE owner_recovery_codes (user_id uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE, code_hash text NOT NULL, used_at timestamptz, PRIMARY KEY (user_id, code_hash));

-- Marketing center
ALTER TABLE social_accounts ADD COLUMN display_name text, ADD COLUMN linked_by uuid REFERENCES users(id), ADD COLUMN linked_at timestamptz NOT NULL DEFAULT now(), ADD COLUMN refresh_token_enc text, ADD COLUMN expires_at timestamptz;
ALTER TABLE social_posts ADD COLUMN created_by uuid REFERENCES users(id), ADD COLUMN campaign_id uuid, ADD COLUMN media_key text, ADD COLUMN published_at timestamptz, ADD COLUMN metrics jsonb;
CREATE TABLE marketing_campaigns (id uuid PRIMARY KEY DEFAULT gen_random_uuid(), name text NOT NULL, kind text NOT NULL DEFAULT 'organic' CHECK (kind IN ('organic','paid')), occasion_id uuid REFERENCES occasions(id) ON DELETE SET NULL, budget_cents int, status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','owner_authorized','running','ended')), authorized_by uuid REFERENCES users(id), authorized_at timestamptz, created_by uuid NOT NULL REFERENCES users(id), created_at timestamptz NOT NULL DEFAULT now(),
  CHECK (kind = 'organic' OR status IN ('draft') OR authorized_by IS NOT NULL));   -- paid campaigns can never leave draft without an Owner authorization
ALTER TABLE social_posts ADD FOREIGN KEY (campaign_id) REFERENCES marketing_campaigns(id) ON DELETE SET NULL;
ALTER TABLE social_posts DROP CONSTRAINT IF EXISTS social_posts_status_check;
ALTER TABLE social_posts ADD CONSTRAINT social_posts_status_check CHECK (status IN ('draft','pending_approval','approved','publishing','published','failed','blocked_no_api_access'));

INSERT INTO cosmetic_items(id,kind,name_en,name_ar,payload,animated,behavioral) VALUES
 ('frame_neon','frame','Neon Ring','إطار نيون','{"colors":["#FF4D94","#8B5CF6","#38BDF8"]}',true,false),
 ('frame_gold','frame','Gold Ring','إطار ذهبي','{"colors":["#FBBF24","#F59E0B"]}',false,false),
 ('cover_sunset','cover','Sunset Cover','غلاف الغروب','{"gradient":["#3a1c71","#d76d77","#ffaf7b"]}',false,false),
 ('cover_ocean','cover','Ocean Cover','غلاف المحيط','{"gradient":["#0ea5e9","#6366f1"]}',false,false),
 ('color_rose','name_color','Rose Name','اسم وردي','{"gradient":["#FF4D94","#FF7A59"]}',false,false),
 ('color_violet','name_color','Violet Name','اسم بنفسجي','{"gradient":["#8B5CF6","#38BDF8"]}',false,false),
 ('gift_rose','gift','Rose','وردة','{"emoji":"🌹"}',false,false),
 ('gift_coffee','gift','Coffee','قهوة','{"emoji":"☕"}',false,false),
 ('gift_star','gift','Star','نجمة','{"emoji":"⭐"}',false,false),
 ('effect_sparkle','effect','Sparkle Effect','تأثير لامع','{"lottie":"sparkle"}',true,false),
 ('badge_respectful','badge','Respectful Member','عضو محترم','{}',false,true),
 ('badge_friendly','badge','Friendly Chatter','محادث ودود','{}',false,true),
 ('badge_early','badge','Early Member','عضو مبكر','{}',false,true),
 ('stk_smile','sticker','Smile','ابتسامة','{"emoji":"😊"}',false,false),('stk_heart','sticker','Heart','قلب','{"emoji":"💖"}',false,false),
 ('stk_party','sticker','Party','احتفال','{"emoji":"🥳"}',true,false),('stk_fire','sticker','Fire','نار','{"emoji":"🔥"}',true,false),('stk_wave','sticker','Wave','تلويحة','{"emoji":"👋"}',true,false);
INSERT INTO daily_challenges(id,metric,target,title_en,title_ar,reward_item) VALUES
 ('send_3_likes','likes_sent',3,'Send 3 likes','أرسل 3 إعجابات','frame_neon'),
 ('chat_5','messages_sent',5,'Send 5 messages','أرسل 5 رسائل','gift_rose'),
 ('set_bio','profile_bio_set',1,'Write your bio','اكتب نبذتك','color_rose'),
 ('login_today','daily_login',1,'Open the app today','افتح التطبيق اليوم','gift_star');
INSERT INTO app_config(key,value) VALUES ('matching.weights','{"interests":40,"distance":25,"age":15,"activity":10,"verified":10}'),('rewards.max_ad_claims_per_day','3'),('security.audit_retention_note','"audit_log is retained; evidence/messages follow retention jobs"') ON CONFLICT DO NOTHING;
