# Início automático no Android — 08/10/2026

Teste local da alteração de **Assistir Agora**, antes de publicar uma atualização.
Foi instalado um build **debug** no emulador Android 14 / API 34
`CiNey_Android14` (`emulator-5556`), com conexão de depuração Flutter.
A versão permaneceu `1.0.19+21`; não houve tag, release ou publicação no GitHub.
A instalação manteve a conta, os favoritos e o histórico existentes.

## Resultados observados

| Fluxo | Resultado |
| --- | --- |
| Filme pela tela de detalhes | **Assistir Agora** abriu diretamente EmbedMovies, sem o seletor de servidores do app. |
| Seleção dentro do embed | O menu PlayerFlix abriu o WatchPlay automaticamente, sem toque no servidor ou no botão de reprodução. |
| Primeira reprodução do filme | O app registrou vídeo carregado e reprodução iniciada. O elemento de vídeo estava com `readyState=4`, `paused=false`, duração de 8.700,578 segundos e posição avançando. |
| Sair e reabrir pela tela de detalhes | O app preservou o ponto salvo. Em uma reabertura, carregou 194.400 ms e o vídeo informou 194,600 segundos após iniciar, sem seleção manual. |
| Avanço após retomar | Em outra reabertura com ponto salvo de 194.600 ms, o vídeo avançou de 228,486 para 233,338 e 238,517 segundos em amostras sucessivas. Uma captura posterior confirmou imagem do filme, com vídeo de 1920 × 800. |
| Série A Coroa Perfeita, T1E1 | O endereço `/serie/278573/1/1` carregou, mas o menu retornou zero opções de reprodução e nenhum vídeo. A automação não acionou a seta de próximo episódio. Reprodução e continuidade dessa série não foram confirmadas. |

A inspeção do filme confirmou os frames `myembed.biz`, `playerflix.ink` e
`v2.watchplay.shop`, com início automático habilitado. Os dados de reprodução
foram conferidos no vídeo da WebView e na sessão do player, pela depuração local.
O primeiro início do filme ocorreu aproximadamente 11 segundos após o toque em
**Assistir Agora**; a reabertura seguinte carregou em cerca de 7 segundos.

O aviso de DNS de uma requisição secundária (`página principal: false`) também
apareceu no filme que reproduziu. Esse aviso isolado não demonstra falha do
servidor inteiro. Não houve automação de verificação humana ou anúncio.

## Limites

O teste de retomada descrito foi feito pelo botão da **tela de detalhes**.
Ele não validou o cartão da seção **Continuar Assistindo** nessa primeira execução.
Esse fluxo foi corrigido posteriormente, conforme a seção abaixo.
Não foram validados créditos, troca real
de episódio, TV física ou reprodução de todo o catálogo.

O build inicial no caminho original falhou em `jni:buildCMakeDebug`, com saída
nativa esperada ausente. Uma cópia temporária das fontes atuais em um caminho
sem espaços ou acentos compilou em 63 segundos. Nenhum arquivo de Cast foi
alterado nesta atividade; o build inclui as alterações locais que já existiam.

Scripts de inspeção, logs brutos e o APK de depuração ficaram fora do repositório.

## Evidências

- [Filme após reabrir](images/testes-android-2026-10-08/autoplay-movie-resumed.png).
- [Imagem do filme em reprodução](images/testes-android-2026-10-08/autoplay-movie-final.png).
- [Menu sem opções no episódio](images/testes-android-2026-10-08/autoplay-series-debug.png).

## Correção posterior: continuar no servidor usado

O histórico passou a guardar `server` por filme ou episódio, junto com o tempo.
Uma rota sem escolha explícita, como o cartão **Continuar Assistindo**, agora
procura esse servidor nas fontes atuais. O nome é salvo em vez do índice, para
resistir a mudanças na ordem da lista. Uma nova escolha manual prevalece e passa
a acompanhar o progresso no novo servidor. Escritas pendentes conservam o nome
do servidor da mídia que originou a posição.

Registros antigos, sem esse campo, preservam o tempo e usam o padrão atual
(EmbedMovies quando disponível) até registrar o servidor numa reprodução.
Não é possível recuperar a escolha antiga a partir de um histórico que nunca
gravou o servidor.

Antes de o usuário dispensar novos testes, passaram 54 testes Flutter de
histórico, continuidade, entrada por conta, detalhes, preferências e sessão.
Incluem restauração de SuperFlix e EmbedMovies, mudança na ordem das fontes,
escolha explícita e troca de servidor. A análise da TV passou; no celular
continuam os dois erros anteriores no teste do atualizador e as 20 informações
de depreciação do player.

O build debug da correção compilou e foi instalado no emulador. O emulador
encerrou durante a conexão de depuração; a verificação do cartão com a nova
versão não foi concluída. O usuário dispensou a continuação dos testes.
Nenhuma atualização foi publicada.
