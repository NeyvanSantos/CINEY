# Reprodução HLS na Android TV

Implementação em `packages/ciney_core/lib/features/player/tv/`, consumida pelo
host `cinemax_tv`. O documento `tv-player-engine.md` registra a implementação
anterior, que deixava a reprodução dos embeds inteiramente com o fornecedor.

## Fluxo

1. O servidor escolhido abre em uma WebView visível.
2. O host TV registra `embed_media_observer`, incluindo a ponte de foco/teclas.
   O observador é instalado antes dos documentos do fornecedor, inclusive frames.
3. `tv_hls_observer.js` observa respostas fetch/XHR com conteúdo `#EXTM3U` e
   fontes HLS de elementos de vídeo. Não envia URLs `blob:` ao player nativo.
   Prioriza a playlist multivariante, preservando qualidade adaptativa e áudio.
   Quando o fornecedor exibe seu menu, `tv_remote_navigation.js` adiciona foco
   laranja às opções de áudio/servidor. As setas movem a seleção e OK aciona a
   opção. O menu do aplicativo se recolhe para entregar o controle ao fornecedor.
   A abertura do vídeo começa após confirmar o servidor; o prazo de carregamento
   não expira enquanto a pessoa está escolhendo.
4. A sessão fornece o User-Agent da WebView e os cookies da URL de mídia,
   incluindo HttpOnly. Referer, Origin e cabeçalhos de aplicação observados são
   encaminhados à fonte nativa. Cookies e URLs assinadas não entram nos logs.
5. O player Android prepara o HLS com `VideoFormat.hls`, mesmo em endereços sem
   extensão. Seleciona português quando a faixa é identificada e a fonte não
   está marcada como legendada.
6. Após inicializar, a WebView é descarregada e os controles nativos assumem.
   Falhas mantêm a recuperação por recarga/troca de servidor. Uma sessão antiga
   não pode assumir a tela após recarga, troca ou suspensão.

O carregamento de HTML não é confirmação de reprodução. O prazo da descoberta
permanece ativo até encontrar mídia ou exibir recuperação. Clipes inferiores a
três minutos são rejeitados na promoção de embeds para evitar anúncios.

O player usa os codecs do dispositivo. Não há conversão de vídeo nem licença
DRM implementada neste fluxo. Servidores que não carreguem uma playlist
observável continuam disponíveis pela interface original e pelo menu de
recuperação. A compatibilidade com cada fornecedor deve ser verificada ao vivo.

Referências: [HLS no ExoPlayer](https://developer.android.com/media/media3/exoplayer/hls),
[WebViewCompat](https://developer.android.com/reference/androidx/webkit/WebViewCompat)
e [VideoPlayerController.networkUrl](https://pub.dev/documentation/video_player/latest/video_player/VideoPlayerController/VideoPlayerController.networkUrl.html).

## Testes reproduzíveis

Na pasta `cinemax`, os testes `tv_hls_candidate_test.dart`,
`tv_embed_player_test.dart`, `tv_hls_observer_test.cjs` e
`tv_remote_navigation_test.cjs` verificam dados de sessão,
playlist principal, rejeição de mensagens inválidas, anúncios, idempotência e
cancelamento durante uma recarga.

O teste Android `cinemax_tv/integration_test/tv_hls_playback_test.dart` usa o
`PlayerScreen` real com catálogo de teste e os plugins reais. A substituição do
catálogo existe somente no teste; não altera autenticação ou rotas do aplicativo.
O servidor local `scripts/tv-hls-fixture.cjs` exige cookie HttpOnly, Referer e
X-Session nas playlists, nos segmentos e na chave AES-128.

Com FFmpeg instalado, o script gera automaticamente um vídeo sintético H.264/AAC
de 190 segundos com criptografia AES-128 em `.work/tv-hls-fixture/` quando a
playlist ainda não existe. Execute o servidor em um terminal e o teste em outro:

```powershell
node scripts/tv-hls-fixture.cjs .work/tv-hls-fixture
adb -s SERIAL reverse tcp:8879 tcp:8879
cd cinemax_tv
flutter test integration_test/tv_hls_playback_test.dart -d SERIAL --no-pub
```

Para verificar um fornecedor real, passe
`--dart-define=TV_HLS_PROVIDER=URL_DO_EMBED` para um filme com mais de duas horas
(por exemplo, TMDB `157336`, usado nesta validação). O teste verifica início nativo,
posição avançando, pausa, avanço com D-pad, retomada e liberação. As credenciais
do teste local são fictícias.
O parâmetro `--dart-define=TV_HLS_HOLD_SECONDS=30` acrescenta uma verificação de
progressão contínua durante 30 segundos depois dos comandos de pausa e avanço.

## Versão local

O build debug da TV usa `com.ciney.tv.local`, nome **CiNey TV Local** e sufixo
`-local`. Pode coexistir com a versão publicada. O build release mantém o pacote
e a identificação existentes. A geração do APK local não publica uma release.
O atualizador não oferece versões públicas ao pacote local de teste.
