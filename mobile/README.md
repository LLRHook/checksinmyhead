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
   ```bash
   flutter pub get
   ```

3. **Set up iOS project:**
   ```bash
   cd ios
   pod install
   cd ..
   ```

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

3. **Run the application from the command line:**
   ```bash
   # For iPhone simulator
   flutter run -d simulator
   
   # Or if you have configured a specific device in Xcode
   flutter run
   ```

## Troubleshooting

- If you encounter signing issues, ensure you've properly configured the signing settings in Xcode
- Run `flutter doctor -v` to diagnose any setup issues
- For CocoaPods issues, try running `pod repo update` in the `ios` directory

## Adding Android Support Later

If you need to add Android support to the project in the future:

```bash
flutter create --platforms=android .
```

This will add the Android platform-specific files to your existing project.

## Note on Project Structure

- After initial project creation, we've removed the platform-specific code for Android, Linux, and Windows to keep the project clean for iOS development
- Only maintain the platform folders you actually need for development

## Updating Flutter

To update Flutter to the latest version:

```bash
cd ~/development/flutter
git pull
flutter doctor
```