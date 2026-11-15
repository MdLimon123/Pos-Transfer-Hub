# Transfer Hub – Flutter POS Background Upload / Download Module

A Flutter (Android + iOS) feature module that uploads and downloads large files in the
background, with global progress, notifications, pause/resume, retries and
network-aware recovery. Built for the LAAN TECH USA take-home assessment.

State management: **flutter_bloc**. Networking: **dio**.

## Features

| Requirement | Where |
|---|---|
| Pick a large file, `multipart/form-data` POST upload with live % and progress bar | `ui/pages/upload_page.dart`, `TransferService.upload` |
| Upload continues when navigating away / minimising | Foreground service + app-level Bloc (see *Background strategy*) |
| Persistent completion notification, tap returns to a relevant screen | `NotificationService`, `TabCubit` |
| Download a previously uploaded file with progress | `ui/pages/files_page.dart`, `TransferService.download` |
| Background download with its own notification | Same pipeline as uploads |
| Global dashboard + floating banner reachable from anywhere | `ui/pages/transfers_page.dart`, `ui/widgets/transfer_banner.dart` |
| Pause / resume | Downloads resume byte-exact via HTTP `Range`; uploads restart (see limitations) |
| Poor network handling | Idle timeouts, automatic back-off retries, auto-pause when offline, auto-resume when back online |
| Error handling with friendly messages + retry | `core/failure.dart`, retry button on every failed transfer |
| Saved to a sensible location | Android: `Downloads/TransferHub/` via MediaStore (10+). iOS: app Documents `TransferHub/`, visible in the Files app |

Extras: login screen (username/password, with a Register link to the website), profile tab with sign-out, server file list with
delete, transfer history persisted across restarts, up to 3 concurrent transfers
with a queue.

## Architecture

```
lib/
  main.dart                 composition root (manual constructor injection)
  app.dart                  MaterialApp, notification-tap routing, global banner overlay
  core/
    api_client.dart         one Dio: base URL, bearer token, 401 -> sign-out, timeouts
    failure.dart            exception -> user-friendly Failure (network? auth? message)
    notification_service.dart   progress / result notifications + foreground-service notification
    foreground_service.dart     starts/stops the Android foreground service from transfer counts
    storage_bridge.dart     MethodChannel: save to public Downloads, open file
  features/
    auth/                   AuthCubit + AuthRepository (token in secure storage)
    files/                  FilesCubit + FilesRepository (GET /get, DELETE /delete)
    transfers/
      models/               TransferTask (immutable, JSON-serialisable), RemoteFile
      data/                 TransferService (bytes on the wire), TransferStore (history)
      bloc/                 TransfersBloc  <- the heart of the app
  ui/                       pages, TransferTile, TransferBanner, TabCubit
android/.../MainActivity.kt   MediaStore save, open-file intent, legacy storage permission
```

### Key design decisions

1. **One global `TransfersBloc`, provided above `MaterialApp`.** Transfers belong
   to the app, not to a screen, so leaving a page can never cancel them. Every
   screen (upload list, file list, dashboard, banner, app-bar badge) is just a
   view over `TransfersState`.
2. **Transfers never emit state directly.** A running transfer is plain async
   work that reports back through private events (`_Progress`, `_Completed`,
   `_Failed`). All state changes are therefore serialised through the Bloc,
   which keeps pause/cancel/offline races predictable (stale progress for a
   paused task is simply ignored).
3. **Layering.** `TransferService` only moves bytes (no Bloc, no UI, no
   notifications) so it is trivially fakeable; `TransfersBloc` owns scheduling,
   retries and side effects; widgets hold no business logic.
4. **Resumable downloads by construction.** Data is streamed to
   `<app-support>/downloads/<id>.part`. Resume = `Range: bytes=<partial size>-`
   and append. A `200` reply (server ignored the range) restarts cleanly, a
   `416` means the file was already complete, and a stream that ends before
   `Content-Length` is treated as a dropped connection, not success.
