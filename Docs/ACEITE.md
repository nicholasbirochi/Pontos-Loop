# Critérios de aceite

## Cálculo

- XCTest aprovado no pacote DecisionCore.
- Fixtures independentes coincidem dentro de R$ 0,000001.
- Parcelas somam o total nominal sem perder centavos.
- Rendimento zero, pontos zero, prazos reais e empate funcionam.
- Dados inválidos não produzem recomendação ou NaN.
- Exemplos de CENARIOS.md consistentes.
- Taxa, acúmulo e valor do milheiro editáveis.
- Não há contagem dupla de benefícios.
- Quitação após primeiro vencimento e bônus anterior ao pagamento rejeitados.

## Interface

- iOS/macOS compilam e executam.
- iPhone pequeno/maior, retrato/paisagem e janela estreita/ampla no Mac.
- Dark Mode, Dynamic Type e VoiceOver não escondem informação.
- Entradas como 1000,00, 1.000,00, 0,8 e 2,50 funcionam.
- Erros explicados; histórico persiste; compartilhamento funciona.
- Cenários antigos orientam atualizar datas que já passaram.
- Desembolso e custo econômico claramente separados.

## Entrega

- Identidade e ícone próprios.
- README permite gerar e executar o projeto.
- Assinatura sob conta do usuário; não publicar sem pedido.
- VALIDACAO.md distingue checks executados e pendentes.
- Sem credenciais, conta bancária ou telemetria.
