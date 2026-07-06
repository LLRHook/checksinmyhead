import SwiftUI

@main
struct VictorWakeApp: App {
    init() {
        if ProcessInfo.processInfo.environment["VICTOR_WAKE_RESET_DEFAULTS"] == "1" {
            WakeSettingsKeys.resetStoredValues()
        }
    }

    var body: some Scene {
        WindowGroup {
            WakeRemoteView()
        }
    }
}
