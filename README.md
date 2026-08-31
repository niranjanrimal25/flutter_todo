# Niranjan Todo

A beautiful todo app with reminders, alarms and a timer, built with Flutter.

## Features

- ✅ Create, edit, delete, and complete tasks
- 🖼️ Optional task image attachments from the camera or gallery, with preview, replace, remove, and persistent local storage
- ☑️ Subtasks / checklists with add, edit, delete, completion toggles, and progress tracking
- 🎵 Built-in and custom alarm tones with five-second previews and persistent device-file imports
- 🚀 Native `flutter_native_splash` launch screen followed by an animated branded loading screen while local data loads
- 🎨 Branded launcher icon setup for Android adaptive icons and iOS using `flutter_launcher_icons`
- ✅ Reusable in-app SnackBar confirmations for task, alarm, and timer actions
- 🔔 **Recurring task reminders** — optional per-task ON/OFF reminders every 1–24 hours, with due-time anchoring, stable notification IDs, reboot/process-death recovery, and notification deep links back to the task
- ⏰ **Alarm section** — set one-time, everyday, or custom day-wise alarms with labels and bundled/custom tones; they **ring exactly on time** — looping sound + continuous vibration from a foreground service, full-screen alert over the lock screen, Stop/Snooze on the notification and the ring screen — even when the app is killed or the phone was rebooted (alarms reschedule automatically at boot)
- ⏱️ **Timer section** — countdown timer with presets (up to 2 hours) plus a **custom hours/minutes** option; a **live countdown stays in the notification** when the app is closed, and it **rings** the same way as an alarm when finished
- 📅 **Nepali (Bikram Sambat) calendar** — pick due dates with the Nepali date picker
- 🇳🇵 Nepali dates shown in Devanagari digits and month names
- 🏷️ Priorities (Low / Medium / High), categories, and search
- 🔎 Filter tasks: All / Today / Completed / Pending
- 🧩 Kanban board with To Do / In Progress / Done columns and native long-press drag-and-drop
- 🌱 Habits section with streaks, 14-day heatmaps, monthly history, and daily reminders
- 🌙 Light & dark themes (dark mode covers cards, chips, dialogs, pickers, and system surfaces)
- 🔔 Alarms & timer ring a custom alarm tone even when the app is closed
- 💾 Local persistence with SQLite (`sqflite`)
- ☁️ Optional private Firebase sync between Android and iPhone using the same account

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

- `lib/models/` — `todo.dart`, `subtask.dart`, `habit.dart`, `habit_log.dart`, and `alarm.dart` with SQLite (de)serialization
- `lib/providers/` — `TodoProvider`, `HabitProvider`, `AlarmProvider`, `ThemeProvider`
- `lib/screens/` — `main_shell.dart` (bottom nav), `home_screen.dart`, `habits_screen.dart`, `add_edit_todo_screen.dart`, `alarm_timer_screen.dart`
- `lib/services/` — `storage_service.dart` (sqflite), `firebase_sync_service.dart`, `image_storage_service.dart`, `notification_service.dart`
- `lib/widgets/` — todo cards, Kanban view, Nepali calendar widget, Nepali date picker dialog, empty state
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
- Habits are intentionally separate from tasks and alarms. SQLite schema
  version 11 adds `habits` and `habit_logs`, with one unique log per habit/day.
  The Habits tab provides quick today toggles, a 14-day heatmap, current and
  longest streaks, all-time completion totals, and a full tappable
  `table_calendar` month grid. Marking a day is optimistic for an instant UI
  update and rolls back if the
  local write fails.
- Habit reminders use a rolling 30-day set of one-shot local notifications so
  completing today cancels today's reminder while future reminders remain
  scheduled. The window is refreshed at startup and whenever a habit day is
  toggled. Reminders are local to each device and do not require cloud sync.
- The Home app-bar view button opens the List / Kanban selector. Kanban uses
  Flutter's native `LongPressDraggable` and `DragTarget` widgets,
  so it does not add a board package or a second ordering system. Columns group
  by `TodoStatus` while each column keeps the existing priority/newest order;
  List view continues to use priority sorting independently. Dropping a task
  into Done sets the existing `isCompleted` flag, and moving it back to To Do
  or In Progress clears that flag. Each drop is written to SQLite immediately.
- `Todo.status` is intentionally separate from `isCompleted`: In Progress is
  useful for active work, while the legacy boolean remains available to the
  existing filters and reminder code. SQLite schema version 9 adds the
  `status` column and version 10 adds stable sync identity/timestamps. During
  the migration, existing rows with `isCompleted = 1` become Done and all
  other rows become To Do; no saved tasks are discarded.
