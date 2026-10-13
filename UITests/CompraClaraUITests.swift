import XCTest

final class CompraClaraUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.segmentedControls["scenarioPicker"].waitForExistence(timeout: 10))
        app.segmentedControls.buttons["Compra"].tap()
    }

    private func comparePurchase() {
        for (label, value) in [("Preço no Pix", "950,00"), ("Total no cartão", "1000,00")] {
            let field = app.textFields[label]
            XCTAssertTrue(field.waitForExistence(timeout: 5))
            field.tap()
            let current = field.value as? String ?? ""
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
            field.typeText(value)
            if app.buttons["Concluir"].exists { app.buttons["Concluir"].tap() }
        }
        app.buttons["compareNow"].tap()
        XCTAssertTrue(app.staticTexts["recommendation"].waitForExistence(timeout: 5))
    }

    func testSimpleStartAndPhotoEntry() {
        XCTAssertFalse(app.staticTexts["recommendation"].exists)
        XCTAssertTrue(app.buttons["importPhoto"].exists)
        XCTAssertFalse(app.textFields["Rendimento líquido mensal"].exists)
        app.buttons["importPhoto"].tap()
        XCTAssertTrue(app.navigationBars["Ler uma oferta"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Escolher fotos"].exists)
        app.buttons["Fechar"].tap()
    }

    func testChatExplainsCurrentSimulation() {
        comparePurchase()
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
        comparePurchase()
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
        XCTAssertTrue(app.staticTexts[name].firstMatch.waitForExistence(timeout: 5))
        app.staticTexts[name].firstMatch.tap()
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
