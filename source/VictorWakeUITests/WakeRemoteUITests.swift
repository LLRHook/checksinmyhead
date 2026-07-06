import XCTest

@MainActor
final class WakeRemoteUITests: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testDefaultScreenValuesAreVisibleAndFieldsPersistEdits() {
        let app = XCUIApplication()
        app.launchEnvironment["VICTOR_WAKE_RESET_DEFAULTS"] = "1"
        app.launch()

        let hostField = app.textFields["hostField"]
        let portField = app.textFields["portField"]
        let macAddressField = app.textFields["macAddressField"]

        XCTAssertTrue(app.navigationBars["Victor Wake"].waitForExistence(timeout: 5))
        XCTAssertEqual(hostField.value as? String, "70.18.244.191")
        XCTAssertEqual(portField.value as? String, "40009")
        XCTAssertEqual(macAddressField.value as? String, "D8-43-AE-2C-9D-B2")
        XCTAssertTrue(app.buttons["wakeButton"].exists)
        XCTAssertEqual(app.staticTexts["statusValue"].label, "ready")

        replaceText(in: hostField, with: "70.18.244.192")
        replaceText(in: portField, with: "40010")
        replaceText(in: macAddressField, with: "D843AE2C9DB2")

        let editedHost = hostField.value as? String ?? ""
        let editedPort = portField.value as? String ?? ""
        let editedMACAddress = macAddressField.value as? String ?? ""

        XCTAssertTrue(editedHost.contains("70.18.244.192"))
        XCTAssertTrue(editedPort.contains("40010"))
        XCTAssertTrue(editedMACAddress.contains("D843AE2C9DB2"))

        app.terminate()
        app.launchEnvironment.removeValue(forKey: "VICTOR_WAKE_RESET_DEFAULTS")
        app.launch()

        XCTAssertEqual(app.textFields["hostField"].value as? String, editedHost)
        XCTAssertEqual(app.textFields["portField"].value as? String, editedPort)
        XCTAssertEqual(app.textFields["macAddressField"].value as? String, editedMACAddress)
    }

    private func replaceText(in element: XCUIElement, with text: String) {
        XCTAssertTrue(element.waitForExistence(timeout: 5))
        let currentValue = element.value as? String ?? ""
        element.tap()
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()

        if !currentValue.isEmpty {
            let deleteKeys = String(repeating: XCUIKeyboardKey.delete.rawValue, count: currentValue.count)
            element.typeText(deleteKeys)
        }

        element.typeText(text)
    }
}
