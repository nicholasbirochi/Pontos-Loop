import XCTest

final class CompraClaraUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testChatExplainsCurrentSimulation() {
        XCTAssertTrue(app.staticTexts["recommendation"].waitForExistence(timeout: 10))
        app.buttons["explainResult"].tap()
        app.buttons["Qual opção vale mais a pena?"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", "Pelos dados da simulação")).firstMatch.waitForExistence(timeout: 5))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Noah no iPhone"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testSavedScenarioSurvivesRelaunchAndCanBeRestored() {
        XCTAssertTrue(app.buttons["saveScenario"].waitForExistence(timeout: 10))
        app.buttons["saveScenario"].tap()
        let alert = app.alerts["Salvar simulação"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        let name = "Compra salva de teste"
        let field = alert.textFields.firstMatch
        let current = field.value as? String ?? ""
        field.tap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        field.typeText(name)
        alert.buttons["Salvar"].tap()
        app.terminate()
        app.launch()
        app.tabBars.buttons["Salvos"].tap()
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: 5))
        app.staticTexts[name].tap()
        XCTAssertTrue(app.staticTexts["recommendation"].waitForExistence(timeout: 5))
    }

    func testModesAndSavedTabAreReachable() {
        XCTAssertTrue(app.segmentedControls["scenarioPicker"].waitForExistence(timeout: 10))
        app.segmentedControls.buttons["Antecipar"].tap()
        XCTAssertTrue(app.staticTexts["Soma das parcelas restantes"].exists)
        app.segmentedControls.buttons["Pontos"].tap()
        XCTAssertTrue(app.staticTexts["Valor da fatura"].exists)
        app.tabBars.buttons["Salvos"].tap()
        XCTAssertTrue(app.navigationBars["Suas simulações"].waitForExistence(timeout: 5))
    }
}
