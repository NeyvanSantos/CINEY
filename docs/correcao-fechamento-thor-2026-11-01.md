# Correção da transição para o player nativo — 01/11/2026

## Escopo e decisão

Após o crash nativo em AudioTrack descrito no diagnóstico, foram corrigidas duas
falhas verificáveis da passagem de reprodução do WebView para o ExoPlayer:
o início nativo não aguardava a confirmação de parada do provedor e o provedor
podia voltar a reproduzir por autoplay tardio.

A decisão foi corrigir essa disputa de reprodução mantendo o navegador como
transporte autenticado. Não foram alterados codecs, dependências, resolução,
assinatura oficial ou comportamento do CastLite. Encerrar o WebView descartaria
cookies e recuperação de segmentos 401/403; capturar exceções Kotlin não trata
o SIGSEGV nativo. Os logs não permitem provar qual componente invalidou o buffer
de áudio original: a mudança elimina falhas da integração, sem atribuir uma
correção inexistente ao firmware da TCL.

## Mudanças

- `tv_browser_transport.js`: responde `localPaused` com identificador e resultado
  somente depois de executar a pausa/parada do player. Bloqueia novos eventos
  `play`/`playing` enquanto o player nativo detém a reprodução, preservando a
  posição para retomada. Uma parada que falhou não vira sucesso em nova tentativa.
- `PlaybackPauseRequests.java`: correlaciona identificador e origem, entrega o
  resultado uma única vez, rejeita confirmações tardias e falha requisições
  pendentes ao encerrar o transporte.
- `BrowserMediaTransport.java`: acrescenta a confirmação assíncrona com timeout
  de três segundos, sem bloquear a UI. O comando antigo sem identificador continua
  aceito. Uma resposta sem sucesso booleano verdadeiro não libera a reprodução.
- `NativeTvPlayerActivity.kt`: prepara o ExoPlayer após a confirmação; falha de
  pausa volta ao fluxo de erro/servidores. Uma resposta de geração antiga ou de
  Activity encerrada não inicia outro player.
