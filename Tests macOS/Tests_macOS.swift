//
//  Tests_macOS.swift
//  Tests macOS
//
//  Created by Eduardo Almeida on 23/08/2020.
//

import AppKit
import XCTest

@MainActor
final class Tests_macOS: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testSettingsNavigationAndRefreshPicker() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES"]
        app.launch()
        app.typeKey(",", modifierFlags: .command)

        let settingsWindow = app.windows.matching(
            identifier: "com_apple_SwiftUI_Settings_window"
        ).firstMatch
        XCTAssertTrue(settingsWindow.waitForExistence(timeout: 5))
        XCTAssertFalse(settingsWindow.buttons["Help"].exists)

        let generalTab = settingsWindow.buttons["General"]
        XCTAssertTrue(generalTab.exists)
        generalTab.click()

        let refreshPicker = settingsWindow.descendants(matching: .any)["Refresh interval"]
        XCTAssertTrue(refreshPicker.waitForExistence(timeout: 2))

        let serversTab = settingsWindow.buttons["Servers"]
        XCTAssertTrue(serversTab.exists)
        serversTab.click()

        XCTAssertTrue(
            app.descendants(matching: .any)["settings-server-list"]
                .waitForExistence(timeout: 2)
        )

        let addServerButton = app.descendants(matching: .any)["settings-add-server"]
        let refreshServersButton = app.descendants(matching: .any)["settings-refresh-servers"]
        XCTAssertTrue(addServerButton.exists)
        XCTAssertTrue(refreshServersButton.exists)
        XCTAssertGreaterThanOrEqual(addServerButton.frame.width, 24)
        XCTAssertGreaterThanOrEqual(addServerButton.frame.height, 24)
        XCTAssertGreaterThanOrEqual(refreshServersButton.frame.width, 24)
        XCTAssertGreaterThanOrEqual(refreshServersButton.frame.height, 24)
        refreshServersButton.click()
        addServerButton.click()

        let editor = settingsWindow.sheets.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 2))
        XCTAssertTrue(editor.buttons["Cancel"].exists)
        XCTAssertFalse(settingsWindow.buttons["Delete Server"].exists)

        let serverName = "UI Test Server \(UUID().uuidString)"
        let nameField = editor.descendants(matching: .any)["server-editor-name"]
        let endpointField = editor.descendants(matching: .any)["server-editor-endpoint"]
        XCTAssertTrue(nameField.waitForExistence(timeout: 2))
        XCTAssertTrue(endpointField.exists)

        nameField.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
        nameField.typeText(serverName)
        endpointField.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
        endpointField.typeText("http")
        endpointField.typeKey(":", modifierFlags: [])
        endpointField.typeText("//localhost")
        endpointField.typeKey(":", modifierFlags: [])
        endpointField.typeText("9091/transmission/rpc")

        let saveButton = editor.descendants(matching: .any)["server-editor-save"]
        XCTAssertTrue(saveButton.exists)
        expectation(
            for: NSPredicate(format: "enabled == true"),
            evaluatedWith: saveButton
        )
        waitForExpectations(timeout: 2)
        saveButton.click()
        XCTAssertTrue(editor.waitForNonExistence(timeout: 3))

        let serverRow = app.descendants(matching: .any)["settings-server-row-\(serverName)"]
        XCTAssertTrue(serverRow.waitForExistence(timeout: 2))

        let editButton = app.descendants(matching: .any)["settings-edit-server"]
        let deleteButton = app.descendants(matching: .any)["settings-delete-server"]
        let speedLimitsButton = app.descendants(matching: .any)["settings-speed-limits"]
        XCTAssertGreaterThanOrEqual(deleteButton.frame.width, 24)
        XCTAssertGreaterThanOrEqual(deleteButton.frame.height, 24)
        XCTAssertFalse(editButton.isEnabled)
        XCTAssertFalse(deleteButton.isEnabled)
        XCTAssertFalse(speedLimitsButton.isEnabled)

        serverRow.coordinate(
            withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)
        ).click()
        XCTAssertTrue(editButton.isEnabled)
        XCTAssertTrue(deleteButton.isEnabled)
        XCTAssertTrue(speedLimitsButton.isEnabled)

        editButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
        let editSheet = settingsWindow.sheets.firstMatch
        XCTAssertTrue(editSheet.waitForExistence(timeout: 2))
        XCTAssertFalse(settingsWindow.buttons["Delete Server"].exists)
        XCTAssertFalse(editSheet.descendants(matching: .any)["Speed Limits..."].exists)
        XCTAssertGreaterThanOrEqual(editSheet.scrollViews.count, 1)
        XCTAssertTrue(
            editSheet.descendants(matching: .any)["server-editor-custom-headers"]
                .waitForExistence(timeout: 2)
        )

        editSheet.buttons["Cancel"].click()
        XCTAssertTrue(editSheet.waitForNonExistence(timeout: 2))

        speedLimitsButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
        let speedLimitsSheet = settingsWindow.sheets.firstMatch
        XCTAssertTrue(speedLimitsSheet.waitForExistence(timeout: 2))
        XCTAssertTrue(speedLimitsSheet.staticTexts["Speed Limits"].waitForExistence(timeout: 2))
        XCTAssertFalse(speedLimitsSheet.buttons["Back"].exists)
        XCTAssertFalse(speedLimitsSheet.buttons["Test Connection"].exists)
        XCTAssertFalse(speedLimitsSheet.descendants(matching: .any)["server-editor-save"].exists)
        XCTAssertGreaterThanOrEqual(speedLimitsSheet.frame.height, 425)
        let speedLimitsCancelButton = speedLimitsSheet.buttons["Cancel"]
        XCTAssertTrue(speedLimitsCancelButton.exists)
        XCTAssertTrue(speedLimitsSheet.frame.contains(speedLimitsCancelButton.frame))
        speedLimitsCancelButton.click()
        XCTAssertTrue(speedLimitsSheet.waitForNonExistence(timeout: 2))

        deleteButton.click()
        let deleteAlert = settingsWindow.sheets.firstMatch
        XCTAssertTrue(deleteAlert.waitForExistence(timeout: 2))
        XCTAssertTrue(deleteAlert.staticTexts["Delete Server?"].exists)
        deleteAlert.buttons["Delete"].click()
        XCTAssertTrue(serverRow.waitForNonExistence(timeout: 2))

        XCTAssertFalse(app.descendants(matching: .any)["Devices"].firstMatch.exists)
        XCTAssertFalse(app.descendants(matching: .any)["Apple Watch Sync"].firstMatch.exists)
    }

    func testTorrentCommandsAreAvailable() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES"]
        app.launch()

        let torrentMenu = app.menuBars.menuBarItems["Torrent"]
        XCTAssertTrue(torrentMenu.waitForExistence(timeout: 5))
        torrentMenu.click()

        XCTAssertTrue(app.menuItems["Start"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.menuItems["Pause"].exists)
    }

    func testFileMenuMatchesImportWorkflow() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES"]
        app.launch()

        let fileMenu = app.menuBars.menuBarItems["File"]
        XCTAssertTrue(fileMenu.waitForExistence(timeout: 5))
        fileMenu.click()

        let openTorrentFile = app.menuItems["Open Torrent File..."]
        let openMagnetLink = app.menuItems["Open Magnet Link..."]
        XCTAssertTrue(openTorrentFile.waitForExistence(timeout: 2))
        XCTAssertTrue(openMagnetLink.exists)
        XCTAssertFalse(app.menuItems["New"].exists)
        XCTAssertFalse(app.menuItems["Open Recent"].exists)
        XCTAssertFalse(app.menuItems["Save"].exists)
        XCTAssertFalse(app.menuItems["Duplicate"].exists)
        XCTAssertFalse(app.menuItems["Rename..."].exists)
        XCTAssertFalse(app.menuItems["Move To..."].exists)
        XCTAssertFalse(app.menuItems["Revert To"].exists)
        XCTAssertFalse(app.menuItems["Share"].exists)

        app.typeKey(XCUIKeyboardKey.escape.rawValue, modifierFlags: [])
        app.typeKey("u", modifierFlags: .command)

        let sheet = app.windows.firstMatch.sheets.firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 2))
        XCTAssertTrue(
            sheet.descendants(matching: .any)["magnet-link-input"]
                .waitForExistence(timeout: 2)
        )
        let proceedButton = sheet.descendants(matching: .any)["magnet-proceed"]
        XCTAssertTrue(proceedButton.waitForExistence(timeout: 2))
        XCTAssertFalse(sheet.staticTexts["Labels (Optional)"].exists)

        let cancelButton = sheet.descendants(matching: .any)["magnet-cancel"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 2))
        XCTAssertEqual(cancelButton.frame.midY, proceedButton.frame.midY, accuracy: 4)
        cancelButton.click()
        XCTAssertTrue(sheet.waitForNonExistence(timeout: 2))
    }

    func testCancellingTorrentConfirmationDismissesMagnetFlow() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES"]
        app.launch()
        app.typeKey("u", modifierFlags: .command)

        let sheet = app.windows.firstMatch.sheets.firstMatch
        XCTAssertTrue(sheet.waitForExistence(timeout: 2))

        let magnetInput = sheet.descendants(matching: .any)["magnet-link-input"]
        XCTAssertTrue(magnetInput.waitForExistence(timeout: 2))
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(
            "magnet:?xt=urn:btih:abcdef&dn=UI+Test",
            forType: .string
        )
        magnetInput.click()
        app.typeKey("v", modifierFlags: .command)

        let proceedButton = sheet.descendants(matching: .any)["magnet-proceed"]
        XCTAssertTrue(proceedButton.waitForExistence(timeout: 2))
        proceedButton.click()

        let cancelButton = sheet.descendants(matching: .any)["torrent-cancel"]
        let startButton = sheet.descendants(matching: .any)["torrent-start-download"]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 2))
        XCTAssertTrue(startButton.waitForExistence(timeout: 2))
        XCTAssertEqual(cancelButton.frame.midY, startButton.frame.midY, accuracy: 4)

        cancelButton.click()
        XCTAssertTrue(sheet.waitForNonExistence(timeout: 2))
    }

    func testHelpLinksAreAvailableInHelpMenu() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ApplePersistenceIgnoreState", "YES"]
        app.launch()

        let helpMenu = app.menuBars.menuBarItems["Help"]
        XCTAssertTrue(helpMenu.waitForExistence(timeout: 5))
        helpMenu.click()

        let expectedLinks = [
            "Help Center",
            "Submit a Support Request",
            "Privacy Policy"
        ]
        for label in expectedLinks {
            XCTAssertTrue(app.menuItems[label].waitForExistence(timeout: 2))
        }
    }

    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
