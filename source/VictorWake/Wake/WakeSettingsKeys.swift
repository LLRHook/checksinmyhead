import Foundation

enum WakeSettingsKeys {
    static let host = "victorWake.host"
    static let port = "victorWake.port"
    static let macAddress = "victorWake.macAddress"
    static let lastSentTimestamp = "victorWake.lastSentTimestamp"

    static func resetStoredValues() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: host)
        defaults.removeObject(forKey: port)
        defaults.removeObject(forKey: macAddress)
        defaults.removeObject(forKey: lastSentTimestamp)
    }
}
