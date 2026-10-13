import XCTest
@testable import DecisionCore

final class CheckoutComparisonTests: XCTestCase {
    func testSeveralCardsRankWithoutApplyingPrimeToOtherBanks() throws {
        let offers = [
            CheckoutOffer(name: "Pix", total: 950, days: [0]),
            CheckoutOffer(name: "Inter 10x", total: 1000, days: Array(stride(from: 30, through: 300, by: 30)), eligiblePrimeSpend: 1000),
            CheckoutOffer(name: "Itaú 6x", total: 1020, days: Array(stride(from: 30, through: 180, by: 30))),
            CheckoutOffer(name: "Mercado 3x", total: 990, days: [30, 60, 90], cashback: 13)
        ]
        let zero = try DecisionEngine.checkout(offers, reaisPerThousand: 0, monthlyRate: 0)
        XCTAssertEqual(zero.ordered[0].name, "Pix")
        let valued = try DecisionEngine.checkout(offers, reaisPerThousand: 200, monthlyRate: 0)
        XCTAssertEqual(valued.ordered[0].name, "Inter 10x")
        XCTAssertEqual(valued.options[1].presentCost, 920, accuracy: 0.001)
        XCTAssertEqual(valued.options[2].presentCost, 1020, accuracy: 0.001)
        XCTAssertEqual(valued.options[3].presentCost, 977, accuracy: 0.001)
    }

    func testAnticipationCountsNormalPointsOncePlusExtra() throws {
        let report = try DecisionEngine.checkout([
            CheckoutOffer(name: "Pix", total: 950, days: [0]),
            CheckoutOffer(name: "Inter antecipado", total: 960, days: [0], eligiblePrimeSpend: 1000, extraPoints: 500)
        ], reaisPerThousand: 200, monthlyRate: 0)
        XCTAssertEqual(report.ordered[0].presentCost, 780, accuracy: 0.001)
    }

    func testMissingPricesAndInvalidBenefitsAreRejected() {
        for offer in [CheckoutOffer(name: "Zero", total: 0, days: [0]),
                      CheckoutOffer(name: "Cashback inválido", total: 10, days: [0], cashback: 20),
                      CheckoutOffer(name: "Centavos inválidos", total: 10, days: [0], cashback: Decimal(string: "1.001")!),
                      CheckoutOffer(name: "Bônus negativo", total: 10, days: [0], extraPoints: -1)] {
            XCTAssertThrowsError(try DecisionEngine.checkout([CheckoutOffer(name: "Pix", total: 50, days: [0]), offer], reaisPerThousand: 0, monthlyRate: 0))
        }
    }

    func testCheckoutUsesQuotedTotalInsteadOfRoundedInstallmentProduct() {
        let offers = ExtractedOffers.read("3x R$ 92641 R$ 2.77924\n12x R$ 243,16 R$ 2.917,87\nAté R$ 13,20 de cashback")
        XCTAssertEqual(offers.installments.map(\.total), [Decimal(string: "2779.24")!, Decimal(string: "2917.87")!])
        XCTAssertEqual(offers.installments[0].amount, Decimal(string: "926.41"))
    }

    func testPixOnNextLineAndSeparatedCents() {
        let offers = ExtractedOffers.read("R$ 1.000 00\nno Pix\n1x R$ 1.10000")
        XCTAssertEqual(offers.pixPrices, [1000])
        XCTAssertEqual(offers.installments.first?.total, 1100)
    }

    func testCashbackIsNeverUsedAsInstallmentTotal() {
        let offer = ExtractedOffers.read("3x R$ 100 R$ 50 de cashback").installments.first
        XCTAssertEqual(offer?.total, 300)
        XCTAssertNil(offer?.quotedTotal)
    }
}
