# Prompt de expansão

Continue a partir da base compilada e testada de Compra Clara.
Leia AGENTS.md e Docs/FORMULAS.md. Implemente em etapas, com testes relevantes.

1. Múltiplas ofertas reais para o mesmo produto, cada qual com preço, frete,
   entrada, parcelas, taxas já incluídas, benefícios e datas próprias.
   Não presuma preço idêntico em 1x e 12x.
2. Editor de fluxos personalizados: valores e vencimentos por parcela,
   antecipação parcial, cronogramas irregulares e benefícios em datas distintas.
   Use DecisionCore.option e presentValue. O cronograma real é a autoridade.
3. Modo estimado de juros PRICE, separado do total cotado: para pagamentos em
   30, 60, ..., n*30 dias, A=principal*j/(1-(1+j)^(-n)); j=0 usa principal/n.
   Defina entrada, taxas e ajuste de centavos. Não reaplique juros ao total
   cotado e não chame uma taxa de CET sem modelar todos os fluxos.
4. Pontos por fatura: regras configuráveis de elegibilidade, arredondamento,
   prazo e teto. Entrada direta de pontos. Na fatura antecipada, os mesmos pontos
   recebidos antes têm diferença de prazo, não representam pontos novos.
   Modele o benefício nas respectivas datas de cada alternativa.
5. Perfis de resgate/milhas com valor do milheiro, fonte e data. Use valor
   líquido pessoal após taxas, disponibilidade e custos. Não apresente um valor
   genérico de milha como preço de venda garantido. Considere saldo e mínimo.
6. Análise opcional de saldo reservado e obrigações mensais. Menor custo
   econômico não implica capacidade de pagar. Não presuma dinheiro não informado.
7. Sensibilidade a rendimento, valor dos pontos e quantidade de parcelas,
   com gráficos determinísticos e alternativa textual.
8. Exportação/importação JSON versionada, validação e confirmação antes de
   substituir dados. iCloud opcional com entitlements corretos e funcionamento
   local preservado. Não prometa sincronização sem testar em dois dispositivos.

Atualize testes, documentação e critérios de aceite em cada etapa.
Evite scraping, credenciais bancárias e execução de pagamentos.
