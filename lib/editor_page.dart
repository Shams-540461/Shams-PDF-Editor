import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as pdf;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'drawing_pad.dart';
import 'pdf_edits.dart';
import 'text_dialog.dart';
import 'browser_lifecycle.dart';
import 'original_text_service.dart';
import 'object_project.dart';
import 'object_editor.dart';

typedef PdfSaveCallback = Future<bool> Function(Uint8List bytes, String name);

enum _Tool { view, editText, text, line, rectangle, image, draw }

class SyncfusionPdfEditor extends StatefulWidget {
  const SyncfusionPdfEditor({
    super.key,
    this.initialBytes,
    this.fileName = 'document.pdf',
    this.password,
    this.onSave,
    this.textFont,
  });

  final Uint8List? initialBytes;
  final String fileName;
  final String? password;
  final PdfSaveCallback? onSave;
  final pdf.PdfFont? textFont;

  @override
  State<SyncfusionPdfEditor> createState() => _SyncfusionPdfEditorState();
}

class _SyncfusionPdfEditorState extends State<SyncfusionPdfEditor> {
  final _viewer = PdfViewerController();
  final List<Uint8List> _undo = [];
  final Map<Uint8List, ObjectProject?> _objectUndo = {};
  ObjectProject? _project;
  Uint8List? _bytes;
  late String _name;
  _Tool _tool = _Tool.view;
  bool _busy = false, _ready = false, _dirty = false;
  int _revision = 0, _restorePage = 1;
  double _restoreZoom = 1;
  Offset? _firstPoint;
  int? _firstPage;
  _ImageEdit? _lastImage;
  String? _loadError;
  Uint8List? _fontData;
  double _textSize = 16;
  bool _rtl = false;
  bool _textServiceConsent = false;
  static const _maxFileBytes = 30 * 1024 * 1024;
  static const _maxUndoBytes = 64 * 1024 * 1024;

  @override
  void initState() {
    super.initState();
    _bytes = widget.initialBytes == null
        ? null
        : Uint8List.fromList(widget.initialBytes!);
    _name = widget.fileName;
  }

