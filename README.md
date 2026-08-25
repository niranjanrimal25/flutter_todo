# Niranjan Todo

A beautiful todo app with reminders, alarms and a timer, built with Flutter.

## Features

- ✅ Create, edit, delete, and complete tasks
- 🖼️ Optional task image attachments from the camera or gallery, with preview, replace, remove, and persistent local storage
- ☑️ Subtasks / checklists with add, edit, delete, completion toggles, and progress tracking
- 🚀 Native `flutter_native_splash` launch screen followed by an animated branded loading screen while local data loads
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

- `lib/models/` — `todo.dart`, `subtask.dart`, and `alarm.dart` with SQLite (de)serialization
- `lib/providers/` — `TodoProvider`, `AlarmProvider`, `ThemeProvider`
- `lib/screens/` — `main_shell.dart` (bottom nav), `home_screen.dart`, `add_edit_todo_screen.dart`, `alarm_timer_screen.dart`
- `lib/services/` — `storage_service.dart` (sqflite), `image_storage_service.dart`, `notification_service.dart`
- `lib/widgets/` — todo cards, Nepali calendar widget, Nepali date picker dialog, empty state
- `lib/utils/` — theme and shared constants

## Notes

- Notifications are scheduled for the `Asia/Kathmandu` timezone.
- Image attachments are copied from `image_picker`'s temporary cache into the
  app's documents directory (`todo_images/`). The todo stores that stable
  `imagePath` reference; replacing, removing, or deleting a task cleans up
  app-owned old files without deleting originals from the user's gallery.
- Subtasks are stored as JSON in the todo row so existing installations can
  migrate in place. A task card shows checklist progress, while the add/edit
  screen provides add, edit, delete, and completion controls.
- `flutter_native_splash` is configured in `pubspec.yaml` with the branded
  purple background and logo. If native files need to be regenerated after a
  splash configuration change, run:

  ```bash
  dart run flutter_native_splash:create
  ```

  Flutter then shows the existing animated branded loading screen while both
  SQLite todos and alarms load, with a short minimum display time for a smooth
  transition into the task list.
- Camera access is requested only when Capture from camera is selected. iOS
  requests Photos access (including limited-library access) for the gallery;
  Android uses its system Photo Picker for gallery selection and does not ask
  for broad storage access. Camera and photo usage descriptions are declared
  in the platform manifests.
- A task's nullable `reminderTime` is its Reminder ON/OFF state. While it is
  on, the recurring reminder runs every two hours. If the task has a due date
  and time, that is the cadence anchor; otherwise the selected reminder start
  time is used. Editing the task re-arms the schedule, while completing,
  deleting, or turning the toggle off cancels it.
- **Android recurring reminders use the same `alarm` plugin path as alarms.**
  Each task reminder is an `AlarmSettings` entry backed by the plugin's exact
  `AlarmManager` schedule and foreground service, with the same bundled
  looping ringtone, repeating vibration, full-screen intent, Stop button, and
  Snooze button. The plugin owns the native schedule, so it continues through
  Flutter process death and restores pending schedules after boot. The app
  re-arms the next two-hour occurrence after Stop when the task is still
  pending and its reminder is still enabled. If exact-alarm special access is
  denied, the plugin falls back to its allow-while-idle inexact path.
- This is intentionally not a basic `flutter_local_notifications` call: that
  API is still used for soft reminders and the timer chronometer, but task
  reminders go through `AlarmRingScheduler` so they do not auto-dismiss or
  fall back to the short notification ping. A server/OS scheduler would still
  be needed to recover a future recurrence after a user stops an alarm from a
  native notification action without reopening the app.
- **iOS limitation:** the same alarm plugin can provide the ringing behavior
  while iOS allows the app/background audio session to run, but iOS cannot
  guarantee arbitrary code or indefinite alarm audio after the app is force
  terminated. The plugin's warning/notification behavior is therefore the
  platform-correct fallback on iOS.
- Android requires **POST_NOTIFICATIONS** (Android 13+) and
  **SCHEDULE_EXACT_ALARM / Alarms & reminders** access for the precise chain.
  The app requests notification/exact-alarm access at startup. When a user
  enables a recurring reminder it also offers Android's battery-optimization
  exemption prompt; the Alarm tab provides a way to revisit exact-alarm and
  Doze access later. OEM auto-start/battery controls may still need manual
  whitelisting.
- Recurring task alarms use the stable `600000 + taskId` namespace, separate
  from regular alarm IDs, the timer alarm, and legacy notification ranges.
  Tapping the full-screen task reminder opens the task's edit/details screen,
  including from a cold start.
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
