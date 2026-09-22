# v6 — object layout and explicit fallback: verification status

Source changes: immutable object model; base-preserving PDF export; per-page
layout; drag/resize; text styling; delete/duplicate/z-order; history; project
round trip; main-view selection/copy; matching-first explicit font fallback.
New unit cases cover text extraction after export, no duplicate text after
move, base preservation, page targeting, image serialization/resize, project
round trip, bounds, overflow, invalid sizes and rotated-page rejection.
Backend smoke tests also cover automatic fallback and original-family preference.

NOT RUN: Flutter analyze/test/build, .NET build/smoke tests, browser interaction,
Android/iOS builds, or visual positioning checks. Flutter/Dart/.NET executables
are absent. No parser could be installed from the available package source.
Archive integrity and source structure checks are not a substitute for runtime
tests. The launchers continue to run tests before starting the services.

Performed locally: lightweight delimiter balance checks across Dart/C# sources
and existence checks for relative Dart imports passed. This is not syntax/type
analysis. API signatures for Syncfusion PdfStandardFont/PdfTrueTypeFont,
PdfTextExtractor and SfPdfViewer.memory were checked against official API pages:
https://pub.dev/documentation/syncfusion_flutter_pdf/latest/pdf/PdfStandardFont/PdfStandardFont.html
https://pub.dev/documentation/syncfusion_flutter_pdf/latest/pdf/PdfTrueTypeFont/PdfTrueTypeFont.html
https://pub.dev/documentation/syncfusion_flutter_pdf/latest/pdf/PdfTextExtractor/extractText.html
https://pub.dev/documentation/syncfusion_flutter_pdfviewer/latest/pdfviewer/SfPdfViewer/SfPdfViewer.memory.html

Manual acceptance still required: open a two-page PDF; add two text objects and
two images; move/resize each; edit styles; undo/redo; delete; Apply; select/copy
text in View; export and reopen PDF; export and reopen .shams; edit on page 2;
verify a missing-original-font replacement and the reported fallback font.
Also test mouse/touch, narrow screens, custom TTF and unchanged neighboring text.

# Previous auto font update: pending local execution

Added static TTF metadata resolver, exact-name/family face matching, explicit
substitutes and default-original Bold/Italic with size controls. Added smoke
cases for style changes, Base-14 family preservation, missing-font rejection,
explicit substitution and optional Windows Arial parsing/resolution.
Official Syncfusion TrueType font stream APIs and Microsoft OpenType name/OS2
specifications were consulted. No SDKs available here: new C#/Flutter build,
new smoke checks and font rendering are NOT executed or visually verified.
Previous user success predates both latest fitting and font changes.

# Reliability update: verification status

User screenshots confirm the previous .NET build, ten smoke checks, Flutter
analyzer and five Flutter tests passed. A real CV line was replaced successfully.
This update adds bounded font fitting, manual size reduction, in-dialog errors,
draft retention and a submission lock. New smoke cases cover successful fitting,
searchable output, fit-disabled overflow and invalid sizes. They have NOT been
run here: .NET/Flutter SDKs remain unavailable. Run both launchers to validate.

# Validation: Syncfusion .NET migration

- Replaced bundled Python backend with .NET 10 / Syncfusion.Pdf.Imaging.Net.Core 34.2.8 source.
- Checked extraction/redaction API patterns against Syncfusion documentation.
- Added a generated-document smoke harness (old text removed, new text searchable,
  neighbor/second page retained, deletion, stale hash, overflow, Unicode and blank selection).
- Launcher refuses to start the HTTP service if build or smoke checks fail.
- Secret comes only from SYNCFUSION_LICENSE_KEY. Health reports presence, not license validity.
- Only loopback 8765, localhost/127.0.0.1 port 8080 origins, JSON requests,
  bounded input, one edit at a time, no document writes or body/key logging.
- NOT EXECUTED here: dotnet build, smoke harness, Flutter analyzer/tests, browser
  integration or visual PDF verification. SDKs absent; download attempt timed out.
- Earlier Python test results do not validate this replacement and are withdrawn
  from this version's validation report. Earlier user Flutter checks predate this update.
- Archive structure, required source/launcher files and Python removal checked locally.
- No remote deployment, DNS changes, Android/iOS release or Play Store publication.
