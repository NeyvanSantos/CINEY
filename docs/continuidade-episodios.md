# Continuidade dos episódios

O player compartilhado por celular e Android TV busca o próximo episódio no
catálogo enquanto o atual está sendo reproduzido. Ao receber a confirmação de
término, abre o seguinte no mesmo player, inclusive na próxima temporada. A opção
**Próximo episódio automaticamente** em Ajustes & Perfil vem ativada por padrão.
O botão **Próximo episódio** aparece perto do fim e permite avançar manualmente,
mesmo com os demais controles ocultos. Como as fontes não fornecem o instante
dos créditos, o app estima esse período pelos últimos dois minutos, limitados a
10% da duração. Ao voltar para uma parte anterior, o botão desaparece. Ele fica
oculto enquanto o vídeo carrega, a retomada está pendente ou a duração é
desconhecida. Essa regra é compartilhada pelos players nativo e incorporado,
no celular e na TV.
O avanço automático continua esperando o término real do episódio.

A ordem usa os números informados pelo catálogo. Episódios com data de lançamento
futura são excluídos. No último episódio, a reprodução para. Se o catálogo falhar,
o botão permite recarregar a lista perto do fim; o app não inventa episódios nem
salta uma temporada que não conseguiu consultar. Os títulos locais mapeados usam o mesmo
ID TMDB dos endereços dos servidores, evitando os números de exemplo dos plugins.
O catálogo indica a ordem; a disponibilidade do vídeo ainda depende do fornecedor.

O progresso é salvo antes da transição, com escritas em sequência e a identidade
do episódio capturada antes de qualquer espera. O próximo episódio começa do zero,
sem reutilizar a posição de retomada recebida na entrada do player. Sinais do
player anterior são descartados ao trocar ou fechar a reprodução.

## Vídeos incorporados

O iframe do fornecedor continua na estrutura existente. O plugin local
`cinemax/packages/embed_media_observer/` usa a API pública do WebView Flutter e
[`WebViewCompat.addDocumentStartJavaScript`](https://developer.android.com/reference/androidx/webkit/WebViewCompat#addDocumentStartJavaScript(android.webkit.WebView,java.lang.String,java.util.Set%3Cjava.lang.String%3E))
para observar elementos HTML de vídeo nos próprios frames Android, inclusive
quando têm origens diferentes. O script observa o vídeo sem trocar seus controles
ou extrair endereços de mídia.

O observador considera vídeos de pelo menos três minutos para evitar que anúncios
curtos sejam tratados como episódios. Exige reprodução anterior, término real e
posição final válida. A sessão descarta mensagens duplicadas e vídeos menores que
a mídia já selecionada. Esse filtro é conservador: episódios incorporados menores
que três minutos não têm avanço automático. Filmes e vídeos diretos mantêm seu
player.

WebViews sem suporte a `DOCUMENT_START_SCRIPT` mantêm a observação pela ponte
do documento pai. Se ela não conseguir observar a posição
e duração, o botão fica oculto e é necessário escolher o próximo episódio na tela
de detalhes. Em TV, o cursor consegue acionar o botão quando ele aparece.
Durante uma transmissão Cast, o avanço fica desativado.

## Validação

Os testes verificam a ordem do catálogo, troca de temporada, final da série,
lançamentos futuros, falhas de rede, preferência persistida, avanço manual,
histórico separado e sinais de término dos vídeos. O código Java do observador
foi compilado nos hosts Android mobile e TV sem gerar APK.

Ainda é necessário testar a reprodução com SuperFlix e EmbedMovies em aparelho
real. Os testes usam catálogos e vídeos simulados; não confirmam disponibilidade
ou comportamento de um servidor remoto nem o WebView instalado na TCL.