- `MainActivity.kt`: solicita `WebView.onPause()` durante o player nativo,
  preservando a execução JavaScript, e restaura `onResume()` ao retornar à tela
  do navegador. Não usa `pauseTimers()`. Esse comportamento está documentado na
  [API oficial do Android](https://developer.android.com/reference/android/webkit/WebView#onPause()).
- Testes em `tv_browser_transport_test.cjs` e `PlaybackPauseRequestsTest.kt`.

## Validação automatizada executada

| Verificação | Resultado |
| --- | --- |
| Regressões JavaScript antes das correções | Falharam por ausência de confirmação/guarda de autoplay e por confirmação falsa na retentativa |
| Regressões da correlação nativa com implementação inicial vazia | Três falhas de asserção observadas; compilação bem-sucedida |
| Suíte JavaScript dos embeds, HLS, navegação e transporte | 62 aprovados |
| `flutter analyze --no-pub`, Mobile e TV | Sem problemas |
| `flutter test --no-pub`, Mobile | 198 aprovados |
| `flutter test --no-pub`, host TV | 1 aprovado |
| Gradle JDK 17, offline, testes nativos debug e release | 17 aprovados em cada variante; release executado também após o ajuste visual |
| Build release local, lint vital e assinatura de teste | Aprovados |
| `git diff --check` | Aprovado |

Comando de build: `scripts/build-local-mobile-tv.ps1 -Target tv -BuildDrive Y:
-Offline -NativeTests`. Foi usado `subst X:` para as verificações locais com os
caches existentes. Uma análise iniciada por engano na raiz foi interrompida e
substituída pelas análises corretas de cada host. As advertências nativas de
APIs depreciadas e compatibilidade futura do Gradle continuam existentes.

## Teste físico e limites

APK separado `com.ciney.tv.lite_test`, versão `1.0.48-teste-local`, ARM 32 bits,
na TCL C06. O usuário realizou login no pacote de teste. A instalação oficial
`com.ciney.tv` foi preservada; não houve push, tag ou release.

SHA-256 do APK final testado, incluindo pausa visual:
`33cdfa4faca6e247c37172c486ec337f8f4a206d3ba9b112cb4c710caf31ecf2`.

Na execução intermediária de Thor: Ragnarok pelo EmbedMovies, antes da pausa
visual do WebView (APK `667722ad0042ee6564b0849aa78ecad79c3be485f32a5009350ddd9277cc35cc`):

- PID 8798 permaneceu vivo durante o teste.
- 19:58:31: `browserPlaybackStopped=true`, antes da criação do ExoPlayer.
- 19:58:35: decoder `OMX.MS.AVC.Decoder`, vídeo 1726×720.
- 19:58:36: primeiro quadro e READY com 4995 ms de buffer.
- Segmentos HTTP continuaram sendo carregados até 20:00:20.
- O teste foi encerrado pelo comando Menu, que abre a escolha de servidores,
  às 20:00:23: `rendered=2493 dropped=31`. Aproximadamente 107 segundos entre
  primeiro quadro e encerramento voluntário, sem novo SIGSEGV no processo.

Ao cancelar o seletor, o fluxo existente abriu novamente o provedor anterior.
O mesmo processo terminou posteriormente por sinal 9, às 20:01:18, PSS 313 MB.
Portanto, a primeira mudança isolada não eliminou todos os fechamentos observados.

Uma tentativa anterior no pacote de teste voltou ao launcher antes de iniciar
o player nativo: saída SIGNALED, sinal 9, PSS 307 MB. A causa desse sinal 9 não
foi determinada e não deve ser apresentada como corrigida ou como SIGSEGV de
áudio. A TV apresentava pressão de memória nos registros. Uma tentativa pelo
SuperFlix ficou na seleção do servidor e não valida aquele provedor.

Após a pausa visual, a execução final usou PID 11898: confirmação de parada às
20:07:16, primeiro quadro às 20:07:25, avanço visual confirmado por capturas e
carregamento contínuo de segmentos HTTP. Não se mede o sucesso somente pelo
processo estar vivo: as capturas mostram cenas diferentes e o transporte segue
ativo. Houve alternância entre BUFFERING/READY e aviso de underrun no início;
não se apresenta o teste como reprodução sem qualquer engasgo.

A última conferência ocorreu às 20:12:52: PID 11898 ainda ativo, segmentos
carregados até 20:12:41 e nova captura mostrando avanço do filme. Foram mais de
cinco minutos desde o primeiro quadro, sem novo SIGSEGV, callback de erro nativo
ou saída do PID no histórico coletado. O filme foi deixado reproduzindo na
versão de teste. A memória gráfica continuou alta (aproximadamente 215 MiB em
uma amostra), portanto não se declara eliminado o risco de memória da TV.

A consulta direta do JavaScript por depuração remota não respondeu e foi
interrompida; o encaminhamento ADB foi removido. Ela não é apresentada como
validação aprovada do fallback autenticado. Não foi provocado 401/403 físico;
preservação do JavaScript decorre do contrato da API Android, e os testes de
transporte existentes passaram. Não foi assistido o filme inteiro ou validado
todo firmware/dispositivo.

As evidências permanecem em `outputs/diagnostico-thor-2026-11-01/`, ignoradas
pelo Git por conterem dados de runtime. As fontes e testes estão nas pastas
existentes do projeto. O APK de teste está em `outputs/`; o APK oficial permanece
em `releases/tv/`.

Habilidades AAS aplicadas: `systematic-debugging`, `flutter-expert`,
`test-driven-development`, `api-contract-testing`, `code-review-checklist` e
`lint-and-validate`. A habilidade brainstorming foi examinada; seu fluxo de
projeto aberto não foi aplicado a esta correção delimitada.
