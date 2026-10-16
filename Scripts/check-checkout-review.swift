import Foundation
import DecisionCore

@main struct ReviewCheck {
    static func main() throws {
        func photo(_ name: String, _ text: String, selected: PhotoTextRecognizer.Payment? = nil, price: Decimal? = nil) -> ChatAttachment {
            ChatAttachment(name: name, kind: .image, text: text, image: .init(text: text, selectedPayment: selected, advertisedPrice: price))
        }
        let attachments = [
            photo("anuncio", "MAIS VENDIDO\n12x R$ 34,56\nCom seu Cartão Mercado", price: 400),
            photo("itau", "Itaú · Cartão Mercado\n1x R$ 400,00\n2x R$ 210,00 R$ 420,00\n3x R$ 150,00 R$ 450,00", selected: .itau),
            photo("itau-continuacao", "2x R$ 210,00 R$ 420,00\n3x R$ 150,00 R$ 450,00\n4x R$ 115,00 R$ 460,00"),
            photo("mercado", "Itaú · Cartão Mercado\n1x R$ 400,00\n2x R$ 210,00 R$ 420,00\n3x R$ 150,00 R$ 450,00", selected: .mercado),
            photo("mercado-continuacao", "2x R$ 210,00 R$ 420,00\n3x R$ 150,00 R$ 450,00\n4x R$ 115,00 R$ 460,00"),
            photo("inter", "BANCO INTER\n1x R$ 400,00\n2x R$ 210,00 R$ 420,00"),
            photo("inter-continuacao", "3x R$ 150,00 R$ 450,00\n4x R$ 115,00 R$ 460,00")
        ]
        var sources = CheckoutSource.read(attachments)
        assert(sources[0].card == .choose && sources[0].rows.first?.total == "400,00" && sources[0].rows.allSatisfy { !$0.included })
        assert(sources[1].card == .itau && sources[2].continuationOf == sources[1].id)
        assert(sources[3].card == .mercado && sources[4].continuationOf == sources[3].id)
        assert(sources[5].card == .inter && sources[6].continuationOf == sources[5].id)
        assert(sources[6].principal == "400,00")
        let initialPlans = try CheckoutSource.plans(sources)
        assert(initialPlans.count == 12, "Sobreposições não duplicam parcelas, cartões diferentes continuam separados")
        sources[1].card = .other
        sources[1].cashback = "2,00"
        assert(sources[CheckoutSource.leader(2, in: sources)].card == .other)
        assert(sources[CheckoutSource.leader(2, in: sources)].cashback == "2,00", "Edição compartilhada pelas continuações")
        sources[2].rows[0].total = "421,00"
        do { _ = try CheckoutSource.plans(sources); assertionFailure("Totais contraditórios não podem gerar ranking") }
        catch is CalculationError { }
        sources[2].continuationOf = nil
        let separatedPlans = try CheckoutSource.plans(sources)
        assert(separatedPlans.count == 14)
        sources[0].card = .pix; sources[0].rows[0].included = true
        let pixPlans = try CheckoutSource.plans(sources)
        assert(pixPlans.count == 15)
        let unrelated = CheckoutSource.read([attachments[5], photo("outra compra", "2x R$ 230,00 R$ 460,00\n3x R$ 160,00 R$ 480,00")])
        assert(unrelated[1].continuationOf == nil, "Conflitos não herdam cartão")
        let headers = CheckoutSource.read([attachments[5], photo("cartao novo", "Itaú · Cartão Mercado\n1x R$ 400,00")])
        assert(headers[1].card == .choose && headers[1].continuationOf == nil, "Cabeçalho novo inicia outro grupo, mesmo com preço igual")
        let noPrice = CheckoutSource.read([photo("vazio", "Escolha as parcelas")])
        assert(noPrice[0].rows.allSatisfy { !$0.included })
        let explicitPix = CheckoutSource.read([photo("anuncio Pix", "MAIS VENDIDO\nR$ 400,00 no Pix\n12x R$ 34,56")])
        assert(explicitPix[0].card == .pix && explicitPix[0].rows.count == 1 && explicitPix[0].rows[0].included)
        let fileURLs = ["IMG_12.png", "IMG_2.png", "IMG_1.png"].map { URL(fileURLWithPath: $0) }
        assert(ChatAttachmentReader.orderedFiles(fileURLs).map(\.lastPathComponent) == ["IMG_1.png", "IMG_2.png", "IMG_12.png"])
        let mixed = ["outro.png", "IMG_1.png"].map { URL(fileURLWithPath: $0) }
        assert(ChatAttachmentReader.orderedFiles(mixed) == mixed)
        if let path = CommandLine.arguments.dropFirst().first {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let reports = try JSONSerialization.jsonObject(with: data) as! [[String: Any]]
            let real = reports.map { report in
                photo(report["name"] as! String, report["text"] as! String,
                      selected: PhotoTextRecognizer.Payment(rawValue: report["selectedPayment"] as? String ?? ""),
                      price: Decimal(string: report["advertisedPrice"] as? String ?? ""))
            }
            var drafts = CheckoutSource.read(real)
            assert(drafts.count == 7 && drafts[0].rows.allSatisfy { !$0.included } && drafts[0].rows[0].count == 1)
            assert(reports.allSatisfy { ($0["previewBytes"] as? Int ?? 0) > 0 })
            assert(drafts[1].card == .itau && drafts[2].continuationOf == drafts[1].id)
            assert(drafts[3].card == .mercado && drafts[4].continuationOf == drafts[3].id)
            assert(drafts[5].card == .inter && drafts[6].continuationOf == drafts[5].id)
            let cardPlans = try CheckoutSource.plans(drafts)
            assert(cardPlans.count == 36)
            for root in [1, 3, 5] {
                assert(Set(cardPlans.filter { $0.source == root }.map { $0.row.count }) == Set(1...12))
            }
            drafts[0].card = .pix; drafts[0].rows[0].included = true
            let plans = try CheckoutSource.plans(drafts)
            assert(plans.count == 37)
            let offers = try plans.map { plan in
                CheckoutOffer(name: "\(drafts[plan.source].card) \(plan.row.count)x", total: try BrazilianInput.decimal(plan.row.total, label: "total"),
                              days: (0..<(drafts[plan.source].card == .pix ? 1 : plan.row.count)).map { drafts[plan.source].card == .pix ? 0 : 30 * ($0 + 1) },
                              eligiblePrimeSpend: drafts[plan.source].card == .inter ? try BrazilianInput.decimal(drafts[plan.source].principal, label: "base") : 0)
            }
            let result = try DecisionEngine.checkout(offers, reaisPerThousand: 0, monthlyRate: 0)
            assert(result.ordered.filter { $0.presentCost - result.ordered[0].presentCost <= 0.01 }.count == 4)
            print("OK: sete imagens reais, três cartões corretos, 36 planos únicos, 37 com Pix confirmado, ranking e empate de 1x conferidos.")
        }
        print("OK: agrupamento, edição compartilhada, conflitos, deduplicação, Pix confirmado e ordem dos arquivos.")
    }
}