5. **Streaming uploads.** `MultipartFile.fromFile` streams from disk, so a
   multi-hundred-MB upload does not load the file into memory.
6. **Progress throttling.** Progress is coalesced to ~5 events/s for the UI and
   ~1 notification update/s, so large transfers do not flood the Bloc or the
   notification manager.
7. **Errors are data, not strings.** `Failure.from(Object)` maps Dio/IO errors to
   a message plus flags (`isNetwork`, `isAuth`). Network failures are retried
   automatically; auth failures sign the user out; everything else is shown with
   a Retry button.

## Background execution strategy and Android limits

**What the app does**

- While at least one transfer is queued, running, or waiting for network, the
  app runs an Android **foreground service** (`foregroundServiceType="dataSync"`,
  started through `flutter_local_notifications`) with a low-priority ongoing
  notification. A foreground service tells Android the user has knowingly
  started long-running work, so the process (and the Dart isolate running Dio)
  is not frozen or killed when the app is minimised.
- Each transfer additionally has its **own** notification: ongoing with a
  progress bar while running, a calm notification when paused / waiting /
  failed, and a **persistent result notification** on completion. Tapping a
  finished-upload notification opens the *Files* tab; a finished-download
  notification opens the *Transfers* tab (where the file can be opened).
- `connectivity_plus` feeds network changes to the Bloc: going offline parks
  running transfers as *Waiting for network*; coming back online resumes them
  automatically (downloads continue from the byte they stopped at).
- The foreground service is stopped as soon as nothing is pending.

**Why not WorkManager / a separate background isolate?**
WorkManager jobs are deferrable and may be delayed by Doze and quotas, and a
separate isolate would need its own copy of the state and an IPC layer. For
*user-initiated, visible* transfers, a foreground service plus a single
in-process Bloc is the simpler and more reliable choice, and the UI and the
transfer always share one source of truth.

**Platform limits to be aware of**

| Limit | Impact | Mitigation here |
|---|---|---|
| Swiping the app away from recents may kill the process on many OEM ROMs (Xiaomi, Oppo, Huawei...) | In-flight transfers stop | State is persisted; on next launch unfinished transfers show as *Paused – interrupted* and resume from the saved `.part` file |
| Doze / App Standby / OEM battery savers | Network and CPU can be throttled for non-exempt apps | Foreground service; users may need to exempt the app from battery optimisation on aggressive OEMs |
| Android 12+ forbids starting a foreground service from the background | Auto-resume after the process is already in the background may not be able to start the service | Service is kept alive while anything is *waiting for network*, so it is already running when connectivity returns; start failures are caught |
| Android 13+ `POST_NOTIFICATIONS` runtime permission | Without it notifications are hidden (transfers still run) | Requested at start-up |
| Android 14+ requires a declared FGS type; Android 15 caps `dataSync` services at ~6 h per day | Extremely long sessions would be stopped by the OS | Not an issue for this module's workload; see *Improvements* |
| Android 10+ scoped storage | Cannot write to `/sdcard/Download` directly | Finished files are published through `MediaStore.Downloads`; Android 9 and below use the legacy path + `WRITE_EXTERNAL_STORAGE` |
| Cleartext HTTP | The mock server is `http://` | `usesCleartextTraffic="true"` (would be HTTPS in production) |

## Poor-network behaviour

- `connectTimeout` 15 s; `receiveTimeout` 30 s, which for streamed downloads is
  an *idle* timeout, so a stalled connection fails fast instead of hanging.
- Network-type failures (timeouts, resets, 502/503/504, truncated streams) are
  retried automatically with exponential back-off (2 s, 4 s, 8 s): 3 retries for
  downloads (each resumes from the partial file), 2 for uploads.
- If the device reports it is offline, retries stop and the transfer waits;
  it restarts by itself when connectivity returns.
