# CastLite — MVP Android nativo

Navegador Kotlin com WebView, detecção de vídeos e Google Cast (Default Media Receiver).
O projeto existente foi continuado nesta pasta. Abra **esta pasta**, que contém `settings.gradle.kts`, no Android Studio.

## Executar no Android Studio

1. Use **File > Open** e selecione `G:\WebNeyCast\CastLite\CastLite`.
2. Aguarde a sincronização do Gradle. Os arquivos `gradlew`, `gradlew.bat` e `gradle/wrapper/gradle-wrapper.jar` estão incluídos.
3. Em **Settings > Build, Execution, Deployment > Build Tools > Gradle > Gradle JDK**, escolha um **JDK 17**. Neste PC existe `C:\Program Files\Microsoft\jdk-17.0.18.8-hotspot`. Java 26 não é compatível com este Gradle.
4. Conecte o celular por USB, desbloqueie a tela e aceite a autorização de depuração. Em celulares Xiaomi/MIUI, habilite também **Instalar via USB** e aceite o aviso de instalação.
5. Selecione o celular e clique em **Run**. Para transmitir, celular e Chromecast precisam estar na mesma rede Wi-Fi.

O SDK 35 já está instalado neste PC. Em outro PC, instale **Android SDK Platform 35** pelo SDK Manager e deixe o Android Studio gerar `local.properties`.

## Compilar pelo terminal

No PowerShell, dentro da pasta do projeto:

```powershell
$env:JAVA_HOME = 'C:\Program Files\Microsoft\jdk-17.0.18.8-hotspot'
.\gradlew.bat assembleDebug testDebugUnitTest lintDebug
```

No Linux/macOS, com JDK 17 e SDK Android configurados:

```sh
chmod +x gradlew
./gradlew assembleDebug testDebugUnitTest lintDebug
```

APK: `app/build/outputs/apk/debug/app-debug.apk`.
Relatórios: `app/build/reports/tests/testDebugUnitTest/index.html` e `app/build/reports/lint-results-debug.html`.
A primeira execução precisa de internet para obter as dependências. O Wrapper verifica o SHA-256 da distribuição Gradle.

Se houver falha no seu PC, envie o trecho a partir de **What went wrong**, ou o log gerado por:

```powershell
.\gradlew.bat assembleDebug --stacktrace *> build-error.log
```

## Usar e validar o MVP

1. Digite um endereço ou uma pesquisa e toque em **Ir**. A toolbar possui **Voltar**, **Cast** e **Recarregar**; o botão Voltar do Android também navega no histórico.
2. Abra uma página com vídeo e, se necessário, dê play para que ela solicite a mídia.
3. Toque no ícone **Cast**, escolha o Chromecast e aguarde o nome do dispositivo aparecer.
4. Toque em **Vídeos detectados (N)** e escolha o vídeo. Após o receiver aceitar o carregamento, o vídeo no documento do celular é pausado.
5. Use **Reproduzir/Pausar** e **Parar** na barra inferior. O estado do botão acompanha o player remoto; Parar encerra a mídia e mantém a conexão com a TV.
6. Navegue para outra página: a lista é limpa. Recarregue e use Voltar para conferir a navegação.

