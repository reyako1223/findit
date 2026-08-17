# FindIt – Flutter Mobile + Rust Core

FindIt is a phone-first, offline Smart Lost & Found Matcher for Rust Demo Day. Flutter renders the Android interface while Rust owns the important application logic.

## What stays in Rust?

- Creating IDs and typed reports
- Required-field and date validation
- Creating, updating, deleting, and returning records
- Loading and saving private `reports.json` data
- Search and status filters
- Dashboard statistics
- Lost-versus-Found comparisons
- Explainable match scores
- Development sample records

Flutter collects input, displays the values returned by Rust, and controls navigation. The application has no account, server, cloud database, or internet requirement.

## Rust concepts demonstrated

| Course topic | FindIt example | Study companion |
|---|---|---|
| Ownership and borrowing | Owned form inputs; borrowed report slices in matching and statistics | Zero to Rust Ep 02; Rust Book Ch 4; Rustlings `move_semantics` |
| Structs, enums, and pattern matching | `ItemReport`, `ReportType`, `ItemStatus`, and `match` expressions | Ep 03; Book Ch 5–6; Rustlings `structs`, `enums`, `options` |
| Collections | `Vec<ItemReport>` and `HashSet<String>` | Ep 04; Book Ch 8; Rustlings `vecs`, `strings`, `hashmaps` |
| `Option` and `Result` | Optional contact information and recoverable validation/storage errors | Ep 03–05; Book Ch 6 & 9; Rustlings `options`, `error_handling` |
| Closures and iterators | `filter`, `map`, `fold`, `flat_map`, and `collect` | Ep 07; Book Ch 13; Rustlings `iterators` |
| Modules, Cargo, and testing | Separate models/app modules, `cargo fmt`, Clippy, and unit tests | Ep 08–09; Book Ch 7, 11 & 14; Rustlings `modules`, `tests`, `clippy` |

Recommended references:

- [Zero to Rust](https://www.zerotorust.com/) for the session sequence
- [The Rust Programming Language](https://doc.rust-lang.org/book/) for detailed explanations
- [Rustlings](https://rustlings.rust-lang.org/) for small compile-to-pass exercises

## Main features

- Animated splash screen and polished mobile dashboard
- Lost and Found report forms with Rust validation
- Rust-generated IDs such as `LST-0001` and `FND-0001`
- Offline JSON persistence in private app storage
- Smart matches at 60% and above
- Excellent, Strong, and Possible match indicators
- Complete point-by-point match explanation
- Mark as Returned confirmation
- Search by item, location, color, and category
- All, Lost, Found, and Returned filters
- Report details, editing, and confirmed deletion
- Built-in Rust Demo Guide aligned with the course sessions
- Development-only sample-data helper
- Android application ID `com.findit.demo`

## Architecture

```text
findit_flutter/
├── android/                     # Flutter Android project
├── lib/
│   ├── main.dart                # App bootstrap and Rust initialization
│   ├── findit_app.dart          # Mobile screens and navigation
│   ├── app_controller.dart      # Thin Flutter-to-Rust controller
│   ├── app_theme.dart           # Visual design system
│   └── src/rust/                # Generated bridge bindings
├── rust/
│   └── src/api/
│       ├── models.rs            # Rust structs and enums
│       └── findit.rs            # Storage, CRUD, matching, and tests
├── rust_builder/                # Cargokit native build integration
├── test/widget_test.dart
├── flutter_rust_bridge.yaml
└── pubspec.yaml
```

Generated files under `lib/src/rust/` and `rust/src/frb_generated.rs` should not be edited manually.

## Run on an Android phone

Install Flutter stable, Rust stable, Android Studio, the Android SDK/NDK, and the four Rust Android targets. Then enable Developer options and USB debugging on the phone.

```powershell
flutter doctor -v
rustup target add aarch64-linux-android armv7-linux-androideabi i686-linux-android x86_64-linux-android
adb devices
Set-Location D:\rust\findit_flutter
flutter pub get
flutter run
```

If `flutter` is not recognized, use the included portable Flutter executable:

```powershell
Set-Location D:\rust\findit_flutter
D:\rust\.tools\flutter\bin\flutter.bat run
```

Always run the command inside `D:\rust\findit_flutter`, where `pubspec.yaml` is located.

## Checks and build

```powershell
dart format lib test
flutter analyze
flutter test

Set-Location rust
cargo fmt --all
cargo check --locked
cargo test --locked
cargo clippy --all-targets --locked -- -D warnings
```

Regenerate the typed Flutter bridge after changing a public Rust function, struct, or enum:

```powershell
D:\rust\.tools\frb\bin\flutter_rust_bridge_codegen.exe generate
```

Build a debug APK:

```powershell
Set-Location D:\rust\findit_flutter
flutter build apk --debug
adb install -r build\app\outputs\flutter-apk\app-debug.apk
```

## Matching algorithm

| Criterion | Rust score |
|---|---:|
| Same item name | 35 |
| Same category | 20 |
| Same color | 15 |
| Same location | 20 |
| Description keyword similarity | Up to 10 |
| **Total** | **100** |

String checks ignore case, trim outer spaces, and collapse repeated whitespace. Reports below 60% are not suggested.

- 90–100%: Excellent Match
- 75–89%: Strong Match
- 60–74%: Possible Match

## Demo Day script

> FindIt is a Flutter mobile app whose core logic is written in Rust. Rust models reports with structs and enums, validates data with Result, stores optional contact details with Option, processes records with iterators, and saves everything locally as JSON.

Suggested flow:

1. Open FindIt and show the offline dashboard.
2. Report a lost black wallet in the Library.
3. Report a found black wallet in the Library.
4. Open Matches and show the percentage produced by Rust.
5. Explain the scoring rows, then mark the item Returned.
6. Return Home and show the updated statistics.
7. Open the Rust Demo Guide and connect the code to your sessions.

In a debug build, **Add Data** creates ready-to-use sample records for rehearsal.
