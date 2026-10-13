import XCTest
@testable import DecisionCore

final class SimpleAssistantTests: XCTestCase {
    private func comparison(pix: Decimal = 950, count: Int = 10) throws -> Comparison {
        try DecisionEngine.purchase(referencePrice: 1000, pixPrice: pix, cardTotal: 1000,
            days: (1...count).map { $0 * 30 }, eligibleSpend: 1000, reaisPerPoint: 2.5,
            reaisPerThousand: 20, rewardsEnabled: true, cashback: 0,
            benefitDay: 0, monthlyRate: 0)
    }

    func testRecommendationUsesComparisonCostsAndWinner() throws {
        let answer = SimpleAssistant.reply(to: "O que devo escolher?", comparison: try comparison())
        XCTAssertTrue(answer.contains("Pagar no Pix"))
        XCTAssertTrue(answer.contains("R$ 950,00") || answer.contains("R$ 950,00"))
        XCTAssertTrue(answer.contains("R$ 992,00") || answer.contains("R$ 992,00"))
    }

    func testNilComparisonAsksToFixInput() {
        XCTAssertTrue(SimpleAssistant.reply(to: "Qual opção compensa?", comparison: nil).contains("corrija os dados"))
    }

    func testTieIsHandledExplicitly() throws {
        let answer = SimpleAssistant.reply(to: "Qual a melhor escolha?", comparison: try comparison(pix: 992))
        XCTAssertTrue(answer.contains("empate econômico"))
    }

    func testAccentedIntentIsNormalized() throws {
        let answer = SimpleAssistant.reply(to: "Qual opção é melhor?", comparison: try comparison())
        XCTAssertTrue(answer.contains("compensa Pagar no Pix"))
    }

    func testUnsupportedAndSubstringLookalikesDoNotTriggerPurchaseAdvice() throws {
        let unsupported = SimpleAssistant.reply(to: "Explique pixar e cartão postal", comparison: try comparison())
        XCTAssertTrue(unsupported.contains("assistente local com respostas prontas"))
    }

    func testConceptualAnswersWorkWithoutValidSimulation() {
        XCTAssertTrue(SimpleAssistant.reply(to: "O que é custo econômico?", comparison: nil).contains("reais de hoje"))
        XCTAssertTrue(SimpleAssistant.reply(to: "Como funcionam os pontos?", comparison: nil).contains("400"))
        XCTAssertTrue(SimpleAssistant.reply(to: "O que é cashback?", comparison: nil).contains("dinheiro que volta"))
    }

    func testUnrelatedBestQuestionAndLongInputAreLimited() throws {
        XCTAssertTrue(SimpleAssistant.reply(to: "Qual o melhor celular?", comparison: try comparison()).contains("respostas prontas"))
        XCTAssertTrue(SimpleAssistant.reply(to: String(repeating: "a", count: 501), comparison: nil).contains("500 caracteres"))
    }

    func testNegatedRecommendationDoesNotRecommend() throws {
        let answer = SimpleAssistant.reply(to: "Não recomende uma opção, só explique", comparison: try comparison())
        XCTAssertTrue(answer.contains("não vou recomendar"))
        XCTAssertFalse(answer.contains("compensa Pagar"))
    }
}
