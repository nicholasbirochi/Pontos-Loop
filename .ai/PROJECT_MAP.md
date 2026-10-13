# CompraClara — projeto 60

App nativo SwiftUI, iOS 17+ e macOS 14+, sem dependências remotas.

- `AppRootView`: mantém rascunho e histórico e conecta Simular, Noah e Salvos.
- `InputState.calculate`: valida a entrada brasileira e transforma datas em fluxos.
- `DecisionCore/DecisionEngine`: dinheiro em Decimal e valor presente em Double.
- `DecisionCore/SimpleAssistant`: respostas locais por assunto, com a comparação atual.
- `CalculatorView`: entrada, comparação, detalhes e compartilhamento.
- `AssistantView`: conversa em memória; nenhuma chamada de rede.
- `HistoryStore`: UserDefaults versionado v1, até 100 cenários; rascunho preservado.
- `project.yml`: fonte XcodeGen; projeto Xcode gerado incluído para abrir diretamente.

Validação: `swift test --package-path Packages/DecisionCore`,
`python3 Scripts/check_math.py`, builds iOS/macOS e UI tests no simulador.

Limites: taxas e pontos são hipóteses editáveis; chat por regras, sem LLM;
instalação física requer assinatura Apple e iPhone conectado. Não há sincronização.
