import 'package:flutter/material.dart';

/// One coordinated theme: palette + typography + shape + icon style, in light and dark.
class NearMeTheme {
  const NearMeTheme(this.id, this.nameEn, this.nameAr, this.primary, this.secondary, this.darkBg, this.lightBg,
      {this.radius = 20, this.iconRounded = true, this.fontFamily, this.seasonal = false});
  final String id, nameEn, nameAr;
  final Color primary, secondary, darkBg, lightBg;
  final double radius;
  final bool iconRounded, seasonal;
  final String? fontFamily;

  LinearGradient get gradient => LinearGradient(colors: [primary, secondary], begin: Alignment.topLeft, end: Alignment.bottomRight);

  ThemeData build(Brightness b) {
    final dark = b == Brightness.dark;
    final bg = dark ? darkBg : lightBg;
    final surface = dark ? Color.alphaBlend(Colors.white.withValues(alpha: .06), bg) : Colors.white;
    final scheme = ColorScheme.fromSeed(seedColor: primary, brightness: b).copyWith(
      primary: primary, secondary: secondary, surface: surface,
      onSurface: dark ? const Color(0xFFF4F4FB) : const Color(0xFF14142B),
    );
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
    return ThemeData(
      useMaterial3: true, brightness: b, colorScheme: scheme, scaffoldBackgroundColor: bg, fontFamily: fontFamily,
      cardTheme: CardThemeData(color: surface, elevation: 0, shape: shape, margin: EdgeInsets.zero),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface, indicatorColor: primary.withValues(alpha: .2), height: 68,
        labelTextStyle: WidgetStatePropertyAll(TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: scheme.onSurface)),
      ),
      filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(shape: shape, minimumSize: const Size.fromHeight(52), backgroundColor: primary)),
      inputDecorationTheme: InputDecorationTheme(
        filled: true, fillColor: surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(radius - 4), borderSide: BorderSide.none),
      ),
      chipTheme: ChipThemeData(shape: const StadiumBorder(), side: BorderSide.none, backgroundColor: surface),
      appBarTheme: AppBarTheme(backgroundColor: Colors.transparent, elevation: 0, foregroundColor: scheme.onSurface),
    );
  }
}

Color _c(int v) => Color(0xFF000000 | v);

