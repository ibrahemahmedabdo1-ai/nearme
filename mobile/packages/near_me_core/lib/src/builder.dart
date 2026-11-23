/// App Builder configuration: DATA ONLY (no code is ever downloaded). The Admin app edits it, the backend validates it
/// (rejects script/code keys), and the Customer app reads the published version and applies it on top of safe defaults.
class AppBuilderConfig {
  const AppBuilderConfig({this.themeId, this.tabs = const {}, this.features = const {}, this.texts = const {}});
  final String? themeId;
  final Map<String, String> tabs; // chats, home, near, profile -> label
  final Map<String, bool> features; // rewind, boost, gifts, stickers, challenges, ...
  final Map<String, String> texts; // welcome_title, welcome_subtitle, ...

  static const defaultTabs = {'chats': 'المحادثات', 'home': 'الرئيسية', 'near': 'Near Me', 'profile': 'ملفي'};
  static const featureKeys = ['rewind', 'boost', 'gifts', 'stickers', 'gifs', 'challenges', 'rewarded_ads', 'inventory'];

  factory AppBuilderConfig.fromJson(Object? j) {
    if (j is! Map) return const AppBuilderConfig();
    String? s(Object? v, [int max = 60]) => v is String && v.length <= max ? v : null;
    final tabs = <String, String>{}, features = <String, bool>{}, texts = <String, String>{};
    if (j['tabs'] is Map) (j['tabs'] as Map).forEach((k, v) { if (defaultTabs.containsKey(k) && s(v, 24) != null) tabs['$k'] = v as String; });
    if (j['features'] is Map) (j['features'] as Map).forEach((k, v) { if (featureKeys.contains(k) && v is bool) features['$k'] = v; });
    if (j['texts'] is Map) (j['texts'] as Map).forEach((k, v) { if (s(v, 120) != null) texts['$k'] = v as String; });
    return AppBuilderConfig(themeId: s(j['theme_id'], 40), tabs: tabs, features: features, texts: texts);
  }

  Map<String, dynamic> toJson() => {if (themeId != null) 'theme_id': themeId, 'tabs': tabs, 'features': features, 'texts': texts};
  String tab(String k) => tabs[k] ?? defaultTabs[k]!;
  bool feature(String k) => features[k] ?? true; // features are ON unless the Owner switches them off
  String text(String k, String fallback) => texts[k] ?? fallback;
}
