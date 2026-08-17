# FindIt – Smart Lost & Found Matcher

> **Recommended phone version:** the complete Flutter + Rust mobile application is in [`findit_flutter/`](findit_flutter/README.md). Use that version for Android phones and APK builds. The original Tauri 2 implementation remains below as a working reference.

FindIt is a polished, offline-first mobile application for reporting lost and found items and discovering likely matches. It was built for Rust Demo Day: the interface is HTML/CSS with a small JavaScript bridge, while validation, IDs, record management, JSON persistence, filtering, statistics, and the complete matching algorithm live in Rust.

## Project Overview

FindIt is designed for a school, campus, dorm, or small community. A person can report an item they lost or found, see all local records, and use a transparent score to compare active lost reports with active found reports. There is no account, server, cloud database, analytics service, or internet requirement.

## Purpose

The app demonstrates how Rust can power the important parts of a real mobile experience without making the project hard to explain. The data stays private on the device and remains available after the app closes.

## Features

- Short animated splash screen and mobile dashboard
- Live Lost, Found, and Returned counts supplied by Rust
- Lost and Found report flows with required-field validation
- Rust-generated IDs such as `LST-0001` and `FND-0001`
- Offline JSON persistence in Tauri's private application data directory
- Match suggestions at 60% or higher with an explainable point breakdown
- Match detail view and safe “Mark as Returned” confirmation
- Search by item, location, color, or category in Rust
- All/Lost/Found/Returned record filters
- Full report details, editing, and confirmed deletion
- Proper empty, success, loading, and error states
- Development-only sample data helper
- Responsive layouts, Android safe areas, and accessible touch targets

## Technologies Used

- **Rust 2024 edition** – application logic
- **Tauri 2** – desktop/mobile application framework and Rust-to-webview commands
- **Serde and serde_json** – typed JSON serialization
- **Chrono** – dates and creation timestamps
- **HTML, CSS, and vanilla JavaScript** – mobile interface and command bridge
- **Vite** – small frontend development and production build tool

The checked-in lockfiles keep known-good dependency versions reproducible. The project currently uses the Tauri 2.11 release line and Vite 7.3.6.

## Why Rust?

Rust owns FindIt's core logic: data validation, ID creation, record updates, matching, match scores, filtering, dashboard statistics, error handling, and local file storage. Its type system makes states such as Lost, Found, and Returned explicit, while `Result` lets the interface show useful errors instead of crashing.

## Rust Concepts Demonstrated

- Structs: `ItemReport`, report inputs, statistics, and match results
- Enums and pattern matching: `ReportType` and `ItemStatus`
- Ownership and borrowing: inputs are cleaned by value; collections are read by reference
- `Vec`, `Option`, and `Result`
- Modules, functions, iterators, closures, and collection transforms
- Mutex-protected shared application state
- File handling and application data paths
- Serde serialization and deserialization
- Recoverable error handling and mutation rollback when a save fails
- Unit tests for validation, storage, matching, and IDs

## Project Structure

```text
findit/
├── index.html                 # Mobile application shell and SVG icon set
├── src/
│   ├── main.js                # Rendering, navigation, forms, and Rust invokes
│   ├── styles.css             # Responsive Android-style design system
│   └── assets/app-icon.svg    # FindIt source icon
├── src-tauri/
│   ├── capabilities/          # Tauri 2 permissions
│   ├── icons/                 # Generated desktop, Android, and iOS icons
│   ├── src/
│   │   ├── main.rs            # Desktop entry point
│   │   ├── lib.rs             # Shared desktop/mobile Tauri builder
│   │   ├── models.rs          # Enums, structs, and validation
│   │   ├── storage.rs         # reports.json loading and saving
│   │   ├── matcher.rs         # Explainable 100-point matcher
│   │   └── commands.rs        # Tauri commands and application state
│   ├── Cargo.toml
│   └── tauri.conf.json
├── package.json
└── README.md
```

At runtime, `reports.json` is created below the operating system's private app-data location for `com.findit.demo`. It is deliberately not stored in the project folder.

## Installation Requirements

### Windows desktop development

1. Rust stable with the MSVC toolchain
2. Microsoft C++ Build Tools with “Desktop development with C++”
3. Microsoft Edge WebView2 (normally already present on Windows 10/11)
4. Node.js LTS and npm

### Android development

Install Android Studio, then use its SDK Manager to install:

- Android SDK Platform
- Android SDK Platform-Tools
- Android SDK Build-Tools
- Android SDK Command-line Tools
- NDK (Side by side)

The Android Studio bundled JBR supplies Java. On Windows PowerShell, configure the tool paths (adjust them if Android Studio or the SDK is installed elsewhere):

```powershell
[System.Environment]::SetEnvironmentVariable("JAVA_HOME", "C:\Program Files\Android\Android Studio\jbr", "User")
[System.Environment]::SetEnvironmentVariable("ANDROID_HOME", "$env:LocalAppData\Android\Sdk", "User")
$ndkVersion = Get-ChildItem -Name "$env:LocalAppData\Android\Sdk\ndk" | Select-Object -Last 1
[System.Environment]::SetEnvironmentVariable("NDK_HOME", "$env:LocalAppData\Android\Sdk\ndk\$ndkVersion", "User")
```

Restart the terminal, then add Rust's Android targets:

```powershell
rustup target add aarch64-linux-android armv7-linux-androideabi i686-linux-android x86_64-linux-android
```

## How to Run

From the project root:

```powershell
npm install
npm run tauri dev
```

The first Rust build takes longer because Cargo compiles Tauri and the Windows webview integration. Later launches reuse the cache.

To preview only the responsive visual shell in a normal browser, run `npm run dev`. The browser preview intentionally has no fake data backend; saved records and business operations are available only in Tauri, where Rust owns them.

## Checks and Tests

```powershell
npm run check
npm run build
Set-Location src-tauri
cargo fmt --all
cargo check --locked
cargo test --locked
cargo clippy --all-targets --locked -- -D warnings
```

## How to Run on Android

Connect a phone with USB debugging enabled, or start an Android emulator. Verify it appears:

```powershell
adb devices
```

Initialize the generated Android Studio project once, then run FindIt:

```powershell
npm run tauri android init
npm run tauri android dev
```

If more than one emulator/device is connected, Tauri will prompt for the target. The generated Android project lives under `src-tauri/gen/android/` and is intentionally ignored because `tauri android init` regenerates it from the checked-in Tauri configuration and icons.

For a physical phone, keep the phone and development computer on the same network when using the live development server. A release APK does not need network access.

## How to Build an Android APK

After Android setup and `android init`:

```powershell
npm run tauri android build -- --apk
```

For a local demo, the generated debug APK can be installed with `adb install -r <path-to-apk>`. For public distribution, create and protect a signing key, configure release signing in the generated Android project, and build a signed release/AAB according to Android's publishing requirements.

## How the Matching Algorithm Works

Rust compares every active Lost report with every active Found report. Text equality ignores case, trims outer whitespace, and collapses repeated spaces.

| Criterion | Points |
|---|---:|
| Same item name | 35 |
| Same category | 20 |
| Same color | 15 |
| Same location | 20 |
| Similar description keywords | Up to 10 |
| **Total** | **100** |

Description similarity uses an explainable keyword overlap: punctuation and common filler words are removed, unique keywords are collected, then the shared keywords are divided by all unique keywords. The resulting fraction supplies up to ten points.

- 90–100%: Excellent Match
- 75–89%: Strong Match
- 60–74%: Possible Match
- Below 60%: not suggested

Returned reports are excluded so resolved items do not keep appearing as suggestions.

## Development Sample Data

In a debug build, the Home screen shows **Add Sample Data**. It adds a lost black wallet and found black wallet in the Library plus a separate USB report. The helper is idempotent and refuses to run in release builds, so production users never receive forced sample records.

## Demo Day Presentation Flow

The full story fits in two to three minutes:

1. Open FindIt and briefly show the splash screen and offline dashboard.
2. Tap **Report Lost Item** and report a black wallet in the Library.
3. Tap **Report Found Item** and enter the same core details.
4. Open **Matches** and point out the percentage generated by Rust.
5. Open **View Match** and explain the five scoring criteria.
6. Tap **Mark as Returned** and confirm.
7. Return to Home and show the updated Returned statistic.
8. If time allows, show Records search plus Edit/Delete confirmations.

For an even faster rehearsal, add the development sample data first and begin at step 4.

## Main Tauri Commands

The webview invokes these Rust commands: `add_report`, `update_report`, `delete_report`, `get_report`, `get_reports`, `get_statistics`, `find_matches`, `mark_as_returned`, and the development-only sample helper. Every command returns serialized data or a user-readable error; normal invalid input never panics the app.
