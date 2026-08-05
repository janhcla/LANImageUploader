//
//  LANImageUploaderUITests.swift
//  LANImageUploaderUITests
//
//  Created by Jan Hagen Clausen on 21/02/2025.
//

import XCTest

final class LANImageUploaderUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingHome"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))

        XCTAssertTrue(
            app.staticTexts["Capture. Organize. Upload."].waitForExistence(timeout: 5),
            "Home should expose the primary capture/upload workflow"
        )
        XCTAssertTrue(app.buttons["home-scan-documents"].exists)
        XCTAssertTrue(app.buttons["home-capture-image"].exists)
    }

    @MainActor
    func testConfiguredSettingsExposesConnectionTest() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingHome", "-uiTestingConfiguredServer"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))

        let settings = app.buttons["home-settings"]
        for _ in 0..<8 where !settings.exists || !settings.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        XCTAssertTrue(settings.isHittable)
        settings.tap()

        let testConnection = app.buttons["settings-test-connection"]
        for _ in 0..<8 where !testConnection.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(testConnection.waitForExistence(timeout: 5))
        XCTAssertTrue(testConnection.isHittable)
        XCTAssertTrue(testConnection.isEnabled)
    }

    @MainActor
    func testFullAppUnlockAlwaysExposesRestorePurchases() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingHome"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))

        let settings = app.buttons["home-settings"]
        for _ in 0..<8 where !settings.exists || !settings.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        XCTAssertTrue(settings.isHittable)
        settings.tap()

        let fullAppUnlock = app.buttons["Full App Unlock"]
        for _ in 0..<8 where !fullAppUnlock.exists || !fullAppUnlock.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(fullAppUnlock.waitForExistence(timeout: 5))
        XCTAssertTrue(fullAppUnlock.isHittable)
        fullAppUnlock.tap()

        XCTAssertTrue(
            app.buttons["restore-purchases-button"].waitForExistence(timeout: 5),
            "Restore Purchases must remain visible for previously purchased accounts."
        )
    }

    @MainActor
    func testLaunchPerformance() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingOnboarding"]
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            app.launch()
            XCTAssertTrue(
                app.staticTexts["Capture anything. Keep it private."].waitForExistence(timeout: 5),
                "Onboarding should explain the privacy boundary"
            )
            app.terminate()
        }
    }
}
