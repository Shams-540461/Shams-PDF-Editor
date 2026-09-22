import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as pdf;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'object_project.dart';

class ObjectEditorResult {
  const ObjectEditorResult(this.project, this.bytes);
  final ObjectProject project;
  final Uint8List bytes;
}

class ObjectEditor extends StatefulWidget {
  const ObjectEditor({super.key, required this.project, required this.page,
    this.password, this.initialTool, this.fontData, this.point,
    this.fontSize = 16, this.rtl = false});
  final ObjectProject project;
  final int page;
  final String? password, initialTool;
  final Uint8List? fontData;
  final Offset? point;
  final double fontSize;
  final bool rtl;
  @override
  State<ObjectEditor> createState() => _ObjectEditorState();
}

class _ObjectEditorState extends State<ObjectEditor> {
  late List<PdfObject> _objects;
  final List<List<PdfObject>> _undo = [], _redo = [];
  final Map<int, String> _fontFamilies = {};
  late int _page;
  int _count = 1, _nextId = 1;
  int? _selected;
  Size _pageSize = const Size(595, 842);
  Uint8List? _preview;
  bool _busy = true, _changed = false, _allowExit = false;
  String? _error;
  PdfObject? _dragStart;
  double _dragScale = 1;

  PdfObject? get _active {
    for (final o in _objects) { if (o.id == _selected) return o; }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _objects = [...widget.project.objects];
    _page = widget.page;
    for (final o in _objects) { _nextId = math.max(_nextId, o.id + 1); }
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  Future<void> _initialize() async {
    await _work(() async {
      final doc = pdf.PdfDocument(inputBytes: widget.project.base, password: widget.password);
      try { _count = doc.pages.count; } finally { doc.dispose(); }
      for (final o in _objects) { await _loadFont(o); }
      await _loadPage();
    });
    if (!mounted || _error != null) return;
    if (widget.initialTool == 'text') await _addText();
    if (widget.initialTool == 'image') await _addImage();
  }

  Future<void> _work(Future<void> Function() fn) async {
    if (!mounted) return;
    setState(() { _busy = true; _error = null; });
    try { await fn(); }
    catch (e) {
      if (mounted) setState(() => _error = e is StateError ? e.message.toString() : e.toString());
    } finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _loadFont(PdfObject object) async {
    if (object.fontData == null || _fontFamilies.containsKey(object.id)) return;
    final name = 'Shams_${identityHashCode(this)}_${object.id}';
    final loader = FontLoader(name)..addFont(Future.value(ByteData.sublistView(object.fontData!)));
    await loader.load();
    _fontFamilies[object.id] = name;
  }

  Future<void> _loadPage() async {
    if (mounted) setState(() { _preview = null; _selected = null; });
    final doc = pdf.PdfDocument(inputBytes: widget.project.base, password: widget.password);
    try { _pageSize = doc.pages[_page - 1].getClientSize(); }
    finally { doc.dispose(); }
    final bytes = await widget.project.pagePreview(_page, password: widget.password);
    if (mounted) setState(() { _preview = bytes; _selected = null; });
  }

  void _checkpoint() {
    _undo.add([..._objects]);
    if (_undo.length > 40) _undo.removeAt(0);
    _redo.clear();
    _changed = true;
  }
  void _history(bool redo) {
    final from = redo ? _redo : _undo, to = redo ? _undo : _redo;
    if (from.isEmpty) return;
    setState(() { to.add([..._objects]); _objects = from.removeLast(); _selected = null; _changed = true; });
  }
  void _setObject(PdfObject object) {
    setState(() { _objects = [for (final o in _objects) if (o.id == object.id) object else o]; });
  }
  Future<void> _addText() => _work(() async {
    if (_objects.length >= 100) throw StateError('Maximum 100 objects per project.');
    final object = PdfObject(id: _nextId, page: _page,
      bounds: (widget.point ?? const Offset(40, 40)) & const Size(150, 24),
      text: '', fontSize: widget.fontSize, fontData: widget.fontData, rtl: widget.rtl);
    final edited = await showDialog<PdfObject>(context: context,
      builder: (_) => _TextProperties(object: object, pageSize: _pageSize));
    if (edited == null || !mounted) return;
    await _loadFont(edited);
    if (!mounted) return;
    setState(() { _checkpoint(); _objects.add(edited); _selected = edited.id; _nextId++; });
  });

  Future<void> _addImage() => _work(() async {
    if (_objects.length >= 100) throw StateError('Maximum 100 objects per project.');
    final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['png', 'jpg', 'jpeg']);
    if (file == null) return;
    final length = await file.length();
    if (length != null && length > 10 * 1024 * 1024) throw StateError('Use an image under 10 MB.');
    final bytes = await file.readAsBytes();
    if (bytes.length > 10 * 1024 * 1024) throw StateError('Use an image under 10 MB.');
    final bitmap = pdf.PdfBitmap(bytes);
    if (bitmap.width <= 0 || bitmap.height <= 0 || bitmap.width * bitmap.height > 25000000) {
      throw StateError('Use an image of at most 25 megapixels.');
    }
    final ratio = bitmap.height / bitmap.width;
    final width = math.min(180.0, math.min(_pageSize.width, _pageSize.height / ratio));
    final object = PdfObject(id: _nextId++, page: _page, image: bytes,
      bounds: PdfObject.constrain((widget.point ?? const Offset(40, 40)) & Size(width, width * ratio), _pageSize));
    if (!mounted) return;
    setState(() { _checkpoint(); _objects.add(object); _selected = object.id; });
  });

  Future<void> _properties() => _work(() async {
    final active = _active;
    if (active == null || active.text == null) return;
    final result = await showDialog<PdfObject>(context: context,
      builder: (_) => _TextProperties(object: active, pageSize: _pageSize));
    if (result == null || !mounted) return;
    _checkpoint();
    _setObject(result);
  });

  void _delete() {
    if (_active == null) return;
    setState(() { _checkpoint(); _objects.removeWhere((o) => o.id == _selected); _selected = null; });
  }
  Future<void> _duplicate() => _work(() async {
    final object = _active;
    if (object == null) return;
    if (_objects.length >= 100) throw StateError('Maximum 100 objects per project.');
    final copy = object.copy(id: _nextId++, bounds: PdfObject.constrain(object.bounds.shift(const Offset(12, 12)), _pageSize));
    await _loadFont(copy);
    if (!mounted) return;
    setState(() { _checkpoint(); _objects.add(copy); _selected = copy.id; });
  });
  void _reorder(bool front) {
    final object = _active;
    if (object == null) return;
    setState(() {
      _checkpoint(); _objects.remove(object);
      if (front) { _objects.add(object); } else { _objects.insert(0, object); }
    });
  }
  void _nudge(Offset delta) {
    final object = _active;
    if (object == null || _busy) return;
    _checkpoint();
    _setObject(object.copy(bounds: PdfObject.constrain(object.bounds.shift(delta), _pageSize)));
  }

  Future<void> _saveProject() => _work(() async {
    final bytes = ObjectProject(widget.project.base, _objects).encode();
    if (bytes.length > 80 * 1024 * 1024) throw StateError('Project exceeds 80 MB.');
    await FilePicker.saveFile(fileName: 'shams-editable.shams', bytes: bytes, mimeType: 'application/json');
  });
  Future<void> _done() => _work(() async {
    final project = ObjectProject(widget.project.base, _objects);
    final bytes = await project.render(password: widget.password);
    if (!mounted) return;
    setState(() => _allowExit = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.pop(context, ObjectEditorResult(project, bytes));
  });
  Future<void> _cancel() async {
    if (_busy) return;
    if (_changed) {
      final discard = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
        title: const Text('Discard layout changes?'),
        content: const Text('Use Apply to keep this layout, or Save project to keep editable objects.'),
        actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep editing')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Discard'))]));
      if (discard != true) return;
    }
    if (!mounted) return;
    setState(() => _allowExit = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.pop(context);
  }

  Widget _button(String label, IconData icon, VoidCallback? action) => TextButton.icon(
    onPressed: _busy ? null : action, icon: Icon(icon, size: 18), label: Text(label));

  Widget _object(PdfObject object, double scale) {
    final selected = _selected == object.id;
    final r = object.bounds;
    return Positioned(key: ValueKey('object-${object.id}'), left: r.left * scale,
      top: r.top * scale, width: r.width * scale, height: r.height * scale,
      child: GestureDetector(behavior: HitTestBehavior.opaque,
        onTap: _busy ? null : () => setState(() => _selected = object.id),
        onDoubleTap: _busy || object.text == null ? null : () { _selected = object.id; _properties(); },
        onPanStart: _busy ? null : (_) {
          setState(() => _selected = object.id); _checkpoint(); _dragStart = object; _dragScale = scale;
        },
        onPanUpdate: _busy ? null : (d) {
          final current = _active;
          if (current != null) _setObject(current.copy(bounds: PdfObject.constrain(
            current.bounds.shift(d.delta / _dragScale), _pageSize)));
        },
        onPanEnd: (_) => _dragStart = null,
        onPanCancel: () { if (_dragStart != null) _setObject(_dragStart!); _dragStart = null; },
        child: Stack(clipBehavior: Clip.none, children: [
          Positioned.fill(child: object.image != null
            ? Image.memory(object.image!, fit: BoxFit.fill, gaplessPlayback: true)
            : ClipRect(child: Text(object.text!, softWrap: false,
              textScaler: TextScaler.noScaling,
              textDirection: object.rtl ? TextDirection.rtl : TextDirection.ltr,
              style: TextStyle(fontFamily: _fontFamilies[object.id], fontSize: object.fontSize * scale,
                fontWeight: object.bold ? FontWeight.bold : FontWeight.normal,
                fontStyle: object.italic ? FontStyle.italic : FontStyle.normal,
                color: Color(object.color), height: 1.12)))),
          if (selected) ...[
            Positioned.fill(child: IgnorePointer(child: DecoratedBox(decoration:
              BoxDecoration(border: Border.all(color: Colors.teal, width: 2))))),
            Positioned(right: 0, bottom: 0, width: 24, height: 24,
              child: GestureDetector(behavior: HitTestBehavior.opaque,
                onPanStart: _busy ? null : (_) { _checkpoint(); _dragStart = object; _dragScale = scale; },
                onPanUpdate: _busy ? null : (d) {
                  final current = _active;
                  if (current == null) return;
                  final ratio = current.bounds.height / current.bounds.width;
                  final maxWidth = math.min(_pageSize.width - current.bounds.left,
                    (_pageSize.height - current.bounds.top) / ratio);
                  final width = (current.bounds.width + d.delta.dx / _dragScale)
                    .clamp(math.min(12.0, maxWidth), maxWidth).toDouble();
                  if (current.text != null) {
                    final size = (current.fontSize * width / current.bounds.width).clamp(6.0, 200.0).toDouble();
                    try { _setObject(current.copy(fontSize: size).measured(_pageSize)); }
                    catch (_) { /* Keep the last valid size at the page boundary. */ }
                  } else {
                    _setObject(current.copy(bounds: current.bounds.topLeft & Size(width, width * ratio)));
                  }
                },
                onPanEnd: (_) => _dragStart = null,
                onPanCancel: () { if (_dragStart != null) _setObject(_dragStart!); _dragStart = null; },
                child: const ColoredBox(color: Colors.teal, child: Icon(Icons.open_in_full, size: 18, color: Colors.white)))),
          ],
        ])));
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: _allowExit,
    onPopInvokedWithResult: (didPop, result) { if (!didPop) _cancel(); },
    child: CallbackShortcuts(bindings: {
      const SingleActivator(LogicalKeyboardKey.arrowLeft): () => _nudge(const Offset(-1, 0)),
      const SingleActivator(LogicalKeyboardKey.arrowRight): () => _nudge(const Offset(1, 0)),
      const SingleActivator(LogicalKeyboardKey.arrowUp): () => _nudge(const Offset(0, -1)),
      const SingleActivator(LogicalKeyboardKey.arrowDown): () => _nudge(const Offset(0, 1)),
    }, child: Focus(autofocus: true, child: Scaffold(
      appBar: AppBar(title: const Text('Arrange text / images'), leading: IconButton(
        icon: const Icon(Icons.close), onPressed: _busy ? null : _cancel),
        actions: [_button('Save project', Icons.save_outlined, _saveProject),
          _button('Apply', Icons.check, _done)]),
      body: Column(children: [
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
          _button('Text', Icons.text_fields, _preview == null ? null : _addText),
          _button('Image', Icons.add_photo_alternate, _preview == null ? null : _addImage),
          _button('Properties', Icons.edit, _active?.text != null ? _properties : null),
          _button('Delete', Icons.delete_outline, _active != null ? _delete : null),
          _button('Duplicate', Icons.copy, _active != null ? _duplicate : null),
          _button('Front', Icons.flip_to_front, _active != null ? () => _reorder(true) : null),
          _button('Back', Icons.flip_to_back, _active != null ? () => _reorder(false) : null),
          _button('Undo', Icons.undo, _undo.isNotEmpty ? () => _history(false) : null),
          _button('Redo', Icons.redo, _redo.isNotEmpty ? () => _history(true) : null),
          _button('Previous', Icons.chevron_left, _page > 1 ? () => _work(() async { _page--; await _loadPage(); }) : null),
          Text('Page $_page / $_count'),
          _button('Next', Icons.chevron_right, _page < _count ? () => _work(() async { _page++; await _loadPage(); }) : null),
        ])),
        const Padding(padding: EdgeInsets.all(8), child: Text(
          'Drag to move • Bottom-right handle to resize • Double-click text to edit • Arrow keys to nudge. '
          'Layout text preview is approximate; Apply shows the actual PDF.')),
        if (_error != null) Padding(padding: const EdgeInsets.all(8), child: SelectableText(_error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error))),
        if (_busy) const LinearProgressIndicator(),
        Expanded(child: LayoutBuilder(builder: (context, constraints) {
          if (_preview == null) return const Center(child: Text('Preparing page…'));
          final scale = math.min(math.max(1.0, constraints.maxWidth - 24) / _pageSize.width,
            math.max(1.0, constraints.maxHeight - 24) / _pageSize.height);
          return Center(child: SizedBox(width: _pageSize.width * scale, height: _pageSize.height * scale,
            child: Stack(children: [
              Positioned.fill(child: IgnorePointer(child: SfPdfViewer.memory(_preview!, key: ValueKey(_preview),
                password: widget.password, canShowPasswordDialog: false,
                pageSpacing: 0, maxZoomLevel: 1, enableTextSelection: false,
                enableDoubleTapZooming: false, canShowScrollHead: false,
                canShowScrollStatus: false, canShowPaginationDialog: false,
                onDocumentLoadFailed: (details) {
                  if (mounted) setState(() => _error = 'Page preview could not load: ${details.description}');
                },
                pageLayoutMode: PdfPageLayoutMode.single))),
              Positioned.fill(child: GestureDetector(behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _selected = null))),
              for (final object in _objects.where((o) => o.page == _page)) _object(object, scale),
            ])));
        })),
      ]),
    ))),
  );
}

