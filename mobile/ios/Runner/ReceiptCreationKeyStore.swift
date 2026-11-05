import Flutter
import Security
import UIKit

/// A narrow device-bound recovery-capability store. Source links elsewhere in
/// Drift remain ordinary bearer URLs; this adapter does not encrypt them.
final class ReceiptCreationKeyStore {
  private let service: String
  private let addItem: (CFDictionary) -> OSStatus
  private let copyItem: (CFDictionary, UnsafeMutablePointer<CFTypeRef?>) -> OSStatus
  private let randomBytes: (UnsafeMutableRawPointer) -> OSStatus
  private let queue = DispatchQueue(label: "app.billington.receipt-creation-keys")

  init(service: String = "app.billington.receipt-creation.v1",
       addItem: @escaping (CFDictionary) -> OSStatus = { SecItemAdd($0, nil) },
       copyItem: @escaping (CFDictionary, UnsafeMutablePointer<CFTypeRef?>) -> OSStatus = { SecItemCopyMatching($0, $1) },
       randomBytes: @escaping (UnsafeMutableRawPointer) -> OSStatus = { SecRandomCopyBytes(kSecRandomDefault, 32, $0) }) {
    self.service = service
    self.addItem = addItem
    self.copyItem = copyItem
    self.randomBytes = randomBytes
  }

  func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "app.billington/receipt_creation_keys", binaryMessenger: messenger)
    channel.setMethodCallHandler { [self] call, reply in
      guard call.method == "read" || call.method == "createIfAbsent" else {
        reply(FlutterMethodNotImplemented)
        return
      }
      guard let args = call.arguments as? [String: Any], let locator = args["locator"] as? String,
            locator.hasPrefix("receipt-v1:"), locator.utf8.count <= 128 else {
        reply(["status": "error"])
        return
      }
      // The platform handler runs on the main thread. No background/locked
      // access, authentication prompt, synchronization or plaintext fallback.
      guard UIApplication.shared.applicationState == .active,
            UIApplication.shared.isProtectedDataAvailable else {
        reply(["status": "locked"])
        return
      }
      queue.async {
        let result = call.method == "read" ? self.read(locator) : self.createIfAbsent(locator)
        DispatchQueue.main.async {
          guard UIApplication.shared.applicationState == .active,
                UIApplication.shared.isProtectedDataAvailable else {
            reply(["status": "locked"])
            return
          }
          reply(result)
        }
      }
    }
  }

  private func query(_ locator: String) -> [String: Any] {
    return [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: locator,
            kSecAttrSynchronizable as String: false,
            kSecUseAuthenticationUI as String: kSecUseAuthenticationUIFail]
  }

  func read(_ locator: String) -> [String: Any] {
    var request = query(locator)
    request[kSecReturnData as String] = true
    request[kSecMatchLimit as String] = kSecMatchLimitOne
    var value: CFTypeRef?
    let status = copyItem(request as CFDictionary, &value)
    if status == errSecSuccess {
      guard let bytes = value as? Data, bytes.count == 32 else { return ["status": "error"] }
      return ["status": "available", "bytes": FlutterStandardTypedData(bytes: bytes)]
    }
    return statusResult(status)
  }

  func createIfAbsent(_ locator: String) -> [String: Any] {
    let existing = read(locator)
    guard existing["status"] as? String == "absent" else { return existing }
    var bytes = Data(count: 32)
    let randomStatus = bytes.withUnsafeMutableBytes { buffer in
      randomBytes(buffer.baseAddress!)
    }
    guard randomStatus == errSecSuccess else { return ["status": "error"] }
    var request = query(locator)
    request[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    request[kSecValueData as String] = bytes
    let status = addItem(request as CFDictionary)
    // A concurrent creator won. Retrieve its value; never return our losing RNG.
    if status == errSecDuplicateItem || status == errSecSuccess { return read(locator) }
    return statusResult(status)
  }

  private func statusResult(_ status: OSStatus) -> [String: Any] {
    switch status {
    case errSecItemNotFound: return ["status": "absent"]
    case errSecInteractionNotAllowed: return ["status": "locked"]
    default: return ["status": "error"]
    }
  }
}
