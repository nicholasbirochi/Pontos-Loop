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
