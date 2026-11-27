import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:near_me_core/near_me_core.dart';

/// AdMob wiring. IDs come from --dart-define. Defaults are Google's official TEST IDs.
/// Production builds must inject real IDs and must never ship these defaults.
const _bannerId = String.fromEnvironment('ADMOB_BANNER_ID', defaultValue: 'ca-app-pub-3940256099942544/6300978111');
const _rewardedId = String.fromEnvironment('ADMOB_REWARDED_ID', defaultValue: 'ca-app-pub-3940256099942544/5224354917');
const _interstitialId = String.fromEnvironment('ADMOB_INTERSTITIAL_ID', defaultValue: 'ca-app-pub-3940256099942544/1033173712');
const _nativeId = String.fromEnvironment('ADMOB_NATIVE_ID', defaultValue: 'ca-app-pub-3940256099942544/2247696110');
const _appOpenId = String.fromEnvironment('ADMOB_APP_OPEN_ID', defaultValue: 'ca-app-pub-3940256099942544/5662855259');
const _rewardedInterstitialId = String.fromEnvironment('ADMOB_REWARDED_INTERSTITIAL_ID', defaultValue: 'ca-app-pub-3940256099942544/5354046379');

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
  AppOpenAd? _appOpen;
  bool _appOpenLoading = false;
  RewardedInterstitialAd? _rewardedInterstitial;
  bool _rewardedInterstitialLoading = false;
  final Map<String, DateTime> _lastPlacementImpression = {};
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
      _preloadAppOpen();
      _preloadRewardedInterstitial();
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
      _preloadAppOpen();
      _preloadRewardedInterstitial();
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
  bool canShow(String placement) {
    if (!enabled(placement) || _max(placement) <= 0 ||
        (_sessionImpressions[placement] ?? 0) >= _max(placement)) return false;
    final p = _p(placement);
    final minGap = (p?['min_gap_sec'] as num?)?.toInt() ?? 0;
    final last = _lastPlacementImpression[placement];
    return last == null || DateTime.now().difference(last).inSeconds >= minGap;
  }

  void recordImpression(String placement) {
    _sessionImpressions[placement] = (_sessionImpressions[placement] ?? 0) + 1;
    _lastPlacementImpression[placement] = DateTime.now();
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


  void _preloadAppOpen() {
    if (!canShow('app_open') || _appOpen != null || _appOpenLoading) return;
    _appOpenLoading = true;
    AppOpenAd.load(
      adUnitId: _appOpenId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) { _appOpen = ad; _appOpenLoading = false; },
        onAdFailedToLoad: (_) { _appOpen = null; _appOpenLoading = false; },
      ),
    );
  }

  /// App-open ads are shown only on a return from background, never over a private chat,
  /// authentication, support, verification, appeal, or safety workflow.
  void onForegroundReturn({required String currentScreen}) {
    if (!canShow('app_open') || _appOpen == null ||
        !adAllowed(screen: currentScreen, format: 'app_open', isTransition: true)) {
      _preloadAppOpen();
      return;
    }
    final ad = _appOpen!;
    _appOpen = null;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdImpression: (_) => recordImpression('app_open'),
      onAdDismissedFullScreenContent: (a) { a.dispose(); _preloadAppOpen(); },
      onAdFailedToShowFullScreenContent: (a, _) { a.dispose(); _preloadAppOpen(); },
    );
    ad.show();
  }

  void _preloadRewardedInterstitial() {
    if (!canShow('rewarded_interstitial_cosmetic') ||
        _rewardedInterstitial != null || _rewardedInterstitialLoading) return;
    _rewardedInterstitialLoading = true;
    RewardedInterstitialAd.load(
      adUnitId: _rewardedInterstitialId,
      request: const AdRequest(),
      rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
        onAdLoaded: (ad) { _rewardedInterstitial = ad; _rewardedInterstitialLoading = false; },
        onAdFailedToLoad: (_) { _rewardedInterstitial = null; _rewardedInterstitialLoading = false; },
      ),
    );
  }

  /// Separate opt-in format from standard Rewarded; the user must press its dedicated button.
  Future<bool> showRewardedInterstitial() async {
    if (!canShow('rewarded_interstitial_cosmetic') ||
        _rewardedInFlight || _rewardedInterstitial == null) return false;
    _rewardedInFlight = true;
    final ad = _rewardedInterstitial!;
    _rewardedInterstitial = null;
    final done = Completer<bool>();
    var earned = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdImpression: (_) => recordImpression('rewarded_interstitial_cosmetic'),
      onAdDismissedFullScreenContent: (a) {
        a.dispose(); _rewardedInFlight = false; _preloadRewardedInterstitial();
        if (!done.isCompleted) done.complete(earned);
      },
      onAdFailedToShowFullScreenContent: (a, _) {
        a.dispose(); _rewardedInFlight = false; _preloadRewardedInterstitial();
        if (!done.isCompleted) done.complete(false);
      },
    );
    try {
      await ad.show(onUserEarnedReward: (_, __) => earned = true);
    } catch (_) {
      ad.dispose(); _rewardedInFlight = false; _preloadRewardedInterstitial();
      if (!done.isCompleted) done.complete(false);
    }
    return done.future;
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
        onAdLoaded: (ad) async {
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
          try {
            await ad.show(onUserEarnedReward: (_, __) => earned = true);
          } catch (_) {
            ad.dispose();
            _rewardedInFlight = false;
            if (!done.isCompleted) done.complete(false);
          }
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


/// Native feed ad. A single, clearly labeled ad is inserted between organic discovery cards.
class NmNativeAd extends StatefulWidget {
  const NmNativeAd({super.key, this.placement = 'discovery_native'});
  final String placement;
  @override
  State<NmNativeAd> createState() => _NmNativeAdState();
}

class _NmNativeAdState extends State<NmNativeAd> {
  NativeAd? _ad;
  bool _loaded = false;
  bool _attempted = false;

  @override
  void initState() {
    super.initState();
    AdService.instance.addListener(_serviceChanged);
    _tryLoad();
  }

  void _serviceChanged() {
    if (!AdService.instance.ready && _ad != null) {
      _ad!.dispose(); _ad = null;
      if (mounted) setState(() => _loaded = false);
    } else {
      _tryLoad();
    }
  }

  void _tryLoad() {
    if (!mounted || _attempted || !AdService.instance.ready ||
        !AdService.instance.canShow(widget.placement) ||
        !adAllowed(screen: 'home', format: 'native', isTransition: false)) return;
    _attempted = true;
    _ad = NativeAd(
      adUnitId: _nativeId,
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (_) { if (mounted) setState(() => _loaded = true); },
        onAdImpression: (_) => AdService.instance.recordImpression(widget.placement),
        onAdFailedToLoad: (ad, _) { ad.dispose(); _ad = null; },
      ),
      nativeTemplateStyle: NativeTemplateStyle(templateType: TemplateType.medium),
    )..load();
  }

  @override
  void dispose() {
    AdService.instance.removeListener(_serviceChanged);
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_ad == null || !_loaded) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Padding(
          padding: EdgeInsetsDirectional.only(start: 8, bottom: 4),
          child: Text('إعلان', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(height: 280, child: AdWidget(ad: _ad!)),
        ),
      ]),
    );
  }
}
