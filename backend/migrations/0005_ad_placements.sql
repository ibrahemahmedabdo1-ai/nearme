-- Fixed set of AdMob placements, all DISABLED until the Owner enables them. No placement exists for chat threads, auth, verification,
-- appeals, support, or safety screens (policy: ads never appear there).
INSERT INTO ad_config(placement,format,enabled,min_gap_sec,max_per_session) VALUES
 ('home_feed','banner',false,120,3),
 ('tab_transition','interstitial',false,180,3),
 ('rewarded_cosmetic','rewarded',false,0,5)
ON CONFLICT (placement) DO NOTHING;
