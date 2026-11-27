import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:near_me_core/near_me_core.dart';

/// AdMob wiring. IDs come from --dart-define. Defaults are Google's official TEST IDs.
/// Production builds must inject real IDs and must never ship these defaults.
const _bannerId = String.fromEnvironment('ADMOB_BANNER_ID', defaultValue: 'ca-app-pub-3940256099942544/6300978111');
const _rewardedId = String.fromEnvironment('ADMOB_REWARDED_ID', defaultValue: 'ca-app-pub-3940256099942544/5224354917');
const _interstitialId = String.fromEnvironment('ADMOB_INTERSTITIAL_ID', defaultValue: 'ca-app-pub-3940256099942544/1033173712');

class AdService extends ChangeNotifier {
  AdService._();
  static final AdService instance = AdService._();

  bool _ready = false;
  bool _initializing = false;
  bool _initialized = false;
  DateTime? _lastInterstitial;
  InterstitialAd? _loaded;
  final Map<String, int> _sessionImpressions = {};
  int _eligibleTransitionsSinceInterstitial = 0;
  bool _rewardedInFlight = false;
  List<dynamic> placements = const [];

  bool get ready => _ready;

  /// Must run once per app launch before any ad request. A failed or unresolved
  /// consent flow fails closed: no ad SDK requests are made.
  Future<void> init(List<dynamic> remotePlacements) async {
    placements = remotePlacements;
    if (_initialized || _initializing) return;
    _initializing = true;
    try {
      final canRequest = await _resolveConsent();
      notifyListeners();
      if (!canRequest) return;
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(maxAdContentRating: MaxAdContentRating.pg),
      );
      await MobileAds.instance.initialize();
      _ready = true;
      _initialized = true;
      notifyListeners();
      _preload();
    } catch (_) {
      // Keep ads disabled if consent or SDK initialization cannot be verified.
      _ready = false;
      notifyListeners();
    } finally {
      _initializing = false;
    }
  }

  Future<bool> _resolveConsent() async {
    final updated = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () async {
        try {
          await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
        } catch (_) {
          // Check canRequestAds() below; UMP may still have a valid prior-session choice.
        } finally {
          if (!updated.isCompleted) updated.complete();
        }
      },
      (_) {
        if (!updated.isCompleted) updated.complete();
      },
    );
    // Never leave startup waiting forever if the consent SDK/network stalls.
    try {
      await updated.future.timeout(const Duration(seconds: 15));
    } on TimeoutException {
      return false;
    }
    return ConsentInformation.instance.canRequestAds();
  }

  Future<bool> get privacyOptionsRequired async {
    try {
      return await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
          PrivacyOptionsRequirementStatus.required;
    } catch (_) {
      return false;
    }
  }

  /// Call only from the user's Privacy choices settings entry point.
  Future<void> showPrivacyOptions() async {
    await ConsentForm.showPrivacyOptionsForm((_) {});
    final canRequest = await ConsentInformation.instance.canRequestAds();
    if (!canRequest) {
      _ready = false;
      _loaded?.dispose();
      _loaded = null;
    } else if (!_ready) {
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(maxAdContentRating: MaxAdContentRating.pg),
      );
      await MobileAds.instance.initialize();
      _ready = true;
      _initialized = true;
      _preload();
    }
    notifyListeners();
  }

  Map<String, dynamic>? _p(String placement) {
    for (final p in placements) {
      if ((p as Map<String, dynamic>)['placement'] == placement) return p;
    }
    return null;
  }

  bool enabled(String placement) => _ready && (_p(placement)?['enabled'] == true);
  int _max(String placement) => (_p(placement)?['max_per_session'] as int?) ?? 0;
  bool canShow(String placement) =>
      enabled(placement) &&
      _max(placement) > 0 &&
      (_sessionImpressions[placement] ?? 0) < _max(placement);

  void recordImpression(String placement) {
    _sessionImpressions[placement] = (_sessionImpressions[placement] ?? 0) + 1;
  }

  void _preload() {
    if (!canShow('tab_transition') || _loaded != null) return;
    InterstitialAd.load(
      adUnitId: _interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (a) => _loaded = a,
        onAdFailedToLoad: (_) => _loaded = null,
      ),
    );
  }

  /// Optional, explicitly user-initiated rewarded ad. The reward is non-cash cosmetic only.
  Future<bool> showRewarded() async {
    if (!canShow('rewarded_cosmetic') || _rewardedInFlight) return false;
    _rewardedInFlight = true;
    final done = Completer<bool>();
    RewardedAd.load(
      adUnitId: _rewardedId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          var earned = false;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdImpression: (_) => recordImpression('rewarded_cosmetic'),
            onAdDismissedFullScreenContent: (a) {
              a.dispose();
              _rewardedInFlight = false;
              if (!done.isCompleted) done.complete(earned);
            },
            onAdFailedToShowFullScreenContent: (a, _) {
              a.dispose();
              _rewardedInFlight = false;
              if (!done.isCompleted) done.complete(false);
            },
          );
          ad.show(onUserEarnedReward: (_, __) => earned = true);
        },
        onAdFailedToLoad: (_) {
          _rewardedInFlight = false;
          if (!done.isCompleted) done.complete(false);
        },
      ),
    );
    return done.future;
  }

  /// Interstitials are limited to natural tab transitions, at least two eligible
  /// transitions apart, plus the Owner's minimum gap and per-session cap.
  void maybeShowInterstitial({required String fromScreen}) {
    final p = _p('tab_transition');
    if (!canShow('tab_transition')) return;
    _eligibleTransitionsSinceInterstitial++;
    if (_eligibleTransitionsSinceInterstitial < 2 || _loaded == null) return;
    if (!adAllowed(
      screen: fromScreen,
      format: 'interstitial',
      isTransition: true,
      lastInterstitial: _lastInterstitial,
      minGapSec: (p?['min_gap_sec'] as int?) ?? 120,
    )) return;

    final ad = _loaded!;
    _loaded = null;
    _lastInterstitial = DateTime.now();
    _eligibleTransitionsSinceInterstitial = 0;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdImpression: (_) => recordImpression('tab_transition'),
      onAdDismissedFullScreenContent: (a) {
        a.dispose();
        _preload();
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        a.dispose();
        _preload();
      },
    );
    ad.show();
  }
}

