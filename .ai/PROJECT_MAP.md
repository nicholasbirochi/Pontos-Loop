# CompraClara — projeto 60

App nativo SwiftUI, iOS 17+ e macOS 14+, sem dependências remotas.

- `AppRootView`: mantém rascunho e histórico e conecta Simular, Noah e Salvos.
- `InputState.calculate`: valida a entrada brasileira e transforma datas em fluxos.
- `DecisionCore/DecisionEngine`: dinheiro em Decimal e valor presente em Double.
- `DecisionCore/SimpleAssistant`: respostas locais por assunto, com a comparação atual.
- `CalculatorView`: entrada simples (Pix direto, total e parcelas), comparação explícita e detalhes recolhidos.
- `PhotoImportView`: até 4 fotos/arquivos, revisão editável, aplicação somente após validar.
- `PhotoTextRecognizer`: Apple Vision local, imagens até 20 MB, orientação corrigida e redução para 2400 px.
- `DecisionCore/OfferExtractor`: extrai preços Pix e ofertas regulares explícitas; não adivinha valores ambíguos.
- `AssistantView`: conversa em memória; nenhuma chamada de rede.
- `HistoryStore`: UserDefaults versionado v1, até 100 cenários; preço Pix direto opcional mantém compatibilidade com cenários antigos.
- `project.yml`: fonte XcodeGen; projeto Xcode gerado incluído para abrir diretamente.

Validação: `swift test --package-path Packages/DecisionCore`,
`python3 Scripts/check_math.py`, builds iOS/macOS e UI tests no simulador.

Limites: taxas e pontos são hipóteses editáveis; chat por regras, sem LLM;
instalação física requer assinatura Apple e iPhone conectado. Não há sincronização.
