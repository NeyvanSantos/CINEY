# Escolha do caminho de reproducao para TV - 2026-10-23

## Evidencia local
TV Android API 30, aproximadamente 918 MiB de RAM utilizavel. Durante travadas: pressao de memoria, paginacao intensa e grande GL mtrack. Esse contador nao identifica sozinho a origem das alocacoes. Queda de WebViews de 1 para 0 nao certifica handoff nativo bem-sucedido. video_player 2.11.1/video_player_android 2.9.5 no lock mobile; confirmar lock TV antes de implementar.

## Recomendacao
Prototipo exclusivamente TV com Activity Android dedicada, Media3 ExoPlayer e PlayerView/SurfaceView, fora da composicao Flutter. Flutter permanece no catalogo. WebView usada para selecao/validacao e descoberta da sessao HLS. Transferir URL, User-Agent, cookies, Referer, Origin, posicao e preferencia de audio; nunca registrar tokens ou cookies. Liberar a WebView depois de confirmar imagem/estado READY do nativo, sem manter duas reproducoes. Na falha, liberar recursos nativos e reconstruir o embed com estado de selecao preservado. Retornar posicao/duracao/resultado ao historico Flutter e manter proximo episodio e escolha de servidor.

Activity dedicada evita composicao do video dentro do canvas Flutter, mas manter o engine pausado ainda consome memoria. Medir memoria real: nao prometer eliminar todo o custo do Flutter. Evitar segunda instancia do player e segundo engine.

## Ordem de trabalho
1. Instrumentar AnalyticsListener: primeiro frame, decoder/hardware, frames descartados, buffer/rebuffer, resolucao, bitrate, erro; sem URLs de sessao.
2. Prototipo SurfaceView e controles D-pad com retorno de progresso; habilitado apenas no APK de teste.
3. Ajustar LoadControl com limite de bytes especifico para TV de pouca RAM; experimentar 16/24/32 MiB como hipoteses, com medicao de rebuffer; nao usar limite arbitrario definitivo nem prometer limite para memoria grafica.
4. Garantir faixa PT-BR, HLS multivariante, cabecalhos para playlists/segmentos/chaves, retomada, selecao manual de servidor e fallback.
5. Comparar mesmo filme/servidor/qualidade em sessoes separadas: inicio, 5 e 15 minutos, memoria, swap, frames descartados e tempo de rebuffer.

## Alternativas
Nao trocar automaticamente para VideoViewType.platformView: o plugin Android atual adverte contra esse modo por problema conhecido. HCPP nao serve nesta TV API 30: exige API 34+, Vulkan/Impeller e versao Flutter compativel. Tunneling pode ajudar certas TVs, mas somente teste separado e reversivel, pois depende do hardware. Buffer maior pode piorar RAM; buffer muito pequeno pode aumentar rebuffer. Nao reduzir qualidade sem medir.

## Fontes oficiais consultadas
- https://developer.android.com/media/media3/ui/surface
- https://developer.android.com/media/media3/exoplayer/battery-consumption
- https://developer.android.com/media/media3/exoplayer/analytics
- https://developer.android.com/reference/androidx/media3/exoplayer/DefaultLoadControl
- https://developer.android.com/media/media3/ui/androidtv
- https://docs.flutter.dev/platform-integration/android/platform-views
- https://pub.dev/packages/video_player_android

Status: pesquisa e escolha arquitetural; prototipo ainda nao implementado, sem comprovacao de ganho fisico. Backups em Codex.md devem ser preservados.

## Implementacao e teste fisico
Activity dedicada implementada no host TV, Media3 1.9.0, PlayerView SurfaceView, buffer alvo 24 MiB (hipotese inicial), cabecalhos da sessao, preferencia PT-BR, posicao inicial e retorno do progresso. Exibe controles nativos por D-pad; Menu retorna a lista Flutter de servidores. Timeout de inicio 25 s e fallback ao embed. A pagina e parada/carregada em branco apos primeiro quadro, sem destruir indevidamente a view pertencente ao plugin.

APK de teste armeabi-v7a instalado na TV 192.168.100.130:5555. Teste fisico confirmou NativeTvPlayerActivity ativa, decoder OMX.MS.AVC.Decoder, primeiro quadro e estado READY com 7844 ms em buffer naquele instante. Video avancou. Menu retornou a MainActivity e exibiu SuperFlix/EmbedMovies sem iniciar o embed anterior por tras.

Amostra nativa curta: rendered=644, dropped=36; evento dropped=36 em 28996 ms. Ainda ha descarte de quadros, portanto nao afirmar fluidez resolvida. Nao houve confirmacao auditiva de dublagem nem teste de filme completo. A preferencia de idioma foi implementada, mas precisa de confirmacao de audio real. Consumo grafico permaneceu elevado na primeira amostra (~210 MiB GL mtrack); SurfaceView nao eliminou toda a pressao de memoria.

Verificacoes: analise Dart do host e nucleo sem problemas; 21 testes de continuidade e teste especifico da ponte nativa passaram; build release de teste compilou. Nao publicado. Backup em Codex.md.
