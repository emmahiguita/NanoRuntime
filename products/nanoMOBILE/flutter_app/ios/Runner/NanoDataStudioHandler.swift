import Flutter
import UIKit
import SQLite3

/// Manejador de almacenamiento local y bases de datos SQLite en iOS sandbox:
/// Atiende los canales com.nanoai/data_studio y com.nanoai/automation_store.
internal final class NanoDataStudioHandler: NanoChannelHandler {
  private var studioChannel: FlutterMethodChannel?
  private var storeChannel: FlutterMethodChannel?

  func register(with messenger: FlutterBinaryMessenger) {
    studioChannel = FlutterMethodChannel(name: "com.nanoai/data_studio", binaryMessenger: messenger)
    studioChannel?.setMethodCallHandler { [weak self] (call, result) in
      self?.handleStudio(call: call, result: result)
    }

    storeChannel = FlutterMethodChannel(name: "com.nanoai/automation_store", binaryMessenger: messenger)
    storeChannel?.setMethodCallHandler { [weak self] (call, result) in
      self?.handleStore(call: call, result: result)
    }
  }

  func detach() {
    studioChannel?.setMethodCallHandler(nil)
    storeChannel?.setMethodCallHandler(nil)
    studioChannel = nil
    storeChannel = nil
  }

  private func documentsPath(filename: String) -> String {
    let docs = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    try? FileManager.default.createDirectory(at: docs, withIntermediateDirectories: true)
    return docs.appendingPathComponent(filename).path
  }

  private func handleStudio(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "defaultDatabase":
      result(documentsPath(filename: "nano_data_studio.db"))

    case "demoDatabase":
      result(documentsPath(filename: "nano_demo_studio.db"))

    case "createDatabase":
      let name = (call.arguments as? [String: Any])?["name"] as? String ?? "nano_db"
      result(documentsPath(filename: "\(name).db"))

    case "listTables":
      let path = (call.arguments as? [String: Any])?["path"] as? String ?? documentsPath(filename: "nano_data_studio.db")
      result(fetchTables(path: path))

    case "query":
      guard let args = call.arguments as? [String: Any],
            let path = args["path"] as? String,
            let sql = args["sql"] as? String else {
        result(["columns": [], "rows": []])
        return
      }
      result(runQuery(path: path, sql: sql))

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func handleStore(call: FlutterMethodCall, result: @escaping FlutterResult) {
    let dbPath = documentsPath(filename: "automation_store.db")
    ensureStoreTable(path: dbPath)

    switch call.method {
    case "section":
      let key = (call.arguments as? [String: Any])?["key"] as? String ?? ""
      result(getStoreValue(path: dbPath, key: key))

    case "setSection":
      guard let args = call.arguments as? [String: Any],
            let key = args["key"] as? String,
            let value = args["value"] as? String else {
        result(false)
        return
      }
      result(setStoreValue(path: dbPath, key: key, value: value))

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func fetchTables(path: String) -> [String] {
    var db: OpaquePointer?
    guard sqlite3_open(path, &db) == SQLITE_OK else { return [] }
    defer { sqlite3_close(db) }

    var stmt: OpaquePointer?
    let query = "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';"
    guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else { return [] }
    defer { sqlite3_finalize(stmt) }

    var tables: [String] = []
    while sqlite3_step(stmt) == SQLITE_ROW {
      if let cName = sqlite3_column_text(stmt, 0) {
        tables.append(String(cString: cName))
      }
    }
    return tables
  }

  private func runQuery(path: String, sql: String) -> [String: Any] {
    var db: OpaquePointer?
    guard sqlite3_open(path, &db) == SQLITE_OK else {
      return ["columns": [], "rows": []]
    }
    defer { sqlite3_close(db) }

    var stmt: OpaquePointer?
    guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
      return ["columns": [], "rows": []]
    }
    defer { sqlite3_finalize(stmt) }

    let count = sqlite3_column_count(stmt)
    var columns: [String] = []
    for i in 0..<count {
      columns.append(String(cString: sqlite3_column_name(stmt, i)))
    }

    var rows: [[Any]] = []
    while sqlite3_step(stmt) == SQLITE_ROW {
      var row: [Any] = []
      for i in 0..<count {
        switch sqlite3_column_type(stmt, i) {
        case SQLITE_INTEGER: row.append(sqlite3_column_int64(stmt, i))
        case SQLITE_FLOAT: row.append(sqlite3_column_double(stmt, i))
        case SQLITE_TEXT: row.append(String(cString: sqlite3_column_text(stmt, i)))
        case SQLITE_NULL: row.append(NSNull())
        default: row.append(NSNull())
        }
      }
      rows.append(row)
    }
    return ["columns": columns, "rows": rows]
  }

  private func ensureStoreTable(path: String) {
    var db: OpaquePointer?
    guard sqlite3_open(path, &db) == SQLITE_OK else { return }
    defer { sqlite3_close(db) }
    let schema = "CREATE TABLE IF NOT EXISTS kv_store (key TEXT PRIMARY KEY, value TEXT);"
    sqlite3_exec(db, schema, nil, nil, nil)
  }

  private func getStoreValue(path: String, key: String) -> String? {
    var db: OpaquePointer?
    guard sqlite3_open(path, &db) == SQLITE_OK else { return nil }
    defer { sqlite3_close(db) }
    var stmt: OpaquePointer?
    let sql = "SELECT value FROM kv_store WHERE key = ? LIMIT 1;"
    guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
    defer { sqlite3_finalize(stmt) }
    sqlite3_bind_text(stmt, 1, (key as NSString).utf8String, -1, nil)
    if sqlite3_step(stmt) == SQLITE_ROW, let val = sqlite3_column_text(stmt, 0) {
      return String(cString: val)
    }
    return nil
  }

  private func setStoreValue(path: String, key: String, value: String) -> Bool {
    var db: OpaquePointer?
    guard sqlite3_open(path, &db) == SQLITE_OK else { return false }
    defer { sqlite3_close(db) }
    var stmt: OpaquePointer?
    let sql = "INSERT OR REPLACE INTO kv_store (key, value) VALUES (?, ?);"
    guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return false }
    defer { sqlite3_finalize(stmt) }
    sqlite3_bind_text(stmt, 1, (key as NSString).utf8String, -1, nil)
    sqlite3_bind_text(stmt, 2, (value as NSString).utf8String, -1, nil)
    return sqlite3_step(stmt) == SQLITE_DONE
  }
}
