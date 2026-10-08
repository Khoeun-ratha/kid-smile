import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

void configureDatabaseFactory() {
  // No shared worker: avoids needing the generated sqflite_sw.js, at the
  // cost of the DB living in this tab only (fine for a single-player app).
  databaseFactory = databaseFactoryFfiWebNoWebWorker;
}
