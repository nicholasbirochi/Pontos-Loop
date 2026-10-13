import XCTest
import Foundation
@testable import DecisionCore

final class DecisionEngineTests: XCTestCase {
    private func purchase(rate: Double = 0, count: Int = 10,
                          pix: Decimal = 950, benefitDay: Int = 0) throws -> Comparison {
        try DecisionEngine.purchase(referencePrice: 1000, pixPrice: pix, cardTotal: 1000,
            days: (1...count).map { $0 * 30 }, eligibleSpend: 1000, reaisPerPoint: 2.5,
            reaisPerThousand: 20, rewardsEnabled: true, cashback: 0,
            benefitDay: benefitDay, monthlyRate: rate)
    }

    func testWithoutInvestmentFivePercentPixWins() throws {
        let result = try purchase()
        XCTAssertEqual(result.recommendation, "Pagar no Pix")
        XCTAssertEqual(result.options[1].presentCost, 992, accuracy: 0.000_001)
        XCTAssertEqual(result.difference, 42, accuracy: 0.000_001)
    }

    func testZeroDiscountAndOneInstallmentPointsWin() throws {
        let result = try purchase(count: 1, pix: 1000)
        XCTAssertEqual(result.recommendation, "Pagar no cartão")
        XCTAssertEqual(result.difference, 8, accuracy: 0.000_001)
    }

    func testAnnuityClosedFormAndDelayedPoints() throws {
        let result = try purchase(rate: 0.008, benefitDay: 30)
        let annuity = 100 * (1 - pow(1.008, -10)) / 0.008
        XCTAssertEqual(result.options[1].presentCost, annuity - 8 / 1.008, accuracy: 0.000_001)
        XCTAssertEqual(result.recommendation, "Pagar no cartão")
    }

    func testDatesAffectOpportunityCost() throws {
        let immediate = try DecisionEngine.presentValue(
            [CashFlow("Pagamento", amount: 1000, day: 0)], monthlyRate: 0.01)
        let later = try DecisionEngine.presentValue(
            [CashFlow("Pagamento", amount: 1000, day: 60)], monthlyRate: 0.01)
        XCTAssertEqual(immediate, 1000)
        XCTAssertEqual(later, 1000 / pow(1.01, 2), accuracy: 0.000_001)
    }

    func testInstallmentsPreserveCentavos() throws {
        let flows = try DecisionEngine.installments(total: 100, days: [30, 60, 90])
        let expected = ["33.33", "33.33", "33.34"].map { Decimal(string: $0)! }
        XCTAssertEqual(flows.map(\.amount), expected)
        XCTAssertEqual(flows.reduce(Decimal(0)) { $0 + $1.amount }, 100)
    }

    func testAnticipationWithoutBonusLosesYield() throws {
        let remaining = try DecisionEngine.installments(total: 1000, days: [30, 60])
        let result = try DecisionEngine.anticipation(remaining: remaining, quote: 1000,
            paymentDay: 0, incrementalPoints: 0, reaisPerThousand: 20, bonusDay: 0, monthlyRate: 0.01)
        XCTAssertEqual(result.recommendation, "Manter os vencimentos")
    }

    func testAnticipationRealBonusCanReverseDecision() throws {
        let remaining = [CashFlow("Fatura", amount: 1000, day: 30)]
        let result = try DecisionEngine.anticipation(remaining: remaining, quote: 1000,
            paymentDay: 0, incrementalPoints: 1000, reaisPerThousand: 20, bonusDay: 0, monthlyRate: 0.01)
        XCTAssertEqual(result.recommendation, "Antecipar pagamento")
        XCTAssertEqual(result.options[1].presentCost, 980)
    }

    func testRedeemingPointsUsesOpportunityCost() throws {
        let result = try DecisionEngine.redemption(bill: 1000, billDay: 0, pointsSpent: 1000,
            offeredDiscount: 15, alternativeValuePerThousand: 20, monthlyRate: 0)
        XCTAssertEqual(result.recommendation, "Pagar e guardar os pontos")
        XCTAssertEqual(result.options[1].presentCost, 1005)
        XCTAssertEqual(result.options[1].cashOutlay, 985)
    }

    func testTieWithinOneCent() throws {
        let result = try purchase(pix: 992)
        XCTAssertEqual(result.recommendation, "Empate econômico")
    }

    func testInvalidInputsThrowInsteadOfProducingNaN() {
        XCTAssertThrowsError(try DecisionEngine.presentValue([], monthlyRate: -1))
        XCTAssertThrowsError(try DecisionEngine.presentValue(
            [CashFlow("x", amount: 1, day: -1)], monthlyRate: 0))
        XCTAssertThrowsError(try DecisionEngine.installments(total: 10, days: []))
        XCTAssertThrowsError(try DecisionEngine.installments(total: 100.001, days: [30]))
        XCTAssertThrowsError(try DecisionEngine.earnedPoints(eligibleSpend: 100, reaisPerPoint: 0))
        XCTAssertThrowsError(try DecisionEngine.redemption(bill: 10, billDay: 0, pointsSpent: 1,
            offeredDiscount: 11, alternativeValuePerThousand: 20, monthlyRate: 0))
        XCTAssertThrowsError(try DecisionEngine.anticipation(
            remaining: [CashFlow("x", amount: 100, day: 30)], quote: 100, paymentDay: 10,
            incrementalPoints: 10, reaisPerThousand: 20, bonusDay: 0, monthlyRate: 0))
    }

    func testBreakEvenCanBeNegative() throws {
        XCTAssertEqual(try DecisionEngine.breakEvenDiscount(
            referencePrice: 1000, cardPresentCost: 1050), -5, accuracy: 0.000_001)
    }

    struct Fixture: Decodable {
        struct Flow: Decodable { let amount: String; let day: Int }
        let id: String
        let rate: Double
        let flows: [Flow]
        let expectedPV: Double
    }

    func testIndependentDecimalFixtures() throws {
        let path = try XCTUnwrap(Bundle.module.url(forResource: "cases", withExtension: "json", subdirectory: "Fixtures"))
        let fixtures = try JSONDecoder().decode([Fixture].self, from: Data(contentsOf: path))
        for fixture in fixtures {
            let flows = try fixture.flows.map { flow -> CashFlow in
                let amount = try XCTUnwrap(Decimal(string: flow.amount))
                return CashFlow(fixture.id, amount: amount, day: flow.day)
            }
            let actual = try DecisionEngine.presentValue(flows, monthlyRate: fixture.rate)
            XCTAssertEqual(actual, fixture.expectedPV, accuracy: 0.000_001, fixture.id)
        }
    }
}
