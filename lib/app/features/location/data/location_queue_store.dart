import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/location_sample.dart';

/// Durable local queue of GPS points captured between server flushes.
///
/// Opened ONLY from inside the foreground-task isolate ([TmsLocationHandler]
/// in `location_service.dart`) — the main app isolate never touches this
/// database, so there is no cross-isolate concurrent-write hazard to guard
/// against.
///
/// Points survive here until the server confirms it received them
/// ([deleteByUuids]); if a flush fails (offline, timeout), they simply stay
/// queued for the next attempt.
class LocationQueueStore {
  static const _dbName = 'tracking_queue.db';
  static const _table = 'pending_locations';

  Database? _db;

  Future<Database> _database() async {
    final existing = _db;
    if (existing != null) return existing;

    final dbPath = p.join(await getDatabasesPath(), _dbName);
    final db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            trip_id INTEGER NOT NULL,
            location_uuid TEXT NOT NULL UNIQUE,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            accuracy REAL,
            speed REAL,
            heading REAL,
            recorded_at TEXT NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_pending_locations_recorded_at ON $_table(recorded_at)',
        );
      },
    );
    _db = db;
    return db;
  }

  Future<void> enqueue(LocationSample sample) async {
    final db = await _database();
    await db.insert(
      _table,
      sample.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// The oldest [limit] not-yet-confirmed points, oldest first — the shape
  /// a batch flush should be sent and (on ack) deleted in.
  Future<List<LocationSample>> oldestBatch({required int limit}) async {
    final db = await _database();
    final rows = await db.query(
      _table,
      orderBy: 'recorded_at ASC',
      limit: limit,
    );
    return rows.map(LocationSample.fromDbMap).toList();
  }

  /// Removes exactly the points the server acknowledged. Never called on a
  /// failed/uncertain flush — a failed attempt leaves rows queued for retry.
  Future<void> deleteByUuids(List<String> uuids) async {
    if (uuids.isEmpty) return;
    final db = await _database();
    final placeholders = List.filled(uuids.length, '?').join(',');
    await db.delete(
      _table,
      where: 'location_uuid IN ($placeholders)',
      whereArgs: uuids,
    );
  }

  Future<void> clearForTrip(int tripId) async {
    final db = await _database();
    await db.delete(_table, where: 'trip_id = ?', whereArgs: [tripId]);
  }

  Future<int> pendingCount() async {
    final db = await _database();
    final result = await db.rawQuery('SELECT COUNT(*) AS c FROM $_table');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Bounds queue growth during an extended offline period by dropping the
  /// oldest rows beyond [maxRows]. Only triggers once the cap is exceeded.
  Future<void> trimToMax(int maxRows) async {
    final db = await _database();
    final count = await pendingCount();
    final overflow = count - maxRows;
    if (overflow <= 0) return;
    await db.delete(
      _table,
      where: '''id IN (
        SELECT id FROM $_table ORDER BY recorded_at ASC LIMIT ?
      )''',
      whereArgs: [overflow],
    );
  }
}
