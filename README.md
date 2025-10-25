# VK Downloader

A cross-platform Flutter desktop application that lets you browse VK, capture downloadable media, and manage large download batches with fine-grained controls.

## Key Features
- **Embedded VK browser** powered by `flutter_inappwebview` so you can authenticate with your account, browse groups, and trigger media discovery without leaving the app.
- **Smart media harvesting** that normalizes URLs, deduplicates files, and keeps track of where each item was found.
- **Bulk selection tools** including select-all, clear-all, and per-item toggles so you can stage exactly the files you want.
- **Download management** with pause-after-five throttling, a cancellable queue, progress indicator, and automatic scrolling of activity logs.
- **Collapsible sidebar** with search, filters, and compact event/history feeds for an uncluttered workspace.
- **Persistent preferences** for cookies, folders, and UI state via secure storage and shared preferences.

## Architecture Overview
The project follows a lean Clean Architecture-inspired structure:

- `lib/app.dart` exposes the `VkDownloaderApp` widget and configures theming.
- `lib/main.dart` boots the Flutter bindings and launches the app shell.
- `lib/features/home/presentation` contains the widget tree (`HomeScreen`) that renders the UI, reacts to state changes, and wires up user interactions.
- `lib/features/home/application` holds orchestration logic. `HomeController` owns the `HomeState`, responds to events from the webview, and delegates to supporting services. The `MediaDownloadService` manages throttled transfers, progress updates, and cancellation.
- `lib/features/home/domain` defines core models (`MediaItem`), filters, and URL normalization helpers.
- `lib/core/persistence` wraps secure storage and preferences into reusable clients.

This separation keeps UI, domain logic, and platform integrations testable and maintainable.

## Technology Stack
- **Flutter** (Material 3) for the desktop UI.
- **Dart 3.8+** language features (sealed classes, pattern matching).
- **flutter_inappwebview** for the embedded browser and VK session handling.
- **flutter_secure_storage** and **shared_preferences** for persisting cookies, tokens, and user settings.
- **path_provider** for resolving platform-specific download directories.

## Prerequisites
- Flutter SDK 3.22 or newer with desktop support enabled.
- Git (to clone the repository).
- VK account credentials (for signing in through the embedded browser).

### Linux
1. Install Flutter and its dependencies:
   ```bash
   sudo snap install flutter --classic
   sudo apt update
   sudo apt install clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev
   flutter doctor
   ```
2. Enable Linux desktop targets and fetch packages:
   ```bash
   flutter config --enable-linux-desktop
   flutter pub get
   ```
3. Run the application:
   ```bash
   flutter run -d linux
   ```

### Windows
1. Install the Flutter SDK by downloading the ZIP from [flutter.dev](https://docs.flutter.dev/get-started/install/windows) and extracting it, then add `flutter\bin` to your PATH.
2. Install Visual Studio with the “Desktop development with C++” workload (includes MSVC, Windows 10/11 SDK, and CMake).
3. From an elevated PowerShell or Command Prompt, verify the toolchain and enable desktop support:
   ```powershell
   flutter doctor
   flutter config --enable-windows-desktop
   flutter pub get
   ```
4. Run the application:
   ```powershell
   flutter run -d windows
   ```

> **Note:** The first launch may take longer while Flutter builds native binaries for your platform.

## Usage Guide
1. **Sign in to VK:** Use the embedded browser to log in to your VK account. Cookies are stored securely so you stay signed in between sessions.
2. **Discover media:** Navigate through feeds, albums, or events. Detected media items appear in the sidebar with thumbnails, metadata, and the source context.
3. **Filter and select:** Narrow the list by search text or media type, then use the select-all/clear-all controls or toggle individual items.
4. **Manage downloads:** Choose a destination folder and start the download queue. Progress indicators show completed vs. remaining files, and the queue pauses for 2 seconds after every 5 items to respect VK rate limits.
5. **Monitor activity:** The visited pages and event logs auto-scroll so you can track background operations. Collapse the sidebar for a focused browsing view when needed.
6. **Control long runs:** Use the Stop button to cancel the in-flight batch or Clear to wipe the discovered media list before starting a new session.

## Development Tips
- Run `flutter analyze` to lint the project before committing.
- The home feature is state-driven. Extend `HomeState` and `HomeController` for new UX scenarios rather than embedding logic into widgets.
- When adding new persistence needs, create a service under `lib/core` and inject it into the controller so presentation widgets remain declarative.

## License
Distributed under the MIT License. See [`LICENSE`](LICENSE) for more information.
