# Niranjan Todo

A beautiful todo app with reminders, alarms and a timer, built with Flutter.

## Features

- ✅ Create, edit, delete, and complete tasks
- 🔔 Local notifications for task reminders (with exact-alarm scheduling on Android)
- ⏰ **Alarm section** — set daily repeating alarms with labels; they **ring** (full-screen alarm with looping sound) even when the app is closed
- ⏱️ **Timer section** — countdown timer with presets (up to 2 hours) plus a **custom hours/minutes** option; a **live countdown stays in the notification** when the app is closed, and it **rings** when finished
- 📅 **Nepali (Bikram Sambat) calendar** — pick due dates with the Nepali date picker
- 🇳🇵 Nepali dates shown in Devanagari digits and month names
- 🏷️ Priorities (Low / Medium / High), categories, and search
- 🔎 Filter tasks: All / Today / Completed / Pending
- 🌙 Light & dark themes
- 💾 Local persistence with SQLite (`sqflite`)

## Getting Started

```bash
flutter pub get
flutter run
```

Run the tests:

```bash
flutter test
```

## Project structure

- `lib/models/` — `todo.dart`, `alarm.dart` with SQLite (de)serialization
- `lib/providers/` — `TodoProvider`, `AlarmProvider`, `ThemeProvider`
- `lib/screens/` — `main_shell.dart` (bottom nav), `home_screen.dart`, `add_edit_todo_screen.dart`, `alarm_timer_screen.dart`
- `lib/services/` — `storage_service.dart` (sqflite), `notification_service.dart`
- `lib/widgets/` — todo cards, Nepali calendar widget, Nepali date picker dialog, empty state
- `lib/utils/` — theme and shared constants

## Notes

- Notifications are scheduled for the `Asia/Kathmandu` timezone.
- Android: exact alarms require the user to grant "Alarms & reminders" access
  (requested at startup).
