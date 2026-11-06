# Flutter iOS Development Setup Guide

This guide will help you set up Flutter for iOS development on macOS and get our application running on the iOS simulator.

## Prerequisites

- macOS 11 (Big Sur) or later
- At least 44GB of free disk space (70GB recommended)
- Minimum of 8GB RAM (16GB recommended)

## Installation Steps

### 1. Install Development Tools

1. **Install Xcode**
   - Open the App Store and install the latest version of Xcode
   - After installation, configure command-line tools:
     ```bash
     sudo sh -c 'xcode-select -s /Applications/Xcode.app/Contents/Developer && xcodebuild -runFirstLaunch'
     sudo xcodebuild -license
     ```

2. **Install Rosetta 2 (For Apple Silicon Macs)**
   - Required for some Flutter components:
     ```bash
     sudo softwareupdate --install-rosetta --agree-to-license
     ```

3. **Install CocoaPods**
   - Required for Flutter plugins with native iOS code:
     ```bash
     sudo gem install cocoapods
     ```
   - Configure your PATH by adding this line to your `~/.zshenv` file:
     ```bash
     export PATH=$HOME/.gem/bin:$PATH
     ```
   - Restart all terminal sessions after this change

### 2. Install Flutter SDK

> **IMPORTANT:** The Flutter SDK must be installed in your `~/development` directory, NOT in the project directory.

1. **Install Visual Studio Code** (version 1.86 or later)
2. **Install the Flutter extension** for VS Code
3. **Install Git** (if not already installed)
4. **Install Flutter SDK:**
   - Create the development directory:
     ```bash
     mkdir ~/development
     cd ~/development
     ```
   - Download and install Flutter:
     ```bash
     git clone https://github.com/flutter/flutter.git
     ```
   - Add Flutter to your PATH by adding this line to your `~/.zshenv` file:
     ```bash
     export PATH="$PATH:$HOME/development/flutter/bin"
     ```
   - Restart your terminal and run:
     ```bash
     flutter doctor
     ```
   - Follow any additional steps recommended by `flutter doctor`

### 3. Configure iOS Simulator

1. **Install iOS Simulator:**
   ```bash
   xcodebuild -downloadPlatform iOS
   ```

2. **Launch the simulator:**
   ```bash
   open -a Simulator
   ```

3. **Configure simulator settings** (if needed):
   - Select a 64-bit device (iPhone 13 or later)
   - Adjust display size in the simulator app: Window > Fit Screen (Cmd + 4)

## Project Setup

1. **Clone the project repository:**
   ```bash
   git clone [REPOSITORY_URL]
   cd [PROJECT_DIRECTORY]
   ```

2. **Install dependencies:**
   Use Flutter **3.41.5**, matching the canonical validation SDK pin in `.github/workflows/checks.yml`. The
   committed lock includes that SDK's exact framework/test dependencies. Verify
   acquisition without rewriting it:
   ```bash
   flutter pub get --enforce-lockfile
   flutter analyze
   flutter test
   ```
   For an approved dependency change, use ordinary `flutter pub get` to generate
   the lock, review its package/checksum diff, then rerun enforced acquisition.

3. **Set up iOS project:**
   ```bash
   cd ios
   pod install --deployment
   cd ..
   ```

The root `./dev.sh setup` performs all three locked acquisitions explicitly using
Flutter 3.41.5 and CocoaPods 1.16.2 (the committed Podfile.lock version). It preserves
existing environment files. Ordinary `./dev.sh` uses `--no-pub` and guards against
implicit CocoaPods acquisition; rerun setup if Flutter detects changed native state.
It chooses the sole booted iOS simulator or `BILLINGTON_SIMULATOR_ID`, reports ambiguity,
and never erases/shuts down a device. Use `./dev.sh --no-mobile` for backend/web only.

## Running the Application

1. **Open the iOS project in Xcode:**
   ```bash
   open ios/Runner.xcworkspace
   ```

