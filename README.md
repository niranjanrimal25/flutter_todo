# Niranjan Todo

A beautiful todo app with reminders, alarms and a timer, built with Flutter.

## Features

- ✅ Create, edit, delete, and complete tasks
- 🔔 Local notifications for task reminders (with exact-alarm scheduling on Android)
- ⏰ **Alarm section** — set daily repeating alarms with labels and a **custom ringtone** (Classic Beep / Chime / Siren); they **ring exactly on time** — looping sound + continuous vibration from a foreground service, full-screen alert over the lock screen, Stop/Snooze on the notification and the ring screen — even when the app is killed or the phone was rebooted (alarms reschedule automatically at boot)
- ⏱️ **Timer section** — countdown timer with presets (up to 2 hours) plus a **custom hours/minutes** option; a **live countdown stays in the notification** when the app is closed, and it **rings** the same way as an alarm when finished
- 📅 **Nepali (Bikram Sambat) calendar** — pick due dates with the Nepali date picker
- 🇳🇵 Nepali dates shown in Devanagari digits and month names
- 🏷️ Priorities (Low / Medium / High), categories, and search
- 🔎 Filter tasks: All / Today / Completed / Pending
- 🌙 Light & dark themes (dark mode covers cards, chips, dialogs, pickers, and system surfaces)
- 🔔 Alarms & timer ring a custom alarm tone even when the app is closed
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
- Alarms/timers use the [`alarm`](https://pub.dev/packages/alarm) plugin
  (AlarmManager + a foreground service). Exact firing requires the user to
  grant **"Alarms & reminders"** access on Android 12+; the Alarm tab shows
  the status with a Grant button. For maximum reliability, also exempt the
  app from **battery optimization** (Doze) — the Alarm tab offers that too.
- Full-screen alerts over the lock screen are granted automatically on
  Android 14+ when the app has exact-alarm access.
- **iOS limitations:** iOS does not allow apps to run arbitrary code or loop
  audio in the background. Alarms on iOS are delivered as local
  notifications (background fetch may re-check pending alarms, and audio
  background mode is enabled), but there is no guaranteed-to-the-second
  delivery, no looping ring, and no lock-screen takeover like Android. This
  is a platform constraint, not an app bug.
- Some OEMs (Xiaomi, Oppo, Samsung, …) aggressively kill background apps —
  see [dontkillmyapp.com](https://dontkillmyapp.com/) for how to whitelist
  the app (Auto-start / battery exemption).
