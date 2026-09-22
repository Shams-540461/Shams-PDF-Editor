# شمس PDF ایڈیٹر — نیا update

یہ مکمل source update ہے، تیار APK یا آزمودہ production release نہیں۔ PDF کا کام
Syncfusion Flutter اور Syncfusion .NET سے ہوتا ہے؛ Python PDF سروس شامل نہیں۔

## پہلے یہ کریں

1. دونوں چلتی ہوئی CMD ونڈوز میں Ctrl+C دبائیں۔ اگر Y/N آئے تو Y دبائیں۔
2. موجودہ `C:\flutter_projects\shams_pdf_editor` کی ایک نقل `shams_pdf_editor_backup` کے نام سے رکھیں۔ اصل فولڈر حذف نہ کریں۔
3. نئی ZIP الگ جگہ Extract کریں۔ اس کے `shams_pdf_editor` کے اندر کا سامان اپنے موجودہ `shams_pdf_editor` فولڈر میں copy کریں اور matching فائلیں replace کریں۔
4. خیال رہے کہ `C:\flutter_projects\shams_pdf_editor\pubspec.yaml` ہو؛ غلطی سے اندر ایک اور `shams_pdf_editor` فولڈر نہ بن جائے۔
5. پہلی CMD میں:

```cmd
cd /d C:\flutter_projects\shams_pdf_editor
start_text_service.cmd
```

اگر نئی CMD کھولی ہے اور key موجود نہیں، پہلے اسی CMD میں اپنی key دوبارہ مقرر کریں:

```cmd
set "SYNCFUSION_LICENSE_KEY=YOUR_KEY_HERE"
start_text_service.cmd
```

`YOUR_KEY_HERE` اپنی key سے بدلیں۔ key یہاں یا screenshot میں نہ بھیجیں۔

6. دوسری CMD میں:

```cmd
cd /d C:\flutter_projects\shams_pdf_editor
start_editor_web.cmd
```

7. دونوں ونڈوز کھلی رکھیں۔ web server تیار ہونے پر براؤزر میں http://localhost:8080 کھولیں یا Ctrl+F5 سے refresh کریں۔

## تصویر اور نئی عبارت کیسے منتقل ہوگی؟

- PDF کھولیں، **Arrange text/images** دبائیں۔ **Text** یا **Image** سے چیز شامل کریں۔
- چیز پر click کرکے منتخب کریں، پھر drag کریں۔ تصویر یا text کے نچلے دائیں handle سے سائز بدلیں۔ تصویر کا تناسب قائم رہے گا۔
- عبارت پر double-click یا **Properties** دبائیں: متن، size، Bold، Italic اور color بدل سکتے ہیں۔
- **Delete، Duplicate، Front، Back، Undo، Redo** اسی حصے میں ہیں۔ keyboard کے تیر سے باریک جگہ بدل سکتے ہیں۔
- صفحہ بدلنے کے لیے Previous/Next ہیں۔ یہ canvas صفحے کو دستیاب جگہ میں fit کرتا ہے؛ zoom والا مکمل desktop design editor نہیں۔
- **Apply** دبائیں۔ اب اصل PDF کا نتیجہ دکھے گا۔ layout کے دوران متن کی شکل اندازاً دکھتی ہے؛ حتمی Syncfusion rendering Apply کے بعد دیکھیں۔
- مرکزی **View** حالت میں عبارت select اور copy کریں۔ پھر اوپر **Save PDF** کا نشان دبائیں۔

## دو طرح کی فائلیں — اہم فرق

**PDF:** عام PDF، نئی عبارت حقیقی text ہوتی ہے، screenshot نہیں۔ دوسروں کو یہی دیں۔

**Save project → .shams:** اپنی editable فائل۔ اسے بھی محفوظ کریں تاکہ بعد میں اپنی
شامل کردہ text/images دوبارہ منتقل کر سکیں۔ مرکزی Open سے یہ فائل بھی کھلتی ہے۔
صرف محفوظ PDF دوبارہ کھولنے سے movable handles واپس نہیں آتے۔ project میں پوری PDF،
تصاویر اور fonts شامل ہوتے ہیں؛ اسے نجی جگہ رکھیں۔ خودکار autosave نہیں ہے۔

پہلے سے PDF میں موجود تصویر یا گزشتہ ورژن میں مستقل شامل ہوچکی تصویر draggable
object نہیں بنے گی۔ نئی تصویر اس update میں دوبارہ شامل کریں۔ اصل عبارت بدلنے،
line/rectangle/drawing شامل کرنے سے پہلے editable objects commit ہونے کی اطلاع آئے گی؛
اپنا project پہلے محفوظ کرلیں۔ main viewer میں form/annotation بدلنے سے بھی layer commit ہوتی ہے۔

## فونٹ کی وجہ سے رکاوٹ

اصل عبارت کے dialog میں **Auto + Helvetica if unavailable** پہلے اصل دستیاب فونٹ
آزماتا ہے۔ نہ ملے تو Helvetica استعمال ہوتا ہے۔ تبدیلی کے بعد اصل استعمال شدہ فونٹ
کا نام اور سائز بتایا جاتا ہے۔ متبادل فونٹ کی شکل پرانے فونٹ سے مختلف ہوسکتی ہے۔

بالکل اسی family کا فونٹ چاہیے تو **Auto: match original font** منتخب کریں اور
اصل فونٹ کی اجازت یافتہ TTF، مناسب Bold/Italic سمیت، `syncfusion_api\fonts` میں رکھیں،
پھر سروس restart کریں۔ آزمائشی SDK ہر ممکن فونٹ خود فراہم نہیں کرتا۔

## حدود اور جانچ

اس update کے نئے Flutter/.NET tests لکھے گئے ہیں، لیکن یہاں SDK موجود نہ ہونے کی وجہ سے
انہیں چلایا نہیں جاسکا۔ launchers انہیں آپ کے کمپیوٹر پر خود چلائیں گے۔ Android/iOS
release اور Play Store publication ابھی باقی ہیں۔ SSS ایپ کے فولڈر کو نہ چھیڑیں۔

Scan کی عبارت خودبخود selectable نہیں بنتی؛ OCR شامل نہیں۔ اصل PDF کی عبارت بدلنا
اب بھی مناسب سفید پس منظر پر English کی ایک سطر تک محدود ہے۔ Urdu/Arabic کی نئی
عبارت کے لیے supporting TTF چاہیے۔ پرانے paragraphs کی خودکار reflow، ہر قسم کے
embedded فونٹ کی reuse اور ہر PDF کی مکمل editing کا دعویٰ نہیں کیا گیا۔

پہلے ایک غیر حساس PDF کی نقل میں دو text اور دو تصاویر شامل کرکے move/resize کریں،
Apply، Save، دوبارہ Open اور text copy دیکھیں۔ اصل اہم فائل پر کام سے پہلے یہ ایک
مختصر عملی جانچ ضروری ہے۔