- Firebase sync is optional and keeps SQLite as the offline-first source for
  the UI. To enable private Android/iPhone sync, create a Firebase project,
  add the Android package `com.example.todo_app` and the iOS bundle id
  `com.example.todoApp`, enable Email/Password Authentication, and run:

  ```bash
  dart pub global activate flutterfire_cli
  flutterfire configure
  flutter pub get
  ```

  The Firebase native configuration files are project-specific and should not
  be copied from another project. After selecting the Firebase project in the
  Firebase CLI, deploy the included rules with
  `firebase deploy --only firestore:rules`, or paste `firestore.rules` into the
  Firestore Rules editor. On both phones,
  tap the cloud button in Home and sign in with the same email/password. New
  and edited tasks sync automatically, existing sessions sync on startup, and
  open apps receive remote task changes in real time. Cloud writes use a
  per-task `syncId` and last-updated timestamp, so local SQLite ids never
  collide between devices.
- The cloud sync intentionally shares task fields, priorities, due dates,
  status, completion, reminders, categories, and subtasks. Image attachments
  and imported custom reminder-tone files remain device-local because their
  filesystem paths are not valid on the other phone; built-in reminder tones
  do sync. Firebase Storage can be added later if cross-device attachments
  are needed.
- `flutter_native_splash` is configured in `pubspec.yaml` with the branded
  purple background and logo. If native files need to be regenerated after a
  splash configuration change, run:

  ```bash
  dart run flutter_native_splash:create
  ```

  Flutter then shows the existing animated branded loading screen while both
  SQLite todos and alarms load, with a short minimum display time for a smooth
  transition into the task list.
- `flutter_launcher_icons` is configured to generate the branded launcher icon
  for Android and iOS. It reuses the existing checklist mark in two prepared
  1024x1024 PNGs: `assets/images/app_icon.png` is the opaque iOS/fallback
  source, and `assets/images/app_icon_foreground.png` is the transparent
  adaptive foreground (also used for Android 13+ themed monochrome icons).
  Regenerate after `flutter pub get` with:

  ```bash
  dart run flutter_launcher_icons
  ```

  For a future logo upload, provide an sRGB PNG at 1024x1024 pixels. Keep an
  iOS source opaque and full-bleed because Apple applies its own rounded mask.
  For Android adaptive icons, provide a transparent 1024x1024 foreground and
  keep important artwork inside the central 66x66 dp safe zone of Android's
  108x108 dp adaptive canvas (roughly a 626px diameter centered area); leave
  the outer area transparent and use a separate solid background color or
  layer. Avoid text and fine details near the edge because launchers apply
  different masks and scaling.
- Runtime alternate launcher-icon switching is intentionally not enabled yet.
  iOS requires `setAlternateIconName` plus alternate `AppIcon` asset
  definitions, while Android requires multiple disabled/enabled
  `activity-alias` launcher entries and native component toggling. The app
  currently has one reliable cross-platform default rather than exposing a
  Settings control that would work on only one platform or risk duplicate
  launcher entries. Alternate static icon sources can be added later without
  changing the primary app icon configuration.
- Camera access is requested only when Capture from camera is selected. iOS
  requests Photos access (including limited-library access) for the gallery;
  Android uses its system Photo Picker for gallery selection and does not ask
  for broad storage access. Camera and photo usage descriptions are declared
  in the platform manifests.
- A task's nullable `reminderTime` is its Reminder ON/OFF state. While it is
  on, `reminderIntervalHours` controls a one-to-24-hour cadence and
  `reminderTone` controls the alarm sound. If the task has a due date and time,
  that is the first cadence anchor; otherwise the reminder start time is used.
  Editing the task re-arms the schedule, while completing, deleting, or
  turning the toggle off cancels it.
- Alarms store `AlarmRepeat.once`, `AlarmRepeat.everyday`, or
  `AlarmRepeat.custom` plus ISO weekdays (Monday = 1 through Sunday = 7).
  Repeating alarms are re-scheduled from the ring screen and repaired from
  SQLite at app startup; one-time alarms persist their next occurrence and
  are consumed after they ring.
- Alarm tones are previewed with `audioplayers`. Built-in choices include
  Classic Beep, Chime, Siren, Bell, Digital, and Pulse; imported audio files
  are copied to the app's documents directory by `ToneStorageService`. The
  alarm stores the resulting path, so the alarm plugin can play a custom tone
  from native code even when Flutter is not running. File/document pickers use
  user-selected file access and do not require broad storage permission; the
  audio file itself is validated and copied into app storage.
- `AppFeedback` is the shared short-lived in-app SnackBar helper. CRUD and
  timer messages use it; these confirmations are deliberately not system
  notifications.
- **Android recurring reminders use the same `alarm` plugin path as alarms.**
  Each task reminder is an `AlarmSettings` entry backed by the plugin's exact
  `AlarmManager` schedule and foreground service, with the same bundled
  looping ringtone, repeating vibration, full-screen intent, Stop button, and
  Snooze button. The plugin owns the native schedule, so it continues through
  Flutter process death and restores pending schedules after boot. A native
  recurrence companion arms the next per-task occurrence through the plugin
  without waiting for Dart, while the Flutter ring screen also validates the
  task before re-arming after Stop. If exact-alarm special access is denied,
  the plugin falls back to its allow-while-idle inexact path.
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
