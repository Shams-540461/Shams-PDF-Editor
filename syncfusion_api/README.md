# Shams Syncfusion local text service

Target: .NET 10, Windows x64, Syncfusion.Pdf.Imaging.Net.Core 34.2.8.
Set SYNCFUSION_LICENSE_KEY in CMD and run ../start_text_service.cmd.
Never embed the key in Dart or commit it. Health does not validate entitlement.

GET /health reports engine and key presence.
POST /edit accepts the Flutter adapter's select/replace JSON protocol.
The full PDF is base64 encoded in each request and handled in memory.

This is a local development service, not a public API. Deployment needs TLS,
authentication, quotas, process time/memory isolation and native assets for the
server OS. CORS is not authentication. GitHub Pages cannot run this backend.
SDK/vendor licensing and telemetry behavior is governed by Syncfusion.

Read ../EDIT_TEXT_URDU.md for supported edits and limitations. Redaction removes
underlying content/graphics inside the rectangle, not just visible characters.
Returned bytes are a new full save after reopening the redacted PDF; this feature
is not a document sanitization or confidential-data-removal guarantee.

Official API references used:
https://help.syncfusion.com/document-processing/pdf/pdf-library/net/working-with-text-extraction
https://help.syncfusion.com/document-processing/pdf/pdf-library/net/working-with-redaction
https://help.syncfusion.com/document-processing/licensing/how-to-register-in-an-application
