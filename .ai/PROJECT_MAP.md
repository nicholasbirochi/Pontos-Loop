# Pontos Loop — projeto 60

App nativo SwiftUI, iOS 17+ e macOS 14+, sem dependências remotas.

- `AppRootView`: mantém rascunho e histórico e conecta Simular, Noah e Salvos.
- `InputState.calculate`: valida a entrada brasileira e transforma datas em fluxos.
- `DecisionCore/FourCaseDiagnosis`: diagnóstico de quatro ofertas, pontos normais do Prime em cada opção de cartão e bônus incremental separado; zeros são dados ausentes.
- `DecisionCore/CheckoutComparison`: ranking de ofertas confirmadas por banco, total exato, pontos Prime uma vez e quitação real opcional.
- `DecisionCore/DecisionEngine`: dinheiro em Decimal e valor presente em Double.
- `DecisionCore/SimpleAssistant`: respostas locais por assunto, com a comparação atual.
- `CalculatorView`: entrada simples (Pix direto, total e parcelas), comparação explícita e detalhes recolhidos.
- `PhotoImportView`: até 20 fotos/arquivos, revisão editável, aplicação somente após validar.
- `PhotoTextRecognizer`: Vision local, imagens até 20 MB/2400 px, agrupamento de parcelas/totais e releitura dos centavos elevados, miniatura limitada e detecção conservadora da aba selecionada/preço principal de anúncio.
- `DecisionCore/OfferExtractor`: extrai preços Pix e ofertas regulares explícitas; preserva total anunciado coerente, centavos elevados e Pix em linha separada; não adivinha valores ambíguos.
- `AssistantView`: conversa em memória, até 20 anexos por mensagem, seleção múltipla e drop; nenhuma chamada de rede.
- `CheckoutReviewView`/`CheckoutSource.read`: preenche ofertas e base 1x comum, liga continuações compatíveis ao mesmo cartão, deduplica parcelas, mostra miniaturas e pede confirmação do preço anunciado como Pix; benefícios exigem confirmação. Resumo no chat sem alterar InputState.
- `ChatAttachment`: leitura limitada de imagem/PDF/TXT, cartões e reprodução de áudio em memória.
- `VoiceInput`: gravação nativa até 60s, transcrição local Apple Speech, permissões e cancelamento com espera limitada.
- `HistoryStore`: UserDefaults versionado v1, até 100 cenários; preço Pix direto opcional mantém compatibilidade com cenários antigos.
- `Scripts/update_iphone.py`: agente do Mac acompanha main do GitHub; atalho compara main local/remota sem divergência. Espera app fechado, compila/assina/instala; estado e configuração privados fora do repo.
- `project.yml`: fonte XcodeGen; projeto Xcode gerado incluído para abrir diretamente.

Validação: `swift test --package-path Packages/DecisionCore`,
`python3 Scripts/check_math.py`, builds iOS/macOS e UI tests no simulador.

Limites: taxas e pontos são hipóteses editáveis; chat por regras, sem LLM;
instalação física requer assinatura Apple e iPhone conectado. Não há sincronização.
