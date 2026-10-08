# Retomar o filme no ponto de parada

O player compartilhado por celular e Android TV procura o progresso salvo ao
abrir um título. Isso funciona tanto pela seção **Continuar Assistindo** como pela
tela de detalhes. O registro mais recente tem prioridade sobre uma posição antiga
recebida pela rota. A opção **Retomar reprodução** em Ajustes & Perfil controla
esse comportamento.

O histórico também guarda o nome do servidor usado para reproduzir cada filme
ou episódio. **Continuar Assistindo** procura esse nome nas fontes atuais antes
de abrir o player: EmbedMovies continua no EmbedMovies, SuperFlix no SuperFlix.
A escolha independe da ordem da lista de servidores. Uma troca manual passa a
ser registrada com o progresso da reprodução no novo servidor; as escritas
pendentes da reprodução anterior mantêm o servidor anterior.

Uma escolha explícita de servidor prevalece sobre o histórico. Na transição para
o próximo episódio, o player conserva o servidor da sessão. Os registros antigos
não contêm essa informação; continuam legíveis e usam o padrão atual do app
(EmbedMovies quando disponível) até uma reprodução gravar o servidor. Se o
servidor salvo deixar de existir na lista, o player usa uma fonte disponível.

A posição é armazenada em milissegundos, sem arredondar para minutos. Ao pausar,
sair pelo botão Voltar ou pelo retorno do sistema, ou mudar de aplicativo, o player
consulta a posição atual. A saída pelo player espera a escrita do histórico antes
de voltar ao catálogo. Durante a reprodução, há salvamento periódico a cada dois
segundos. Um encerramento abrupto do processo pode perder o intervalo desde o
último salvamento; não há como executar a consulta final depois que o sistema
encerra o processo.

Paradas nos primeiros segundos e durante os créditos são preservadas. O histórico
não considera mais 95% como conclusão; ele remove o ponto de retomada quando a
reprodução efetivamente termina ou alcança toda a duração. Episódios continuam
com registros próprios e o avanço para o episódio seguinte começa do zero.

## Vídeos dos servidores incorporados

O botão **Assistir Agora** e a escolha de um episódio na tela de detalhes abrem
diretamente o EmbedMovies (`https://myembed.biz`) quando ele está disponível,
tanto no celular como na TV. O player mantém a seleção manual de servidor.
Sem EmbedMovies, a tela de detalhes conserva o fluxo anterior de escolha.

No EmbedMovies, `assets/player/embed_startup.js` tenta abrir a opção de reprodução
também na primeira abertura, sem precisar de histórico salvo. Desligar
**Retomar reprodução** inicia do zero e mantém essa tentativa de início automático.
Nos demais fornecedores, a ativação automática continua condicionada à retomada.
No EmbedMovies/PlayerFlix, reconhece as opções do menu `#optionList` e usa o
controle existente do fornecedor. Para
o menu compacto com abas **Dublado/Legendado**, aciona **Servidor Principal**,
inclusive quando o texto está em um `div` ou `span` com evento delegado.
Se houver mais de um controle visível com esse nome, mantém a seleção manual.
A seleção só ocorre no domínio e caminho do título que o app abriu, com até
20 segundos de espera pelo menu, e não aciona links de anúncios ou verificação.
Uma interação da pessoa cancela a seleção automática.

Quando o menu expõe áudio e servidor nas opções, a última escolha manual é
guardada no armazenamento local da página. Na próxima retomada, ela tem prioridade
se ainda existir; caso contrário, usa a primeira opção visível da aba de áudio
atual. Essa preferência é local ao WebView e ao domínio do fornecedor.

Depois de confirmar a posição de retomada, ou quando não há ponto a restaurar,
o script tenta reproduzir o vídeo uma vez. Se o fornecedor só liberar o intervalo
de busca após iniciar o vídeo,
essa tentativa pode ocorrer antes; o ponto salvo permanece protegido enquanto
a busca estiver pendente. Uma pausa ou a consulta de saída cancela tentativas pendentes. Caso o
fornecedor exija um gesto real, os controles continuam disponíveis para o toque
manual; cliques de script não garantem permissão de autoplay, conforme o
[guia de autoplay da MDN](https://developer.mozilla.org/en-US/docs/Web/Media/Guides/Autoplay).
O script usa [`HTMLElement.click()`](https://developer.mozilla.org/en-US/docs/Web/API/HTMLElement/click)
dentro da WebView e não depende de Python ou automação instalada no computador.

O observador de frames Android também é instalado para filmes. O recurso
`assets/player/playback_resume.js` aplica a posição usando
[`HTMLMediaElement.currentTime`](https://developer.mozilla.org/en-US/docs/Web/API/HTMLMediaElement/currentTime)
depois que o vídeo e o intervalo de busca ficam disponíveis. A posição é aplicada
uma vez, para permitir que a pessoa avance ou rebobine livremente depois. Enquanto
a retomada está pendente, o app conserva o ponto anterior.

Uma consulta ao sair é encaminhada aos frames, que pausam o vídeo e respondem com
a posição corrente e um identificador da consulta. A sessão valida a mídia e o
identificador antes de aceitar a resposta. Se não houver resposta em 800 ms, usa
o último sinal válido, quando disponível. Os comandos só são aceitos do frame pai.

O filtro de vídeos de pelo menos três minutos continua evitando anúncios curtos.
Quando há uma duração salva, clipes com menos da metade dessa duração também são
ignorados para proteger o progresso do filme durante anúncios mais longos.
Players opacos, WebViews sem observação de frames ou fornecedores que não permitam
buscar o vídeo podem impedir a retomada automática. A precisão efetiva também
depende da posição que o player consegue informar e alcançar. A implementação
não altera as pontes protegidas de Cast nem sincroniza histórico entre aparelhos.

## Verificação

Os testes usam o player nativo simulado e scripts executados em contexto de vídeo
simulado. Cobrem navegação de **Assistir Agora** no celular e na TV, temporada e
número do episódio escolhido, início sem histórico, seleção do servidor, áudio
salvo, menu assíncrono, cancelamento manual, falha de autoplay, retomada sem
parâmetro de rota, histórico mais recente, créditos,
preferência desligada, pausa/saída, mudança de aplicativo, milissegundos, espera
pela capacidade de busca e consulta nos frames. O início automático de um filme
e a retomada pela tela de detalhes foram confirmados no emulador com build debug
contendo esta alteração. O episódio T1E1 de A Coroa Perfeita carregou sem opções
de vídeo; reprodução da série, créditos e avanço de episódios continuam sem
validação remota. Consulte o
[relatório do início automático](teste-inicio-automatico-android-2026-10-08.md).

Validação do início automático em 08/10/2026: passaram 46 testes Flutter
(`details_auto_play`, `embed_document`, `stream_resolver`,
`player_episode_continuity`, `playback_preferences`, `embed_playback_session` e
`embed_navigation`) e 37 testes Node (`embed_startup`, `embed_media_observer` e
`embed_bridge`). A análise completa do celular continua com dois erros anteriores
em `test/app_updater_test.dart`, por chamar `AppUpdater.selectLatestRelease`,
ausente na implementação atual, e 20 avisos informativos de `withOpacity`.
A análise de `cinemax_tv` passou sem problemas.