  @override
  void dispose() {
    updateBrowserDirty(false);
    _viewer.dispose();
    super.dispose();
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      _message(e is StateError ? e.message.toString() : 'Operation failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Discard unsaved changes?'),
            content: const Text('Save first if you want to keep these changes.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false),
                  child: const Text('Keep editing')),
              TextButton(onPressed: () => Navigator.pop(context, true),
                  child: const Text('Discard')),
            ],
          ),
        ) ?? false;
  }

  pdf.PdfDocument _document(Uint8List bytes) => pdf.PdfDocument(
        inputBytes: bytes,
        password: widget.password,
      );

  Future<Uint8List> _snapshot() async {
    FocusManager.instance.primaryFocus?.unfocus();
    await WidgetsBinding.instance.endOfFrame;
    return Uint8List.fromList(await _viewer.saveDocument());
  }

  Future<Uint8List> _readFile(PlatformFile file) async {
    final length = await file.length();
    if (length != null && length > _maxFileBytes) {
      throw StateError('Please use a file smaller than 30 MB.');
    }
    final bytes = await file.readAsBytes();
    if (bytes.length > _maxFileBytes || bytes.isEmpty) {
      throw StateError('The file is empty or larger than 30 MB.');
    }
    return bytes;
  }

  // Revision keys force a fresh viewer; edits use PDF coordinates, never pixels.
  void _replace(Uint8List bytes, {int? page, bool dirty = true}) {
    setState(() {
      _restorePage = page ?? math.max(1, _viewer.pageNumber);
      _restoreZoom = _viewer.zoomLevel;
      _bytes = bytes;
      _revision++;
      _ready = false;
      _dirty = dirty;
      updateBrowserDirty(dirty);
      _loadError = null;
      _firstPoint = null;
      _firstPage = null;
    });
  }

  Future<void> _open() => _run(() async {
        if (!await _confirmDiscard() || !mounted) return;
        final file = await FilePicker.pickFile(
          type: FileType.custom, allowedExtensions: ['pdf', 'shams']);
        if (file == null) return;
        ObjectProject? project;
        final Uint8List bytes;
        if (file.name.toLowerCase().endsWith('.shams')) {
          final length = await file.length();
          if (length != null && length > 80 * 1024 * 1024) throw StateError('Project exceeds 80 MB.');
          project = ObjectProject.decode(await file.readAsBytes());
          bytes = await project.render(password: widget.password);
        } else {
          bytes = await _readFile(file);
        }
        final doc = _document(bytes);
        try {
          if (doc.pages.count == 0) throw StateError('PDF has no pages.');
        } finally {
          doc.dispose();
        }
        if (!mounted) return;
        _undo.clear();
        _objectUndo.clear();
        _project = project;
        _lastImage = null;
        _name = file.name.replaceFirst(RegExp(r'\.shams$', caseSensitive: false), '.pdf');
        _replace(bytes, page: 1, dirty: false);
      });

  void _viewerEdited() {
    if (!_ready || _busy || !mounted) return;
    setState(() {
      _dirty = true;
      updateBrowserDirty(true);
      // Avoid overwriting viewer-side form/annotation edits during image resize.
      _lastImage = null;
      _undo.clear();
      _objectUndo.clear();
      if (_project != null) _message('Form/annotation changed: added objects are now committed. Use your saved .shams project to rearrange them.');
      _project = null;
    });
  }

  Future<void> _save() => _run(() async {
        // Capture viewer form/annotation edits as well as our page graphics.
        final bytes = await _snapshot();
        if (!mounted) return;
        final bool saved;
        if (widget.onSave != null) {
          saved = await widget.onSave!(bytes, _name);
        } else {
          final uri = await FilePicker.saveFile(
            fileName: _name,
            bytes: bytes,
            mimeType: 'application/pdf',
          );
          saved = uri != null;
        }
        if (!mounted || !saved) return;
        setState(() => _dirty = false);
        updateBrowserDirty(false);
        _message(kIsWeb && widget.onSave == null
            ? 'PDF export handed to your browser.' : 'PDF saved.');
      });

  Future<void> _mutate(
    int pageNumber,
    void Function(pdf.PdfPage page) draw, {
    Uint8List? base,
    _ImageEdit? image,
  }) async {
    final before = await _snapshot();
    final after = await PdfEdits.apply(
      base ?? before, pageNumber, draw, password: widget.password);
    if (!mounted) return;
    _remember(before);
    _project = null;
    _lastImage = image;
    _replace(after, page: pageNumber);
  }

  Future<void> _undoEdit() => _run(() async {
        if (_undo.isEmpty) return;
        _lastImage = null;
        final bytes = _undo.removeLast();
        _project = _objectUndo.remove(bytes);
        _replace(bytes);
      });

  void _remember(Uint8List before) {
    _undo.add(before);
    _objectUndo[before] = _project;
    while (_undo.length > 10 ||
        _undo.fold<int>(0, (sum, b) => sum + b.length) > _maxUndoBytes) {
      _objectUndo.remove(_undo.removeAt(0));
    }
  }

  Future<bool> _confirmCommitObjects() async {
    if (_project == null || _project!.objects.isEmpty) return true;
    return await showDialog<bool>(context: context, builder: (c) => AlertDialog(
      title: const Text('Commit added objects first?'),
      content: const Text('This operation commits movable objects into the PDF. '
        'Save a .shams project in Arrange text/images first if you want to move them later. '
        'Saving a PDF alone keeps text selectable, but does not store editable object handles.'),
      actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Continue'))])) ?? false;
  }

  Future<void> _arrange({int? page, Offset? point, String? tool}) async {
    final before = await _snapshot();
    if (!mounted) return;
    updateBrowserDirty(true);
    final result = await Navigator.push<ObjectEditorResult>(context, MaterialPageRoute(
      builder: (_) => ObjectEditor(project: _project ?? ObjectProject(before, []),
        page: page ?? math.max(1, _viewer.pageNumber), point: point,
        initialTool: tool, password: widget.password, fontData: _fontData,
        fontSize: _textSize, rtl: _rtl)));
    if (!mounted) return;
    updateBrowserDirty(_dirty);
    if (result == null) return;
    _remember(before);
    _project = result.project;
    _lastImage = null;
    _replace(result.bytes, page: page);
    _message('Layout applied. View mode lets you select/copy text. Save PDF to export.');
  }

  Future<String?> _textDialog() => showDialog<String>(
    context: context,
    builder: (_) => TextInsertDialog(rtl: _rtl),
  );

  Future<void> _chooseFont() => _run(() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom, allowedExtensions: ['ttf']);
    if (file == null) return;
    final bytes = await _readFile(file);
    // Validate before accepting the font. Variable/unsupported fonts can fail.
    pdf.PdfTrueTypeFont(bytes, _textSize).measureString('Test');
    if (!mounted) return;
    setState(() => _fontData = bytes);
    _message('Font loaded. It will be used for new text.');
  });

  Future<void> _sample() => _run(() async {
    if (!await _confirmDiscard() || !mounted) return;
    final doc = pdf.PdfDocument();
    late Uint8List bytes;
    try {
      doc.pages.add().graphics.drawString(
        'Your ideas. Your document.',
        pdf.PdfStandardFont(pdf.PdfFontFamily.helvetica, 24),
        bounds: const Rect.fromLTWH(36, 36, 440, 70),
        brush: pdf.PdfBrushes.black);
      bytes = Uint8List.fromList(await doc.save());
    } finally { doc.dispose(); }
    if (!mounted) return;
    _undo.clear();
    _objectUndo.clear();
    _project = null;
    _lastImage = null;
    _name = 'shams-document.pdf';
    _replace(bytes, page: 1);
  });

  Future<double?> _imageWidth(double current, double maximum) async {
    double width = current.clamp(1.0, maximum).toDouble();
    return showDialog<double>(
      context: context,
      builder: (context) => StatefulBuilder(builder: (context, update) {
        return AlertDialog(
          title: const Text('Image size'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Width: ${width.toStringAsFixed(0)} PDF points'),
            const Text('Aspect ratio is preserved.'),
            Slider(value: width, min: 1, max: maximum,
                onChanged: (value) => update(() => width = value)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, width),
                child: const Text('Apply')),
          ],
        );
      }),
    );
  }

  Future<void> _editOriginalText(int pageNumber, Offset point) async {
    if (!_textServiceConsent) {
      final consent = await showDialog<bool>(context: context, builder: (dialogContext) =>
        AlertDialog(
          title: const Text('Edit original PDF text'),
          content: Text('This tool sends the open PDF to the text editing service at '
              '${OriginalTextService.endpoint}. The bundled local service processes it '
              'in memory on your computer. Continue only if you trust this address. '
              'Other editing tools do not use this service.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Continue')),
          ],
        ));
      if (consent != true || !mounted) return;
      _textServiceConsent = true;
    }
    final before = await _snapshot();
    final selection = await OriginalTextService.select(
      before, pageNumber, point.dx, point.dy);
    if (!mounted) return;
    final after = await showDialog<TextReplacement>(context: context,
      barrierDismissible: false,
      builder: (context) => _OriginalTextDialog(
        original: selection['text'] as String,
        originalSize: (selection['size'] as num).toDouble(),
        originalFont: selection['fontName'] as String? ?? 'Unknown (restart the updated service)',
        originalBold: selection['bold'] as bool? ?? false,
        originalItalic: selection['italic'] as bool? ?? false,
        onApply: (text, size, fit, bold, italic, mode) => OriginalTextService.replace(
          before, pageNumber, selection, text, fontSize: size, autoFit: fit,
          bold: bold, italic: italic, fontMode: mode),
      ));
    if (after == null || !mounted) return;
    _remember(before);
    _project = null;
    _lastImage = null;
    _replace(after.bytes, page: pageNumber);
    _message('Original text replaced. Font used: ${after.fontName}, ${after.fontSize.toStringAsFixed(1)} pt. Review, then Save PDF.');
  }

  Future<void> _tap(PdfGestureDetails details) async {
    if (_busy || !_ready || _tool == _Tool.view || details.pageNumber < 1) return;
    await _run(() async {
      final pageNumber = details.pageNumber;
      final point = details.pagePosition;
      final doc = _document(_bytes!);
      late Size size;
      try {
        final page = doc.pages[pageNumber - 1];
        if (page.rotation != pdf.PdfPageRotateAngle.rotateAngle0) {
          _message('Editing rotated pages is not supported in this widget.');
          return;
        }
        size = page.getClientSize();
      } finally {
        doc.dispose();
      }
      if (point.dx < 0 || point.dy < 0 ||
          point.dx >= size.width || point.dy >= size.height) return;
      if (_tool == _Tool.text || _tool == _Tool.image) {
        await _arrange(page: pageNumber, point: point, tool: _tool.name);
        return;
      }
      if (!await _confirmCommitObjects() || !mounted) return;
      switch (_tool) {
        case _Tool.view:
          return;
        case _Tool.editText:
          await _editOriginalText(pageNumber, point);
          break;
        case _Tool.text: {
          final text = await _textDialog();
          if (!mounted || text == null) return;
          if (widget.textFont == null && _fontData == null &&
              text.runes.any((rune) => rune > 255)) {
            _message('Load a TTF font supporting your language using the Font button.');
            return;
          }
          final font = widget.textFont ?? (_fontData == null
              ? pdf.PdfStandardFont(pdf.PdfFontFamily.helvetica, _textSize)
              : pdf.PdfTrueTypeFont(_fontData!, _textSize));
          final format = pdf.PdfStringFormat(
            textDirection: _rtl ? pdf.PdfTextDirection.rightToLeft : pdf.PdfTextDirection.leftToRight,
            alignment: _rtl ? pdf.PdfTextAlignment.right : pdf.PdfTextAlignment.left,
          );
          final bounds = Rect.fromLTWH(point.dx, point.dy,
              size.width - point.dx, size.height - point.dy);
          // Reject text that would be silently clipped by the remaining area.
          // Explicit newlines are supported; long lines must fit without wrap.
          final measured = font.measureString(text, format: format);
          if (measured.width > bounds.width || measured.height > bounds.height) {
            _message('Text does not fit here. Tap further up or use shorter text.');
            return;
          }
          await _mutate(pageNumber, (page) => page.graphics.drawString(
              text, font, brush: pdf.PdfBrushes.black, bounds: bounds, format: format));
          break;
        }
        case _Tool.line:
        case _Tool.rectangle: {
          if (_firstPoint == null || _firstPage != pageNumber) {
            setState(() { _firstPoint = point; _firstPage = pageNumber; });
            _message('Start selected. Tap the second point on this page.');
            return;
          }
          final start = _firstPoint!;
          if ((point - start).distance < 1) return;
          final rectangle = Rect.fromPoints(start, point);
          if (_tool == _Tool.rectangle &&
              (rectangle.width < 1 || rectangle.height < 1)) return;
          final tool = _tool;
          await _mutate(pageNumber, (page) {
            final pen = pdf.PdfPen(pdf.PdfColor(220, 30, 40), width: 2);
            if (tool == _Tool.line) {
              page.graphics.drawLine(pen, start, point);
            } else {
              page.graphics.drawRectangle(pen: pen, bounds: rectangle);
            }
          });
          break;
        }
        case _Tool.draw: {
          final drawing = await showDialog<InkDrawing>(
            context: context, builder: (_) => const DrawingPad());
          if (!mounted || drawing == null) return;
          final width = math.min(240.0,
            math.min(size.width - point.dx, (size.height - point.dy) * 2));
          if (width < 10) {
            _message('Tap farther from the page edge to insert a drawing.');
            return;
          }
          await _mutate(pageNumber, (page) => PdfEdits.drawInk(
            page, drawing.strokes,
            Rect.fromLTWH(point.dx, point.dy, width, width / 2),
            InkDrawing.canvasSize));
          break;
        }
        case _Tool.image: {
          final file = await FilePicker.pickFile(
              type: FileType.custom, allowedExtensions: ['png', 'jpg', 'jpeg']);
          if (file == null) return;
          final bytes = await _readFile(file);
          final bitmap = pdf.PdfBitmap(bytes);
          final ratio = bitmap.height / bitmap.width;
          final maximum = math.min(size.width - point.dx,
              (size.height - point.dy) / ratio);
          if (!mounted || maximum <= 1) return;
          final width = await _imageWidth(math.min(160.0, maximum), maximum);
          if (!mounted || width == null) return;
          final base = await _snapshot();
          final image = _ImageEdit(base, pageNumber, point, bytes,
              width, ratio, maximum);
          await _mutate(pageNumber, image.draw, base: base, image: image);
          break;
        }
      }
    });
  }

  Future<void> _resizeImage() => _run(() async {
        final old = _lastImage;
        if (old == null) return;
        final width = await _imageWidth(old.width, old.maximum);
        if (!mounted || width == null || width == old.width) return;
        final image = _ImageEdit(old.base, old.page, old.point, old.bytes,
            width, old.ratio, old.maximum);
        await _mutate(image.page, image.draw, base: image.base, image: image);
      });

  String get _hint => switch (_tool) {
        _Tool.view => 'Scroll or pinch to zoom.',
        _Tool.editText => 'Tap an existing English text line to replace it. Original line width is preserved.',
        _Tool.text => 'Tap where the text should start.',
        _Tool.line => 'Tap two points on one page to draw a line.',
        _Tool.rectangle => 'Tap two opposite corners on one page.',
        _Tool.image => 'Tap the top-left corner, then choose a PNG or JPEG.',
        _Tool.draw => 'Tap a position on the page, then draw or sign in the pad.',
      };

  @override
  Widget build(BuildContext context) {
    final enabled = _ready && !_busy;
    return PopScope(
      canPop: !_dirty && !_busy,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || _busy) return;
        if (await _confirmDiscard() && mounted) {
          setState(() => _dirty = false);
          updateBrowserDirty(false);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.of(context).pop(result);
          });
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_bytes == null ? 'Shams PDF Editor' : '$_name${_dirty ? ' *' : ''}'),
          actions: [
            IconButton(tooltip: 'New sample PDF', onPressed: _busy ? null : _sample,
                icon: const Icon(Icons.note_add_outlined)),
            IconButton(tooltip: 'Open PDF', onPressed: _busy ? null : _open,
                icon: const Icon(Icons.folder_open)),
            IconButton(tooltip: 'Undo editor action',
                onPressed: enabled && _undo.isNotEmpty ? _undoEdit : null,
                icon: const Icon(Icons.undo)),
            IconButton(tooltip: 'Save PDF', onPressed: enabled ? _save : null,
                icon: const Icon(Icons.save)),
          ],
        ),
        body: Column(children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(children: [
              for (final tool in _Tool.values)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(tool == _Tool.editText ? 'Edit original text' : tool == _Tool.text ? 'Add text' : tool.name), selected: _tool == tool,
                    onSelected: enabled ? (_) => setState(() {
                      _tool = tool; _firstPoint = null; _firstPage = null;
                    }) : null,
                  ),
                ),
              TextButton.icon(
                onPressed: enabled ? () => _run(() => _arrange()) : null,
                icon: const Icon(Icons.open_with),
                label: const Text('Arrange text/images'),
              ),
              if (_lastImage != null) TextButton.icon(
                onPressed: enabled ? _resizeImage : null,
                icon: const Icon(Icons.photo_size_select_large),
                label: const Text('Resize image'),
              ),
              TextButton.icon(
                onPressed: enabled && _tool != _Tool.editText ? _chooseFont : null,
                icon: const Icon(Icons.font_download_outlined),
                label: Text(_fontData == null ? 'Load TTF font' : 'Change font'),
              ),
              const SizedBox(width: 8),
              const Text('RTL'),
              Switch(value: _rtl, onChanged: enabled && _tool != _Tool.editText ? (v) => setState(() => _rtl = v) : null),
              DropdownButton<double>(
                value: _textSize,
                items: [10.0, 12.0, 16.0, 20.0, 24.0, 32.0].map((v) =>
                    DropdownMenuItem(value: v, child: Text('${v.toInt()} pt'))).toList(),
                onChanged: enabled && _tool != _Tool.editText ? (v) => setState(() => _textSize = v ?? 16) : null,
              ),
            ]),
          ),
          Padding(padding: const EdgeInsets.all(8), child: Text(_hint)),
          if (_busy) const LinearProgressIndicator(),
          Expanded(child: _bytes == null
              ? Center(child: SingleChildScrollView(child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.description_outlined, size: 72, color: Color(0xFF126B64)),
                      const SizedBox(height: 20),
                      Text('Make your PDF yours.', style: Theme.of(context).textTheme.headlineMedium,
                        textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      const Text('Add text, insert and resize an image, draw, then save a copy.',
                        textAlign: TextAlign.center),
                      const SizedBox(height: 28),
                      Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.center, children: [
                        FilledButton.icon(onPressed: _busy ? null : _open,
                          icon: const Icon(Icons.upload_file), label: const Text('Open a PDF')),
                        OutlinedButton.icon(onPressed: _busy ? null : _sample,
                          icon: const Icon(Icons.note_add_outlined), label: const Text('Try a sample')),
                      ]),
                      const SizedBox(height: 24),
                      const Text('Your document is processed on this device.\nUp to 30 MB per file.',
                        textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      const Text('Original-text replacement: English lines only, within the original width. Embedded images cannot be selected for editing.',
                        textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
                    ]),
                  ),
                )) )
              : Stack(children: [
                  AbsorbPointer(
                    absorbing: _busy,
                    child: SfPdfViewer.memory(
                      _bytes!, key: ValueKey(_revision), controller: _viewer,
                      password: widget.password,
                      canShowPasswordDialog: false,
                      initialPageNumber: _restorePage,
                      initialZoomLevel: _restoreZoom,
                      interactionMode: _tool == _Tool.view ? PdfInteractionMode.selection : PdfInteractionMode.pan,
                      enableTextSelection: _tool == _Tool.view,
                      canShowTextSelectionMenu: _tool == _Tool.view,
                      enableDoubleTapZooming: _tool == _Tool.view,
                      enableDocumentLinkAnnotation: _tool == _Tool.view,
                      enableHyperlinkNavigation: _tool == _Tool.view,
                      canShowSignaturePadDialog: false,
                      onTap: _tap,
                      onDocumentLoaded: (_) {
                        if (mounted) setState(() => _ready = true);
                      },
                      onDocumentLoadFailed: (details) {
                        if (mounted) setState(() {
                          _ready = false;
                          _loadError = details.description;
                        });
                      },
                      onFormFieldValueChanged: (_) => _viewerEdited(),
                      onAnnotationAdded: (_) => _viewerEdited(),
                      onAnnotationEdited: (_) => _viewerEdited(),
                      onAnnotationRemoved: (_) => _viewerEdited(),
                    ),
                  ),
                  if (_loadError != null)
                    Center(child: Card(child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text('Unable to display PDF: $_loadError\n'
                          'Check the password and web PDF.js setup, or open another PDF.'),
                    ))),
                ])),
        ]),
      ),
    );
  }
}

