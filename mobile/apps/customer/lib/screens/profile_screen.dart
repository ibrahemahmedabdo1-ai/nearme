import 'package:flutter/material.dart';
import 'package:near_me_core/near_me_core.dart';
import '../app_state.dart';
import '../ads.dart';
import '../pin_lock.dart';
import 'notifications_screen.dart';
import 'profile_edit_screen.dart';
import 'rewards_screen.dart';
import 'safety_screens.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.state});
  final AppState state;
  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsetsDirectional.all(16), children: [
      const Text('ملفي', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
      const SizedBox(height: 12),
      GlassCard(child: Column(children: [
        ListTile(leading: const Icon(Icons.edit_outlined), title: const Text('تعديل الملف والاهتمامات'), onTap: () => _go(context, ProfileEditScreen(api: state.api))),
        ListTile(leading: const Icon(Icons.favorite_border), title: const Text('أعجبوا بك'), onTap: () => _go(context, IncomingLikesScreen(api: state.api))),
        ListTile(leading: const Icon(Icons.notifications_none), title: const Text('الإشعارات'), onTap: () => _go(context, NotificationsScreen(api: state.api))),
        ListTile(leading: const Icon(Icons.emoji_events_outlined), title: const Text('الإنجازات والمخزون'), onTap: () => _go(context, RewardsScreen(api: state.api, builder: state.builder, onWatchRewardedAd: AdService.instance.showRewarded))),
        ListTile(leading: const Icon(Icons.verified_outlined), title: const Text('توثيق الحساب'), onTap: () => _go(context, VerificationScreen(api: state.api))),
        ListTile(leading: const Icon(Icons.support_agent), title: const Text('الدعم والملاحظات'), onTap: () => _go(context, SupportTicketScreen(api: state.api))),
        ListTile(leading: const Icon(Icons.gavel_outlined), title: const Text('اعتراض على عقوبة'), onTap: () => _go(context, AppealScreen(api: state.api))),
        ListTile(leading: const Icon(Icons.palette_outlined), title: const Text('الثيم'), subtitle: Text(themeById(state.themeId).nameAr), onTap: () => _pickTheme(context)),
        ListTile(leading: const Icon(Icons.language), title: const Text('اللغة'), subtitle: Text(state.language == 'ar' ? 'العربية' : 'English'), onTap: () => state.setLanguage(state.language == 'ar' ? 'en' : 'ar')),
        ListTile(leading: const Icon(Icons.dark_mode_outlined), title: const Text('الوضع'), subtitle: Text(state.themeMode.name), onTap: () => state.setThemeMode(ThemeMode.values[(state.themeMode.index + 1) % 3])),
        ListTile(leading: const Icon(Icons.lock_outline), title: const Text('قفل PIN ورمز الخداع'), onTap: () => _pinSettings(context)),
        ListTile(leading: const Icon(Icons.shield_outlined), title: const Text('مركز الأمان'), onTap: () => _go(context, SecurityCenterScreen(api: state.api))),
        ListenableBuilder(
          listenable: AdService.instance,
          builder: (context, _) => FutureBuilder<bool>(
            future: AdService.instance.privacyOptionsRequired,
            builder: (context, snapshot) {
              if (snapshot.data != true) return const SizedBox.shrink();
              return ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('خيارات الخصوصية والإعلانات'),
                onTap: () async {
                  try {
                    await AdService.instance.showPrivacyOptions();
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('تعذر فتح خيارات الخصوصية. حاول مرة أخرى.')),
                      );
                    }
                  }
                },
              );
            },
          ),
        ),
        ListTile(leading: const Icon(Icons.logout), title: const Text('تسجيل الخروج'), onTap: state.signOut),
        ListTile(leading: Icon(Icons.delete_forever_outlined, color: Theme.of(context).colorScheme.error), title: const Text('حذف الحساب'), onTap: () => _confirmDelete(context)),
      ])),
    ]);
  }

  void _go(BuildContext c, Widget w) => Navigator.push(c, MaterialPageRoute<void>(builder: (_) => w));

  Future<void> _pinSettings(BuildContext c) async {
    final real = TextEditingController(), decoy = TextEditingController();
    int timeout = state.allowedPinTimeouts.contains(state.pinTimeoutSec) ? state.pinTimeoutSec : state.allowedPinTimeouts.first;
    await showDialog<void>(context: c, builder: (_) => StatefulBuilder(builder: (ctx, set) => AlertDialog(
      title: const Text('قفل التطبيق'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: real, obscureText: true, keyboardType: TextInputType.number, maxLength: 8, decoration: const InputDecoration(labelText: 'رمز PIN (4-8 أرقام)')),
        TextField(controller: decoy, obscureText: true, keyboardType: TextInputType.number, maxLength: 8, decoration: const InputDecoration(labelText: 'رمز الخداع (اختياري)', helperText: 'يفتح واجهة فارغة لا تعرض أي بيانات حقيقية')),
        DropdownButton<int>(value: timeout, items: [for (final t in state.allowedPinTimeouts) DropdownMenuItem(value: t, child: Text(t == 0 ? 'فورًا' : '${t ~/ 60 == 0 ? '$t ثانية' : '${t ~/ 60} دقيقة'}'))], onChanged: (v) => set(() => timeout = v ?? timeout)),
      ]),
      actions: [
        TextButton(onPressed: () async { await PinStore().clear(); if (ctx.mounted) Navigator.pop(ctx); }, child: const Text('إيقاف القفل')),
        FilledButton(onPressed: () async {
          final err = await PinStore().setPins(real: real.text, decoy: decoy.text.isEmpty ? null : decoy.text);
          if (err != null) { if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(err == 'pin_too_simple' ? 'الرمز بسيط جدًا' : err == 'decoy_same_as_real' ? 'رمز الخداع يجب أن يختلف' : 'صيغة غير صحيحة'))); return; }
          await state.setPinTimeout(timeout); if (ctx.mounted) Navigator.pop(ctx);
        }, child: const Text('حفظ')),
      ],
    )));
  }

  void _pickTheme(BuildContext c) => showModalBottomSheet(context: c, builder: (_) => ListView(children: [for (final t in kThemes) ListTile(leading: CircleAvatar(backgroundColor: t.primary), title: Text(t.nameAr), onTap: () { state.setTheme(t.id); Navigator.pop(c); })]));

  void _confirmDelete(BuildContext c) => showDialog<void>(
        context: c,
        builder: (_) => AlertDialog(
          title: const Text('حذف الحساب نهائيًا؟'),
          content: const Text('سيتم حذف ملفك ورسائلك وبياناتك. لا يمكن التراجع.'),
          actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('إلغاء')), TextButton(onPressed: () { Navigator.pop(c); state.deleteAccount(); }, child: const Text('حذف'))],
        ),
      );
}
