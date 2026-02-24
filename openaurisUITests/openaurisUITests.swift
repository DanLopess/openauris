//
//  openaurisUITests.swift
//  openaurisUITests
//
//  Created by Daniel Lopes on 23.02.2026.
//

import XCTest

final class openaurisUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testDashboardSmokeRendersCoreSections() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-openauris-ui-testing")
        app.launch()

        XCTAssertTrue(app.staticTexts["OpenAuris"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Quick Actions"].exists)
        XCTAssertTrue(app.buttons["Toggle Dictation"].exists)
        XCTAssertTrue(app.staticTexts["History"].exists)
        XCTAssertTrue(app.staticTexts["Settings"].exists)
    }
}
