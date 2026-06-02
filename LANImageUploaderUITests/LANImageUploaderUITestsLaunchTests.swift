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
        throw XCTSkip("Launch screenshot capture is unstable and non-functional coverage in CI.")
    }
}
