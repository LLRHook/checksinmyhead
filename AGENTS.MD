# Repository guidance

## TestFlight versioning

- Before preparing a TestFlight build, bump both the marketing version and source build number in `mobile/pubspec.yaml` (`version: X.Y.Z+N`).
- Keep the Runner target's `MARKETING_VERSION` values in `mobile/ios/Runner.xcodeproj/project.pbxproj` in sync with `X.Y.Z`.
- Update the visible app version in `mobile/lib/screens/settings/settings_screen.dart` to match.
- Increment `N` for each release build. The TestFlight workflow may override the binary build number with the next available App Store Connect value, so confirm the workflow summary shows a build number newer than the last upload.
- Do not use the marketing version as the build-number input; confirm the uploaded artifact reports the intended marketing version and build number.
