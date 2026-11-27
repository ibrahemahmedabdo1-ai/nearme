-- Additional AdMob placements for formats already created in the publisher account.
-- Disabled by default; private chat, auth, support, verification, appeals and safety remain excluded.
INSERT INTO ad_config(placement,format,enabled,min_gap_sec,max_per_session) VALUES
 ('discovery_native','native',false,90,3),
 ('app_open','app_open',false,14400,1),
 ('rewarded_interstitial_cosmetic','rewarded_interstitial',false,300,2)
ON CONFLICT (placement) DO NOTHING;
