import XCTest

final class PontosLoopUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.buttons["newScenario"].waitForExistence(timeout: 10))
        app.buttons["newScenario"].tap()
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
        app.steppers["purchaseCount"].buttons.element(boundBy: 1).tap()
        app.buttons["compareNow"].tap()
        XCTAssertTrue(app.staticTexts["recommendation"].waitForExistence(timeout: 5))
    }

    func testZeroDefaultsAndMissingOffersAreNotRecommendedAsFree() {
        app.segmentedControls.buttons["4 cenários"].tap()
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "Pontos Loop zerado"
        shot.lifetime = .keepAlways
        add(shot)
        XCTAssertTrue((app.textFields["Valor da compra elegível sem juros"].value as? String ?? "").hasPrefix("0"))
        XCTAssertTrue((app.textFields["Preço final no Pix com desconto"].value as? String ?? "").hasPrefix("0"))
        app.buttons["compareNow"].tap()
        XCTAssertFalse(app.staticTexts["recommendation"].exists)
        app.buttons["explainResult"].tap()
        app.buttons["Diagnóstico dos 4 cenários"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Preencha pelo menos 2")).firstMatch.waitForExistence(timeout: 5))
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
        app.buttons["Diagnóstico dos 4 cenários"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", "Diagnóstico dos 4 cenários")).firstMatch.waitForExistence(timeout: 5))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Noah no iPhone"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testChatComposerAndAttachmentMenu() {
        app.tabBars.buttons["Noah"].tap()
        XCTAssertTrue(app.buttons["chatMicrophone"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["sendQuestion"].isEnabled)
        app.buttons["chatAttachments"].tap()
        XCTAssertTrue(app.buttons["Arquivo ou áudio"].waitForExistence(timeout: 5))
        app.buttons["Arquivo ou áudio"].tap()
        let cancel = app.buttons.matching(NSPredicate(format: "label IN %@", ["Cancelar", "Cancel"])).firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 20))
        cancel.tap()
        let field = app.textFields["chatQuestion"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap(); field.typeText("O que são pontos?")
        app.buttons["sendQuestion"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Pontos são uma recompensa")).firstMatch.waitForExistence(timeout: 5))
        app.buttons["newChat"].tap()
        XCTAssertTrue(app.buttons["Diagnóstico dos 4 cenários"].waitForExistence(timeout: 5))
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Noah chat com áudio e anexos"
        screenshot.lifetime = .keepAlways
        add(screenshot)
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
