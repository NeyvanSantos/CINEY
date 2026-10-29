# Qualidade real e brilho da imagem no player TV

Implementação autorizada pelo usuário em 29/10/2026, seguindo `AGENTS.md` e `cinemax/regras/`. Esta entrega usa o pacote local de teste `com.ciney.tv.lite_test` na TV `192.168.100.130:5555`.

## Comportamento implementado

- Ações laterais **Qualidade**, **Brilho** e **Servidores**, com foco visível e navegação por controle remoto. Voltar fecha primeiro o painel aberto; Menu mantém a troca de servidores.
- Resolução derivada do formato de vídeo recebido pelo decodificador, preservada ao recriar o player para ativar brilho. Automática é o padrão. Opções manuais vêm somente de faixas que a fonte oferece e o aparelho suporta.
- Seleção manual preserva as configurações de áudio/legenda; a recriação para brilho reaplica a qualidade escolhida.
- O seletor não promete mais 1080p para o SuperFlix antes de resolver a mídia. Em fonte de qualidade única, o painel informa esse limite.
- Brilho modifica os pixels do filme por `media3-effect`, com intensidade de 0 a 100 mapeada para adição RGB linear de 0 a 0,30. Original restaura transformação neutra. O ajuste é local à sessão, não altera o backlight/configurações globais da TV.
- Para preservar a reprodução padrão, o pipeline gráfico só é habilitado ao primeiro ajuste positivo. A primeira ativação recria o decodificador, conservando posição e pausa; pode haver uma breve preparação. Alterações seguintes usam o mesmo pipeline. Em pausa, alterações são coalescidas e um seek exato de 1 ms atualiza o quadro.
- Recursos públicos usam HTTP nativo. A sessão do navegador permanece quando houve fallback real por 401/403/HTML. A WebView só é liberada para uma abertura inteiramente pública depois do primeiro quadro **e** de todas as faixas estarem prontas.
- Cookies da sessão não são enviados pelo caminho HTTP público. Os diagnósticos registram estados, dimensões, contadores e identificadores aleatórios, sem URLs de mídia ou credenciais.

## Decisões e revisão

Mantido Media3 e composição nativa por SurfaceView. Não houve troca por bibliotecas de reprodução paralelas nem aumento indiscriminado de buffer: continuam os limites de 10–30 s / 24 MiB. O módulo de efeitos foi alinhado à versão 1.9.2 já resolvida no projeto para as demais dependências Media3.

A validação física intermediária reproduziu timeout ao liberar o decodificador anterior na primeira ativação. Os callbacks agora conferem a identidade da sessão; uma falha de release antiga não encerra sua substituta. O prazo de liberação foi ajustado para 2 s, diante de encerramentos observados acima do padrão de 500 ms. A revisão de foco considerou a alternância entre toque, painéis e D-pad.

O teste intermediário também mediu aproximadamente 60 MiB disponíveis com a página completa do provedor retida. Ao liberar a página numa abertura pública, foram observados aproximadamente 135 MiB disponíveis. São amostras do dispositivo inteiro, não uma medição isolada de alocação nem promessa de ganho fixo.

## Validação automatizada executada

- Sete testes JVM em `TvPlaybackOptionsTest`: somente resoluções suportadas, fonte 240p, disponibilidade real de 1080p, deduplicação, limite de brilho e condições de liberação/retenção do navegador. Resultado: 7 passaram, 0 falhas/erros.
- `flutter test --no-pub test/tv_source_quality_label_test.dart test/stream_resolver_test.dart test/castlite_entrypoints_test.dart`, em `cinemax/`: 14 passaram, incluindo os dois fluxos CastLite exercitados.
- `flutter test --no-pub test/native_playback_bridge_test.dart`, em `cinemax_tv/`: 1 passou. O contrato Flutter/nativo de abertura, ready e posição continua exercitado.
- Três suítes JavaScript de transporte, observação HLS e navegação TV: 18 passaram.
- `flutter analyze --no-pub`, nos hosts Mobile e TV: sem problemas nas execuções desta etapa.
- Análise focal dos dois arquivos do núcleo alterados: sem problemas. Formatação do novo teste Dart conferida; `git diff --check` sem erros de whitespace. Há aviso Git de normalização LF/CRLF no script PowerShell.
- Builds Android release locais com `-NativeTests` concluídos. Gradle mantém avisos existentes de APIs depreciadas; não foram apresentados como erros de compilação.

