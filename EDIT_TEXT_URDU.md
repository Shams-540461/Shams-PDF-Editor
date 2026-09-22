# نیا Auto font، Bold، Italic اور Size

- Replacement font میں **Auto: match original font** پہلے سے منتخب ہے۔
- اصل فونٹ کا نام دکھائی دے گا۔ Bold، Italic اور Size ابتدا میں اصل سطر جیسے ہوں گے۔
- Bold اور Italic کے بٹن سے انداز بدلیں۔ Size میں 6 سے 200 pt لکھ سکتے ہیں؛
  اصل سائز 6 سے کم ہو تو اتنا چھوٹا سائز بھی قبول ہے۔ اصل مستطیل سے باہر متن نہیں پھیلے گا۔
- Fit فعال ہو تو جگہ کے مطابق سائز مزید چھوٹا ہو سکتا ہے۔ عین منتخب سائز کے لیے Fit بند کریں؛
  جگہ کم ہو تو واضح پیغام آئے گا اور عبارت برقرار رہے گی۔
- Auto کمپیوٹر پر موجود اسی نام کی مکمل static TTF فائل استعمال کرتا ہے۔ PDF کے اندر
  موجود جزوی فونٹ کو نہیں نکالتا۔ ہر PDF میں عین وہی فونٹ ملنے کی ضمانت نہیں۔
- فونٹ نہ ملے تو اس کی اصل TTF اور مطلوبہ Bold/Italic فائلیں syncfusion_api/fonts میں
  رکھیں اور سروس دوبارہ چلائیں۔ ایڈیٹر خاموشی سے فونٹ تبدیل نہیں کرے گا۔
- متبادل قبول ہو تو dropdown سے Helvetica، Times یا Courier خود منتخب کر سکتے ہیں۔

## اس اپ ڈیٹ کی فائلیں

دونوں CMD میں Ctrl+C کریں مگر بند نہ کریں۔ ZIP میں سے **lib** اور **syncfusion_api**
فولڈر کے اندر کی نئی فائلیں اپنے پروجیکٹ کے انہی فولڈرز میں copy/Replace کریں۔
اس بار FontCatalog.cs بھی نئی فائل ہے اور ShamsPdfApi.csproj/Program.cs بھی بدلے ہیں۔
پھر key والی CMD میں start_text_service.cmd اور دوسری میں start_editor_web.cmd چلائیں۔
ویب تیار ہو تو Ctrl+F5 دبائیں۔ نئی تبدیلیوں کا build یہاں نہیں چلا؛ launcher پر جانچ کریں۔

# نئی بہتری: لمبی عبارت اور error کی صورت میں سہولت

- Replace original line میں Font size اور Fit text to original area شامل ہیں۔
- Fit پہلے سے فعال ہے۔ عبارت کو اصل مستطیل میں بٹھانے کے لیے فونٹ چھوٹا ہوتا ہے۔
- سائز 6 pt سے نیچے نہیں جاتا؛ پہلے ہی چھوٹا اصل فونٹ ہو تو مزید چھوٹا نہیں ہوتا۔
- دستی سائز 200 pt تک ہو سکتا ہے، مگر عبارت اصل مستطیل میں آنا ضروری ہے۔
- ناکامی پر خانہ کھلا رہتا ہے اور آپ کی لکھی عبارت نہیں مٹتی۔
- ایک درخواست چل رہی ہو تو دوبارہ Apply بند رہتا ہے۔

اپ ڈیٹ کے لیے دونوں CMD میں Ctrl+C سے سروس اور ویب سرور روکیں، CMD بند نہ کریں۔
ZIP سے lib/editor_page.dart، lib/original_text_service.dart،
syncfusion_api/PdfTextEditor.cs اور syncfusion_api/SmokeTests.cs کو انہی جگہوں پر Replace کریں۔
پھر key والی CMD میں start_text_service.cmd اور دوسری میں start_editor_web.cmd چلائیں۔
build کے بعد browser میں Ctrl+F5 کریں۔ نئی جانچ ناکام ہو تو error بھیجیں۔
پچھلا ورژن آپ کے کمپیوٹر پر چل چکا ہے؛ اس نئی تبدیلی کا build یہاں نہیں چلایا جا سکا۔

# Syncfusion سروس: پہلے مقامی آزمائش

اس اپ ڈیٹ میں PDF کی اصل سطر بدلنے کا کام Syncfusion .NET انجام دیتا ہے۔
Python سروس کی ضرورت نہیں۔ یہ ابھی مقامی آزمائش کا ورژن ہے، شائع شدہ ویب سروس نہیں۔

## فائلیں کہاں رکھنی ہیں؟

1. موجودہ `C:\flutter_projects\shams_pdf_editor` کی ایک backup copy رکھیں۔
2. ZIP کو الگ جگہ Extract کریں۔ اس کے `shams_pdf_editor` فولڈر کے **اندر کی فائلیں**
   اپنے `C:\flutter_projects\shams_pdf_editor` میں copy کریں۔ ایک جیسے نام پر Replace کریں۔
