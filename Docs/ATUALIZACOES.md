# Atualizações gratuitas pelo Mac

O app iOS é compilado e assinado. Um commit no GitHub não substitui diretamente
seu aplicativo instalado. Com a Conta Apple pessoal, o Mac pode fazer essa etapa
usando o Xcode e o iPhone já pareado, sem contratar o Apple Developer Program.

## Funcionamento

- O atualizador verifica a cada **5 minutos**, enquanto sua sessão do Mac estiver
  ligada. Compara os commits da **main** local e da main do repositório público.
- Usa o histórico que estiver à frente, desde que um seja continuação do outro.
  Se divergirem, aguarda correção do Git. **Arquivos apenas salvos, sem commit,
  não são publicados nem instalados automaticamente.**
- Mudanças somente em documentação não recompilam o app. Se XcodeGen estiver
  instalado ao configurar, ele regenera o projeto na cópia de compilação.
- Compila numa cópia separada, assina com a equipe já configurada e instala no
  iPhone. Não altera a pasta de trabalho nem faz push de código ou dados.
- Precisa do Xcode, conexão com GitHub/Apple, iPhone disponível por cabo ou por
  Wi-Fi com pareamento e rede compatíveis, Modo de Desenvolvedor e confiança
  autorizados. Após reiniciar o aparelho, desbloqueie-o.
- Aguarda o processo do Pontos Loop ser encerrado. Para aplicar uma atualização,
  feche-o no seletor de apps do iPhone. Isso evita substituir o app durante uma
  conversa/gravação. Ele não abre o aplicativo automaticamente.
- Falha de compilação/instalação mantém a versão anterior. Após três falhas do
  mesmo commit, para de compilar até um commit novo ou uma tentativa pelo atalho.
- Com a equipe pessoal, a assinatura tem validade limitada. O atualizador tenta
  recompilar quando o prazo registrado vencer; depende da disponibilidade do
  aparelho e da conta Apple. Não garante instalação permanente sem renovação.

## Configurar neste Mac

Selecione sua equipe no target iOS do Xcode. Obtenha o UDID do aparelho em
`xcrun devicectl list devices` e execute, na pasta do projeto:

```sh
python3 Scripts/update_iphone.py --setup --project /caminho/do/projeto --device UDID_DO_SEU_IPHONE
```

A configuração e o identificador do aparelho ficam somente em
`~/Library/Application Support/Pontos Loop/Atualizador`, com acesso restrito.
O agente de usuário é `~/Library/LaunchAgents/com.nicholasbirochi.pontosloop.updater.plist`.
Certificados permanecem nas Chaves do Mac; não entram no GitHub.

Para tentar agora, abra **Atualizar Pontos Loop.command**. O atalho também respeita
app aberto/aparelho indisponível. Para consultar o último resultado:

```sh
python3 Scripts/update_iphone.py --status
```

Para desligar a verificação automática, preservando os arquivos locais:

```sh
python3 Scripts/update_iphone.py --stop
```

Para reativar, execute novamente a configuração. Não há runner do GitHub, API
paga, publicação no TestFlight ou sincronização de faturas/conversas.

## TestFlight e App Store

São os caminhos de distribuição Apple para atualizações sem o Mac do usuário,
mas exigem preparar a distribuição e ter uma assinatura do programa aplicável.
Nenhuma contratação foi feita para este projeto. Referências consultadas em 14/10/2026:

- [Conta pessoal e limites](https://developer.apple.com/help/account/basics/about-your-developer-account)
- [Executar no aparelho](https://developer.apple.com/documentation/xcode/running-your-app-on-simulated-or-physical-devices)
- [Dispositivos e conexão Wi-Fi](https://developer.apple.com/documentation/xcode/managing-your-simulated-and-physical-devices-in-device-hub)
- [Apple Developer Program](https://developer.apple.com/help/account/membership/program-enrollment/)