- After retries are exhausted the transfer is marked *Failed* with a plain-language
  reason and a Retry button; a downloaded partial file is kept, so retry continues.

## Error handling

| Situation | What the user sees |
|---|---|
| No / flaky network | "Cannot reach the server…", "The network is too slow…" + auto-retry / Retry |
| Server 5xx | "Server error (500). Please try again later." |
| 401 / 403 | Signed out with "Your session has expired. Please sign in again." |
| 404 | "The file no longer exists on the server." |
| 413 | "The server rejected the file because it is too large." |
| Empty / deleted / unreadable local file | Rejected before upload with a clear message |
| Disk full / storage error | "Not enough free storage space on this device." |

## Run instructions

Requirements: Flutter 3.44+ (Dart 3.x), Android SDK with platform 37 (Gradle
installs it automatically once licences are accepted: `flutter doctor --android-licenses`).

```bash
flutter pub get
flutter test            # bloc + error-mapping tests
flutter run             # on a connected Android device / emulator
flutter build apk --release   # build/app/outputs/flutter-apk/app-release.apk
```

Using the app:

1. Register at <http://108.136.142.112:90/> (once).
2. Sign in with that username/password (the login screen has a *Register* link
   that opens the website).
3. **Upload** tab → *Choose file*. Leave the screen or minimise the app; watch the
   banner, the notification, or the **Transfers** tab.
4. **Files** tab → download icon on a file. Pause / resume / cancel from the
   file row, the Transfers tab, or the banner.
5. Test resilience: turn on airplane mode mid-transfer (it parks and resumes by
   itself), or use the pause button.

Downloads are saved to **Downloads/TransferHub/** (visible in the Files app).

The release APK is signed with the debug key (fine for review, not for the Play Store).

## Assumptions

- The server needs no special upload header beyond the `file` form field and the
  bearer token (as in the provided `curl` examples).
- Download URLs are the `url` field returned by `/upload` and `/get`.
- The uploaded `name` returned by the server (e.g. `photo_ab12cd34.jpg`) is the
  identity of a remote file; the display name is `original_name`.
- Tokens expire (the payload carries `exp`); an expired token returns the user to
  the sign-in screen rather than refreshing silently, because the API has no
  refresh endpoint.

## Known limitations and what I would improve with more time

- **Uploads cannot truly resume.** The mock API accepts a single multipart POST
  and has no chunk/offset or tus-style endpoint, so *pause* cancels the request
  and *resume* restarts the file. With server support I would add chunked
  uploads (`Content-Range` per chunk) so pause and crash recovery are lossless.
- **Process death.** If the OS kills the process, transfers pause and must be
  resumed by the user. Improvement: re-launch automatically (or use Android 14
  *user-initiated data transfer* jobs via WorkManager, which the system
  schedules and can keep alive/restart).
- **Picker copies.** `file_picker` copies the chosen document into app cache
  before upload, which temporarily doubles storage for very large files.
  Improvement: stream directly from the content URI with a small native bridge.
- **Notification actions.** Pause/Cancel buttons directly on the notification
  were left out because action taps run in a background isolate that cannot
  reach the Bloc without extra IPC.
- **Integrity.** No checksum verification of downloads (the server exposes an
  `ETag`, which could be validated, and could also be sent as `If-Range` to
  guard against a file changing between resumes).
- **Testing.** Unit tests cover the Bloc (with a fake service), error mapping and
  serialisation. Missing: widget tests and an integration test against a local
  mock server with simulated throttling/drops.
- **Auth.** Token is stored with `flutter_secure_storage`; there is no registration
  screen because registration happens on the provided website.
- **iOS.** Supported (files saved to the app's Documents folder, shown in the Files
  app). iOS has no foreground service, so transfers may be suspended shortly after
  the app is backgrounded; resumable downloads and auto-retry recover them. True
  long-running background transfers would need a background `URLSession` strategy.