class _TextProperties extends StatefulWidget {
  const _TextProperties({required this.object, required this.pageSize});
  final PdfObject object;
  final Size pageSize;
  @override
  State<_TextProperties> createState() => _TextPropertiesState();
}
class _TextPropertiesState extends State<_TextProperties> {
  late final _text = TextEditingController(text: widget.object.text);
  late final _size = TextEditingController(text: widget.object.fontSize.toString());
  late bool _bold = widget.object.bold, _italic = widget.object.italic, _rtl = widget.object.rtl;
  late int _color = widget.object.color;
  String? _error;
  @override
  void dispose() { _text.dispose(); _size.dispose(); super.dispose(); }
  void _apply() {
    try {
      final object = widget.object.copy(text: _text.text,
        fontSize: double.tryParse(_size.text) ?? double.nan,
        bold: _bold, italic: _italic, rtl: _rtl, color: _color).measured(widget.pageSize);
      Navigator.pop(context, object);
    } catch (e) { setState(() => _error = e is StateError ? e.message.toString() : e.toString()); }
  }
  @override
  Widget build(BuildContext context) => AlertDialog(title: const Text('Text properties'),
    content: SizedBox(width: 450, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: _text, autofocus: true, minLines: 2, maxLines: 6, maxLength: 2000,
        decoration: const InputDecoration(labelText: 'Text (line breaks supported)')),
      TextField(controller: _size, keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: 'Size, 6–200 pt')),
      Wrap(spacing: 8, children: [
        FilterChip(label: const Text('Bold'), selected: _bold, onSelected: (v) => setState(() => _bold = v)),
        FilterChip(label: const Text('Italic'), selected: _italic, onSelected: (v) => setState(() => _italic = v)),
        FilterChip(label: const Text('RTL'), selected: _rtl, onSelected: (v) => setState(() => _rtl = v)),
      ]),
      DropdownButton<int>(value: _color, items: [
        const DropdownMenuItem(value: 0xff000000, child: Text('Black')),
        const DropdownMenuItem(value: 0xffb71c1c, child: Text('Red')),
        const DropdownMenuItem(value: 0xff0d47a1, child: Text('Blue')),
        const DropdownMenuItem(value: 0xff00695c, child: Text('Teal')),
        if (![0xff000000, 0xffb71c1c, 0xff0d47a1, 0xff00695c].contains(_color))
          DropdownMenuItem(value: _color, child: const Text('Custom project color')),
      ], onChanged: (v) => setState(() => _color = v!)),
      if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
    ]))), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      FilledButton(onPressed: _apply, child: const Text('Apply'))]);
}
