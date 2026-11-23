import 'api_client.dart';

/// Arabic messages for backend error codes (shared by all three apps).
const Map<String, String> kErrorsAr = {
  'device_not_registered': 'هذا الحساب مسجّل على جهاز آخر. استخدم طلب نقل الجهاز.',
  'install_id_required': 'تعذّر التحقق من الجهاز',
  'storage_not_configured': 'رفع الملفات غير مفعّل بعد على الخادم',
  'malware_scanner_not_configured': 'فحص الملفات غير مفعّل بعد على الخادم',
  'gif_provider_not_configured': 'خدمة الـ GIF غير مفعّلة بعد',
  'platform_api_not_configured': 'واجهة هذه المنصة غير مفعّلة بعد',
  'ai_not_configured': 'خدمة الذكاء الاصطناعي غير مفعّلة بعد',
  'forbidden': 'ليست لديك صلاحية',
  'owner_only': 'للمالك فقط',
  'owner_approval_required': 'تتطلب موافقة المالك',
  'daily_cap_reached': 'وصلت للحد اليومي',
  'boost_cooldown': 'يمكنك التعزيز مرة كل 24 ساعة',
  'rewind_window_closed': 'انتهت مهلة التراجع (5 دقائق)',
  'nothing_to_rewind': 'لا يوجد ما يمكن التراجع عنه',
  'already_matched': 'تمّ التطابق بالفعل',
  'conversation_required': 'يجب أن تكون بينكما محادثة مقبولة',
  'item_not_owned': 'لا تملك هذا العنصر',
  'not_completed': 'لم يكتمل التحدي بعد',
  'already_claimed': 'تم استلام المكافأة اليوم',
  'invalid_gif_url': 'رابط GIF غير صالح',
  'attachment_not_ready': 'الملف لم يُفحص بعد',
};
String errorText(Object e, [String fallback = 'حدث خطأ غير متوقع']) => e is ApiException ? (kErrorsAr[e.code] ?? 'خطأ (${e.code})') : 'تعذّر الاتصال بالخادم';