Os testes iniciais de política/rótulos foram executados antes da implementação e falharam por comportamento ausente. Os testes de retenção foram acrescentados após reproduzir a pressão de memória fisicamente. Não foi executada nem certificada a suíte Flutter inteira do repositório nesta entrega.

## Evidência visual de brilho

Com Shrek 2 pausado na mesma cena e controles visíveis, a luminância digital média ponderada de uma região estática (`x=25..500`, `y=70..300`) foi:

| Estado | Luminância média na captura (escala 0–255) |
|---|---:|
| Original | 3,98 |
| Brilho +40 | 16,63 |
| Original restaurado | 3,98 |

Essa comparação verifica transformação/restauração dos pixels capturados; não mede nits do painel nem calibração fotométrica. Capturas em `outputs/tv-qualidade-brilho-2026-10-29/`: `final-original.png`, `final-brilho40.png`, `final-original-restaurado.png`. A comparação foi feita no build de validação `1CDB704E60ABBC66CD3E1211BA71B23A794A80A59D379EA2FB052B8F00254415`, antes dos ajustes posteriores exclusivos de interação/foco/cores.

## Disponibilidade e qualidade das fontes

O teste anterior de Shrek 2 confirmou 720p no EmbedMovies e 240p no SuperFlix principal. O manifesto do SuperFlix anunciado ao player tinha uma única variante 426 × 240. O alternativo foi aberto pela interface durante esta etapa, mas permaneceu carregando e não forneceu mídia resolvida no intervalo observado. Não foi inventada uma variante 1080p. Outros títulos ou players internos podem oferecer outras faixas.

Opções 1080p são cobertas por fixture JVM de faixas suportadas; uma fonte real 1080p ainda não foi confirmada fisicamente nesta sessão. O limite da fonte continua sendo uma condição externa.

## Arquivos desta implementação

- `cinemax_tv/android/app/src/main/kotlin/com/cinemax/cinemax/NativeTvPlayerActivity.kt`: integração de controles, brilho, ciclo de vida e prontidão.
- `TvPlayerControls.kt` e `TvPlaybackOptions.kt`, na mesma pasta: interface nativa e políticas.
- `MainActivity.kt` e `SessionHttpDataSource.kt`, na mesma pasta: retenção condicional e transporte público/autenticado.
- `cinemax_tv/android/app/src/test/kotlin/com/cinemax/cinemax/TvPlaybackOptionsTest.kt`: testes JVM.
- `cinemax_tv/android/app/build.gradle.kts`: Media3 consistente e JUnit.
- `packages/ciney_core/lib/plugin_engine/runtime/stream_resolver.dart` e `features/details/presentation/widgets/server_selection_sheet.dart`: rótulos honestos.
- `cinemax/test/tv_source_quality_label_test.dart` e `stream_resolver_test.dart`: regressões de rótulos/seleção.
- `scripts/build-local-mobile-tv.ps1`: opção `-NativeTests` para validar o player junto do build local.
- Plano, este relatório, continuidade em `Codex.md` e evidências nas respectivas pastas.

Alterações locais anteriores foram preservadas. Backup dos arquivos relevantes antes desta etapa em `.work/recovery/before-tv-quality-brightness-2026-10-29/`. Os testes antigos e o diagnóstico de Shrek 1 permanecem como histórico; seus resultados não são misturados aos builds desta entrega.

Skills aplicadas: `brainstorming`, `flutter-expert`, `systematic-debugging`, `test-driven-development`, `lint-and-validate`, `code-review-checklist`, `api-contract-testing` e `auth-implementation-patterns`.

## Validação prolongada

Em andamento. Os resultados e o hash do APK final serão registrados após a execução no aparelho.