class _ImageEdit {
  const _ImageEdit(this.base, this.page, this.point, this.bytes,
      this.width, this.ratio, this.maximum);
  final Uint8List base, bytes;
  final int page;
  final Offset point;
  final double width, ratio, maximum;

  void draw(pdf.PdfPage page) => page.graphics.drawImage(
      pdf.PdfBitmap(bytes),
      Rect.fromLTWH(point.dx, point.dy, width, width * ratio));
}

class _OriginalTextDialog extends StatefulWidget {
  const _OriginalTextDialog({required this.original, required this.originalSize,
    required this.onApply, required this.originalFont, required this.originalBold,
    required this.originalItalic});
  final String original;
  final double originalSize;
  final String originalFont;
  final bool originalBold;
  final bool originalItalic;
  final Future<TextReplacement> Function(String, double, bool, bool, bool, String) onApply;
  @override
  State<_OriginalTextDialog> createState() => _OriginalTextDialogState();
}

class _OriginalTextDialogState extends State<_OriginalTextDialog> {
  late final TextEditingController _controller;
  late final TextEditingController _sizeController;
  bool _autoFit = true;
  late bool _bold;
  late bool _italic;
  String _fontMode = 'autoFallback';
  bool _saving = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.original);
    _sizeController = TextEditingController(text: widget.originalSize.toString());
    _bold = widget.originalBold;
    _italic = widget.originalItalic;
  }
  @override
  void dispose() {
    _controller.dispose();
    _sizeController.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    if (_saving) return;
    final size = double.tryParse(_sizeController.text);
    final minimum = widget.originalSize < 6 ? widget.originalSize : 6.0;
    if (size == null || !size.isFinite || size < minimum || size > 200) {
      setState(() => _error = 'Choose a font size from $minimum to 200 pt.');
      return;
    }
    if (_controller.text.runes.any((c) => c < 32 || c > 126)) {
      setState(() => _error = 'Use one line of plain English text. Original Urdu/Arabic replacement is not supported yet.');
      return;
    }
    if (_controller.text == widget.original && size == widget.originalSize &&
        _bold == widget.originalBold && _italic == widget.originalItalic &&
        (_fontMode == 'auto' || _fontMode == 'autoFallback')) {
      Navigator.pop(context);
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final bytes = await widget.onApply(_controller.text, size, _autoFit, _bold, _italic, _fontMode);
      if (!mounted) return;
      setState(() => _saving = false);
      // Let PopScope rebuild before closing the dialog.
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.pop(context, bytes);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e is StateError ? e.message.toString() : 'The edit could not be completed. Your text is still here; please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: const Text('Replace original line'),
      content: SizedBox(width: 520, child: SingleChildScrollView(child: Column(
        mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Selected original text:'),
          SelectableText(widget.original),
          const SizedBox(height: 16),
          TextField(controller: _controller, autofocus: true, maxLength: 2000,
            enabled: !_saving, minLines: 2, maxLines: 4,
            decoration: const InputDecoration(labelText: 'Replacement text',
              border: OutlineInputBorder())),
          const SizedBox(height: 12),
          Text('Original font: ${widget.originalFont}'),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _fontMode,
            decoration: const InputDecoration(labelText: 'Replacement font',
              border: OutlineInputBorder()),
            items: const [
              DropdownMenuItem(value: 'autoFallback', child: Text('Auto + Helvetica if unavailable')),
              DropdownMenuItem(value: 'auto', child: Text('Auto: match original font')),
              DropdownMenuItem(value: 'helvetica', child: Text('Substitute: Helvetica')),
              DropdownMenuItem(value: 'times', child: Text('Substitute: Times')),
              DropdownMenuItem(value: 'courier', child: Text('Substitute: Courier')),
            ],
            onChanged: _saving ? null : (value) => setState(() => _fontMode = value!),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 12, children: [
            FilterChip(label: const Text('Bold', style: TextStyle(fontWeight: FontWeight.bold)),
              selected: _bold, onSelected: _saving ? null : (v) => setState(() => _bold = v)),
            FilterChip(label: const Text('Italic', style: TextStyle(fontStyle: FontStyle.italic)),
              selected: _italic, onSelected: _saving ? null : (v) => setState(() => _italic = v)),
          ]),
          const SizedBox(height: 12),
          TextField(controller: _sizeController, enabled: !_saving,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: 'Font size (pt)',
              helperText: 'Original size: ${widget.originalSize} pt',
              border: const OutlineInputBorder())),
          SwitchListTile(contentPadding: EdgeInsets.zero,
            title: const Text('Fit text to original area'),
            subtitle: const Text('Reduce the font if needed, down to 6 pt. Paragraphs stay in place.'),
            value: _autoFit,
            onChanged: _saving ? null : (value) => setState(() => _autoFit = value)),
          if (_error != null) ...[
            Semantics(liveRegion: true, child: Text(_error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error))),
            const SizedBox(height: 12),
          ],
          const Text('Auto + fallback first tries the original font. If the font or requested style is unavailable, Helvetica is used; it may look different. Choose strict Auto for an exact available family. Original color is retained. '
            'The original line is removed. Its rectangle becomes white; intersecting graphics or images can also be removed. '
            'Use plain text on a white background and review before saving. '
            'Leave empty to delete this line. Undo is available before closing.'),
        ],
      ))),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _saving ? null : _apply,
          child: Text(_saving ? 'Applying...' : 'Apply replacement')),
      ],
    ),
  );
}
