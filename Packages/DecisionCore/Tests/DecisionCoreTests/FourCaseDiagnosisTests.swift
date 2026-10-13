import XCTest
@testable import DecisionCore

final class FourCaseDiagnosisTests: XCTestCase {
    private func report(extra: Decimal = 0, pix: Decimal = 950, quote: Decimal = 1000,
                        interest: Decimal = 1100, milheiro: Decimal = 20) throws -> FourCaseReport {
        try DecisionEngine.fourCases(principal: 1000, pixPrice: pix,
            noInterestDays: [30, 60], interestTotal: interest, interestDays: [30, 60],
            anticipationQuote: quote, anticipationDay: 0, firstDueDay: 30,
            extraPoints: extra, reaisPerThousand: milheiro,
            normalPointDay: 30, anticipatedPointDay: 0, monthlyRate: 0)
    }
    func testOrdinaryPrimePointsArePresentInAllThreeCardScenariosOnce() throws {
        let r = try report()
        XCTAssertEqual(r.cases.map(\.normalPoints), [400, 400, 0, 400])
        XCTAssertEqual(r.cases.map { $0.option!.presentCost }, [992, 1092, 950, 992])
        XCTAssertEqual(r.comparison?.recommendation, PurchaseCase.pix.rawValue)
    }
    func testOnlyIncrementalBonusCanReverseTheChoice() throws {
        let r = try report(extra: 3000)
        XCTAssertEqual(r.cases[3].extraPoints, 3000)
        XCTAssertEqual(r.cases[3].option!.presentCost, 932)
        XCTAssertEqual(r.comparison?.recommendation, PurchaseCase.anticipate.rawValue)
    }
    func testInterestDoesNotIncreaseOrdinaryPoints() throws {
        XCTAssertEqual(try report(interest: 2000).cases[1].normalPoints, 400)
    }
    func testNoahReportsAllFourCasesAndDoesNotMisreadSemJurosAsNegation() throws {
        let r = try report()
        let answer = SimpleAssistant.reply(to: "Qual é melhor: sem juros ou Pix?", comparison: r.comparison, diagnostics: r)
        for kind in PurchaseCase.allCases { XCTAssertTrue(answer.contains(kind.rawValue)) }
        XCTAssertTrue(answer.contains("menor custo"))
        XCTAssertFalse(answer.contains("não vou recomendar"))
    }

    func testZeroPricesAreMissingRatherThanFreeWinners() throws {
        let r = try DecisionEngine.fourCases(principal: 0, pixPrice: 0,
            noInterestDays: [], interestTotal: 0, interestDays: [],
            anticipationQuote: 0, anticipationDay: 0, firstDueDay: 30,
            extraPoints: 0, reaisPerThousand: 0, normalPointDay: 0,
            anticipatedPointDay: 0, monthlyRate: 0)
        XCTAssertNil(r.comparison)
        XCTAssertTrue(r.cases.allSatisfy { $0.option == nil })
        XCTAssertTrue(r.summary.contains("Preencha pelo menos 2"))
    }
    func testMissingAndInvalidOffersStayVisibleInDiagnosis() throws {
        let r = try report(pix: 0, quote: 0, interest: 900)
        XCTAssertEqual(r.cases.filter { $0.option != nil }.count, 1)
        XCTAssertTrue(r.summary.contains("total com juros não pode"))
        XCTAssertNil(r.comparison)
    }
    func testZeroPointValueIsExplicitAndTieIsNotClaimedAsOneWinner() throws {
        let r = try report(pix: 1000, milheiro: 0)
        XCTAssertTrue(r.summary.contains("Empate econômico"))
        XCTAssertTrue(r.summary.contains("valor dos pontos está zerado"))
    }
}
