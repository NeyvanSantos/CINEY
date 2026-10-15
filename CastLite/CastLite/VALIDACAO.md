# Validação do MVP — 12/10/2026

## Build e testes

Com JDK 17 e Android SDK 35 neste PC:

```text
.\gradlew.bat assembleDebug testDebugUnitTest lintDebug
BUILD SUCCESSFUL in 42s
52 actionable tasks: 25 executed, 27 up-to-date
```

- 15 testes JVM passaram: 6 de endereço/pesquisa, 6 de detecção/MIME e 3 de catálogo por navegação.
- Lint: zero erros, 9 avisos (targetSdk 35 exigido pelo escopo, versões mais novas de dependências, estilo de botões e falso positivo de ortografia em português).
- Gradle Wrapper completo e JAR comparado ao SHA-256 oficial de Gradle 8.9.
- Distribuição Gradle com `distributionSha256Sum` no Wrapper.
- Assinatura do APK de depuração validada por `apksigner verify --verbose` (v2).
- Erros iniciais de compilação foram corrigidos antes do build final.

APK: `app/build/outputs/apk/debug/app-debug.apk`

SHA-256:

```text
475A4FFC4B7989F9FF93EB8C85420233963BE10ADD5F3DDF1F1EFCB01C6B34A7
```

## Celular real

Aparelho identificado pelo ADB como modelo **2312DRA50G**, Android **13**.

- Instalação de depuração: **Success**, após aceitar a instalação no aparelho.
- Abertura de `com.example.castlite/.MainActivity`: **Status: ok**, cold start informado pelo Android de 1390 ms.
- Google carregou na WebView; barra de endereço, Ir, Voltar, Recarregar, botão de Cast e contador foram vistos na captura e árvore de acessibilidade.
- Cast terminou a inicialização e exibiu o estado desconectado.
- Captura: `artifacts/launch.png`; árvore: `artifacts/launch.xml`.
- O trecho de log coletado não contém `FATAL EXCEPTION` nem `AndroidRuntime`; contém mensagens de componentes MIUI, sem encerramento observado do app.

## Limites desta validação

O Android recusou os toques automáticos do ADB com `INJECT_EVENTS`. A página de teste controlada não chegou a ser aberta pelo agente no celular. A autorização de **Depuração USB (Configurações de segurança)** foi solicitada ao usuário; nenhum ajuste de segurança foi feito pelo agente.

Ainda precisam de teste físico/manual:

- detecção real por requisições e DOM, atualização da lista, pesquisa, voltar e recarregar;
- seleção de Chromecast, reprodução na TV e controles remotos;
- Android sem Google Play Services;
- insets e comportamento em Android 15/targetSdk 35 (o celular disponível usa Android 13).

Os testes JVM validam a lógica de formatos, URLs e catálogo, não substituem esses testes de WebView/Cast.

Na validação inicial, a próxima etapa (proxy) ainda estava pendente da confirmação do funcionamento do MVP; o reteste e a implementação subsequentes estão registrados abaixo.

Nova tentativa após o usuário informar que estava pronto: aparelho conectado e app aberto, mas o primeiro toque via ADB continuou recusado por INJECT_EVENTS. Os testes interativos continuam pendentes. O servidor de teste e o encaminhamento USB foram encerrados.

Diagnóstico posterior: o usuário confirma que a opção está ativa. A permissão Android `INJECT_EVENTS` consta como `granted=true` para `com.android.shell`, mas a propriedade MIUI `persist.security.adbinput` retorna `0`; `persist.security.adbinstall` retorna `1`. O usuário Android atual é 0. Reconectar o transporte ADB e testar novamente não resolveu. Isso não comprova o estado visual da opção nem a causa da divergência. A documentação oficial do scrcpy recomenda reiniciar o aparelho após habilitar a opção de segurança em Xiaomi: https://github.com/Genymobile/scrcpy#prerequisites . Próximo passo manual: reiniciar, desbloquear e reconectar o aparelho; nenhum reboot foi executado pelo agente.

Nova verificação: a tela das Opções do desenvolvedor foi lida diretamente. Depuração USB, Instalar via USB e Depuração USB (Config. de segurança) estão marcadas como ativas; `persist.security.adbinput` agora retorna `1`. Apesar disso, o toque pelo ADB retornou 255/INJECT_EVENTS antes e após reconectar o transporte. Log do InputManager confirma a recusa para uid 2000. A configuração visual está confirmada; não há evidência de que o celular tenha sido reiniciado após essa mudança para 1. Evidência da tela em `artifacts/developer-settings.xml`.

## Reteste do Cast e correção do relay — 12/10/2026

- Implementado relay HTTP temporário no celular para o receiver obter a mídia através da rede local. O relay busca cookies no CookieManager, repassa User-Agent, Referer, Origin, Authorization e Range; reescreve URLs de segmentos e chaves em playlists HLS.
- O aviso foi ajustado: aceitação da solicitação pelo receiver não é mais apresentada como confirmação de reprodução; após 10 s sem estado ativo, o app informa que o vídeo não iniciou.
- Build final `assembleDebug testDebugUnitTest lintDebug --offline`: **BUILD SUCCESSFUL in 34s**, 52 tarefas (23 executadas, 29 em cache). Os 16 testes JVM passaram (0 falhas); lint terminou sem falha.
- APK corrigido instalado no 2312DRA50G (Android 13) por `adb install -r`: **Success**. O app abriu sem falha fatal observada.
- Teste real repetido no APK final instalado, no receiver **tv ney**, com `https://media.w3.org/2010/05/sintel/trailer.mp4`: após o envio via relay, o CastLite exibiu **PAUSAR** e **PARAR** habilitados, indicando estado remoto em reprodução.
- Um teste alternativo com a URL do Big Buck Bunny no Google Cloud Storage retornou `AccessDenied` para chamada anônima; essa URL não foi usada como evidência de falha do Cast.
- O relay ainda depende de celular e TV na mesma rede local. DRM, codec não aceito, DASH com segmentos que dependam de cabeçalhos e fontes inacessíveis continuam fora do que esta correção resolve.

SHA-256 do APK final: `D2704F80B9409539474AE59FF7DC3B566B2AD365F82F46A036DF45E9A08EA630`.
