import Foundation

/// Respostas locais sobre a calculadora; não chama serviços ou modelos de IA.
public enum SimpleAssistant {
    public static func reply(to question: String, comparison: Comparison?) -> String {
        guard question.count <= 500 else {
            return "A pergunta passou do limite de 500 caracteres. Resuma e tente novamente."
        }
        let normalized = question.folding(options: [.diacriticInsensitive, .caseInsensitive],
                                          locale: Locale(identifier: "pt_BR"))
        let words = Set(normalized.components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty })
        func has(_ terms: String...) -> Bool { !words.isDisjoint(with: terms) }
        let fallback = "Consigo explicar esta calculadora: Pix, cartão, parcelas, rendimento informado, pontos, cashback, antecipação e resgate. Sou o Noah, um assistente local com respostas prontas. Tente: ‘Qual opção vale mais a pena?’"
        guard !has("postal", "pixar", "tempo", "clima", "celular", "acoes", "bitcoin", "senha", "noticias") else {
            return fallback
        }
        let asksResult = has("escolher", "escolha", "recomende", "recomendar", "recomendacao", "compensa", "melhor", "vale", "resultado", "economizo", "economia")
        if asksResult && has("nao", "nunca", "sem") {
            return "Tudo bem, não vou recomendar uma opção. Posso explicar o custo econômico, os pontos ou como preencher a simulação."
        }
        if asksResult {
            guard let comparison, comparison.options.count >= 2 else {
                return "Primeiro corrija os dados na aba Simular. Assim eu consigo explicar o resultado com os valores certos."
            }
            let ordered = comparison.ordered
            func money(_ value: Double) -> String {
                value.formatted(.currency(code: "BRL").locale(Locale(identifier: "pt_BR")))
            }
            if comparison.difference <= 0.01 {
                return "Deu empate econômico na simulação: a diferença é de até R$ 0,01. As opções ficam em \(money(ordered[0].presentCost)) e \(money(ordered[1].presentCost)) em reais de hoje. Escolha o prazo mais confortável para você."
            }
            return "Pelos dados da simulação, compensa \(ordered[0].name). O custo em reais de hoje é \(money(ordered[0].presentCost)), contra \(money(ordered[1].presentCost)) na outra opção. A vantagem estimada é de \(money(comparison.difference)). Isso considera o rendimento e os benefícios que você informou, com dinheiro reservado para pagar a fatura inteira."
        }
        if has("custo", "economico", "presente") {
            return "É uma forma de comparar tudo em reais de hoje. Pagar depois pode ter um custo menor se o dinheiro render enquanto espera. A conta também considera pontos e cashback. Esse valor ajuda na comparação; o dinheiro que sai da conta é o ‘desembolso’."
        }
        if has("rendimento", "render", "investido", "taxa") {
            return "É quanto o dinheiro reservado rende por mês, já descontando impostos e custos. Se ele não fica investido, coloque 0%. A taxa da tela é só um exemplo editável, não uma promessa de rendimento. O dinheiro precisa estar disponível nas datas das parcelas."
        }
        if has("antecipar", "antecipacao", "quitacao", "adiantar") {
            return "Antecipar é pagar antes. Na aba Antecipar, informe o saldo das parcelas, os vencimentos e a oferta de quitação do banco. A conta compara essa oferta com manter os pagamentos e só inclui pontos extras que você realmente ganharia ao antecipar."
        }
        if has("resgate", "resgatar", "trocar", "usar") && has("pontos", "resgate", "resgatar") {
            return "Trocar pontos por desconto pode compensar, mas você abre mão de usá-los depois. Na aba Pontos, compare o desconto da fatura com o valor que esses pontos teriam em outro uso possível. O maior desconto aparente nem sempre é o melhor negócio."
        }
        if has("cashback") {
            return "Cashback é dinheiro que volta para você. Informe apenas o valor confirmado e quando poderá usá-lo. Some com pontos só se o programa permitir receber os dois; assim a conta não inclui o mesmo benefício duas vezes."
        }
        if has("pontos", "ponto", "milheiro") {
            return "Pontos são uma recompensa do cartão. Exemplo: R$ 1.000 em compras a 1 ponto por R$ 2,50 geram cerca de 400 pontos. Se 1.000 pontos valerem R$ 20 no seu resgate, esses 400 valeriam R$ 8. Troque os exemplos pelas regras do seu programa. Pontos não são saldo na conta."
        }
        if has("parcela", "parcelas", "parcelar", "cartao", "juros") {
            return "Preencha o total que será cobrado no cartão, incluindo juros e taxas, a quantidade de parcelas e o primeiro vencimento. Parcelar não é automaticamente mais barato: a vantagem depende do desconto no Pix, do rendimento e dos benefícios. Reserve o dinheiro para pagar a fatura inteira."
        }
        if has("pix", "desconto") {
            return "No Pix, você paga hoje. Informe o preço e o desconto oferecido pela loja. A calculadora compara esse valor com o custo do cartão em reais de hoje. Quanto maior o desconto, mais o Pix tende a compensar."
        }
        if has("preencher", "funciona", "comecar", "ajuda") {
            return "Comece em Simular: informe o preço, o desconto no Pix e o total no cartão. Ajuste parcelas e vencimento. Use rendimento de 0% se o dinheiro não render. O resultado aparece no topo. Depois pergunte: ‘Qual opção vale mais a pena?’"
        }
        return fallback
    }
}
