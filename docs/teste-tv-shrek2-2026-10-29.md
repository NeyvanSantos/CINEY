# Teste físico de Shrek 2 — 29/10/2026

TV `192.168.100.130:5555`, modelo Smart TV, pacote `com.ciney.tv.lite_test`, versão `1.0.46-teste-local`. Filme confirmado pelo título/cartaz: **Shrek 2 (2004)**. Foram exercitados os dois servidores na versão que já estava instalada, sem alteração de código ou instalação durante este teste.

SHA-256 do APK conferido diretamente na TV: `959875E436C16EF9BBA7180F8ED838B930AA8BFF4CB23B32CCD4693F934BBD70`. O APK local posterior com filas assíncronas não foi usado nesta execução.

## Resultado

| Medida | EmbedMovies | SuperFlix — servidor principal |
|---|---|---|
| Resolução registrada pelo decodificador | 1280 × 720 | 426 × 240 |
| Primeiro quadro após iniciar o player nativo | 4,77 s | 5,04 s |
| Player pronto após iniciar | 5,29 s | 6,89 s |
| Pausa e retomada | Funcionaram | Funcionaram |
| Mudança de trecho na barra | Funcionou; pronto em 1,10 s | Funcionou; pronto em 1,27 s |
| Quadros renderizados / descartados | 3819 / 6 (0,16%) | 4263 / 15 (0,35%) |
| Erro do player | Nenhum registrado | Nenhum registrado |
| Buffering não solicitado após abertura | Nenhum registrado | Nenhum registrado |

Percentual de descarte: descartados / (renderizados + descartados). Os contadores incluem abertura e mudança de trecho. Não equivalem a uma avaliação audiovisual de todo o filme.

As sessões nativas duraram aproximadamente 3 min 6 s e 3 min 45 s, respectivamente, incluindo pausas e operações de teste. A reprodução foi confirmada por imagens em momentos distintos. O EmbedMovies foi aberto do início e buscado para aproximadamente 30 minutos; o SuperFlix retomou a posição salva e depois foi buscado para outro trecho próximo dos 30 minutos. Não foi assistido o filme inteiro.

## Abertura do SuperFlix

A primeira abertura permaneceu em tela preta antes de disponibilizar mídia. Após a troca de servidor e nova abertura, o provedor apresentou a validação Cloudflare, exibiu transitoriamente falha de verificação e depois liberou o menu. Não houve automação de desafio. Os tempos da tabela começam no player nativo e **não incluem** essa espera do provedor.

O rótulo de 1080p no seletor não correspondeu à resolução efetivamente decodificada nesta amostra. O motivo de a seleção do SuperFlix permanecer em 240p não foi determinado neste teste; não se atribui isso automaticamente à rede, ao arquivo ou à seleção adaptativa. A fluidez observada em 240p não certifica fluidez em 720p/1080p nesse servidor. Nesta comparação, o EmbedMovies entregou qualidade superior.

## Evidências e limites

- Log: `outputs/tv-shrek2-2026-10-29/player.log`.
- Resoluções extraídas de `dumpsys media.metrics` para o UID do CiNey, com timestamps correspondentes às sessões: `outputs/tv-shrek2-2026-10-29/resolucao-codec.json`.
- Capturas de detalhes, reprodução, pausa e mudança de trecho na mesma pasta de evidências.
- Relógio dos registros: o da TV. Os intervalos são calculados pelos timestamps do mesmo dispositivo.
- O teste confirmou reprodução e controles nos trechos amostrados. Não confirma ausência de travamentos em todo o catálogo, durante o filme inteiro ou em qualidade superior à registrada.

O código-fonte permaneceu como estava; não foram repetidos testes automatizados porque este trabalho foi uma validação física, sem mudança de implementação. Evidências e relatório ficaram nas pastas de diagnóstico e documentação do projeto.

## Verificação posterior das opções de qualidade

A inspeção somente de leitura das playlists esclareceu o limite do SuperFlix principal nesta sessão: o manifesto mestre anuncia uma única variante `RESOLUTION=426x240`, `BANDWIDTH=150000`, codecs AVC/AAC. Portanto, os 240p observados não resultaram de escolher uma variante menor entre várias qualidades anunciadas por esse manifesto. Evidência: `outputs/tv-shrek2-2026-10-29/superflix-qualidades.jsonl`.

Na reabertura do EmbedMovies, o provedor escolheu outro player interno (`v2.watchplay.shop`); foi capturada uma playlist de mídia sem variantes, registrada em `embed-qualidades.jsonl`. Isso não comprova o máximo de todos os players internos do EmbedMovies. A execução anterior em 720p permanece confirmada pelo decodificador.

A revisão do player nativo não encontrou restrição `setMaxVideoSize`, `setMaxVideoBitrate` ou equivalente fixando o máximo em 720p. Não foi encontrada uma variante 1080p nas playlists capturadas nesta verificação. Não foi alterada a implementação, nem fabricada resolução por upscale. Fontes ou players internos diferentes ainda podem oferecer outras versões.
