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

## Pontos Loop 1.3.1 — mais anexos e atualização pelo Mac (14/10/2026)

- 43 testes Swift aprovados, incluindo comparação com 240 ofertas e rejeição
  acima de 1.000. O limite dos seletores, arquivos e drop passou para 20 anexos.
- Checagem nativa de mídia aprovou 20 anexos, rejeição de 21 e áudio de exatamente
  40 MB versus 40 MB + 1 byte. A leitura por lote é validada antes de acumular mais
  áudio; os limites de arquivo individual e duração continuam preservados.
- Sete testes do atualizador aprovados: históricos Git compatíveis/divergentes,
  documentação sem reconstrução, app aberto preservado, falha de build sem
  avançar versão instalada, pausa após três falhas, diagnóstico privado e agente
  sem leitura do projeto no OneDrive.
- Builds macOS e iPhone arm64 assinado aprovados. Os testes de interface da 1.3
  continuam registrados acima; não foram apresentados como nova execução 1.3.1.
- Instalação pelo atualizador concluída no iPhone 13 físico; consulta do aparelho
  confirmou 1.3.1, build 5. O usuário confirmou selecionar sete prints juntos.
- Agente do Mac registrado com intervalo de 300 segundos; execução real em
  segundo plano terminou com código 0 e estado "Em dia". A leitura do OneDrive
  pelo agente havia falhado; o fluxo automático passou a acompanhar o GitHub.
  Somente o atalho manual lê a main local. As condições e os comandos de parada
  estão em ATUALIZACOES.md. Wi-Fi e renovação após vencer o perfil não testados.

## Pontos Loop 1.3.2 — leitura e revisão automática (16/10/2026)

- 44 testes Swift aprovados, incluindo símbolo de multiplicação nas parcelas
  e rejeição de totais conflitantes em vez de calcular um custo com OCR incorreto.
- Checagem nativa aprovou quatro imagens fictícias regulares e uma com centavos
  elevados (90, 06 e 89), totais deslocados verticalmente e ajuste de centavos.
- Checagem da revisão aprovou banco ambíguo opcional, anúncios excluídos,
  imagens sem valores que não bloqueiam o lote e base 1x comum somente quando única.
- Sete imagens fornecidas pelo usuário foram testadas apenas localmente. As
  54 ofertas dos seis prints de checkout foram conferidas uma a uma, incluindo
  os centavos dos totais. Nenhuma dessas imagens ou seus valores entrou no repo.
- Fluxo completo no Mac: selecionar os sete arquivos no painel nativo, enviar,
  confirmar sem editar campos e receber o resumo correto no chat. A ordem de
  seleção variou; a leitura não dependeu de adivinhar qual print vinha antes.
  O anúncio ficou excluído inicialmente. Cartões ambíguos entraram só pelo preço;
  Pix e antecipação sem preço real foram informados como dados ausentes.
- Builds macOS e iPhone arm64 aprovados. A cópia de teste Mac usou identificador
  separado para preservar rascunho e histórico do aplicativo normal.
- Suíte completa de seis testes de interface aprovada no simulador iPhone 13:
  compositor/anexos, explicação do chat, navegação, histórico após reabrir,
  importação e padrões zerados. Instalação no iPhone físico é verificada à parte.

## Pontos Loop 1.3.3 — contexto entre prints e prévia (16/10/2026)

- Checagem nativa de revisão aprovada: continuação por parcelas compatíveis,
  herança de cartão/base, edição de benefícios compartilhada, separação manual,
  deduplicação por grupo e rejeição de totais contraditórios. Cabeçalhos de cartões
  diferentes permanecem separados mesmo quando os preços são iguais.
- Sete imagens reais verificadas apenas localmente: três grupos de cartões,
  cada um com todas as opções de 1x a 12x, somando 36 planos únicos. O anúncio
  fornece um preço preenchido; confirmar que é Pix acrescenta a 37ª opção.
  Conferidos o ranking, o empate das opções 1x e a quantidade de pontos Prime.
  Fotos, valores reais e identificadores continuam fora do repositório.
- OCR sintético aprovado para abas Itaú/Mercado Livre selecionadas e ambíguas,
  fundo escuro sem sugestão indevida, preço principal com vírgula ou ponto,
  miniaturas, centavos elevados e totais deslocados. Preço anunciado não vira
  automaticamente preço Pix quando a modalidade não está escrita.
- Fluxo completo no Mac: selecionar sete arquivos, enviar, ampliar miniatura,
  voltar, confirmar preço como Pix sem digitar valores e receber o diagnóstico
  com os três cartões e suas continuações corretamente identificados.
- Suíte completa de seis testes de interface aprovada novamente no iPhone 13
  simulado. Os 44 testes do motor já passaram na 1.3.2; seu código não mudou.
- A associação automática usa a ordem das imagens e parcelas compatíveis. Envie
  primeiro o cabeçalho do cartão, depois suas continuações. Layouts sem destaque
  visual legível ainda podem pedir uma confirmação do cartão por grupo.
- Antecipação depende da cotação real do Inter; cashback condicional e valor
  monetário dos pontos não são inventados para completar o ranking.
- Builds finais macOS e iOS Simulator aprovados; build genérico iPhone arm64
  aprovado durante esta validação. Assinatura e instalação física são conferidas
  pelo atualizador do Mac, mantendo o identificador do app e seus dados salvos.
