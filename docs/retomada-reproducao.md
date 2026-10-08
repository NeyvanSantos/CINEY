# Retomar o filme no ponto de parada

O player compartilhado por celular e Android TV procura o progresso salvo ao
abrir um título. Isso funciona tanto pela seção **Continuar Assistindo** como pela
tela de detalhes. O registro mais recente tem prioridade sobre uma posição antiga
recebida pela rota. A opção **Retomar reprodução** em Ajustes & Perfil controla
esse comportamento.

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

Ao retomar um ponto salvo, `assets/player/embed_startup.js` tenta abrir a opção
de reprodução antes de aplicar a posição. No EmbedMovies/PlayerFlix, reconhece
as opções do menu `#optionList` e usa o controle existente do fornecedor. Para
o menu compacto com abas **Dublado/Legendado**, aciona **Servidor Principal**.
A seleção só ocorre no domínio e caminho do título que o app abriu, com até
20 segundos de espera pelo menu, e não aciona links de anúncios ou verificação.
Uma interação da pessoa cancela a seleção automática.

Quando o menu expõe áudio e servidor nas opções, a última escolha manual é
guardada no armazenamento local da página. Na próxima retomada, ela tem prioridade
se ainda existir; caso contrário, usa a primeira opção visível da aba de áudio
atual. Essa preferência é local ao WebView e ao domínio do fornecedor.

Depois de confirmar a posição de retomada, o script tenta reproduzir o vídeo
uma vez. Se o fornecedor só liberar o intervalo de busca após iniciar o vídeo,
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
simulado. Cobrem seleção do servidor, áudio salvo, menu assíncrono, cancelamento
manual, falha de autoplay, retomada sem parâmetro de rota, histórico mais recente, créditos,
preferência desligada, pausa/saída, mudança de aplicativo, milissegundos, espera
pela capacidade de busca e consulta nos frames. A reprodução com os servidores
remotos ainda precisa de validação em aparelho real.