Teste com um vídeo público sem autenticação, por exemplo [Sintel, trailer público hospedado pelo W3C](https://media.w3.org/2010/05/sintel/trailer.mp4).
O teste de Cast deve ser feito em **celular real**, na mesma rede Wi-Fi do Chromecast; não use emulador para validar transmissão.

## O que está implementado

- Kotlin, minSdk 24, compileSdk/targetSdk 35, ViewBinding e Gradle Kotlin DSL.
- AGP 8.7.3, Kotlin 2.0.21, Gradle 8.9, JDK 17.
- WebView com endereço/pesquisa Google, progresso, voltar e recarregar.
- `shouldInterceptRequest` identifica MP4, HLS (`.m3u8`), DASH (`.mpd`) e WebM pelo caminho da URL, sem alterar requisições.
- `evaluateJavascript` varre `<video>` e `<source>` no fim do carregamento e ao abrir a lista, incluindo fontes dinâmicas. MIME declarado permite reconhecer endpoints sem extensão.
- URLs HTTP(S) são mantidas integralmente, incluindo assinaturas. Duplicatas e `blob:` são ignorados; formatos desconhecidos não recebem MIME MP4 por suposição.
- Lista por navegação, incluindo mudanças de rota de SPA. Callbacks já pendentes da navegação anterior são descartados.
- `MediaRouteActionProvider`, `MediaLoadRequestData`, MIME por formato e controles via `RemoteMediaClient`.
- Relay HTTP temporário no celular para a TV buscar a mídia na mesma rede local, com cookies da WebView, User-Agent, Referer, Origin, autorização capturada em memória e requisições Range; playlists HLS têm as referências de segmentos/chaves reescritas pelo relay.
- A interface diferencia o pedido de carregamento aceito pelo receiver da reprodução remota confirmada e alerta quando o player permanece sem mídia.
- Inicialização assíncrona do Cast e verificação de Google Play Services. Se indisponível, o ícone Cast fica oculto, aparece uma explicação e o navegador continua disponível.
- Serviço de transmissão em primeiro plano com notificação de mídia (reproduzir/pausar, voltar e parar), preservando o relay e o navegador de origem ao fechar as telas.
- Modo **Economizar rede**, ligado por padrão, limita variantes HLS a 720p/3 Mb/s quando disponíveis; pode ser desativado no menu para a próxima transmissão. Não recomprime arquivos de qualidade única.
- 16 testes JVM para detecção, pesquisas, URLs assinadas, deduplicação, atualização de contexto da fonte e troca de página.

## Limitações do MVP

- **Sem DRM**, descriptografia ou contorno de proteções.
- O relay requer celular e Chromecast na mesma rede Wi-Fi privada; sem endereço LAN disponível o app tenta a URL direta. Ele não contorna links expirados, login não acessível à WebView ou bloqueios de origem.
- Detectar uma extensão não garante que codec, manifesto ou origem sejam aceitos pelo receiver. HLS usa o relay para as referências do manifesto; DASH e codecs não suportados ainda podem falhar.
- A varredura de DOM cobre o documento principal; requisições dos frames também podem ser detectadas, mas não há acesso forçado ao DOM de iframes de outra origem.
- Players com `blob:` podem expor uma URL HTTP(S) de manifesto pela rede, mas o blob em si é ignorado. Páginas sem URL de mídia reconhecível não aparecem na lista.
- Não há transcodificação, suporte especial a lives, DLNA ou Roku.
- Aparelhos sem Google Play Services não transmitem por Google Cast. A abertura nessa condição ainda requer validação em um aparelho desse tipo.

## Teste controlado da detecção (opcional, no PC)

A pasta `manual-tests` contém páginas HTML de teste. Os links locais de mídia são fictícios: servem para conferir a detecção, não a reprodução.

```powershell
python -m http.server 8765 --bind 127.0.0.1 --directory manual-tests
```

Em outro terminal, com ADB disponível:

```powershell
adb reverse tcp:8765 tcp:8765
```

No CastLite, abra `http://127.0.0.1:8765/index.html`:

- Ao abrir: **1** vídeo, mesmo com fontes MP4 repetidas e um blob.
- Toque em **Detectar pela rede**: **4** vídeos (MP4, HLS, DASH e WebM).
- Toque em **Adicionar fonte dinâmica**, depois em **Vídeos detectados**: **5** vídeos.
- Abra **página sem vídeos**: **0** vídeos. Voltar e Recarregar devem manter a contagem coerente.

Ao terminar, encerre o servidor com Ctrl+C e execute `adb reverse --remove tcp:8765`.
Este servidor existe somente para testar HTML via USB no desenvolvimento; ele não faz parte do app nem implementa o proxy da próxima etapa.

## Organização

- `MainActivity.kt`: navegador, ciclo de vida, detecção WebView e comandos Cast.
- `VideoDetector.kt`: validação de URL, formatos e MIME.
- `BrowserAddress.kt`: URL ou pesquisa.
- `VideoCatalog.kt`: deduplicação e identidade da navegação.
- `CastOptionsProvider.kt`: configuração do Default Media Receiver.
- `SimpleSessionListener.kt`: conexão e falhas de sessão Cast.
- `app/src/test`: testes locais, sem precisar de celular.
- `VALIDACAO.md`: evidência de build e limites do teste físico.

## Etapas futuras — somente após confirmação da anterior

1. Proxy HTTP local com headers/cookies da página.
2. DLNA/UPnP com jUPnP.
3. Roku por ECP.
4. Favoritos e histórico com Room.
5. Vídeos locais do celular.
6. Notificação de mídia implementada; validação física em segundo plano pendente, conforme [roteiro de teste](manual-tests/transmissao-segundo-plano.md).

Referências oficiais: [integração Android Cast](https://developers.google.com/cast/docs/android_sender/integrate), [inicialização assíncrona](https://developers.google.com/android/reference/com/google/android/gms/cast/framework/CastContext), [opções de notificação](https://developers.google.com/android/reference/com/google/android/gms/cast/framework/media/CastMediaOptions.Builder), [compatibilidade AGP 8.7](https://developer.android.com/build/releases/agp-8-7-0-release-notes).