/// 30 shipped themes. Seasonal ones are scheduled by the Owner (see Occasions); all support RTL because
/// layout uses Directionality-aware widgets and EdgeInsetsDirectional.
final List<NearMeTheme> kThemes = [
  NearMeTheme('midnight_violet', 'Midnight Violet', 'بنفسجي منتصف الليل', _c(0x8B5CF6), _c(0xFF4D94), _c(0x090915), _c(0xF3F4FA)),
  NearMeTheme('ocean_breeze', 'Ocean Breeze', 'نسيم المحيط', _c(0x0EA5E9), _c(0x6366F1), _c(0x07111F), _c(0xF0F7FC)),
  NearMeTheme('sunset_glow', 'Sunset Glow', 'وهج الغروب', _c(0xFB923C), _c(0xEC4899), _c(0x140A10), _c(0xFFF6F0)),
  NearMeTheme('emerald_night', 'Emerald Night', 'ليل زمردي', _c(0x10B981), _c(0x06B6D4), _c(0x06130F), _c(0xF0FAF6)),
  NearMeTheme('rose_gold', 'Rose Gold', 'ذهبي وردي', _c(0xE11D74), _c(0xF59E0B), _c(0x160A12), _c(0xFFF3F7)),
  NearMeTheme('arctic_blue', 'Arctic Blue', 'أزرق قطبي', _c(0x3B82F6), _c(0x22D3EE), _c(0x08101C), _c(0xF2F7FF)),
  NearMeTheme('royal_gold', 'Royal Gold', 'ذهبي ملكي', _c(0xD4A017), _c(0x7C3AED), _c(0x0F0C06), _c(0xFFFAEB), radius: 16),
  NearMeTheme('cherry_blossom', 'Cherry Blossom', 'زهر الكرز', _c(0xF472B6), _c(0xC084FC), _c(0x170B14), _c(0xFFF1F8)),
  NearMeTheme('forest_mist', 'Forest Mist', 'ضباب الغابة', _c(0x22C55E), _c(0x84CC16), _c(0x07110A), _c(0xF2FAF3)),
  NearMeTheme('lavender_sky', 'Lavender Sky', 'سماء اللافندر', _c(0xA78BFA), _c(0x60A5FA), _c(0x0D0B1A), _c(0xF5F3FF)),
  NearMeTheme('coral_reef', 'Coral Reef', 'الشعاب المرجانية', _c(0xFF6B6B), _c(0x4ECDC4), _c(0x150B0B), _c(0xFFF4F2)),
  NearMeTheme('graphite', 'Graphite', 'جرافيت', _c(0x94A3B8), _c(0x38BDF8), _c(0x0B0D12), _c(0xF4F5F7), radius: 12),
  NearMeTheme('neon_city', 'Neon City', 'مدينة النيون', _c(0x00E5FF), _c(0xFF00E5), _c(0x05050F), _c(0xEFFCFF), radius: 8),
  NearMeTheme('desert_sand', 'Desert Sand', 'رمال الصحراء', _c(0xC2793E), _c(0xE8B04B), _c(0x120D07), _c(0xFBF4EA)),
  NearMeTheme('mint_fresh', 'Mint Fresh', 'نعناع منعش', _c(0x2DD4BF), _c(0x34D399), _c(0x06110F), _c(0xEFFBF8)),
  NearMeTheme('berry_blast', 'Berry Blast', 'توت بري', _c(0xBE185D), _c(0x7C3AED), _c(0x13060E), _c(0xFDF2F8)),
  NearMeTheme('crimson_noir', 'Crimson Noir', 'قرمزي داكن', _c(0xDC2626), _c(0xF97316), _c(0x0E0606), _c(0xFEF2F2), radius: 14),
  NearMeTheme('indigo_dream', 'Indigo Dream', 'حلم النيلي', _c(0x6366F1), _c(0xA855F7), _c(0x090A1C), _c(0xF1F2FF)),
  NearMeTheme('peach_cream', 'Peach Cream', 'كريمة الخوخ', _c(0xFB7185), _c(0xFDBA74), _c(0x160C0C), _c(0xFFF5F2)),
  NearMeTheme('teal_wave', 'Teal Wave', 'موجة تركوازية', _c(0x14B8A6), _c(0x3B82F6), _c(0x061312), _c(0xEFFAFA)),
  NearMeTheme('plum_velvet', 'Plum Velvet', 'مخمل البرقوق', _c(0x9333EA), _c(0xDB2777), _c(0x100718), _c(0xF8F1FE)),
  NearMeTheme('solar_flare', 'Solar Flare', 'توهج شمسي', _c(0xF59E0B), _c(0xEF4444), _c(0x140D04), _c(0xFFF8E7)),
  NearMeTheme('sky_candy', 'Sky Candy', 'حلوى السماء', _c(0x38BDF8), _c(0xF472B6), _c(0x08121C), _c(0xF0F9FF)),
  NearMeTheme('olive_grove', 'Olive Grove', 'بستان الزيتون', _c(0x65A30D), _c(0xCA8A04), _c(0x0C1006), _c(0xF7FAEC)),
  NearMeTheme('steel_blue', 'Steel Blue', 'أزرق فولاذي', _c(0x4F7CAC), _c(0x9DB4C0), _c(0x0A0F15), _c(0xF2F6FA), radius: 12),
  // Seasonal
  NearMeTheme('ramadan', 'Ramadan', 'رمضان', _c(0xD4A017), _c(0x0EA5A5), _c(0x07101C), _c(0xFFF9E8), seasonal: true),
  NearMeTheme('eid', 'Eid', 'العيد', _c(0x10B981), _c(0xFBBF24), _c(0x06130F), _c(0xF0FDF4), seasonal: true),
  NearMeTheme('winter_frost', 'Winter Frost', 'صقيع الشتاء', _c(0x93C5FD), _c(0xE0E7FF), _c(0x0A101C), _c(0xF3F8FF), seasonal: true),
  NearMeTheme('summer_vibes', 'Summer Vibes', 'أجواء الصيف', _c(0xFF9A44), _c(0x00C2FF), _c(0x14100A), _c(0xFFF8EE), seasonal: true),
  NearMeTheme('valentine', 'Valentine', 'عيد الحب', _c(0xFF2D6F), _c(0xFF8FB1), _c(0x160610), _c(0xFFF0F5), seasonal: true),
];

NearMeTheme themeById(String id) => kThemes.firstWhere((t) => t.id == id, orElse: () => kThemes.first);

/// Picks the theme to show now: manual choice wins; otherwise the first scheduled window containing [now]
/// (country-aware); otherwise the default.
NearMeTheme resolveTheme({required String manualId, required List<ThemeSchedule> schedule, required DateTime now, String? country}) {
  if (manualId.isNotEmpty) return themeById(manualId);
  for (final s in schedule) {
    final inWindow = !now.isBefore(s.from) && now.isBefore(s.to);
    final inCountry = s.countries.isEmpty || (country != null && s.countries.contains(country));
    if (inWindow && inCountry) return themeById(s.themeId);
  }
  return kThemes.first;
}

class ThemeSchedule {
  const ThemeSchedule(this.themeId, this.from, this.to, {this.countries = const []});
  final String themeId;
  final DateTime from, to;
  final List<String> countries;
}
