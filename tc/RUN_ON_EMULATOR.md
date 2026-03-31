# تشغيل التطبيق على المحاكي (Emulator)

## خطوات التشغيل:

### 1. التحقق من المحاكيات المتاحة:
```bash
flutter devices
```

### 2. إذا لم يكن لديك محاكي، قم بإنشاء واحد:

#### لمحاكي Android:
```bash
# فتح Android Studio
# Tools > Device Manager > Create Device
# اختر جهاز (مثل Pixel 5)
# اختر نظام Android (مثل API 33)
# انقر Finish
```

أو من سطر الأوامر:
```bash
# عرض المحاكيات المتاحة
flutter emulators

# تشغيل محاكي محدد
flutter emulators --launch <emulator_id>
```

### 3. تشغيل التطبيق على المحاكي:

#### إذا كان المحاكي يعمل بالفعل:
```bash
flutter run
```

#### أو حدد المحاكي مباشرة:
```bash
# عرض الأجهزة المتاحة
flutter devices

# تشغيل على محاكي محدد
flutter run -d <device_id>
```

### 4. أمثلة:

```bash
# تشغيل على أول محاكي Android متاح
flutter run -d android

# تشغيل على محاكي iOS (إذا كنت على Mac)
flutter run -d ios

# تشغيل على محاكي معين بالاسم
flutter run -d emulator-5554
```

## نصائح:

- تأكد من أن المحاكي يعمل قبل تشغيل `flutter run`
- إذا كان المحاكي بطيئاً، جرب إعادة تشغيله
- يمكنك فتح Android Studio > Device Manager لإنشاء وإدارة المحاكيات