3. تصدیق کریں کہ نئی فائل کا پتہ یہ ہے:
   `C:\flutter_projects\shams_pdf_editor\syncfusion_api\PdfTextEditor.cs`
4. پرانی Python سروس چل رہی ہو تو اس کی CMD میں Ctrl+C دبائیں؛ دونوں سروسز ایک ہی port استعمال کرتی ہیں۔
   موجودہ `android`، `ios`، `.git` اور signing فائلیں حذف کرنے کی ضرورت نہیں۔

## پہلے سروس چلائیں

جس CMD میں آپ نے key سیٹ کی ہے، اسی میں:

```cmd
cd /d C:\flutter_projects\shams_pdf_editor
start_text_service.cmd
```

یہ build کے بعد مصنوعی PDF پر اصل متن ہٹنے، نئی عبارت، دوسری سطر/صفحے،
خالی جگہ، لمبی عبارت اور پرانے selection کی جانچ چلائے گا۔ جانچ ناکام ہو تو
سروس آگے نہیں چلے گی؛ error کا متن بھیجیں۔ key یا اسے سیٹ کرنے والی لائن نہ بھیجیں۔

کامیابی کے بعد براؤزر میں یہ پتہ کھولیں:

http://127.0.0.1:8765/health

`status: ready` کا مطلب سروس چل رہی ہے۔ `licenseKeyLoaded: true` صرف key پڑھے
اور RegisterLicense کو دیے جانے کی اطلاع ہے؛ یہ trial کی صحت یا entitlement کی تصدیق نہیں۔

اگر key والی CMD بند ہو گئی ہو تو نئی CMD میں پہلے یہ چلائیں:

```cmd
set "SYNCFUSION_LICENSE_KEY=YOUR_LICENSE_KEY"
```

YOUR_LICENSE_KEY کو اپنی key سے بدلیں۔ key کو Program.cs یا GitHub میں نہ لکھیں۔

## پھر ایڈیٹر چلائیں

دوسری CMD کھولیں:

```cmd
cd /d C:\flutter_projects\shams_pdf_editor
start_editor_web.cmd
```

براؤزر میں http://localhost:8080 کھولیں۔ دونوں CMD کھلی رہنی چاہییں۔

## عبارت کیسے بدلیں؟

- سادہ انگریزی متن والی PDF کھولیں۔
- **Edit original text** دبائیں، پھر مطلوبہ سطر کے اندر کلک کریں۔
- منتخب عبارت دیکھیں، نئی مختصر عبارت لکھیں اور **Apply replacement** دبائیں۔
- نتیجہ دیکھیں۔ غلط ہو تو **Undo** کریں۔ درست ہو تو **Save PDF** کریں۔
- ڈاؤن لوڈ ہوئی PDF دوبارہ کھول کر نئی عبارت کی تلاش/نقل کرکے تصدیق کریں۔

## اس ورژن کی حدود

یہ پوری سطر کا اصل متن ہٹا کر منتخب فونٹ میں نئی عبارت لکھتا ہے؛
اصل فونٹ کی عین شکل برقرار رہنے کی ضمانت نہیں۔ اصل سائز، رنگ اور bold/italic لیا جاتا ہے۔
نئی عبارت اصل جگہ میں آنی چاہیے؛ Fit فعال ہو تو فونٹ چھوٹا کیا جاتا ہے۔ مکمل پیراگراف خود دوبارہ ترتیب نہیں پاتے۔

منتخب مستطیل سفید ہو جاتا ہے؛ اسی حصے میں موجود تصویر یا گرافکس بھی مٹ سکتے ہیں۔
سفید پس منظر والے سادہ متن پر آزمائیں۔ رنگین پس منظر، تصویر پر لکھائی، گھمائے یا
crop کیے ہوئے صفحات، غیرمعمولی coordinates اور signed/encrypted PDF پر استعمال نہ کریں۔
اردو/عربی کی موجودہ عبارت بدلنا اور scanned PDF کا OCR اس ورژن میں نہیں ہے۔
نئی اردو عبارت شامل کرنے والا Add text + TTF + RTL الگ سہولت ہے۔

## ویب اور موبائل اشاعت

GitHub Pages Flutter کا سامنے والا حصہ چلا سکتا ہے؛ یہ .NET سروس وہاں نہیں چلتی۔
ابھی سروس صرف اسی کمپیوٹر کے browser کے لیے ہے۔ Android/iOS یا دوسرے لوگوں کے
کمپیوٹر سے original-text editing کے لیے الگ HTTPS سرور، authentication اور deployment
کی ترتیب باقی ہے۔ localhost موبائل پر آپ کے laptop کا پتہ نہیں ہوتا۔

## جانچ کی حقیقت

اس اپ ڈیٹ کا .NET build اور Flutter build یہاں نہیں چل سکا کیونکہ SDK دستیاب نہیں تھے۔
یہ code handoff ہے؛ کامیاب build یا production-ready ہونے کا دعویٰ نہیں۔
`start_text_service.cmd` پہلے آپ کے نصب شدہ SDK پر ضروری جانچ کرے گا۔
