/// Client-side mirrors of server policies (the server is always authoritative).
const kRadiusOptionsKm = [1, 5, 10, 25, 50, 100];
const kDefaultRadiusKm = 25;

/// Screens where ads must never appear (mirrors backend/src/domain/policy.ts).
const kAdForbiddenScreens = {
  'chat_thread', 'report_flow', 'block_flow', 'safety_center', 'verification', 'appeal', 'account_deletion', 'login', 'pin_lock', 'onboarding_age_gate',
};

bool adAllowed({required String screen, required String format, required bool isTransition, DateTime? lastInterstitial, int minGapSec = 120, DateTime? now}) {
  if (kAdForbiddenScreens.contains(screen)) return false;
  if (format == 'interstitial' || format == 'app_open') {
    if (!isTransition) return false;
    final n = now ?? DateTime.now();
    if (lastInterstitial != null && n.difference(lastInterstitial).inSeconds < minGapSec) return false;
  }
  return true;
}

bool isAdult(DateTime birth, [DateTime? now]) {
  final n = now ?? DateTime.now();
  var age = n.year - birth.year;
  if (n.month < birth.month || (n.month == birth.month && n.day < birth.day)) age--;
  return age >= 18;
}

/// PIN lock. Decoy PIN opens a harmless empty shell and NEVER touches real account data.
enum PinResult { real, decoy, wrong }

class PinPolicy {
  PinPolicy(this.allowedTimeoutsSec);
  final List<int> allowedTimeoutsSec; // defined by the Owner via remote config
  bool isAllowedTimeout(int s) => allowedTimeoutsSec.contains(s);
  int pickTimeout(int requested) => isAllowedTimeout(requested) ? requested : allowedTimeoutsSec.first;
}

String? validatePin(String pin) {
  if (!RegExp(r'^\d{4,8}$').hasMatch(pin)) return 'pin_format';
  if (RegExp(r'^(\d)\1+$').hasMatch(pin) || '01234567890'.contains(pin) || '09876543210'.contains(pin)) return 'pin_too_simple';
  return null;
}
