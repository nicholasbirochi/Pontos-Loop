# Validação — 13/10/2026

## Comprovado

- `swift test --package-path Packages/DecisionCore --scratch-path /private/tmp/compraclara-swift-tests-20261013`:
  **20 testes aprovados**, sendo 12 de cálculo e 8 do assistente.
- `python3 Scripts/check_math.py`: **15 fixtures, identidades e 250 cronogramas
  aleatórios**, todos aprovados.
- Build **iOS Simulator**, build **iPhone físico arm64 (sem assinatura)** e build
  **macOS** concluídos com sucesso no Xcode instalado.
- Simulador dedicado **iPhone 13**, iOS 27 já instalado: testes de recomendação
  contextual do Noah e navegação entre Compra, Antecipar, Pontos e Salvos aprovados.
- Teste de salvar, relançar o app e restaurar uma simulação aprovado em execução
  específica. O teste foi corrigido para limpar o nome pré-preenchido na caixa de
  salvar; a primeira tentativa do teste procurava um nome diferente do que digitou.
- Captura de tela real produzida com `simctl io … screenshot` e ícone conferido.

Os builds e testes usam `/private/tmp` para evitar metadados de sincronização da
pasta de trabalho na assinatura dos produtos temporários.

## Limites

- **Nenhum iPhone físico conectado** foi detectado por `xcrun devicectl list devices`.
  Instalação e teste no aparelho real dependem de conexão, Conta Apple/equipe de
  assinatura e, quando solicitado, Modo de Desenvolvedor.
- Não foi criada IPA assinada, publicação na App Store ou distribuição TestFlight.
- O tema preto é padrão do aplicativo. O ícone usa o símbolo solicitado em cinza.
- O Noah responde por regras locais: não é um modelo de linguagem e não consulta
  taxas, contas bancárias ou condições atuais.
- Datas de simulações antigas precisam ser revisadas. Não há sincronização entre
  dispositivos, importação de extrato nem cronograma irregular.
- Não houve certificação formal de acessibilidade ou teste em todos os tamanhos de
  tela e versões do iOS; a prioridade foi o formato do iPhone 13.

## Versão 1.1 — simplificação e fotos (13/10/2026)

- 26 testes do pacote (12 cálculo, 9 Noah, 5 extração de ofertas).
- Quatro testes de interface no iPhone 13/iOS 27: entrada simples e abertura do
  importador, Noah contextual, navegação e salvar/relançar/restaurar. Suite completa aprovada.
- `Scripts/check-photo-import.swift`, compilado junto de `App/PhotoTextRecognizer.swift`,
  aprovou OCR de imagem sintética com Pix R$ 950 e 10x R$ 100 e rejeição de imagem
  inválida/acima de 20 MB.
- `Scripts/check-input-compatibility.swift`, compilado com InputState e DecisionEngine,
  validou leitura de JSON legado, cálculo de Pix direto, persistência do novo campo e
  rejeição de Pix com mais de duas casas.
- Fluxo real no Mac: arquivo PNG selecionado pelo painel nativo, preços/parcelas
  conferidos na revisão e comparação confirmada em R$ 950 contra R$ 1.000.
- A câmera e a biblioteca de fotos de um iPhone físico continuam sem validação.
  Não há captura de câmera integrada; a pessoa escolhe imagens já tiradas ou prints.

## Pontos Loop 1.2 — nome, zeros, tutorial e quatro casos

- Nome de exibição Pontos Loop; projeto/esquemas PontosLoop, mantendo bundle IDs
  e armazenamento para compatibilidade.
- 35 testes do pacote: cálculo, Noah, extração de ofertas e quatro cenários.
- Testes do diagnóstico verificam pontos normais nas três alternativas de cartão
  uma vez, juros sem ampliar a base, bônus incremental capaz de mudar o resultado,
  zeros como ausentes, empate e dados incompletos, além da frase “sem juros”.
- A checagem de InputState verificou todos os padrões String em zero, contagens
  zeradas, JSON legado e persistência do preço Pix direto.
- A revisão do histórico Git inspecionou 74 blobs sem encontrar padrões de
  credenciais; documentos e imagens são de especificação/exemplos ilustrativos.
