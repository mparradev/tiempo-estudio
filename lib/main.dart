import 'package:material_ui/material_ui.dart';

import 'study_store.dart';

const ink = Color(0xff191b38);
const purple = Color(0xff5146d8);
const muted = Color(0xff626580);
const mint = Color(0xff19897b);
const surface = Color(0xfff7f7fc);
const palette = [
  0xff5146d8,
  0xff187d9e,
  0xff19897b,
  0xffa24daa,
  0xffad631e,
  0xffbd4a70,
];
const months = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.openStore = StudyStore.open});
  final Future<StudyStore> Function() openStore;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'StudyPlan',
    debugShowCheckedModeBanner: false,
    locale: const Locale('es'),
    supportedLocales: const [Locale('es')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: purple,
        primary: purple,
        surface: Colors.white,
        onSurface: ink,
      ),
      scaffoldBackgroundColor: surface,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: Color(0xffeae7ff),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: ink,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    ),
    home: Planner(openStore: openStore),
  );
}

class Planner extends StatefulWidget {
  const Planner({super.key, required this.openStore});
  final Future<StudyStore> Function() openStore;

  @override
  State<Planner> createState() => _PlannerState();
}

class _PlannerState extends State<Planner> {
  late StudyStore store;
  bool loading = true;
  bool failed = false;
  bool saving = false;
  int tab = 0;
  List<Subject> subjects = [];
  List<StudySession> sessions = [];
  Map<String, int> goals = {};
  DateTime selected = DateUtils.dateOnly(DateTime.now());
  late DateTime month = DateTime(selected.year, selected.month);
  DateTime reportWeek = weekStart(DateTime.now());

