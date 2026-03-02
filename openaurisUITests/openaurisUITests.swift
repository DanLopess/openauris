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
    func testDashboardSmokeRendersCommandCenterSections() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-openauris-ui-testing")
        app.launch()

        XCTAssertTrue(app.staticTexts["OpenAuris"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["Toggle Dictation"].exists)
        XCTAssertTrue(app.buttons["Overview"].exists)
        XCTAssertTrue(app.buttons["Activity"].exists)
        XCTAssertTrue(app.buttons["Models"].exists)
        XCTAssertTrue(app.buttons["Insights"].exists)
        XCTAssertTrue(app.buttons["Milestones"].exists)
        XCTAssertTrue(app.buttons["Preferences"].exists)

        app.buttons["Milestones"].tap()
        XCTAssertTrue(app.staticTexts["Sessions"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Words"].exists)
        XCTAssertTrue(app.staticTexts["Streak"].exists)
        XCTAssertTrue(app.staticTexts["Speaking Time"].exists)
    }

    @MainActor
    func testSidebarRowIsTappableBeyondLabelText() throws {
        let app = XCUIApplication()
        app.launchArguments.append("-openauris-ui-testing")
        app.launch()

        let activityButton = app.buttons["Activity"]
        XCTAssertTrue(activityButton.waitForExistence(timeout: 8))

        let trailingEdge = activityButton.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5))
        trailingEdge.tap()

        XCTAssertTrue(
            app.buttons["Clear History"].waitForExistence(timeout: 3)
        )
    }
}
