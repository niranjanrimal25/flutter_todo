# todo_app

A beautiful Todo app with reminders, built with Flutter.

## Features

- ✅ Create, edit, delete, and complete tasks
- 🔔 Local notifications for task reminders (with exact-alarm scheduling on Android)
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

- `lib/models/todo.dart` — Todo model with SQLite (de)serialization
- `lib/providers/` — `TodoProvider` (state) and `ThemeProvider`
- `lib/screens/` — `home_screen.dart`, `add_edit_todo_screen.dart`
- `lib/services/` — `storage_service.dart` (sqflite), `notification_service.dart`
- `lib/widgets/` — todo cards, Nepali calendar widget, Nepali date picker dialog, empty state
- `lib/utils/` — theme and shared constants

## Notes

- Notifications are scheduled for the `Asia/Kathmandu` timezone.
- Android: exact alarms require the user to grant "Alarms & reminders" access
  (requested at startup).
