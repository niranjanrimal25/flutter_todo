# Niranjan Todo

A beautiful todo app with reminders, alarms and a timer, built with Flutter.

## Features

- ✅ Create, edit, delete, and complete tasks
- 🔔 **Recurring task reminders** — optional per-task ON/OFF reminders every two hours, with due-time anchoring, stable notification IDs, reboot/process-death recovery, and notification deep links back to the task
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
- A task's nullable `reminderTime` is its Reminder ON/OFF state. While it is
  on, the recurring reminder runs every two hours. If the task has a due date
  and time, that is the cadence anchor; otherwise the selected reminder start
  time is used. Editing the task re-arms the schedule, while completing,
  deleting, or turning the toggle off cancels it.
- **Android recurring reminders use a native exact `AlarmManager` chain.** The
  receiver schedules only the next occurrence with
  `setExactAndAllowWhileIdle()`, posts the notification, and schedules the
  following occurrence. The task metadata is stored in app preferences so the
  receiver does not need a Dart isolate while the app is killed. A boot,
  package-update, or timezone-change broadcast rebuilds the chain. This is
  more reliable for a two-hour user-visible reminder than a Dart-side chained
  `zonedSchedule` (the Dart callback cannot run when the process is dead), and
  more timely than WorkManager (periodic work is deliberately inexact and can
  be deferred). It also avoids `setInexactRepeating()` drift while correcting
  for Doze delays. If exact-alarm special access is denied, it falls back to an
  allow-while-idle inexact alarm and continues working.
- Android requires **POST_NOTIFICATIONS** (Android 13+) and
  **SCHEDULE_EXACT_ALARM / Alarms & reminders** access for the precise chain.
  The app requests notification/exact-alarm access at startup. When a user
  enables a recurring reminder it also offers Android's battery-optimization
  exemption prompt; the Alarm tab provides a way to revisit exact-alarm and
  Doze access later. OEM auto-start/battery controls may still need manual
  whitelisting.
- Android notification IDs in the `1000000 + taskId` namespace are stable per
  task and separate from the alarm/timer and legacy notification ranges. iOS
  derives stable slot IDs from a separate `2000000 + taskId * 64 + slot`
  namespace. Tapping a recurring notification launches directly into that
  task's edit/details screen, including from a cold start.
- **iOS equivalent/limitation:** iOS owns local-notification delivery but does
  not provide an Android-style exact repeating alarm receiver or allow an
  app to execute arbitrary Dart code after termination. The app therefore
  schedules a finite five-day horizon (up to 64 two-hour system notifications)
  with stable task/slot IDs; those pending notifications survive app
  termination, and opening the app refreshes the horizon. iOS can defer
  delivery and its system-wide pending-notification limit means this is a
  best-effort horizon rather than an indefinite guarantee. A server push is
  required for indefinite reminders without reopening the app.
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
