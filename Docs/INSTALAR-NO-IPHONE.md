# Colocar o Pontos Loop no seu iPhone 13

O aplicativo é nativo, compatível com iPhone 13 usando iOS 17 ou mais recente.
O projeto Xcode já está incluído; não precisa instalar XcodeGen para abrir.

1. No Mac, dê dois cliques em **Abrir Pontos Loop.command**, ou abra
   **PontosLoop.xcodeproj** no Xcode.
2. Conecte o iPhone 13 por cabo, desbloqueie e toque em **Confiar** se solicitado.
3. No Xcode, adicione sua Conta Apple em **Settings → Apple Accounts**
   (em algumas versões, **Accounts**).
4. Selecione o projeto azul, o target **PontosLoop-iOS** e
   **Signing & Capabilities**. Mantenha **Automatically manage signing** e
   escolha sua equipe em **Team**. Uma conta pessoal pode aparecer como
   **Personal Team**.
5. Se o Xcode avisar que o identificador já está em uso, altere
   `com.nicholasbirochi.compraclara.ios` para um identificador seu e exclusivo.
6. No seletor de execução, escolha o esquema **PontosLoop-iOS** e seu
   **iPhone 13**. Clique no triângulo **Run** (⌘R).
7. Se solicitado, habilite **Ajustes → Privacidade e Segurança → Modo de
   Desenvolvedor** no iPhone e confirme após reiniciar. Siga os avisos de
   confiança no aparelho.

O app aparece na tela inicial. Com uma equipe pessoal, a assinatura pode exigir
renovação pelo Xcode conforme os limites da Apple. Apagar o app apaga também o
histórico local. O Noah funciona sem internet e não precisa de chave de API.

Um ZIP de código ou um aplicativo de simulador não substitui a assinatura do
aparelho. Esta entrega não inclui uma IPA assinada nem distribuição no TestFlight.

Instruções oficiais consultadas em 13/10/2026:

- [Executar em simuladores e aparelhos](https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices)
- [Assinatura com equipe pessoal](https://help.apple.com/xcode/mac/current/en.lproj/dev60b6fbbc7.html)
- [Habilitar o Modo de Desenvolvedor](https://developer.apple.com/documentation/xcode/enabling-developer-mode-on-a-device)

## Usar fotos de uma oferta

Na aba Simular, toque em **Usar foto ou print**, depois **Escolher fotos**.
Selecione até 4 imagens da oferta, confira preço Pix, total, quantidade e data das
parcelas e toque em **Usar e comparar**. Se algum campo não for reconhecido,
preencha manualmente. A leitura acontece no próprio aparelho; não usa a IA do Mac.

## Nome e dados preservados

O app agora aparece como **Pontos Loop**. Abra **PontosLoop.xcodeproj** e use os
esquemas **PontosLoop-iOS** ou **PontosLoop-macOS**. Os identificadores de bundle e
as chaves de armazenamento anteriores foram mantidos para preservar rascunhos e
histórico na atualização. Use **Nova simulação** para começar com tudo zerado.
O repositório atual é https://github.com/nicholasbirochi/Pontos-Loop.
