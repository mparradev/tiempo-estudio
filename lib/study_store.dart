import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart' as mobile;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

enum SessionStatus {
  pending('Pendiente'),
  completed('Completada'),
  rescheduled('Reprogramada');

  const SessionStatus(this.label);
  final String label;
}

class Subject {
  const Subject(this.id, this.name, this.color);
  final int id;
  final String name;
  final int color;
}

class StudySession {
  const StudySession({
    this.id,
    required this.subjectId,
    required this.day,
    required this.start,
    required this.end,
    required this.status,
    required this.notes,
  });

  final int? id;
  final int subjectId;
  final DateTime day;
  final int start;
  final int end;
  final SessionStatus status;
  final String notes;

  int get duration => end - start;
  DateTime get startsAt =>
      DateTime(day.year, day.month, day.day, start ~/ 60, start % 60);

  Map<String, Object?> toRow() => {
    'subject_id': subjectId,
    'day': day.toIso8601String().substring(0, 10),
    'start_minute': start,
    'end_minute': end,
    'status': status.name,
    'notes': notes,
  };

  factory StudySession.fromRow(Map<String, Object?> row) => StudySession(
    id: row['id'] as int,
    subjectId: row['subject_id'] as int,
    day: DateTime.parse(row['day'] as String),
    start: row['start_minute'] as int,
    end: row['end_minute'] as int,
    status: SessionStatus.values.byName(row['status'] as String),
    notes: row['notes'] as String,
  );
}

class StudyStore {
  StudyStore(this.db);
  final Database db;

  static Future<StudyStore> open({
    DatabaseFactory? factory,
    String? location,
  }) async {
    if (factory == null && (Platform.isWindows || Platform.isLinux)) {
      sqfliteFfiInit();
      factory = databaseFactoryFfi;
    }
    final driver = factory ?? mobile.databaseFactory;
    final db = await driver.openDatabase(
      location ?? path.join(await driver.getDatabasesPath(), 'studyplan.db'),
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE subjects (
              id INTEGER PRIMARY KEY, name TEXT NOT NULL, color INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE UNIQUE INDEX subject_name ON subjects (name COLLATE NOCASE)
          ''');
          await db.execute('''
            CREATE TABLE sessions (
              id INTEGER PRIMARY KEY,
              subject_id INTEGER NOT NULL REFERENCES subjects(id) ON DELETE CASCADE,
              day TEXT NOT NULL,
              start_minute INTEGER NOT NULL,
              end_minute INTEGER NOT NULL CHECK(end_minute > start_minute),
              status TEXT NOT NULL,
              notes TEXT NOT NULL
            )
          ''');
          await db.execute(
            'CREATE INDEX session_day ON sessions(day, start_minute)',
          );
          await db.execute('''
            CREATE TABLE goals (week TEXT PRIMARY KEY, minutes INTEGER NOT NULL)
          ''');
        },
      ),
    );
    return StudyStore(db);
  }

  Future<List<Subject>> subjects() async => [
    for (final row in await db.query(
      'subjects',
      orderBy: 'name COLLATE NOCASE',
    ))
      Subject(row['id'] as int, row['name'] as String, row['color'] as int),
  ];

  Future<List<StudySession>> sessions() async => [
    for (final row in await db.query('sessions', orderBy: 'day, start_minute'))
      StudySession.fromRow(row),
  ];

  Future<Map<String, int>> goals() async => {
    for (final row in await db.query('goals'))
      row['week'] as String: row['minutes'] as int,
  };

  Future<void> saveSubject(int? id, String name, int color) async {
    final values = {'name': name, 'color': color};
    if (id == null) {
      await db.insert('subjects', values);
    } else {
      await db.update('subjects', values, where: 'id = ?', whereArgs: [id]);
    }
  }

  Future<void> saveSession(StudySession session) async {
    if (session.id == null) {
      await db.insert('sessions', session.toRow());
    } else {
      await db.update(
        'sessions',
        session.toRow(),
        where: 'id = ?',
        whereArgs: [session.id],
      );
    }
  }

  Future<void> deleteSubject(int id) async =>
      db.delete('subjects', where: 'id = ?', whereArgs: [id]);

  Future<void> deleteSession(int id) async =>
      db.delete('sessions', where: 'id = ?', whereArgs: [id]);

  Future<void> saveGoal(DateTime week, int minutes) async => db.insert(
    'goals',
    {'week': dateKey(week), 'minutes': minutes},
    conflictAlgorithm: ConflictAlgorithm.replace,
  );
}

String dateKey(DateTime date) => date.toIso8601String().substring(0, 10);

DateTime shiftDay(DateTime date, int days) =>
    DateTime(date.year, date.month, date.day + days);

DateTime weekStart(DateTime date) => shiftDay(date, 1 - date.weekday);
