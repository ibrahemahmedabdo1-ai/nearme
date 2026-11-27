import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:near_me_core/near_me_core.dart';

void main() {
  test('30 unique themes', () {
    expect(kThemes.length, 30);
    expect(kThemes.map((t) => t.id).toSet().length, 30);
  });
  test('every theme builds light and dark', () {
    for (final t in kThemes) {
      expect(t.build(Brightness.dark).brightness, Brightness.dark);
      expect(t.build(Brightness.light).brightness, Brightness.light);
    }
  });
  test('theme scheduling: manual wins, schedule by date and country', () {
    final s = [ThemeSchedule('ramadan', DateTime(2027, 2, 8), DateTime(2027, 3, 9), countries: ['EG'])];
    expect(resolveTheme(manualId: 'graphite', schedule: s, now: DateTime(2027, 2, 10), country: 'EG').id, 'graphite');
    expect(resolveTheme(manualId: '', schedule: s, now: DateTime(2027, 2, 10), country: 'EG').id, 'ramadan');
    expect(resolveTheme(manualId: '', schedule: s, now: DateTime(2027, 2, 10), country: 'US').id, kThemes.first.id);
    expect(resolveTheme(manualId: '', schedule: s, now: DateTime(2027, 4, 1), country: 'EG').id, kThemes.first.id);
  });
  test('ad policy', () {
    expect(adAllowed(screen: 'chat_thread', format: 'banner', isTransition: false), false);
    for (final screen in ['login', 'registration', 'onboarding', 'support', 'support_chat', 'support_ticket', 'appeals', 'child_safety', 'moderation']) {
      expect(adAllowed(screen: screen, format: 'banner', isTransition: false), false, reason: 'ads must be blocked in $screen');
    }
    expect(adAllowed(screen: 'home', format: 'native', isTransition: false), true);
    expect(adAllowed(screen: 'home', format: 'interstitial', isTransition: false), false);
    final now = DateTime(2026, 1, 1, 12);
    expect(adAllowed(screen: 'home', format: 'interstitial', isTransition: true, lastInterstitial: now.subtract(const Duration(seconds: 30)), now: now), false);
  });
  test('age and pin', () {
    expect(isAdult(DateTime(2008, 6, 15), DateTime(2026, 6, 15)), true);
    expect(isAdult(DateTime(2008, 6, 16), DateTime(2026, 6, 15)), false);
    expect(validatePin('1111'), 'pin_too_simple');
    expect(validatePin('48271'), null);
    expect(PinPolicy([60, 300]).pickTimeout(10), 60);
  });

  group('AppBuilderConfig', () {
    test('ignores unknown/oversized/non-data values and defaults features ON', () {
      final c = AppBuilderConfig.fromJson({'theme_id': 'x' * 100, 'tabs': {'chats': 'دردشة', 'evil': 'x', 'home': 5}, 'features': {'boost': false, 'hack': false, 'gifs': 'no'}, 'texts': {'welcome_title': 'مرحبا', 'big': 'y' * 500}});
      expect(c.themeId, isNull);
      expect(c.tab('chats'), 'دردشة');
      expect(c.tab('home'), AppBuilderConfig.defaultTabs['home']);
      expect(c.feature('boost'), isFalse);
      expect(c.feature('gifs'), isTrue);
      expect(c.texts.containsKey('big'), isFalse);
      expect(AppBuilderConfig.fromJson('garbage').feature('rewind'), isTrue);
    });
    test('toJson round-trips', () {
      final c = AppBuilderConfig.fromJson({'theme_id': 'ocean', 'tabs': {'near': 'حولي'}, 'features': {'gifts': false}});
      final again = AppBuilderConfig.fromJson(c.toJson());
      expect(again.themeId, 'ocean');
      expect(again.tab('near'), 'حولي');
      expect(again.feature('gifts'), isFalse);
    });
  });
}
