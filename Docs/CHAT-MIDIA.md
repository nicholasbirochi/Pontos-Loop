# Noah: texto, áudio e arquivos

Na aba **Noah**, escreva uma pergunta ou use os controles na área de mensagem:

- **Fotos / +**: selecione até **20 prints na mesma mensagem**. No Mac, também
  pode arrastar imagens ou arquivos para o chat.
- **Arquivo**: imagem, PDF com texto selecionável, TXT ou arquivo de áudio.
- **Microfone**: grave até 1 minuto. **Concluir** termina e tenta transcrever;
  **Cancelar** descarta a gravação. Sair da aba também interrompe.
- **Seta para cima**: envia a mensagem e os anexos.

Os anexos aparecem em cartões. Áudios têm reprodução e transcrição editável antes
de enviar. Confira o texto, especialmente números. Se a transcrição falhar ou a
permissão não estiver disponível, o áudio permanece disponível para reprodução;
escreva a pergunta junto. O Noah informa que não conseguiu interpretar o áudio.

## Comparar prints de uma compra

1. Anexe os prints na ordem: tela inicial de cada cartão, depois as telas que
   continuam suas parcelas. O seletor de fotos mostra a ordem escolhida; arquivos
   da mesma sequência numerada (como IMG_1, IMG_2) são ordenados pelo nome.
2. Em **Conferir ofertas**, cada print tem miniatura: toque para ampliar. As
   continuações compatíveis herdam o cartão e os benefícios do primeiro print;
   parcelas repetidas entram uma única vez. Uma aba clara selecionada pode
   identificar Itaú ou Mercado Livre, mesmo com os dois nomes no cabeçalho.
   Quando o destaque não é legível, confirme o cartão uma vez para todo o grupo.
3. O preço principal do anúncio aparece preenchido quando é legível e tem destaque
   único. Toque em **Confirmar este preço como Pix** se ele também for o preço final
   dessa modalidade; o ícone do Pix sozinho não confirma preço nem desconto.
   O parcelamento do anúncio não substitui a oferta final do checkout.
   Abra um print para corrigir valores, escolher outro cartão ou separar uma
   continuação associada incorretamente. Totais contraditórios no mesmo grupo
   bloqueiam o ranking até serem corrigidos. Prints sem valores ficam excluídos.
4. Para Inter Prime, confira a base elegível sem juros, preenchida pelo preço 1x
   do print ou por um preço 1x único comum às imagens da mesma compra. Os pontos normais entram
   mesmo sem antecipar, uma vez por alternativa. Para outros cartões, informe
   somente benefícios confirmados em reais. Cashback anunciado como “até” não
   entra automaticamente.
5. Se quiser antecipar, copie a **oferta real de quitação do Inter**, escolha o
   print correspondente e informe somente o bônus extra e cashback que permanece.
   O app não deduz a quitação pelos prints da loja.
6. Opcionalmente ajuste datas, rendimento líquido e valor real do milheiro no seu
   resgate. Rendimento e valor dos pontos começam em zero.
7. O Noah informa o menor custo, a próxima faixa de custo, até cinco ofertas
   mais baratas, os empates e os dados faltantes. Pix e antecipação precisam de
   seus preços reais; ele não inventa valores para completar o diagnóstico.

O botão **Conferir e comparar estas ofertas** na mensagem permite revisar de novo.
O diagnóstico fica na conversa; ele não altera a simulação da aba Simular nem o
histórico salvo. Compare ofertas da mesma compra e considere apenas os benefícios
compatíveis entre si. Sem valor do milheiro, pontos ainda não reduzem custo em reais.

## Limites e privacidade

- Até 20 anexos por mensagem, **20 MB por arquivo**. Áudio de até **60 segundos**, somando no máximo **40 MB de áudio por mensagem**.
- Imagens usam Apple Vision, incluindo uma segunda leitura dos centavos elevados.
  Valores ilegíveis e totais incompatíveis exigem revisão. PDFs precisam de texto selecionável: são lidas
  até 20 páginas e 30 mil caracteres; o cartão avisa quando houver corte.
  Para PDF escaneado, mande um print das páginas com a oferta.
- Voz usa o reconhecimento nativo da Apple, com disponibilidade local `pt_BR`
  verificada e `requiresOnDeviceRecognition = true`. Não há fallback para servidor.
  Permissões, transcrição e início da reprodução têm espera limitada.
- Microfone e reconhecimento de fala são permissões separadas, solicitadas no uso.
  O aviso padrão do sistema sobre reconhecimento pode mencionar os serviços da
  Apple; este app exige processamento no aparelho antes de iniciar a transcrição.
- No Mac, confira **Ajustes do Sistema → Privacidade e Segurança → Microfone /
  Reconhecimento de Fala**. No iPhone, confira as permissões correspondentes em
  Ajustes. A disponibilidade depende do aparelho e dos recursos locais da Apple.
- Conversa, miniaturas, texto extraído e áudio ficam em memória na sessão. Gravações
  temporárias são apagadas após carregar ou descartar; a reprodução cria uma cópia
  temporária removida ao parar. Não entram no histórico, no GitHub nem em serviços
  de IA. A conversa guarda até 100 mensagens e 40 MB de áudio; mensagens mais
  antigas saem ao atingir o limite.
- **Nova conversa** limpa o chat. As simulações salvas continuam no dispositivo.

O Noah permanece um assistente por regras sobre a calculadora, sem LLM ou
integração com a IA do Mac. Não analisa documentos de maneira geral, não importa
uma fatura inteira como orçamento e não realiza operações bancárias.
O projeto Noah unificado continua como demanda futura.

Referências Apple consultadas em 13/10/2026:

- [Reconhecimento no aparelho](https://developer.apple.com/documentation/speech/sfspeechrecognitionrequest/requiresondevicerecognition)
- [Disponibilidade local](https://developer.apple.com/documentation/speech/sfspeechrecognizer/supportsondevicerecognition)
- [Autorização de fala](https://developer.apple.com/documentation/speech/asking-permission-to-use-speech-recognition)
- [Permissão de entrada de áudio no Mac](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.device.audio-input)
