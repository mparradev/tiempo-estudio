import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mi_primera_app/main.dart';
import 'package:mi_primera_app/study_store.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  final factory = databaseFactoryFfiNoIsolate;

  test(
    'SQLite conserva materias, sesiones y metas al reabrir la base',
    () async {
      final folder = await Directory.systemTemp.createTemp('studyplan_test_');
      addTearDown(() => folder.delete(recursive: true));
      final location = path.join(folder.path, 'studyplan.db');
      final week = DateTime(2026, 11, 23);
      var store = await StudyStore.open(factory: factory, location: location);
      await store.saveSubject(null, 'Historia', 0xff5146d8);
      final subject = (await store.subjects()).single;
      await store.saveSession(
        StudySession(
          subjectId: subject.id,
          day: week,
          start: 540,
          end: 600,
          status: SessionStatus.completed,
          notes: 'Repasar fechas',
        ),
      );
      await store.saveGoal(week, 180);
      await store.db.close();

      store = await StudyStore.open(factory: factory, location: location);
      addTearDown(store.db.close);
      expect((await store.subjects()).single.name, 'Historia');
      final session = (await store.sessions()).single;
      expect(session.duration, 60);
      expect(session.status, SessionStatus.completed);
      expect(session.notes, 'Repasar fechas');
      expect((await store.goals())[dateKey(week)], 180);
      await store.deleteSubject(subject.id);
      expect(await store.sessions(), isEmpty);
    },
  );

  testWidgets('Una sesión completada se refleja en las estadísticas', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final store = (await tester.runAsync(() async {
      final store = await StudyStore.open(
        factory: factory,
        location: inMemoryDatabasePath,
      );
      await store.saveSubject(null, 'Matemáticas', 0xff5146d8);
      final subject = (await store.subjects()).single;
      await store.saveSession(
        StudySession(
          subjectId: subject.id,
          day: DateTime.now(),
          start: 540,
          end: 600,
          status: SessionStatus.completed,
          notes: '',
        ),
      );
      return store;
    }))!;
    addTearDown(store.db.close);
    await tester.runAsync(() async {
      await tester.pumpWidget(MyApp(openStore: () async => store));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pumpAndSettle();
    expect(find.text('1 h / 10 h'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.bar_chart_outlined));
    await tester.pumpAndSettle();
    expect(find.text('1 de 1 sesiones completadas'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('1 h · 100 %'), 150);
    expect(find.text('1 h · 100 %'), findsOneWidget);
  });
}
