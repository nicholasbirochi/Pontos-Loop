# Prompt completo para o Codex

Quero desenvolver o Compra Clara, um aplicativo nativo bonito, visual, rápido e
simples para meu iPhone e também meu MacBook. Continue o projeto desta pasta,
que já contém uma base SwiftUI e o motor DecisionCore. Priorize iPhone.
Entregue código que eu possa compilar no Xcode e executar nos meus dispositivos.

Leia AGENTS.md, README.md, Docs/FORMULAS.md, Docs/CENARIOS.md, Docs/ACEITE.md,
Docs/VALIDACAO.md e project.yml antes de modificar. Inspecione a implementação.
Não substitua este projeto por um site, PWA ou backend.

## Objetivo e experiência

Responder: vale mais a pena pagar no Pix, usar cartão em uma ou várias parcelas,
antecipar parcelas/fatura ou usar pontos para abater a fatura?
Considere preços, datas, descontos, total cobrado, rendimento líquido e benefícios.

Mostre a opção com menor custo econômico, a diferença em reais e os desembolsos
nominais. Na compra, mostre desconto de equilíbrio. Na antecipação, mostre bônus
mínimo para cobrir o rendimento perdido. No resgate, mostre valor por 1.000 pontos
e custo de abrir mão de outro uso. Explique em uma ou duas frases claras.

## Tecnologia

- SwiftUI, iOS 17+ e macOS 14+.
- DecisionCore puro, como pacote Swift local.
- Charts com alternativa textual acessível.
- Targets separados com views e motor compartilhados.
- XcodeGen, conservando project.yml como fonte.
- Persistência local versionada, sem login, rede ou conta bancária.
- Evite dependências que os frameworks nativos já resolvam.

## Execute o trabalho

1. Verifique o ambiente e gere o projeto.
2. Execute swift test em Packages/DecisionCore. Corrija falhas reais.
3. Compile ambos os targets e corrija APIs específicas de plataforma.
4. Confirme equivalência com os fixtures independentes e os exemplos.
5. Revise parser brasileiro, datas, centavos e tratamento de entrada inválida.
6. Execute no simulador de iPhone e em macOS.
7. Refine o visual conforme Design/Referencia.svg e o prompt visual.
8. Acrescente ícone e metadados próprios, sem logotipo do banco.
9. Confira salvar, reabrir, apagar e compartilhar cenários.
10. Verifique acessibilidade, fontes grandes, claro/escuro e tela pequena.
11. Atualize Docs/VALIDACAO.md apenas com resultados realmente executados.
12. Entregue instruções para executar no Mac e instalar no meu iPhone.

Se faltar Xcode, conclua o possível e informe a compilação pendente.
Não invente teste aprovado, credencial, equipe de assinatura ou taxa atual.

## Cenários mínimos

Compra:
- Pix com desconto e preço de referência.
- Cartão 1x ou parcelado com total informado, incluindo juros e taxas.
- Rendimento líquido zero ou configurável.
- Pontos opcionais: base elegível, gasto por ponto e valor do milheiro.
- Cashback adicional apenas se confirmado e acumulável.
- Primeiro vencimento real e data de disponibilidade do benefício.
- Quantidade variável e atalhos 1x, 3x, 6x, 10x e 12x.
- Preço no cartão pode diferir do preço de referência.

Antecipação:
- Saldo restante, vencimentos futuros e oferta de quitação.
- Data de pagamento efetivo, podendo diferir da solicitação.
- Pontos extras reais oferecidos, inclusive zero.
- Pontos antigos ou idênticos entre as alternativas não são bônus.
- Fatura única corresponde a uma parcela.

Resgate:
- Pontos gastos e desconto oferecido na fatura.
- Valor líquido de outro uso efetivamente viável.
- Prazo do abatimento respeitado no valor presente.
- Pontos gastos têm custo econômico; não são dinheiro gratuito.

## Regras financeiras

Use VP = soma(fluxo / (1+r)^(dias/30)), conforme Docs/FORMULAS.md.
Compare todos os custos e benefícios na mesma data-base.
Não use rendimento simples sobre o total e não duplique ganho de aplicação
com desconto a valor presente.
Respeite centavos, datas mensais e dados cotados pelo estabelecimento.
Não calcule IR/IOF novamente se o rendimento informado já for líquido.

O preset Prime é referência editável: R$ 2,50 por ponto e R$ 20 por milheiro
no Inter Shop. Não anuncie como cashback universal de 0,8%.
O rendimento de 0,8% a.m. é exemplo. Ofertas de antecipação e fatura vêm do usuário.
Mostre fonte e possibilidade de modificar a conversão.

## Visual

Nome: Compra Clara. Português brasileiro. Valores em reais e dígitos monoespaçados.
Fundo limpo, azul/índigo, cartões com cantos arredondados e contraste adequado.
Resultado principal destacado. Campos em grupos curtos, detalhes recolhíveis,
retorno imediato com dados válidos. Sem emojis ou textos promocionais.
Respeite Dark Mode, Dynamic Type, VoiceOver e redução de movimento.
No Mac, suporte teclado e duas colunas quando houver espaço.

## Conclusão

Valide conforme Docs/ACEITE.md. Informe testes executados e limitações reais.
Não publique na App Store, conecte banco ou faça pagamentos.
Mantenha a expansão avançada separada da primeira versão validada.
