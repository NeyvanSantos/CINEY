# Diagnóstico do fechamento relatado ao abrir Thor: Ragnarok

Investigação em 01/11/2026, somente coleta e análise; nenhum código, APK,
configuração da TV ou serviço remoto foi alterado. A versão instalada é a
oficial TV 1.0.48, build 50, pacote `com.ciney.tv`, na TCL C06, Android 11,
ABI ARM de 32 bits.

## Conclusão comprovada

O último fechamento do processo principal foi um crash nativo no caminho de
saída de áudio do ExoPlayer/Android. O histórico de saída registra
`reason=5 (APP CRASH(NATIVE))`, `status=11`, PID 32248, em primeiro plano.
O buffer de crash registra `SIGSEGV / SEGV_MAPERR` na thread
`ExoPlayer:Playb`, endereço inválido `0x5a522c40`.

Pilha relevante:

```
libc.so: __memcpy_base_a55
libaudioclient.so: android::AudioTrack::write
libandroid_runtime.so: writeToTrack<signed char>
libandroid_runtime.so: android_media_AudioTrack_write_native_bytes
android.media.AudioTrack.write
```

Isso localiza a falha imediata na cópia/escrita de áudio nativa. Não identifica,
sozinho, quem invalidou o buffer ou se há um defeito de firmware, da biblioteca
ou da integração. Não é possível tratar esse SIGSEGV com um simples try/catch
Dart ou Kotlin. Os logs coletados não contêm o título do filme; a associação
com Thor vem do relato do usuário e do último evento de crash do aplicativo.

## Linha do tempo da TV, fuso -03:00

| Horário | Evidência |
| --- | --- |
| 19:36:52 | Abre `BrowserSessionTvPlayerActivity` |
| 19:36:53 | ExoPlayer Media3 1.9.2 inicia; transporte de sessão do navegador |
| 19:36:58 | Chromium também cria decoder AVC; há inicializações de duas instâncias de `OMX.MS.AVC.Decoder` no período |
| 19:37:01 | Player nativo informa vídeo 1726×720 |
| 19:37:04 | Decoder AAC informa saída PCM, estéreo, 44100 Hz |
| 19:37:07 | Player nativo registra primeiro quadro; outra thread de áudio registra stop |
| 19:37:12 | Player chega a READY, buffer de 5005 ms, `browserRetained=true` |
| 19:37:14 | AudioFlinger registra `BUFFER TIMEOUT` |
| 19:37:16 | AudioTrack da thread do ExoPlayer é reativado após underrun |
| 19:37:22 | AudioFlinger registra escrita bloqueada por 942 ms |
| 19:37:23 | Novo `BUFFER TIMEOUT` |
| 19:37:27 | SIGSEGV na thread do ExoPlayer, dentro de AudioTrack.write |
| 19:37:29 | Callback do player registra erro 1003, posterior ao sinal fatal |
| 19:37:43 | Android registra saída por crash nativo; ANR secundário é descartado por o processo já estar em crash |

## Memória e integração

A TV tem 939628 kB de RAM total, aproximadamente 918 MiB. O histórico informa
PSS do aplicativo de 285 MB no crash e duas saídas anteriores por LOW_MEMORY,
às 19:34:44 e 19:35:21, enquanto o aplicativo estava em segundo plano.
O gerenciador TCL tentava liberar memória imediatamente antes do SIGSEGV,
mas explicitamente poupava o aplicativo em primeiro plano. O encerramento
investigado não está classificado como LOW_MEMORY.

`NativeTvPlayerActivity.startPlayer` chama `pauseLocalPlayback` antes de iniciar
o ExoPlayer; `MainActivity.nativePlayerReady` pede a pausa novamente e mantém
o WebView para transporte e recuperação de sessão. `BrowserMediaTransport`
envia essa pausa por mensagem assíncrona, sem confirmação nesse método.
Os logs de Chromium e do decoder nativo justificam investigar a sobreposição
na transição. Não comprovam que ambos continuaram reproduzindo até o crash.

O limite de buffer de 24 MiB do player não limita a memória total: Flutter,
WebView, codecs e buffers do sistema também consomem memória. Não foi
identificado, nestes registros, OutOfMemoryError como causa direta.

## Próxima validação necessária

Reproduzir o mesmo título e servidor com coleta contínua de memória e áudio;
registrar confirmação efetiva de pausa do vídeo do WebView e liberação de
decoders durante a transição. Comparar, de maneira controlada, a reprodução
com e sem sobreposição de players e o caminho de saída de áudio. Só então
selecionar uma mitigação e validá-la na TV. Não foi aplicada uma correção
especulativa ou publicada outra versão.

## Coleta e verificações executadas

- `adb logcat -b crash -d -v threadtime`.
- `adb logcat -d -v threadtime`.
- `adb shell dumpsys activity exit-info com.ciney.tv`.
- `adb shell dumpsys package com.ciney.tv`.
- `adb shell cat /proc/meminfo` (a leitura atual não representa o instante do crash).
- Revisão de `NativeTvPlayerActivity.kt`, `BrowserSessionTvPlayerActivity.kt`,
  `MainActivity.kt` e `BrowserMediaTransport.java`.

Os registros brutos permanecem locais na pasta ignorada
`outputs/diagnostico-thor-2026-11-01/`; não foram publicados para evitar expor
URLs e dados de outros aplicativos. Não houve nova reprodução controlada,
alteração de produção ou execução de testes Flutter/JVM nesta investigação.

Habilidades AAS utilizadas: `systematic-debugging` e `code-review-checklist`.
