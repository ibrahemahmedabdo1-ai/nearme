import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:near_me_core/near_me_core.dart';

/// AdMob wiring. IDs come from --dart-define so the Owner can supply production IDs without editing code.
/// Defaults are Google's official TEST ad unit IDs (safe for development; NEVER ship test IDs to production).
const _bannerId = String.fromEnvironment('ADMOB_BANNER_ID', defaultValue: 'ca-app-pub-3940256099942544/6300978111');
const _rewardedId = String.fromEnvironment('ADMOB_REWARDED_ID', defaultValue: 'ca-app-pub-3940256099942544/5224354917');
const _interstitialId = String.fromEnvironment('ADMOB_INTERSTITIAL_ID', defaultValue: 'ca-app-pub-3940256099942544/1033173712');

class AdService {
  AdService._();
  static final AdService instance = AdService._();
  bool _ready = false;
  DateTime? _lastInterstitial;
  InterstitialAd? _loaded;
  final Map<String, int> _sessionImpressions = {};
  int _eligibleTransitionsSinceInterstitial = 0;
  List<dynamic> placements = const []; // from /api/config -> ads (Owner-controlled)

  /// Call after the UMP consent flow. Ads are never requested before consent info is resolved.
  Future<void> init(List<dynamic> remotePlacements) async {
    placements = remotePlacements;
    final done = await _consent();
    if (!done) return;
    await MobileAds.instance.initialize();
    _ready = true;
    _preload();
  }

  Future<bool> _consent() async {
    final completer = ValueNotifier<bool?>(null);
    ConsentInformation.instance.requestConsentInfoUpdate(ConsentRequestParameters(), () async {
      await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
      completer.value = await ConsentInformation.instance.canRequestAds();
    }, (_) { completer.value = false; });
    while (completer.value == null) { await Future<void>.delayed(const Duration(milliseconds: 100)); }
    return completer.value!;
  }

  Map<String, dynamic>? _p(String placement) { for (final p in placements) { if ((p as Map<String, dynamic>)['placement'] == placement) { return p; } } return null; }
  bool enabled(String placement) => _ready && (_p(placement)?['enabled'] == true);
  int _max(String placement) => (_p(placement)?['max_per_session'] as int?) ?? 0;
  bool canShow(String placement) => enabled(placement) && _max(placement) > 0 && (_sessionImpressions[placement] ?? 0) < _max(placement);
  void recordImpression(String placement) { _sessionImpressions[placement] = (_sessionImpressions[placement] ?? 0) + 1; }

  void _preload() { if (!canShow('tab_transition')) return; InterstitialAd.load(adUnitId: _interstitialId, request: const AdRequest(), adLoadCallback: InterstitialAdLoadCallback(onAdLoaded: (a) => _loaded = a, onAdFailedToLoad: (_) => _loaded = null)); }

  /// OPTIONAL rewarded ad (user-initiated only, never required for any essential feature). Resolves true if the reward was earned.
  Future<bool> showRewarded() async {
    if (!canShow('rewarded_cosmetic')) return false;
    final done = Completer<bool>();
    RewardedAd.load(adUnitId: _rewardedId, request: const AdRequest(), rewardedAdLoadCallback: RewardedAdLoadCallback(
      onAdLoaded: (ad) {
        var earned = false;
        ad.fullScreenContentCallback = FullScreenContentCallback(
          onAdShowedFullScreenContent: (_) => recordImpression('rewarded_cosmetic'),
          onAdDismissedFullScreenContent: (a) { a.dispose(); if (!done.isCompleted) done.complete(earned); },
          onAdFailedToShowFullScreenContent: (a, _) { a.dispose(); if (!done.isCompleted) done.complete(false); },
        );
        ad.show(onUserEarnedReward: (_, __) => earned = true);
      },
      onAdFailedToLoad: (_) { if (!done.isCompleted) done.complete(false); },
    ));
    return done.future;
  }

  /// Shows an interstitial only at a natural tab transition, after at least two transition
  /// opportunities since the previous interstitial, and subject to the Owner's minimum gap.
  /// This is intentionally more conservative than showing an ad after every navigation action.
  void maybeShowInterstitial({required String fromScreen}) {
    final p = _p('tab_transition');
    if (!canShow('tab_transition')) return;
    _eligibleTransitionsSinceInterstitial++;
    if (_eligibleTransitionsSinceInterstitial < 2 || _loaded == null) return;
    if (!adAllowed(screen: fromScreen, format: 'interstitial', isTransition: true, lastInterstitial: _lastInterstitial, minGapSec: (p?['min_gap_sec'] as int?) ?? 120)) return;
    final ad = _loaded!;
    _loaded = null;
    _lastInterstitial = DateTime.now();
    _eligibleTransitionsSinceInterstitial = 0;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (a) { a.dispose(); _preload(); },
      onAdFailedToShowFullScreenContent: (a, _) { a.dispose(); _preload(); },
    );
    ad.show();
  }
}

/// Banner that renders nothing unless the placement is enabled by the Owner AND the screen is allowed to show ads.
class NmBanner extends StatefulWidget {
  const NmBanner({super.key, required this.screen, this.placement = 'home_feed'});
  final String screen, placement;
  @override
  State<NmBanner> createState() => _NmBannerState();
}

class _NmBannerState extends State<NmBanner> {
  BannerAd? _ad;
  bool _loaded = false;
  @override
  void initState() {
    super.initState();
    if (adAllowed(screen: widget.screen, format: 'banner', isTransition: false) && AdService.instance.canShow(widget.placement)) {
      _ad = BannerAd(adUnitId: _bannerId, size: AdSize.banner, request: const AdRequest(), listener: BannerAdListener(onAdLoaded: (_) { if (mounted) { AdService.instance.recordImpression(widget.placement); setState(() => _loaded = true); } }, onAdFailedToLoad: (ad, _) => ad.dispose()))..load();
    }
  }
  @override
  void dispose() { _ad?.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => (_ad != null && _loaded) ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [const Text('إعلان', style: TextStyle(fontSize: 10)), SizedBox(width: _ad!.size.width.toDouble(), height: _ad!.size.height.toDouble(), child: AdWidget(ad: _ad!))])) : const SizedBox.shrink();
}