  DateTime get today => DateUtils.dateOnly(DateTime.now());
  DateTime get currentWeek => weekStart(today);

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      store = await widget.openStore();
      await refresh();
    } catch (_) {
      if (mounted) {
        setState(() {
          loading = false;
          failed = true;
        });
      }
    }
  }

  Future<void> refresh() async {
    final newSubjects = await store.subjects();
    final newSessions = await store.sessions();
    final newGoals = await store.goals();
    if (!mounted) return;
    setState(() {
      subjects = newSubjects;
      sessions = newSessions;
      goals = newGoals;
      loading = false;
      failed = false;
    });
  }

  Future<void> save(Future<void> Function() action) async {
    if (saving) return;
    setState(() => saving = true);
    try {
      await action();
      await refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo guardar el cambio. Inténtalo de nuevo.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  List<StudySession> onDay(DateTime day) =>
      sessions.where((s) => DateUtils.isSameDay(s.day, day)).toList();

  List<StudySession> inWeek(DateTime week) => sessions
      .where((s) => !s.day.isBefore(week) && s.day.isBefore(shiftDay(week, 7)))
      .toList();

  int total(Iterable<StudySession> items) =>
      items.fold(0, (sum, s) => sum + s.duration);
  int goal(DateTime week) => goals[dateKey(week)] ?? 600;

  Future<void> editGoal(DateTime week) async {
    final form = GlobalKey<FormState>();
    var input = (goal(week) / 60)
        .toString()
        .replaceFirst(RegExp(r'\.0$'), '')
        .replaceAll('.', ',');
    double? hours() => double.tryParse(input.trim().replaceAll(',', '.'));
    final minutes = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Meta semanal'),
        content: Form(
          key: form,
          child: TextFormField(
            initialValue: input,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Horas de estudio'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (value) => input = value,
            validator: (_) {
              final value = hours();
              return value != null &&
                      value.isFinite &&
                      value >= 1 / 60 &&
                      value <= 168
                  ? null
                  : 'Introduce entre 1 minuto y 168 horas.';
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(context, (hours()! * 60).round());
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (mounted && minutes != null) {
      await save(() => store.saveGoal(week, minutes));
    }
  }

  Future<bool> confirm(String title, String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Eliminar'),
            ),
          ],
        ),
      ) ??
      false;

  Future<Subject?> editSubject([Subject? subject]) async {
    final form = GlobalKey<FormState>();
    var name = subject?.name ?? '';
    var color = subject?.color ?? palette[subjects.length % palette.length];
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(subject == null ? 'Nueva materia' : 'Editar materia'),
          content: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    initialValue: name,
                    autofocus: true,
                    maxLength: 60,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                    textCapitalization: TextCapitalization.sentences,
                    onChanged: (value) => name = value,
                    validator: (_) {
                      if (name.trim().isEmpty) return 'Escribe un nombre.';
                      if (subjects.any(
                        (s) =>
                            s.id != subject?.id &&
                            s.name.toLowerCase() == name.trim().toLowerCase(),
                      )) {
                        return 'Esta materia ya existe.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  const Text('Color'),
                  Wrap(
                    spacing: 6,
                    children: [
                      for (final (index, value) in palette.indexed)
                        IconButton(
                          tooltip: 'Color ${index + 1}',
                          onPressed: () => update(() => color = value),
                          icon: CircleAvatar(
                            radius: 15,
                            backgroundColor: Color(value),
                            child: color == value
                                ? const Icon(
                                    Icons.check,
                                    size: 17,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (form.currentState!.validate()) Navigator.pop(context, true);
              },
              child: const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || accepted != true) return null;
    await save(() => store.saveSubject(subject?.id, name.trim(), color));
    return subjects.where((s) => s.name == name.trim()).firstOrNull;
  }

  Future<void> editSession({StudySession? session, DateTime? day}) async {
    if (saving) return;
    final initial = subjects.isEmpty ? await editSubject() : subjects.first;
    if (!mounted || initial == null) return;
    final value = await Navigator.of(context).push<StudySession>(
      MaterialPageRoute(
        builder: (_) => SessionEditor(
          subjects: subjects,
          initial: initial.id,
          day: day ?? today,
          existing: session,
        ),
      ),
    );
    if (mounted && value != null) await save(() => store.saveSession(value));
  }

  @override
  Widget build(BuildContext context) {
    if (loading || failed) {
      return Scaffold(
        body: Center(
          child: failed
              ? FilledButton.icon(
                  onPressed: () {
                    setState(() {
                      loading = true;
                      failed = false;
                    });
                    load();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Reintentar abrir la base de datos'),
                )
              : const CircularProgressIndicator(),
        ),
      );
    }
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              key: PageStorageKey(tab),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: switch (tab) {
                0 => home(),
                1 => calendar(),
                2 => reports(),
                _ => library(),
              },
            ),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (index) => setState(() => tab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Calendario',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart_rounded),
            label: 'Estadísticas',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book_rounded),
            label: 'Materias',
          ),
        ],
      ),
    );
  }

  List<Widget> home() {
    final next = sessions
        .where(
          (s) =>
              s.status != SessionStatus.completed &&
              !s.startsAt.isBefore(DateTime.now()),
        )
        .firstOrNull;
    final scheduled = onDay(today);
    return [
      Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(26),
          gradient: const LinearGradient(
            colors: [Color(0xff4034b9), Color(0xff6353e8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_stories_rounded, color: Colors.white),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'StudyPlan',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Icon(
                  Icons.offline_pin_outlined,
                  color: Colors.white.withValues(alpha: .85),
                  semanticLabel: 'Disponible sin conexión',
                ),
              ],
            ),
            const SizedBox(height: 26),
            const Text(
              'Tu plan de estudio',
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              longDate(today),
              style: const TextStyle(color: Color(0xffefeaff), fontSize: 15),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      goalCard(currentWeek),
      const SizedBox(height: 20),
      FilledButton.icon(
        onPressed: saving ? null : () => editSession(),
        icon: const Icon(Icons.add),
        label: const Text('Nueva sesión'),
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
      ),
      section('Próxima sesión'),
      if (next != null)
        sessionCard(next, showDate: true)
      else
        const EmptyCard(
          Icons.event_available_outlined,
          'Sin sesiones próximas',
          'Planifica una sesión para organizar tus próximos días.',
        ),
      section('Sesiones de hoy'),
      if (scheduled.isEmpty)
        const EmptyCard(
          Icons.schedule_outlined,
          'Tu día está libre',
          'Las sesiones de hoy aparecerán aquí.',
        ),
      for (final session in scheduled) sessionCard(session),
    ];
  }

  Widget goalCard(DateTime week) {
    final completed = total(
      inWeek(week).where((s) => s.status == SessionStatus.completed),
    );
    final target = goal(week);
    final achieved = completed >= target;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              BadgeIcon(
                achieved
                    ? Icons.emoji_events_outlined
                    : Icons.track_changes_rounded,
                purple,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      achieved ? '¡Meta alcanzada!' : 'Meta semanal',
                      style: const TextStyle(color: muted),
                    ),
                    Text(
                      '${durationLabel(completed)} / ${durationLabel(target)}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Editar meta semanal',
                onPressed: saving ? null : () => editGoal(week),
                icon: const Icon(Icons.edit_outlined, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LinearProgressIndicator(
            value: (completed / target).clamp(0, 1).toDouble(),
            color: mint,
            backgroundColor: const Color(0xffeae9f2),
            minHeight: 8,
            borderRadius: BorderRadius.circular(12),
            semanticsLabel: 'Progreso de la meta semanal',
          ),
        ],
      ),
    );
  }

  Widget sessionCard(StudySession session, {bool showDate = false}) {
    final subject = subjects.firstWhere((s) => s.id == session.subjectId);
    final color = Color(subject.color);
    final statusColor = switch (session.status) {
      SessionStatus.completed => mint,
      SessionStatus.pending => purple,
      SessionStatus.rescheduled => const Color(0xff94511d),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Panel(
        padding: EdgeInsets.zero,
        child: ListTile(
          onTap: saving ? null : () => editSession(session: session),
          leading: BadgeIcon(
            session.status == SessionStatus.completed
                ? Icons.check
                : Icons.menu_book_outlined,
            color,
          ),
          title: Text(
            subject.name,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            [
              if (showDate) longDate(session.day),
              '${clockLabel(session.start)} – ${clockLabel(session.end)}',
              session.status.label,
            ].join(' · '),
            style: TextStyle(color: statusColor),
          ),
          trailing: PopupMenuButton<String>(
            tooltip: 'Opciones de sesión',
            enabled: !saving,
            onSelected: (action) async {
              if (action == 'complete') {
                await save(
                  () => store.saveSession(
                    StudySession(
                      id: session.id,
                      subjectId: session.subjectId,
                      day: session.day,
                      start: session.start,
                      end: session.end,
                      status: SessionStatus.completed,
                      notes: session.notes,
                    ),
                  ),
                );
              } else if (await confirm(
                    '¿Eliminar sesión?',
                    'Se quitará del calendario y de las estadísticas.',
                  ) &&
                  mounted) {
                await save(() => store.deleteSession(session.id!));
              }
            },
            itemBuilder: (_) => [
              if (session.status != SessionStatus.completed)
                const PopupMenuItem(
                  value: 'complete',
                  child: Text('Marcar como completada'),
                ),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Eliminar sesión'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> calendar() {
    final offset = month.weekday - 1;
    final count = DateUtils.getDaysInMonth(month.year, month.month);
    final items = onDay(selected);
    final sessionDates = sessions.map((s) => dateKey(s.day)).toSet();
    return [
      const PageHeading('Calendario', 'Organiza tus sesiones por fecha.'),
      Panel(
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Mes anterior',
                  onPressed: () => changeMonth(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: Text(
                    '${capitalize(months[month.month - 1])} ${month.year}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Mes siguiente',
                  onPressed: () => changeMonth(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final day in ['L', 'M', 'X', 'J', 'V', 'S', 'D'])
                  Expanded(
                    child: Text(
                      day,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            for (var row = 0; row * 7 < offset + count; row++)
              Row(
                children: [
                  for (var col = 0; col < 7; col++)
                    Expanded(
                      child: dayCell(
                        row * 7 + col - offset + 1,
                        count,
                        sessionDates,
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
      section(longDate(selected)),
      if (items.isEmpty)
        const EmptyCard(
          Icons.event_note_outlined,
          'Sin sesiones',
          'Puedes programar una sesión para esta fecha.',
        ),
      for (final session in items) sessionCard(session),
      const SizedBox(height: 12),
      FilledButton.icon(
        onPressed: saving ? null : () => editSession(day: selected),
        icon: const Icon(Icons.add),
        label: const Text('Nueva sesión'),
      ),
    ];
  }

  void changeMonth(int delta) => setState(() {
    month = DateTime(month.year, month.month + delta);
    selected = DateUtils.isSameMonth(month, today) ? today : month;
  });

  Widget dayCell(int number, int count, Set<String> sessionDates) {
    if (number < 1 || number > count) return const SizedBox(height: 42);
    final date = DateTime(month.year, month.month, number);
    final active = DateUtils.isSameDay(date, selected);
    final hasSessions = sessionDates.contains(dateKey(date));
    return Semantics(
      selected: active,
      label: longDate(date),
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => setState(() => selected = date),
        child: SizedBox(
          height: 46,
          child: Center(
            child: Container(
              width: 34,
              height: 36,
              decoration: BoxDecoration(
                color: active
                    ? purple
                    : DateUtils.isSameDay(date, today)
                    ? const Color(0xffeeebff)
                    : null,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ExcludeSemantics(
                    child: Text(
                      '$number',
                      style: TextStyle(
                        color: active ? Colors.white : ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (hasSessions)
                    Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: active ? Colors.white : purple,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> reports() {
    final planned = inWeek(reportWeek);
    final completed = planned
        .where((s) => s.status == SessionStatus.completed)
        .toList();
    final minutes = total(completed);
    final previous = total(
      inWeek(shiftDay(reportWeek, -7))
          .where((s) => s.status == SessionStatus.completed),
    );
    final difference = minutes - previous;
    final dailyMinutes = [
      for (var day = 0; day < 7; day++)
        total(
          completed.where(
            (session) =>
                DateUtils.isSameDay(session.day, shiftDay(reportWeek, day)),
          ),
        ),
    ];
    final breakdown =
        {
            for (final subject in subjects)
              subject: total(completed.where((s) => s.subjectId == subject.id)),
          }.entries.where((entry) => entry.value > 0).toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    return [
      const PageHeading('Estadísticas', 'Revisa tu progreso por semana.'),
      Panel(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: Row(
          children: [
            IconButton(
              tooltip: 'Semana anterior',
              onPressed: () =>
                  setState(() => reportWeek = shiftDay(reportWeek, -7)),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: Text(
                '${longDate(reportWeek)} – ${longDate(shiftDay(reportWeek, 6))}, ${shiftDay(reportWeek, 6).year}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              tooltip: 'Semana siguiente',
              onPressed: () =>
                  setState(() => reportWeek = shiftDay(reportWeek, 7)),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Panel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const BadgeIcon(Icons.timer_outlined, mint),
            const SizedBox(height: 8),
            const Text('Tiempo estudiado', style: TextStyle(color: muted)),
            Text(
              durationLabel(minutes),
              style: const TextStyle(fontSize: 29, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              '${completed.length} de ${planned.length} sesiones completadas',
            ),
            Text(
              difference == 0
                  ? 'Mismo tiempo que la semana anterior'
                  : '${difference > 0 ? '+' : '−'}${durationLabel(difference.abs())} respecto a la semana anterior',
              style: const TextStyle(color: muted),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      goalCard(reportWeek),
      section('Actividad diaria'),
      Panel(child: WeeklyBarChart(minutes: dailyMinutes)),
      section('Distribución por materia'),
      if (breakdown.isEmpty)
        const EmptyCard(
          Icons.bar_chart_rounded,
          'Sin tiempo registrado',
          'Completa una sesión para ver su duración en este reporte.',
        ),
      if (breakdown.isNotEmpty)
        Panel(
          child: Column(
            children: [
              SubjectDonutChart(
                slices: [
                  for (final entry in breakdown)
                    ChartSlice(
                      label: entry.key.name,
                      value: entry.value,
                      color: Color(entry.key.color),
                    ),
                ],
              ),
              const SizedBox(height: 22),
              for (final entry in breakdown)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.key.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${durationLabel(entry.value)} · ${(entry.value * 100 / minutes).round()} %',
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: entry.value / minutes,
                        color: Color(entry.key.color),
                        backgroundColor: const Color(0xffeae9f2),
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
    ];
  }

  List<Widget> library() => [
    const PageHeading('Materias', 'Clasifica tus sesiones por materia.'),
    FilledButton.icon(
      onPressed: saving ? null : () => editSubject(),
      icon: const Icon(Icons.add),
      label: const Text('Nueva materia'),
    ),
    const SizedBox(height: 16),
    if (subjects.isEmpty)
      const EmptyCard(
        Icons.menu_book_outlined,
        'Aún no hay materias',
        'Añade una materia para empezar a planificar.',
      ),
    for (final subject in subjects)
      Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Panel(
          padding: EdgeInsets.zero,
          child: ListTile(
            leading: BadgeIcon(Icons.menu_book_outlined, Color(subject.color)),
            title: Text(
              subject.name,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            onTap: saving ? null : () => editSubject(subject),
            trailing: IconButton(
              tooltip: 'Eliminar materia',
              onPressed: saving
                  ? null
                  : () async {
                      if (await confirm(
                            '¿Eliminar ${subject.name}?',
                            'También se eliminarán sus sesiones y el tiempo asociado de los reportes.',
                          ) &&
                          mounted) {
                        await save(() => store.deleteSubject(subject.id));
                      }
                    },
              icon: const Icon(Icons.delete_outline),
            ),
          ),
        ),
      ),
  ];
}

class SessionEditor extends StatefulWidget {
  const SessionEditor({
    super.key,
    required this.subjects,
    required this.initial,
    required this.day,
    this.existing,
  });
  final List<Subject> subjects;
  final int initial;
  final DateTime day;
  final StudySession? existing;

  @override
  State<SessionEditor> createState() => _SessionEditorState();
}

class _SessionEditorState extends State<SessionEditor> {
  late int subject = widget.existing?.subjectId ?? widget.initial;
  late DateTime day = widget.existing?.day ?? widget.day;
  late int start = widget.existing?.start ?? 9 * 60;
  late int end = widget.existing?.end ?? 10 * 60;
  late SessionStatus status = widget.existing?.status ?? SessionStatus.pending;
  late String notes = widget.existing?.notes ?? '';
  String? error;

  Future<void> pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: day,
      firstDate: DateTime(1900),
      lastDate: DateTime(2199, 12, 31),
    );
    if (mounted && date != null) setState(() => day = date);
  }

  Future<void> pickTime(bool isStart) async {
    final time = isStart ? start : end;
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: time ~/ 60, minute: time % 60),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (!mounted || selected == null) return;
    setState(() {
      final minutes = selected.hour * 60 + selected.minute;
      if (isStart) {
        start = minutes;
      } else {
        end = minutes;
      }
      error = null;
    });
  }

  void submit() {
    if (end <= start) {
      setState(
        () => error = 'La hora de fin debe ser posterior a la de inicio.',
      );
      return;
    }
    Navigator.pop(
      context,
      StudySession(
        id: widget.existing?.id,
        subjectId: subject,
        day: day,
        start: start,
        end: end,
        status: status,
        notes: notes.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.existing == null ? 'Registrar sesión' : 'Editar sesión',
      ),
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              DropdownButtonFormField<int>(
                initialValue: subject,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Materia',
                  prefixIcon: Icon(Icons.menu_book_outlined),
                ),
                items: [
                  for (final item in widget.subjects)
                    DropdownMenuItem(
                      value: item.id,
                      child: Text(item.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => subject = value);
                },
              ),
              const SizedBox(height: 14),
              Panel(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.calendar_today_outlined),
                      title: const Text('Fecha'),
                      subtitle: Text(longDate(day)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: pickDate,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.schedule),
                      title: const Text('Hora de inicio'),
                      trailing: Text(clockLabel(start)),
                      onTap: () => pickTime(true),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.schedule),
                      title: const Text('Hora de fin'),
                      trailing: Text(clockLabel(end)),
                      onTap: () => pickTime(false),
                    ),
                  ],
                ),
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              section('Estado'),
              Wrap(
                spacing: 8,
                children: [
                  for (final value in SessionStatus.values)
                    ChoiceChip(
                      label: Text(value.label),
                      selected: status == value,
                      onSelected: (_) => setState(() => status = value),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: notes,
                minLines: 3,
                maxLines: 6,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Notas (opcional)',
                  alignLabelWithHint: true,
                ),
                onChanged: (value) => notes = value,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: submit,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                ),
                child: const Text('Guardar sesión'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class WeeklyBarChart extends StatelessWidget {
  const WeeklyBarChart({super.key, required this.minutes});

  final List<int> minutes;

  @override
  Widget build(BuildContext context) {
    final highest = minutes.fold(
      0,
      (maximum, value) => value > maximum ? value : maximum,
    );
    const labels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Minutos completados por día',
          style: TextStyle(color: muted),
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 190,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final (index, value) in minutes.indexed)
                Expanded(
                  child: Semantics(
                    label: '${labels[index]}: ${durationLabel(value)}',
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            value == 0 ? '0' : durationLabel(value),
                            maxLines: 1,
                            style: const TextStyle(
                              color: muted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Expanded(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: FractionallySizedBox(
                                heightFactor: highest == 0
                                    ? .02
                                    : (value == 0 ? .02 : value / highest),
                                widthFactor: .68,
                                child: Container(
                                  constraints: const BoxConstraints(
                                    minHeight: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: value == 0
                                        ? const Color(0xffeae9f2)
                                        : purple,
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(9),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            labels[index],
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class ChartSlice {
  const ChartSlice({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final int value;
  final Color color;
}

class SubjectDonutChart extends StatelessWidget {
  const SubjectDonutChart({super.key, required this.slices});

  final List<ChartSlice> slices;

  @override
  Widget build(BuildContext context) {
    final totalMinutes = slices.fold(0, (sum, slice) => sum + slice.value);
    final description = slices
        .map(
          (slice) =>
              '${slice.label}: ${(slice.value * 100 / totalMinutes).round()} %',
        )
        .join(', ');

    return Semantics(
      label: 'Distribución por materia. $description',
      child: SizedBox(
        height: 190,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: const Size.square(180),
              painter: DonutPainter(slices),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  durationLabel(totalMinutes),
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Text('total', style: TextStyle(color: muted)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class DonutPainter extends CustomPainter {
  const DonutPainter(this.slices);

  final List<ChartSlice> slices;

  @override
  void paint(Canvas canvas, Size size) {
    final totalMinutes = slices.fold(0, (sum, slice) => sum + slice.value);
    final bounds = Offset.zero & size;
    var start = -1.5708;
    const fullCircle = 6.283185307179586;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 26
      ..strokeCap = StrokeCap.butt;

    for (final slice in slices) {
      final sweep = fullCircle * slice.value / totalMinutes;
      paint.color = slice.color;
      canvas.drawArc(bounds.deflate(18), start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(DonutPainter oldDelegate) => oldDelegate.slices != slices;
}

class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
      side: const BorderSide(color: Color(0xffebeaf4)),
    ),
    child: Padding(padding: padding, child: child),
  );
}

class BadgeIcon extends StatelessWidget {
  const BadgeIcon(this.icon, this.color, {super.key});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 42,
    height: 42,
    decoration: BoxDecoration(
      color: color.withValues(alpha: .11),
      borderRadius: BorderRadius.circular(13),
    ),
    child: Icon(icon, color: color, size: 22),
  );
}

class EmptyCard extends StatelessWidget {
  const EmptyCard(this.icon, this.title, this.message, {super.key});
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Panel(
    child: Row(
      children: [
        BadgeIcon(icon, purple),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              Text(message, style: const TextStyle(color: muted)),
            ],
          ),
        ),
      ],
    ),
  );
}

class PageHeading extends StatelessWidget {
  const PageHeading(this.title, this.subtitle, {super.key});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 29, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: muted, fontSize: 15)),
      ],
    ),
  );
}

Widget section(String title) => Padding(
  padding: const EdgeInsets.only(top: 18, bottom: 9),
  child: Text(
    title,
    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
  ),
);

String longDate(DateTime date) => '${date.day} de ${months[date.month - 1]}';
String capitalize(String text) => text[0].toUpperCase() + text.substring(1);
String clockLabel(int minute) =>
    '${(minute ~/ 60).toString().padLeft(2, '0')}:${(minute % 60).toString().padLeft(2, '0')}';
String durationLabel(int minutes) {
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  if (hours == 0 && remainder != 0) return '$remainder min';
  if (remainder == 0) return '$hours h';
  return '$hours h $remainder min';
}
