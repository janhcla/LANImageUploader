//
//  LANImageUploaderUITestsLaunchTests.swift
//  LANImageUploaderUITests
//
//  Created by Jan Hagen Clausen on 21/02/2025.
//

import XCTest

final class LANImageUploaderUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        false
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestingHome"]
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    }
}
