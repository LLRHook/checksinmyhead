import Flutter
import Security
import UIKit
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {
  private var service: String!
  private let locator = "receipt-v1:synthetic-native-qualification"

  override func setUp() {
    service = "app.billington.synthetic-save-qa.\(UUID().uuidString)"
  }
  override func tearDown() {
    SecItemDelete([kSecClass as String: kSecClassGenericPassword,
                   kSecAttrService as String: service!] as CFDictionary)
  }

  func testDeviceOnlyRandom32AndExistingValue() {
    let store = ReceiptCreationKeyStore(service: service)
    XCTAssertEqual(store.read(locator)["status"] as? String, "absent")
    let first = store.createIfAbsent(locator)
    let next = ReceiptCreationKeyStore(service: service).createIfAbsent(locator)
    let a = (first["bytes"] as? FlutterStandardTypedData)?.data
    let b = (next["bytes"] as? FlutterStandardTypedData)?.data
    XCTAssertEqual(first["status"] as? String, "available")
    XCTAssertEqual(a?.count, 32)
    XCTAssertEqual(a, b)
    var attributes: CFTypeRef?
    let status = SecItemCopyMatching([kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service!, kSecAttrAccount as String: locator,
      kSecReturnAttributes as String: true] as CFDictionary, &attributes)
    XCTAssertEqual(status, errSecSuccess)
    let values = attributes as? [String: Any]
    XCTAssertEqual(values?[kSecAttrAccessible as String] as? String,
                   kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String)
    XCTAssertEqual(values?[kSecAttrSynchronizable as String] as? Bool, false)
  }

  func testDuplicateSecItemAddRetrievesWinner() {
    let real = ReceiptCreationKeyStore(service: service)
    let winner = real.createIfAbsent(locator)
    var reads = 0
    let contender = ReceiptCreationKeyStore(service: service, copyItem: { query, result in
      reads += 1
      if reads == 1 { return errSecItemNotFound }
      return SecItemCopyMatching(query, result)
    })
    let recovered = contender.createIfAbsent(locator)
    XCTAssertEqual(recovered["status"] as? String, "available")
    XCTAssertEqual((recovered["bytes"] as? FlutterStandardTypedData)?.data,
                   (winner["bytes"] as? FlutterStandardTypedData)?.data)
    XCTAssertEqual(reads, 2)
  }

  func testLockedAndErrorNeverMeanAbsentOrCreate() {
    for status in [errSecInteractionNotAllowed, errSecAuthFailed, errSecNotAvailable, errSecDecode] {
      var adds = 0
      let store = ReceiptCreationKeyStore(service: service, addItem: { _ in adds += 1; return errSecSuccess },
        copyItem: { _, _ in status })
      let result = store.createIfAbsent(locator)
      XCTAssertEqual(result["status"] as? String, status == errSecInteractionNotAllowed ? "locked" : "error")
      XCTAssertEqual(adds, 0)
      XCTAssertNil(result["bytes"])
    }
  }

  func testRandomFailureCannotWriteOrReturnCapability() {
    var adds = 0
    let store = ReceiptCreationKeyStore(service: service,
      addItem: { _ in adds += 1; return errSecSuccess },
      randomBytes: { _ in errSecAllocate })
    let result = store.createIfAbsent(locator)
    XCTAssertEqual(result["status"] as? String, "error")
    XCTAssertEqual(adds, 0)
    XCTAssertNil(result["bytes"])
  }

  func testAddFailureAndMalformedStoredValueFailClosed() {
    let store = ReceiptCreationKeyStore(service: service, addItem: { _ in errSecInteractionNotAllowed })
    XCTAssertEqual(store.createIfAbsent(locator)["status"] as? String, "locked")
    XCTAssertEqual(SecItemAdd([kSecClass as String:kSecClassGenericPassword,
      kSecAttrService as String:service!,kSecAttrAccount as String:locator,
      kSecValueData as String:Data([1])] as CFDictionary,nil),errSecSuccess)
    XCTAssertEqual(store.read(locator)["status"] as? String,"error")
  }
}
