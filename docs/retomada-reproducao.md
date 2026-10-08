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
simulado. Cobrem retomada sem parâmetro de rota, histórico mais recente, créditos,
preferência desligada, pausa/saída, mudança de aplicativo, milissegundos, espera
pela capacidade de busca e consulta nos frames. A reprodução com os servidores
remotos ainda precisa de validação em aparelho real.
