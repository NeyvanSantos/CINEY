# Investigação de Shrek na TV — 28/10/2026

Teste físico por ADB em `192.168.100.130:5555`, Smart_TV C06, Android API 30, pacote `com.ciney.tv.lite_test`, versão `1.0.46-teste-local`. Nenhum APK foi instalado ou publicado nesta investigação. Não houve alteração de código do aplicativo.

## Resultado

Há uma falha reproduzível no transporte do SuperFlix instalado e atividade intensa de paginação durante o EmbedMovies. São problemas distintos. O teste curto do EmbedMovies não reproduziu uma parada prolongada por falta de buffer; não permite certificar um filme inteiro nem atribuir todos os travamentos à memória.

## EmbedMovies: primeiro trecho

- Shrek (2001), duração exibida 1:31:26. Início próximo de zero; reprodução nativa em `NativeTvPlayerActivity`, transporte HTTP direto.
- Primeiro quadro cerca de 3,1 s após abrir a Activity; `OMX.MS.AVC.Decoder` confirmado. WebView descarregada para documento vazio, sem vídeo concorrente encontrado na inspeção.
- Aproximadamente 162 s entre READY e saída pelo Menu. Contadores: 3.829 quadros renderizados, 30 descartados (aproximadamente 0,78% de renderizados + descartados). O descarte pode incluir a abertura/saída; não mede sozinho a percepção de fluidez.
- Nenhuma nova transição a BUFFERING nem erro registrado entre READY e saída, na captura contínua filtrada por `CINEY_NATIVE`.
- Nas amostras em reprodução: GL mtrack aproximadamente 215.268–215.276 kB (210 MiB), PSS aproximadamente 299–304 MiB, SwapPss aproximadamente 46–48 MiB. Esses valores não incluem necessariamente todo o custo de processos auxiliares.
- Entre 14:20:15 e 14:21:05 no relógio da TV: `pswpin` cresceu de 9.511.510 para 9.555.367 e `pswpout` de 10.707.256 para 10.747.829. São contadores globais; não atribuir toda a paginação ao app. `kswapd0` chegou a 86,8% na escala do top, em que quatro núcleos totalizam 400%. MemAvailable nas amostras ficou aproximadamente entre 170 e 185 MiB.
- O alto custo gráfico e a paginação são alvos de investigação/otimização, mas esta amostra não demonstra vazamento nem estabelece causalidade para cada quadro descartado. GL mtrack não deve ser atribuído exclusivamente ao cache de imagens.

## EmbedMovies: retomada e trecho aos 15 minutos

Após testar o SuperFlix, voltei ao EmbedMovies. O filme retomou próximo de 2:42. Segundo início: aproximadamente 7,8 s até primeiro quadro; decoder OMX.MS.AVC.Decoder, inicialização em 3.280 ms. A sessão reproduziu por cerca de 162 s e terminou com 3.809 quadros renderizados e 21 descartados (0,55%). Houve avanço manual pela barra até aproximadamente 15 minutos: BUFFERING iniciou às 14:27:16.538 e READY retornou às 14:27:18.681, cerca de 2,1 s depois. Esse buffering foi provocado pelo seek. Captura posterior confirma avanço até 16:02. Não houve outra transição a BUFFERING depois do seek até a saída.

Nessa sequência de troca de provedores, meminfo mostrou duas instâncias WebView, GL mtrack 225.084 kB (220 MiB), PSS 327–338 MiB e SwapPss chegando a 68 MiB. Isso sugere investigar retenção/liberação das WebViews nas trocas, mas duas instâncias isoladamente não comprovam vazamento ou duas reproduções. O contador é de objetos no processo; uma instância pode estar descarregada ou aguardando coleta. Ao encerrar a medição, deixei a TV no seletor de servidores e encerrei a captura logcat e o encaminhamento de depuração criados nesta sessão.

## SuperFlix: falha confirmada

1. A verificação Cloudflare apresentou falha/espera inicialmente e depois liberou automaticamente o menu. Nenhum desafio foi resolvido por automação.
2. Selecionado Dublado / Servidor Principal. O player nativo iniciou com `transport=browser`, permaneceu com `bufferedMs=0`, falhou com `errorCode=2000` cerca de 7 s depois e retornou ao embed. Não houve primeiro quadro nativo.
3. Na mesma sessão/frame do provedor, playlists retornaram HTTP 200. O primeiro segmento, solicitado com `credentials: 'include'`, falhou com `TypeError`.
4. Repetindo com `credentials: 'same-origin'`, o segmento retornou HTTP 200, 1.367.700 bytes, sincronismo MPEG-TS `0x47` nos offsets 0/188/376. A resposta usa Content-Type `application/javascript`, apesar do conteúdo MPEG-TS. Isso não demonstrou ser a causa: o erro ocorre já no fetch com `include`.
5. O APK efetivamente instalado foi copiado por ADB e seu asset `tv_browser_transport.js` inspecionado: usa `credentials:'include'`. O código local atual já usa `same-origin`. A correção pendente registrada em Codex.md em 23/10 ainda não está no APK da TV.
6. SHA-256 do APK instalado: `94DFD21493AE2FAF209D62F8D45E73F264FB24E6F06E2286E19EF5FF4539A38F`, igual ao APK local `outputs/CiNey-TV-Leve-teste-armeabi-v7a.apk` de 23/10. Reinstalar esse mesmo arquivo não aplicaria a correção.

A diferença de resultado entre os modos de credenciais é compatível com restrições CORS do segmento. A falha no download dos segmentos é comprovada; não foi capturada a mensagem completa de política CORS para afirmar o cabeçalho específico que a provoca.

## Encaminhamento

Primeiro recompilar o APK de teste com o transporte já corrigido e validar o SuperFlix fisicamente. Depois comparar, no mesmo filme/servidor/qualidade e por intervalos maiores, memória, quadros descartados e rebuffers. Não aumentar buffer nem reduzir qualidade por suposição. O transporte via browser mantém WebView viva, converte blocos de 32 KiB para Base64 e grava spool em disco na thread da ponte; é um custo adicional a medir depois de corrigir a transferência. Não foi medido como causa de travamento nesta execução, pois esse caminho falhou antes de reproduzir.

Instrumentação adicional útil: resolução/bitrate, tempo e bytes por segmento, posição e buffer periódicos, duração dos rebuffers e PlaybackStatsListener. A API oficial distingue BUFFERING inicial, após seek e durante reprodução: https://developer.android.com/media/media3/exoplayer/analytics. Referência para interpretação da memória e superfícies compartilhadas: https://developer.android.com/topic/performance/memory-overview.

## Evidências

Arquivos em `outputs/tv-diagnostico-2026-10-28/`: `native-live.log`, `amostras-direto.log`, `segmento-include.log`, `segmento-same-origin.log`, asset extraído do APK e capturas de tela. Os scripts de inspeção não imprimem cookies nem URLs assinadas. Os horários dos logs seguem o relógio da TV e não foram usados como hora local de São Paulo; as comparações usam intervalos.