2. **Configure signing in Xcode:**
   - Select the "Runner" project in the Project Navigator
   - Select the "Runner" target
   - Go to "Signing & Capabilities" tab
   - Check "Automatically manage signing"
   - Select your Apple Developer team
   - Update the Bundle Identifier to something unique
   
   - [If you can't find the "Signing & Capabilities" tab, click here](https://stackoverflow.com/questions/72420093/signing-and-capabilities-tab-missing-in-xcode) 

3. **Run the application from the command line:**
   ```bash
   # From the repository root after locked ./dev.sh setup:
   BILLINGTON_SIMULATOR_ID=<available-iOS-UDID> ./dev.sh
   # Or from mobile/ with an explicitly selected, already prepared target:
   flutter run --no-pub -d <device-id>
   ```

## Troubleshooting

- If you encounter signing issues, ensure you've properly configured the signing settings in Xcode
- Run `flutter doctor -v` to diagnose any setup issues
- For missing/stale CocoaPods state, use CocoaPods 1.16.2 and rerun root `./dev.sh setup`; it uses `pod install --deployment` and reports lock mismatches

## Updating Flutter

Coordinate SDK updates with the CI, TestFlight and App Store workflow pins, then
regenerate and verify the lock under the chosen SDK. Use Flutter 3.41.5 for the
current committed resolution; see the [lock verification evidence](../docs/reviews/2026-11-02-flutter-lock-reproducibility.md).

## Receipt scan boundaries

Each manual scan owns one native HTTP client and a 45-second deadline covering file
setup, upload, the entire decoded response and parsing. Timeout, cancellation and
screen disposal request abort/close; a later manual attempt gets a fresh client. The
original upload subscription is retained, canceled and joined before the attempt
settles, including asynchronous cleanup after stream errors. `ReceiptIoClient` retains
valid upstream/relay handles during SDK TLS handoff and joins setup, paired loopback
acceptance, pumps and teardown. Acceptance matches the initiated local endpoint and
fails finitely at eight unmatched accepted endpoints per attempt. SDK DNS/staggered
setup ownership and physical-platform behavior still limit full native certification.
Redirects and automatic retries are disabled. Decoded bodies are capped at 1 MiB,
including error responses. Errors use finite local messages and retain the rate-limit
UX without displaying provider/server content.

`ParsedReceipt` owns bounded JSON preflight, field validation and checked expansion to
at most 500 review/application lines. Review and `BillData` use the same expansion;
invalid direct or reviewed candidates leave bill state/controllers unchanged. Existing
two-decimal distribution and versioned JPY remain separate concerns. Receipt review
retains currency evidence; explicit receipt-currency confirmation is required after a
scan, including ambiguous dollar evidence. Preview-rate failure does not block a valid
native-currency receipt from continuing or saving locally.
See [local mobile OCR verification](../docs/mobile-ocr-verification.md) for loopback native
I/O, TLS, fixture regeneration, widget disposal, negative controls and evidence limits.
Host qualification is recorded in the [integration note](../docs/reviews/2026-11-04-mobile-tls-integration.md).
The [deadline fixture note](../docs/reviews/2026-11-06-receipt-deadline-fixtures.md)
separates real setup expiry from controlled post-wire expiry and healthy retry;
production's real45-second deadline is unchanged. The [combined committed Flutter row](../docs/reviews/2026-11-06-combined-flutter-acceptance.md)
passed567 visible cases/573 canonical records; whole-program/native/resource gates remain open.
The [iOS lock and native qualification note](../docs/reviews/2026-11-04-ios-lock-qualification.md)
records the generated lock correction, maintained simulator/unsigned release builds
and local transport assertions on one owned simulator. Physical devices, signed public
clients and sustained resource acceptance remain separate gates. Local unsigned QA
uses `--no-codesign`; unit/debug/unsigned QA needs no TestFlight version bump.
The [driver phase-proof supplement](../docs/reviews/2026-11-04-ios-native-phase-acceptance.md)
resolves response-body/complete-ClientHello evidence gaps while retaining the failed
console wrapper and missing post-run receipts; it does not certify resources.
Release `ApiConfig` still selects the hosted API; the test-only constructor is not a
production configuration override.


## Durable receipt save and recovery

Done confirms a name before writing anything. `RecentBillsManager.saveReceipt`
commits one native receipt with a stable operation handle, ordered immutable create
snapshot/version, nonsecret key locator and optional destination intent. All resume,
history/launch retry and tab additions use that owner and the same exact Drift ID.
A valid persisted201 response atomically checkpoints source link, remote ID, frozen
quote and authoritative USD total before presentation or attachment. Failed HTTP,
checkpoint, attachment or presentation leaves truthful saved/pending state.

The iOS adapter generates32 bytes with Security and stores only the recovery capability
in device-only unlocked Keychain. Drift does not hold that capability. This does not
encrypt existing bearer URLs. Missing keys after an attempted publication block retry
rather than replacing the identity; unsupported platforms cannot publish via a fallback.
History/imported snapshots without creation authority require review and never auto-post.
The current unsigned simulator Keychain gate is blocked by missing entitlement; no
signing/provisioning change is authorized. Keyed release publication is disabled in
source until a separately reviewed native/source-floor/old-writer-drain qualification.

See [the mobile save procedure](../docs/mobile-save-verification.md) and
[scoped source evidence](../docs/reviews/2026-11-04-mobile-save-reopen.md). Host/wire
checks do not close identity0003, versioned JPY, the local/server `.005` allocation
mismatch, resources, full integrated/security or release gates.