- Nenhuma publicação de logs de dispositivo, faturas reais ou fotos do usuário.
- As condições oficiais do Prime foram consultadas em 13/10/2026 e documentadas
  em INTER-PRIME.md; a previsão real da fatura e a elegibilidade prevalecem.

- A suíte completa de 5 testes de interface concluiu com TEST SUCCEEDED no iPhone
  13/iOS 27: Noah, navegação, histórico, fotos e padrões zerados sem vencedor grátis.
- O build macOS concluiu com sucesso. A captura inicial confirma o novo nome,
  passo a passo visível no topo e os campos em zero. Histórico anterior preservado.
- Os builds finais macOS e iPhone arm64 sem assinatura foram aprovados, com
  verificação da assinatura local do Mac. A checagem de compatibilidade também
  rejeita Pix, saldo ou quitação zerados nos modos individuais.

## Pontos Loop 1.3 — chat com áudio e comparação de anexos

- 42 testes de DecisionCore aprovados: 12 de cálculo, 7 de quatro cenários,
  6 de extração, 11 de Noah e 6 de comparação entre ofertas. Incluem pontos Prime
  uma vez, bônus separado, outros bancos sem pontos automáticos, centavos do total
  anunciado, Pix em linha separada e cashback não confundido com preço.
- Suíte completa de 6 testes de interface aprovada no iPhone 13/iOS 27, com
  `TEST SUCCEEDED`: os cinco fluxos anteriores e menu de anexos, seletor de
  arquivos, envio de pergunta e limpeza da conversa. O serviço nativo de arquivos
  precisou de até 20s na primeira inicialização; o teste passou com esse prazo.
- Checagem nativa de anexos aprovou TXT, PDF com texto, truncamento explícito,
  arquivos vazios/inválidos e acima de 20 MB, além de WAV vazio ou com 61 segundos
  rejeitados antes de pedir permissão e cancelamento antes de iniciar reprodução.
- Checagem de VoicePermissionGate aprovou conclusão única, callback duplicado,
  timeout, cancelamento e callback tardio, sem pedir permissões reais.
- OCR nativo de quatro imagens sintéticas aprovado, incluindo Pix em duas linhas,
  várias quantidades de parcelas e total anunciado diferente em um centavo.
- Fluxo Mac comprovado pela interface: quatro PNGs selecionados juntos no painel
  nativo, envio, confirmação de Pix/Inter Prime/Mercado Livre/Itaú e diagnóstico
  de oito ofertas no chat. Pix ilustrativo R$ 900 venceu cartão R$ 1.000 por
  R$ 100; total R$ 1.050,01 preservado, cashback condicional mantido em zero e
  antecipação não informada indicada como ausente. A simulação principal não mudou.
  Foram usados apenas arquivos sintéticos, sem prints financeiros do usuário.
- O Mac declarou suporte local a pt_BR, mas a autorização Speech para um áudio
  sintético não retornou neste ambiente. A transcrição real permanece pendente.
  O app limita a espera e preserva áudio válido com aviso para escrever a pergunta;
  não tenta reconhecimento por servidor nem anuncia que entendeu o áudio.
- Gravação real pelo microfone, interrupções de hardware, rotas Bluetooth e
  permissões no iPhone físico ainda precisam de teste no aparelho do usuário.
- Reprodução de áudio sintético verificada com AVPlayer: o executor da interface
  continuou atendendo e a preparação encerrou dentro do prazo, sem acessar o
  microfone. A versão inicial com AVAudioPlayer bloqueou o serviço HAL deste Mac;
  foi substituída por início assíncrono com cancelamento e limite de espera.
  Qualidade audível, volume e rotas reais permanecem dependentes de teste físico.
- Build final macOS aprovado e assinatura local verificada com
  `codesign --verify --deep --strict`. Build iPhone arm64 sem assinatura aprovado.
- A última consulta de dispositivos mostrou somente simuladores e zero identidades
  de assinatura. Instalação física e eventual IPA continuam pendentes; não houve
  envio de aplicativo instalável por AirDrop.
