# Correção da reprodução nos servidores TV — 28/10/2026

Aplicação no pacote local `com.ciney.tv.lite_test`, TV Smart_TV C06, Android API 30, por ADB. Não houve publicação de release, alteração de dados da conta ou limpeza dos dados do aplicativo.

## Alterações

- O APK agora inclui `credentials: 'same-origin'` no transporte do navegador. O APK anteriormente instalado ainda usava `include`, que falhava ao baixar os segmentos do SuperFlix. A validação inicial e os cookies da origem permanecem na sessão do navegador.
- O primeiro quadro do player dedicado não desmonta mais `TvEmbedPlayer` quando o transporte depende dessa WebView. Ela continua fornecendo os segmentos e é liberada na saída/troca. O caminho HTTP direto do EmbedMovies continua descarregando o documento.
- `MainActivity.nativePlayerReady` mantém a WebView do transporte ativa; pausa somente o vídeo do provedor. O caminho HTTP direto continua pausando e descarregando a WebView.
- O SuperFlix usa `BrowserSessionTvPlayerActivity`, com tema declarado no manifesto que preserva a visibilidade da janela subjacente. O vídeo nativo mantém fundo preto opaco. O transporte HTTP direto conserva a Activity opaca. O Android classifica a visibilidade pelo tema do manifesto; trocar somente o tema durante `onCreate` não foi suficiente no teste.
- Durante a Activity de sessão, o canal de ciclo de vida pausa os frames Flutter, evitando que a animação de carregamento concorra com decodificação e transporte. A Activity/janela Android que hospeda a WebView permanece visível. O ciclo de vida normal é restaurado ao retornar.
- O prazo de abertura do transporte browser passa a 45 s (HTTP direto continua 25 s), pois as playlists e o primeiro segmento podem avançar mais lentamente nesta TV. A expiração é registrada explicitamente. Isso não substitui a medição de continuidade.
- A gravação do spool dos segmentos saiu da thread de interface para um executor de trabalho. O ACK só é enviado depois da gravação, preservando a limitação de blocos pendentes e a ordem dos dados. O executor é encerrado ao liberar a sessão.
- Requisições interrompidas antes de retornar a resposta liberam spool e vaga de concorrência mesmo se os cabeçalhos chegarem durante a interrupção.
- Logs de início/fim da transferência registram identificador aleatório, bytes e duração, sem URLs, cookies ou tokens.

Não houve alteração do tamanho do buffer, qualidade padrão ou seleção de áudio.

## Validação automatizada e build

- 17 testes JavaScript de transporte, observação HLS e navegação passaram.
- Dois novos testes Flutter verificam a retenção da WebView no SuperFlix, a liberação no EmbedMovies e a limpeza ao retornar ao seletor. Ambos passaram.
- Análise do host TV e dos arquivos Dart alterados: sem problemas. `git diff --check`: sem problemas.
- O build Android release local compilou e foi instalado com `adb install -r`.
- SHA-256 do APK instalado nesta etapa: `BB1BA419590FA93BCC34EC64AF0E7727192603DD32F2C2D4EEDE3B53DFF07511`.
- APK: `outputs/CiNey-TV-Leve-teste-armeabi-v7a.apk`.

Limitações já presentes na base: a execução ampliada do teste `tv_embed_player_test.dart` encontrou cinco falhas relativas às expectativas antigas do painel/recarga/retorno de background. A análise de todo o núcleo encontrou três infos de estilo em `extensions_screen.dart` e `tv_cast_service.dart`. Não são apresentados como checks aprovados. A análise dos arquivos modificados e os testes direcionados passaram.

## Teste físico

Filme de referência: Shrek (2001). As tentativas intermediárias identificaram que corrigir somente o modo de credenciais permitia iniciar o vídeo, mas não bastava para continuidade/avanço enquanto a sessão era desmontada ou pausada. O APK final inclui os ajustes de ciclo de vida e de gravação descritos acima.

O Cloudflare liberou as sessões durante o teste; não foi implementado bypass ou automação de resolução do desafio. A disponibilidade externa continua dependendo do provedor.

Evidências de validação em `outputs/tv-correcao-servidores-2026-10-28/`, incluindo `native-validacao.log` e capturas. O relógio dos logs é o da TV; os intervalos são usados para as medições.

## Recuperação

Backup anterior às alterações de ciclo de vida em `.work/recovery/before-superflix-session-lifetime/`. O APK original instalado antes da investigação foi preservado em `outputs/tv-diagnostico-2026-10-28/instalado.apk`. As alterações locais anteriores foram preservadas; nenhum reset/clean foi executado.

### Transporte misto e situação da validação

`SessionHttpDataSource` mantém playlists `.m3u8`/`.txt` no navegador e tenta HTTP nativo para os demais recursos, com fallback ao navegador em HTTP 401/403 ou resposta HTML. Cookies não são copiados para o transporte HTTP nativo. A finalidade é evitar a passagem dos segmentos grandes por Base64/ACK na TV de pouca memória.

O ensaio intermediário com HTTP também nas playlists falhou com erro 3002 de leitura do manifesto (PID 3420, 15:28 no relógio da TV). Essa tentativa não é uma validação aprovada. O ajuste subsequente compilou e foi instalado com sucesso; o hash acima corresponde a esse ajuste. A reprodução prolongada e o avanço nos dois servidores ainda precisam ser validados nesse APK.

Após a interrupção, o serviço ADB foi reconectado, mas a TV passou a retornar `unauthorized`. Foi solicitado ao usuário aceitar a autorização de depuração na própria TV. Nenhuma conclusão de estabilidade será baseada apenas na compilação.

Logs dessa etapa: `outputs/tv-correcao-servidores-2026-10-28/retomada-native.log`. Durante a investigação anterior, somente o cache do CiNey (aproximadamente 39,9 MB) foi limpo para permitir a instalação; dados e histórico foram preservados.