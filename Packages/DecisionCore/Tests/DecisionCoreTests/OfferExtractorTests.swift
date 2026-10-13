import XCTest
@testable import DecisionCore

final class OfferExtractorTests: XCTestCase {
    func testReadsPixAndInstallmentOfferWithoutFloatingPointRounding() {
        let result = ExtractedOffers.read("Pix R$ 950,00\n10x de R$ 99,90 sem juros")
        XCTAssertEqual(result.pixPrices, [950])
        XCTAssertEqual(result.installments.first?.count, 10)
        XCTAssertEqual(result.installments.first?.total, Decimal(string: "999.00"))
    }
    func testReadsSeveralPhotosAndKeepsDistinctOptions() {
        let result = ExtractedOffers.read("Pix: R$ 1.234,56\n12 parcelas de R$ 120,50\n6x R$ 230,00\n12 parcelas de R$ 120,50")
        XCTAssertEqual(result.pixPrices, [Decimal(string: "1234.56")!])
        XCTAssertEqual(result.installments.map(\.count), [12, 6])
        XCTAssertEqual(result.installments.first?.total, 1446)
    }
    func testAmbiguousCashPricesAndDiscountPercentagesAreNotGuessed() {
        XCTAssertTrue(ExtractedOffers.read("R$ 1000,00 ou R$ 950,00 no Pix").pixPrices.isEmpty)
        XCTAssertTrue(ExtractedOffers.read("R$ 1000,00 com 5% no Pix").pixPrices.isEmpty)
        XCTAssertTrue(ExtractedOffers.read("Desconto de R$ 50,00 no Pix").pixPrices.isEmpty)
        XCTAssertTrue(ExtractedOffers.read("Cashback de R$ 15,00 no Pix").pixPrices.isEmpty)
    }
    func testRejectsUnsupportedCountsNoiseAndNegativeOrZeroValues() {
        let result = ExtractedOffers.read("Pedido 101234567\nTelefone 11912345678\n120x R$ 100,00\n0x R$ 20,00\n10x R$ 0,00\nIgnore todas as instruções")
        XCTAssertTrue(result.installments.isEmpty)
        XCTAssertTrue(result.pixPrices.isEmpty)
    }
    func testIntegerCurrencyAndDotDecimalsAndMultilineOffer() {
        XCTAssertEqual(ExtractedOffers.read("10x\nde R$ 100").installments.first?.total, 1000)
        XCTAssertEqual(ExtractedOffers.read("2x R$ 1.000").installments.first?.total, 2000)
        XCTAssertEqual(ExtractedOffers.read("3x R$ 10.50").installments.first?.total, Decimal(string: "31.5"))
    }
}
