# Fórmulas e convenções

## Tempo e rendimento

Hoje é o dia 0. Dias inteiros são calculados entre inícios de dias locais.
A interface gera vencimentos por mês civil a partir do primeiro; fins de mês
podem ser ajustados pelo calendário. Datas contratuais diferentes precisam
de cronograma personalizado.

r é rendimento líquido efetivo mensal em fração: 0,8% = 0,008.
O desconto usa dias/30, não CDI por dias úteis ou tributação exata por lote.
Se houver entrada anual líquida no futuro: r=(1+taxaAnual)^(1/12)-1.

## Valor presente

VP = soma(fluxo_i / (1+r)^(dias_i/30)).

Pagamentos são positivos e benefícios negativos. Menor custo presente vence.
Diferença de até R$ 0,01 é empate. Some antes de arredondar a apresentação.
O modelo pressupõe dinheiro reservado com liquidez para os pagamentos.
Use r=0 se o dinheiro não ficar investido.
Desconto a valor presente já inclui custo de oportunidade: não acrescente
um segundo ganho de rendimento.

## Compra

Na entrada simplificada, PixHoje é o preço final informado diretamente, validado
com até duas casas decimais. O motor exige valores válidos e não infere descontos.
Para cenários antigos sem preço Pix direto, preserva-se a regra anterior:
PixHoje = arredondarCentavos(precoReferencia*(1-descontoPix/100)).

Na importação de imagem, TotalCartaoSugerido = parcelas × valorPorParcela.
É apenas uma sugestão revisável: totais contratuais e ajustes na última parcela
podem ser diferentes. Nenhuma comparação importada é aplicada sem confirmação.
Cartao = VPparcelas - VPpontos - VPcashbackAdicional.
O total do cartão contém juros e taxas reais, não reaplicados pelo motor.

PontosEstimados = gastoElegivel/gastoPorPonto.
ValorPontos = pontosEstimados*valorMilheiro/1000.
RetornoNominalPercentual = 100*valorMilheiro/(1000*gastoPorPonto).
Para 20 e 2,50, o retorno derivado é 0,8% nesse resgate específico.

A estimativa de pontos é contínua, sem reproduzir arredondamento ou teto do banco.
Benefícios entram em uma única data escolhida. Crédito por fatura será uma expansão.

DescontoEquilibrioPercentual = 100*(1-VPcartao/precoReferencia).
Desconto maior favorece Pix; menor favorece cartão.
Equilíbrio negativo indica cartão mais caro mesmo sem desconto.
Acima de 100% não há desconto viável nessa faixa que supere o benefício estimado.
Não truncar o número e criar um ponto de equilíbrio inexistente.

## Centavos

ParcelaRegular=arredondarCentavos(total/n).
UltimaParcela=total-ParcelaRegular*(n-1).
A soma é exatamente o total. Rejeite valor tão pequeno que torne a última
parcela negativa. Cronograma real diferente precisa de fluxos explícitos.

## Antecipação

Manter = VPpagamentosRestantes.
Antecipar = VPofertaQuitacao - VPbonusIncremental.

Pontos já recebidos/idênticos entre alternativas não são ganhos novos.
A oferta vem do banco; não inferir desconto ou taxa universal de bonificação.
Use a data de saída efetiva do dinheiro, não a data da solicitação.

BonusMinimoVP=max(0,VPquitacaoSemBonus-VPmanter).
BonusMinimoNaData=BonusMinimoVP*(1+r)^(diasBonus/30).
PontosMinimos=teto(BonusMinimoNaData*1000/valorMilheiro), se milheiro>0.

Fatura única é um pagamento futuro. A base não modela automaticamente a
diferença de prazo dos mesmos pontos normais ao pagar antes; conta apenas bônus
incremental. O prompt de expansão inclui benefícios comuns em datas distintas.

## Resgate na fatura

Guardar = VPfaturaIntegral.
Usar = VPfaturaReduzida + CustoPontosHoje.
CustoPontosHoje = pontosGastos*valorAlternativoMilheiroHoje/1000.
ValorMilheiroResgate = descontoOferecido*1000/pontosGastos.

O valor alternativo deve ser líquido, realista e viável para o usuário.
Se o uso alternativo só ocorrer no futuro, informe seu valor presente.
Não subtraia o desconto duas vezes: a fatura já foi reduzida.
Benefício econômico em pontos não equivale a saldo disponível na conta.

## Precisão e limites

Decimal para valores nominais; Double para potências e VP.
Até 120 pagamentos e 36.600 dias no motor; 36 parcelas na interface inicial.
Taxa finita maior que -100% e até 100% a.m. é limite matemático, não recomendação.
Taxa negativa é permitida como hipótese.
IR, IOF, custos e risco não são calculados automaticamente.
Use rendimento líquido ou inclua os custos nos fluxos.

## Diagnóstico dos quatro cenários — Pontos Loop 1.2

Para a mesma compra elegível: PontosNormais = ValorCompraSemJuros / 2,50.
CustoSemJuros = VPparcelasSemJuros − VPpontosNormais.
CustoComJuros = VPparcelasComJuros − VPpontosNormais; juros não ampliam a base de pontos.
CustoPix = PrecoFinalPixHoje, sem os pontos de compra no cartão.
CustoAntecipar = VPquitacao − VPpontosNormais − VPbonusEXTRA.
Os pontos normais aparecem UMA vez em cada alternativa elegível de cartão.
Os prazos dos pontos normais e dos pontos após antecipar são informados pelo usuário.

Zero em preços/quantidade significa oferta ausente e nunca uma alternativa grátis.
É preciso pelo menos duas ofertas válidas para recomendar; o diagnóstico continua
mostrando as quatro posições com os dados faltantes. Empates até um centavo são
apresentados como empate, inclusive quando há mais de duas alternativas.
Milheiro zero permite mostrar quantidade de pontos, mas seu benefício em reais
fica zero e isso é avisado. Não há conversão universal ou rendimento predefinido.
O diagnóstico presume compra elegível e cumprimento das condições do Inter Loop.
Para pagamentos já contratados sem alternativa Pix real, use o modo Antecipar;
não compare uma dívida existente com uma oferta que não está disponível.
