// Picks the sqflite backend for the current platform. Android/iOS use the
// default platform-channel factory; the web build (Chrome) runs SQLite as
// WebAssembly from `web/sqlite3.wasm`.
export 'db_factory_native.dart'
    if (dart.library.js_interop) 'db_factory_web.dart';