/// Banner remains absent unless Owner enables the placement and the current screen is allowed.
/// It listens for consent completion so a banner is not silently lost during asynchronous startup.
class NmBanner extends StatefulWidget {
  const NmBanner({super.key, required this.screen, this.placement = 'home_feed'});
  final String screen, placement;
  @override
  State<NmBanner> createState() => _NmBannerState();
}

class _NmBannerState extends State<NmBanner> {
  BannerAd? _ad;
  bool _loaded = false;
  bool _attempted = false;

  @override
  void initState() {
    super.initState();
    AdService.instance.addListener(_onAdServiceChanged);
    _tryLoad();
  }

  void _onAdServiceChanged() {
    if (!AdService.instance.ready && _ad != null) {
      _ad!.dispose();
      _ad = null;
      if (mounted) setState(() => _loaded = false);
      return;
    }
    _tryLoad();
  }

  void _tryLoad() {
    if (!mounted || _attempted || !AdService.instance.ready) return;
    if (!adAllowed(screen: widget.screen, format: 'banner', isTransition: false) ||
        !AdService.instance.canShow(widget.placement)) return;
    _attempted = true;
    _ad = BannerAd(
      adUnitId: _bannerId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdImpression: (_) => AdService.instance.recordImpression(widget.placement),
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          _ad = null;
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    AdService.instance.removeListener(_onAdServiceChanged);
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => (_ad != null && _loaded)
      ? Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('إعلان', style: TextStyle(fontSize: 10)),
              SizedBox(
                width: _ad!.size.width.toDouble(),
                height: _ad!.size.height.toDouble(),
                child: AdWidget(ad: _ad!),
              ),
            ],
          ),
        )
      : const SizedBox.shrink();
}
