import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/user_profile.dart';
import '../models/vehicle.dart';
import '../models/maintenance.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final dbPath = await getDatabasesPath();
    _database = await openDatabase(
      p.join(dbPath, 'mon_garage.db'),
      version: 3,
      onCreate: (db, version) async {
        await _createBaseTables(db);
        await _createMaintenanceTables(db);
        await _createOdometerTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createMaintenanceTables(db);
        if (oldVersion < 3) {
          await _createOdometerTable(db);
          final vehicles = await db.query('vehicles');
          for (final vehicle in vehicles) {
            await db.insert('odometer_readings', {
              'vehicle_id': vehicle['id'],
              'reading_date': DateTime.now().toIso8601String().substring(0, 10),
              'mileage': vehicle['mileage'] ?? 0,
              'created_at': DateTime.now().toIso8601String(),
            });
          }
        }
      },
    );
    return _database!;
  }

  Future<void> _createBaseTables(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE user_profile (
      id INTEGER PRIMARY KEY CHECK (id = 1), first_name TEXT NOT NULL,
      last_name TEXT NOT NULL DEFAULT '', country TEXT NOT NULL DEFAULT 'Algérie',
      email TEXT NOT NULL DEFAULT '')''');
    await db.execute('''CREATE TABLE vehicles (
      id INTEGER PRIMARY KEY AUTOINCREMENT, nickname TEXT NOT NULL DEFAULT '',
      make TEXT NOT NULL, model TEXT NOT NULL, year INTEGER,
      fuel TEXT NOT NULL, engine TEXT NOT NULL DEFAULT '',
      engine_code TEXT NOT NULL DEFAULT '', vin TEXT NOT NULL DEFAULT '',
      mileage INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP)''');
  }

  Future<void> _createMaintenanceTables(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS maintenance_records (
      id INTEGER PRIMARY KEY AUTOINCREMENT, vehicle_id INTEGER NOT NULL,
      title TEXT NOT NULL, category TEXT NOT NULL, date TEXT NOT NULL,
      mileage INTEGER NOT NULL, cost REAL NOT NULL DEFAULT 0,
      notes TEXT NOT NULL DEFAULT '')''');
    await db.execute('''CREATE TABLE IF NOT EXISTS maintenance_reminders (
      id INTEGER PRIMARY KEY AUTOINCREMENT, vehicle_id INTEGER NOT NULL,
      title TEXT NOT NULL, due_date TEXT, due_mileage INTEGER,
      notes TEXT NOT NULL DEFAULT '', completed INTEGER NOT NULL DEFAULT 0,
      notified INTEGER NOT NULL DEFAULT 0)''');
  }


  Future<void> _createOdometerTable(DatabaseExecutor db) async {
    await db.execute('''CREATE TABLE IF NOT EXISTS odometer_readings (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      vehicle_id INTEGER NOT NULL,
      reading_date TEXT NOT NULL,
      mileage INTEGER NOT NULL,
      created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
    )''');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_odometer_vehicle_date ON odometer_readings(vehicle_id, reading_date, id)');
  }

  Future<UserProfile?> getProfile() async {
    final rows = await (await database).query('user_profile', where: 'id = 1', limit: 1);
    return rows.isEmpty ? null : UserProfile.fromMap(rows.first);
  }
  Future<void> saveProfile(UserProfile profile) async => (await database).insert(
    'user_profile', {...profile.toMap(), 'id': 1}, conflictAlgorithm: ConflictAlgorithm.replace);

  Future<List<Vehicle>> getVehicles() async {
    final rows = await (await database).query('vehicles', orderBy: 'id DESC');
    return rows.map(Vehicle.fromMap).toList();
  }
  Future<int> saveVehicle(Vehicle vehicle) async {
    final db = await database;
    return db.transaction((txn) async {
      if (vehicle.id == null) {
        final id = await txn.insert('vehicles', vehicle.toMap());
        final today = DateTime.now().toIso8601String().substring(0, 10);
        await _validateMileageAtDate(
          txn,
          vehicleId: id,
          date: today,
          mileage: vehicle.mileage,
          sourceTable: 'odometer_readings',
        );
        await txn.insert('odometer_readings', {
          'vehicle_id': id,
          'reading_date': today,
          'mileage': vehicle.mileage,
          'created_at': DateTime.now().toIso8601String(),
        });
        return id;
      }

      final existing = await txn.query(
        'vehicles',
        columns: ['mileage'],
        where: 'id = ?',
        whereArgs: [vehicle.id],
        limit: 1,
      );
      if (existing.isEmpty) {
        throw const OdometerReadingException('Ce véhicule n’existe plus.');
      }
      final oldMileage = existing.first['mileage'] as int?;
      if (oldMileage != null && oldMileage != vehicle.mileage) {
        final today = DateTime.now().toIso8601String().substring(0, 10);
        await _validateMileageAtDate(
          txn,
          vehicleId: vehicle.id!,
          date: today,
          mileage: vehicle.mileage,
          sourceTable: 'odometer_readings',
        );
      }
      final changed = await txn.update(
        'vehicles',
        vehicle.toMap(),
        where: 'id = ?',
        whereArgs: [vehicle.id],
      );
      if (oldMileage != null && oldMileage != vehicle.mileage) {
        await txn.insert('odometer_readings', {
          'vehicle_id': vehicle.id,
          'reading_date': DateTime.now().toIso8601String().substring(0, 10),
          'mileage': vehicle.mileage,
          'created_at': DateTime.now().toIso8601String(),
        });
      }
      return changed;
    });
  }

  Future<void> _validateMileageAtDate(
    Transaction txn, {
    required int vehicleId,
    required String date,
    required int mileage,
    required String sourceTable,
    int? sourceId,
  }) async {
    if (mileage < 0) {
      throw const OdometerReadingException('Le kilométrage ne peut pas être négatif.');
    }

    final odometerRows = await txn.query(
      'odometer_readings',
      where: 'vehicle_id = ?',
      whereArgs: [vehicleId],
    );
    final maintenanceRows = await txn.query(
      'maintenance_records',
      where: 'vehicle_id = ?',
      whereArgs: [vehicleId],
    );

    final events = <({String date, int mileage})>[];
    for (final row in odometerRows) {
      if (sourceTable == 'odometer_readings' && row['id'] == sourceId) continue;
      events.add((
        date: row['reading_date'] as String,
        mileage: row['mileage'] as int,
      ));
    }
    for (final row in maintenanceRows) {
      if (sourceTable == 'maintenance_records' && row['id'] == sourceId) continue;
      events.add((
        date: row['date'] as String,
        mileage: row['mileage'] as int,
      ));
    }

    for (final event in events) {
      if (event.date.compareTo(date) < 0 && event.mileage > mileage) {
        throw OdometerReadingException(
          'Kilométrage incohérent : le relevé du ${_formatDate(date)} '
          '(${_formatNumber(mileage)} km) est inférieur à un kilométrage '
          'antérieur du ${_formatDate(event.date)} '
          '(${_formatNumber(event.mileage)} km). Le kilométrage doit rester '
          'croissant ou égal au fil du temps.',
        );
      }
      if (event.date.compareTo(date) > 0 && event.mileage < mileage) {
        throw OdometerReadingException(
          'Kilométrage incohérent : le relevé du ${_formatDate(date)} '
          '(${_formatNumber(mileage)} km) est supérieur à un kilométrage '
          'enregistré à une date plus récente, le ${_formatDate(event.date)} '
          '(${_formatNumber(event.mileage)} km). Le kilométrage doit rester '
          'croissant ou égal au fil du temps.',
        );
      }
    }
  }

  Future<List<OdometerReading>> getOdometerReadings(int vehicleId) async {
    final rows = await (await database).query(
      'odometer_readings', where: 'vehicle_id = ?', whereArgs: [vehicleId],
      orderBy: 'reading_date DESC, id DESC');
    return rows.map(OdometerReading.fromMap).toList();
  }

  Future<void> saveOdometerReading({required int vehicleId, required int mileage, required DateTime date, int? id}) async {
    if (mileage < 0) {
      throw const OdometerReadingException('Le kilométrage ne peut pas être négatif.');
    }
    final db = await database;
    final day = date.toIso8601String().substring(0, 10);
    await db.transaction((txn) async {
      await _validateMileageAtDate(
        txn,
        vehicleId: vehicleId,
        date: day,
        mileage: mileage,
        sourceTable: 'odometer_readings',
        sourceId: id,
      );

      if (id == null) {
        await txn.insert('odometer_readings', {
          'vehicle_id': vehicleId,
          'reading_date': day,
          'mileage': mileage,
          'created_at': DateTime.now().toIso8601String(),
        });
      } else {
        final updated = await txn.update(
          'odometer_readings',
          {'reading_date': day, 'mileage': mileage},
          where: 'id = ? AND vehicle_id = ?',
          whereArgs: [id, vehicleId],
        );
        if (updated == 0) {
          throw const OdometerReadingException('Ce relevé n’existe plus. Actualisez l’historique.');
        }
      }

      final latest = await txn.query(
        'odometer_readings',
        where: 'vehicle_id = ?',
        whereArgs: [vehicleId],
        orderBy: 'reading_date DESC, id DESC',
        limit: 1,
      );
      if (latest.isNotEmpty) {
        await txn.update(
          'vehicles',
          {'mileage': latest.first['mileage']},
          where: 'id = ?',
          whereArgs: [vehicleId],
        );
      }
    });
  }

  Future<void> deleteOdometerReading(int readingId, int vehicleId) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('odometer_readings', where: 'id = ? AND vehicle_id = ?', whereArgs: [readingId, vehicleId]);
      final latest = await txn.query('odometer_readings', where: 'vehicle_id = ?', whereArgs: [vehicleId], orderBy: 'reading_date DESC, id DESC', limit: 1);
      if (latest.isNotEmpty) {
        await txn.update('vehicles', {'mileage': latest.first['mileage']}, where: 'id = ?', whereArgs: [vehicleId]);
      }
    });
  }
  Future<int> deleteVehicle(int id) async {
    final db = await database;
    await db.delete('maintenance_records', where: 'vehicle_id = ?', whereArgs: [id]);
    await db.delete('odometer_readings', where: 'vehicle_id = ?', whereArgs: [id]);
    await db.delete('maintenance_reminders', where: 'vehicle_id = ?', whereArgs: [id]);
    return db.delete('vehicles', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<MaintenanceRecord>> getRecords({int? vehicleId}) async {
    final rows = await (await database).query('maintenance_records',
      where: vehicleId == null ? null : 'vehicle_id = ?',
      whereArgs: vehicleId == null ? null : [vehicleId], orderBy: 'date DESC, id DESC');
    return rows.map(MaintenanceRecord.fromMap).toList();
  }
  Future<int> saveRecord(MaintenanceRecord record) async {
    final db = await database;
    return db.transaction((txn) async {
      await _validateMileageAtDate(
        txn,
        vehicleId: record.vehicleId,
        date: record.date,
        mileage: record.mileage,
        sourceTable: 'maintenance_records',
        sourceId: record.id,
      );
      if (record.id == null) return txn.insert('maintenance_records', record.toMap());
      return txn.update(
        'maintenance_records',
        record.toMap(),
        where: 'id = ?',
        whereArgs: [record.id],
      );
    });
  }
  Future<int> deleteRecord(int id) async => (await database).delete('maintenance_records', where: 'id = ?', whereArgs: [id]);

  Future<List<MaintenanceReminder>> getReminders({int? vehicleId}) async {
    final rows = await (await database).query('maintenance_reminders',
      where: vehicleId == null ? null : 'vehicle_id = ?',
      whereArgs: vehicleId == null ? null : [vehicleId], orderBy: 'completed ASC, due_date ASC, due_mileage ASC');
    return rows.map(MaintenanceReminder.fromMap).toList();
  }
  Future<int> saveReminder(MaintenanceReminder reminder) async {
    final db = await database;
    final values = reminder.toMap()..remove('id')..['notified'] = 0;
    if (reminder.id == null) return db.insert('maintenance_reminders', values);
    return db.update('maintenance_reminders', values, where: 'id = ?', whereArgs: [reminder.id]);
  }

  Future<List<MaintenanceReminder>> getUnnotifiedReminders() async {
    final rows = await (await database).query('maintenance_reminders', where: 'completed = 0 AND notified = 0 AND due_mileage IS NOT NULL');
    return rows.map(MaintenanceReminder.fromMap).toList();
  }
  Future<void> markReminderNotified(int id) async => (await database).update(
    'maintenance_reminders', {'notified': 1}, where: 'id = ?', whereArgs: [id]);

  Future<void> setReminderCompleted(int id, bool completed) async => (await database).update(
    'maintenance_reminders', {'completed': completed ? 1 : 0, 'notified': completed ? 1 : 0}, where: 'id = ?', whereArgs: [id]);
  Future<int> deleteReminder(int id) async => (await database).delete('maintenance_reminders', where: 'id = ?', whereArgs: [id]);
}


class OdometerReadingException implements Exception {
  final String message;
  const OdometerReadingException(this.message);

  @override
  String toString() => message;
}

String _formatDate(String value) {
  final parts = value.split('-');
  return parts.length == 3 ? '${parts[2]}/${parts[1]}/${parts[0]}' : value;
}

String _formatNumber(int value) => value.toString().replaceAllMapped(
      RegExp(r'(?<=\d)(?=(\d{3})+$)'), (_) => ' ');

class OdometerReading {
  final int? id;
  final int vehicleId;
  final String date;
  final int mileage;
  const OdometerReading({this.id, required this.vehicleId, required this.date, required this.mileage});
  factory OdometerReading.fromMap(Map<String, Object?> map) => OdometerReading(
    id: map['id'] as int?, vehicleId: map['vehicle_id'] as int,
    date: map['reading_date'] as String, mileage: map['mileage'] as int,
  );
}
