# StudyPlan

Aplicación móvil en español para gestionar materias, programar sesiones de estudio y seguir metas semanales. Usa una base SQLite en el dispositivo. Las funciones principales están disponibles sin conexión ni cuenta.

## Ejecutar

Con un emulador Android o un dispositivo conectado:

```sh
flutter pub get
flutter run
```

Para generar un APK de prueba, usa `flutter build apk --debug`. Flutter lo guarda en `build/app/outputs/flutter-apk/app-debug.apk`.

## Cómo usarla

1. Crea una materia y elige su color.
2. Registra una sesión desde Inicio o el Calendario. Indica su fecha, sus horas y su estado.
3. Marca la sesión como completada cuando termines. Solo el tiempo de sesiones completadas cuenta en los reportes y en el progreso.
4. Usa el lápiz en la tarjeta de meta para cambiar el objetivo de esa semana. Las semanas van de lunes a domingo y la meta predeterminada es de 10 horas.

`flutter test` verifica la persistencia de SQLite y la actualización de las estadísticas.
