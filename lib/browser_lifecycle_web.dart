import 'dart:js_interop';
@JS('shamsSetDirty')
external void _setDirty(JSBoolean dirty);
void updateBrowserDirty(bool dirty) => _setDirty(dirty.toJS);
