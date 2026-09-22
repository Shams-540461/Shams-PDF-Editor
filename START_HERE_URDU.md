اس نئے update کے لیے پہلے **UPDATE_URDU.md** پڑھیں۔ نئی Syncfusion سروس اور اصل عبارت بدلنے کے لیے **EDIT_TEXT_URDU.md** بھی موجود ہے۔

# شروع یہاں سے کریں

یہ نیا **Shams PDF Editor** پروجیکٹ ہے۔ اسے موجودہ SSS ایپ کے فولڈر میں نہ رکھیں۔
یہ ZIP سورس کوڈ ہے؛ ابھی APK یا تیار ویب build نہیں ہے۔

## ۱۔ ZIP کھولیں

ZIP کو Extract کریں اور `shams_pdf_editor` فولڈر یہاں رکھیں:

`C:\flutter_projects\shams_pdf_editor`

اسی فولڈر کے اندر `pubspec.yaml`، `lib` اور `web` ہونے چاہییں۔

## ۲۔ پہلے کمپیوٹر کے براؤزر میں آزمائیں

Windows CMD میں:

```cmd
cd /d C:\flutter_projects\shams_pdf_editor
start_editor_web.cmd
```

یہ dependencies لائے گا، جانچ چلائے گا اور web server شروع کرے گا۔ براؤزر میں خود http://localhost:8080 کھولیں۔
اگر کوئی error آئے تو اس کا متن بھیجیں۔ Flutter پرانا ہونے کی صورت میں پہلے
اس کا ورژن دیکھیں؛ موجودہ SSS پروجیکٹ کا SDK یا dependencies بلاوجہ نہ بدلیں۔

اس ماحول میں Flutter موجود نہیں تھا، اس لیے یہ commands یہاں چلائی نہیں گئیں۔
اس ZIP کو ابھی آزمائش کے لیے پہلا ورژن سمجھیں۔

## ۳۔ ایڈیٹر استعمال کریں

- **Open a PDF** سے اپنی PDF کھولیں، یا **Try a sample** دبائیں۔
- **text** منتخب کرکے صفحے پر جگہ منتخب کریں، پھر عبارت لکھیں۔
- اردو کے لیے پہلے **Load TTF font** سے موزوں اردو فونٹ منتخب کریں اور **RTL** فعال کریں۔
  فونٹ شامل نہیں ہے؛ ایسا فونٹ استعمال کریں جسے PDF میں شامل کرنے کا حق آپ رکھتے ہوں۔
- **line / rectangle** میں دو جگہ ٹیپ کریں۔
- **image** منتخب کریں، صفحے پر جگہ منتخب کریں، پھر PNG/JPEG شامل کریں۔
- **Arrange text/images** میں تصویر یا نئی عبارت پر click کریں، drag کرکے منتقل کریں، اور نچلے دائیں کونے سے resize کریں۔ **Apply** کے بعد اصل PDF کا نتیجہ دیکھیں۔
- دوبارہ منتقل کرنے کے لیے **Save project** سے `.shams` بھی محفوظ کریں۔ صرف PDF دوبارہ کھولنے سے یہ handles واپس نہیں آئیں گے۔
- **draw** منتخب کرکے صفحے پر ٹیپ کریں؛ کھلنے والے خانے میں ڈرائنگ یا دستخط بنائیں۔
- اوپر **Save** کے نشان سے فائل محفوظ کریں، پھر محفوظ شدہ فائل دوبارہ کھول کر دیکھیں۔

Add text نئی عبارت شامل کرتا ہے۔ Edit original text الگ Syncfusion سروس سے محدود سطر کی تبدیلی کرتا ہے؛ تفصیل EDIT_TEXT_URDU.md میں ہے۔
گھمائے ہوئے صفحات اس ورژن میں صرف دیکھے جاسکتے ہیں۔

## ۴۔ موبائل ایپ

یہ الگ ایپ ہوگی۔ اس کا نیا application ID ابھی طے نہیں ہوا۔ SSS کا ID استعمال نہیں کیا گیا۔
پہلے براؤزر کی جانچ مکمل کریں، پھر اپنی منتخب کردہ organization identifier کے ساتھ:

```cmd
dart tool/create_mobile.dart YOUR_REVERSE_DOMAIN
flutter pub get
flutter run
```

`YOUR_REVERSE_DOMAIN` کو اپنی تصدیق شدہ شناخت سے بدلنا ہے؛ اسے جوں کا توں نہ چلائیں۔
اس کے بعد Android/iOS کی platform فائلیں بنیں گی۔ iOS build کے لیے Mac/Xcode چاہیے۔
Play Store کے لیے signing، icon، نئی listing اور AAB کی تیاری الگ مرحلہ ہے۔

## ۵۔ GitHub Pages

ریپوزٹری: `Shams-540461/myoldprojectph2`

پہلے مقامی جانچ مکمل کریں۔ اس کے بعد نئی branch پر اس فولڈر کے اندر کی فائلیں
ریپوزٹری کے مرکزی حصے میں رکھیں۔ پرانے پروجیکٹ کی جگہ یہی نیا پروجیکٹ ہوگا۔
`.github` اور `.gitignore` بھی شامل کریں۔ `.git` کو حذف نہ کریں۔ ZIP کو ریپوزٹری میں
رکھ دینے سے ویب سائٹ نہیں بنے گی؛ اصل فائلیں رکھنی ہیں۔

GitHub میں **Settings → Pages → GitHub Actions** منتخب کریں۔
پھر **Actions → Check and publish PDF editor → Run workflow** کریں۔
پہلی بار custom domain والا انتخاب بند رکھیں۔

ابتدائی پتہ:

`https://shams-540461.github.io/myoldprojectph2/`

یہ پتہ ابھی شائع نہیں کیا گیا؛ workflow کامیاب ہونے کے بعد دستیاب ہوگا۔

## ۶۔ اپنا سب ڈومین

GitHub والے پتے کی جانچ کے بعد Pages میں `tools.shamswmalik.com` شامل کریں۔
اس کے بعد DNS میں صرف `tools` کے متعلقہ ریکارڈ کو GitHub Pages کی طرف کریں۔
پھر workflow میں custom domain فعال کرکے دوبارہ شائع کریں۔ تفصیل README میں ہے۔

Netlify hosting استعمال نہیں ہوگی۔ اگر DNS ابھی Netlify سنبھالتا ہے تو اسے منتقل
کیے بغیر Netlify کا DNS حذف نہ کریں۔ اصل domain کے باقی ریکارڈ برقرار رہیں گے۔

## لائسنس

آپ کی تصویر میں Document SDK کا ۳۰ دن کا ٹرائل فعال تھا۔ PDF Viewer کی شمولیت اور
عوامی اشاعت کے لیے موزوں لائسنس کی تصدیق اپنے Syncfusion اکاؤنٹ سے کریں۔ جدید Flutter
پیکیجز میں الگ license key رجسٹر کرنے کی ضرورت نہیں۔ البتہ .NET سروس کے لیے key CMD میں سیٹ کرنا ضروری ہے۔ کوئی key یہاں نہ بھیجیں۔

## موجودہ حالت

نیا سورس کوڈ اور GitHub Pages workflow تیار ہیں۔ GitHub پر اپ لوڈ، domain تبدیلی،
APK/AAB build اور Play Store اشاعت ابھی نہیں ہوئی۔ SSS ایپ میں کوئی تبدیلی نہیں کی گئی۔
