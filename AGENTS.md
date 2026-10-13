# Instruções do projeto

Projeto local nativo iOS/macOS. Priorize iPhone. Interface em português brasileiro.

- Leia Docs/FORMULAS.md antes de alterar os cálculos.
- DecisionCore não depende de SwiftUI, rede ou persistência.
- Use Decimal para valores nominais; Double para potências e valor presente.
- Não arredonde cada fluxo em valor presente antes de somar.
- Não anuncie rendimento ou conversão de pontos como taxa garantida.
- Não aplique uma conversão universal a todos os resgates.
- Não duplique cashback, pontos ou custo de oportunidade.
- Antecipação conta bônus incremental; pontos já recebidos não são ganhos novos.
- Execute swift test e compile iOS/macOS no Mac.
- Se o ambiente não tiver Swift/Xcode, registre testes pendentes sem simular sucesso.
- Preserve histórico com armazenamento versionado e migrações.
- Não publique, conecte banco ou inclua credenciais sem pedido explícito.
- Não altere assinatura ou configurações globais desnecessariamente.
- Atualize documentação e casos de teste após mudanças relevantes.
