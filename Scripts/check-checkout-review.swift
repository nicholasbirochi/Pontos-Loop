import Foundation

@main struct ReviewCheck {
    static func main() throws {
        let attachments = [
            ChatAttachment(name: "anuncio", kind: .image, text: "MAIS VENDIDO\n12x R$ 34,56"),
            ChatAttachment(name: "inter", kind: .image, text: "BANCO INTER\n1x R$ 400,00\n2x R$ 210,05 R$ 420,10"),
            ChatAttachment(name: "continuacao", kind: .image, text: "4x R$ 110,00 R$ 440,00"),
            ChatAttachment(name: "dois cartoes", kind: .image, text: "Itaú · Cartão Mercado\n1x R$ 400,00"),
            ChatAttachment(name: "sem valores", kind: .image, text: "Escolha as parcelas")
        ]
        let sources = CheckoutSource.read(attachments)
        assert(sources[0].rows.allSatisfy { !$0.included })
        assert(sources[1].card == .inter && sources[1].principal == "400,00")
        assert(sources[2].principal == "400,00" && sources[2].rows.first?.total == "440,00")
        assert(sources[3].card == .choose && sources[3].rows.first?.included == true)
        assert(sources[4].rows.allSatisfy { !$0.included })
        let conflict = CheckoutSource.read([attachments[2], ChatAttachment(name: "outra base", kind: .image, text: "1x R$ 390,00"), attachments[1]])
        assert(conflict[0].principal == "0,00", "Não presumir base comum quando os preços 1x diferem")
        if let path = CommandLine.arguments.dropFirst().first {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let reports = try JSONSerialization.jsonObject(with: data) as! [[String: Any]]
            let real = reports.map { ChatAttachment(name: $0["name"] as! String, kind: .image, text: $0["text"] as! String) }
            let drafts = CheckoutSource.read(real)
            assert(drafts.count == 7 && drafts[0].rows.allSatisfy { !$0.included })
            assert(drafts.flatMap(\.rows).filter(\.included).count == 54)
            assert(drafts.flatMap(\.rows).filter(\.included).allSatisfy { $0.count > 0 && $0.total != "0" })
            print("OK: sete prints reais geraram 54 ofertas preenchidas, anúncio excluído e nenhum campo obrigatório zerado.")
        }
        print("OK: revisão automática, cartão ambíguo opcional, base comum e anúncios verificados.")
    }
}
