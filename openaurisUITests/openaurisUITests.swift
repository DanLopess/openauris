//
//  openaurisUITests.swift
//  openaurisUITests
//
//  Created by Daniel Lopes on 23.02.2026.
//

import XCTest

final class openaurisUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments += ["-openauris-ui-testing", "-SUEnableAutomaticChecks", "NO"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app = nil
    }

    @MainActor
    func testDashboardSmokeRendersCommandCenterSections() throws {
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
        let activityButton = app.buttons["Activity"]
        XCTAssertTrue(activityButton.waitForExistence(timeout: 8))

        let trailingEdge = activityButton.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5))
        trailingEdge.tap()

        XCTAssertTrue(
            app.buttons["Clear History"].waitForExistence(timeout: 3)
        )
    }

    @MainActor
    func testOverviewMovesRuntimeDetailsOutOfOverviewCards() throws {
        XCTAssertTrue(app.buttons["Overview"].waitForExistence(timeout: 8))
        app.buttons["Overview"].tap()

        XCTAssertTrue(app.staticTexts["Runtime Status"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["Permissions"].exists)
    }

    @MainActor
    func testOverviewShowsMinutesSpokenInsteadOfSessionsMetric() throws {
        XCTAssertTrue(app.buttons["Overview"].waitForExistence(timeout: 8))
        app.buttons["Overview"].tap()

        XCTAssertTrue(app.staticTexts["Minutes Spoken"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["Sessions"].exists)
    }

    @MainActor
    func testClosingCommandCenterDoesNotQuitMenuBarApp() throws {
        XCTAssertTrue(app.buttons["Overview"].waitForExistence(timeout: 8))

        app.typeKey("w", modifierFlags: .command)

        XCTAssertFalse(app.wait(for: .notRunning, timeout: 5))
    }

    @MainActor
    func testAppMenuDoesNotExposeOpenCommandCenter() throws {
        let appMenu = app.menuBars.menuBarItems["OpenAuris"]
        XCTAssertTrue(appMenu.waitForExistence(timeout: 5))
        appMenu.click()

        let openCommandCenter = app.menuBars.menuItems["Open Command Center"]
        XCTAssertFalse(openCommandCenter.waitForExistence(timeout: 1))
    }
}
