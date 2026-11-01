# Busca e controles da TV — 31/10/2026

## Diagnóstico e correções

1. **Navegação da busca (alta, confirmada).** O campo de pesquisa não encaminhava explicitamente a seta para baixo aos resultados. Foram adicionados nós de foco por resultado, navegação direcional da grade e retorno ao campo pela primeira linha. Se a busca estiver carregando, a seleção aguarda a resposta atual. Arquivo: `packages/ciney_core/lib/features/search/presentation/search_screen.dart`.
2. **Capas pequenas dentro de células grandes (média, confirmada).** A largura padrão do `GradientPoster` não acompanhava a célula da grade. A busca agora calcula colunas conforme a largura da TV e passa dimensões proporcionais ao pôster. O componente aceita foco externo sem alterar suas dimensões globais. Arquivos: `search_screen.dart` e `core/widgets/gradient_poster.dart`.
3. **Resultados duplicados e ordenação (média, confirmada).** O mesmo identificador TMDB aparecia uma vez por provedor e a equivalência entre “e” e “&” não era considerada na relevância. A busca elimina duplicatas pelo identificador canônico e prioriza correspondências normalizadas. Filmes diferentes com nomes iguais continuam separados; a deduplicação das categorias da página inicial permanece independente. Arquivos: `plugin_manager.dart` e `tmdb_service.dart`.
4. **Controles persistentes no player (média, confirmada antes da correção).** A pausa e o foco nos botões mantinham o controlador visível indefinidamente. O player passou a usar um temporizador de inatividade de cinco segundos, renovado por interação e suspenso durante arraste. Os painéis também são recolhidos. Arquivos nativos: `NativeTvPlayerActivity.kt`, `TvPlayerControls.kt` e novo `TvControlsAutoHide.kt`.

## Validação automatizada

- Mobile: 197 testes aprovados, incluindo três testes de navegação/layout da busca na TV.
- Core: 17 testes aprovados, incluindo relevância e deduplicação da busca.
- TV nativa: 14 testes aprovados, incluindo quatro testes do temporizador de controles.
- Host TV: um teste aprovado. Integração JavaScript: 59 testes aprovados.
- Análise Flutter de Mobile, TV e core sem problemas; `git diff --check` aprovado.
- Testes de regressão reproduziram as falhas de foco, dimensão dos pôsteres, ordenação e duplicação antes das respectivas correções.

## Verificação no aparelho

Smart TV C06, Android 11, ARM de 32 bits. A versão de teste instalada é `com.ciney.tv.lite_test`, separada da aplicação oficial. APK local: `outputs/CiNey-TV-Leve-teste-armeabi-v7a.apk`, SHA-256 `C993BCF2ED6270FB60A117A1BF309E8D30A2CE6E14CA17AA8B7FB1B5640358C9`.

- Busca por “Velozes e Furiosos 10”: dois resultados distintos, com o filme de 2023 primeiro e capas preenchendo as células. Com o teclado recolhido, seta para baixo seleciona o primeiro filme; OK abre os detalhes de “Velozes & Furiosos 10”, de 2023.
- O teclado Android recebe as setas enquanto está aberto. Voltar recolhe o teclado; para baixo passa então aos filmes. Voltar ao campo pela seta para cima pode reabrir o teclado. Não se afirma que as setas naveguem nos filmes enquanto o teclado do sistema está ativo.
- Evidências locais: `outputs/tv-correcoes-2026-10-31/busca-banners-antes.png`, `busca-foco-real.png` e `busca-abre-filme.png`.
- Antes desta atualização, o mesmo filme reproduziu pelo EmbedMovies no player nativo, em 1728 × 720, com primeiro quadro registrado. A persistência dos controles após pausa foi registrada em `controles-apos-pausa-antes.png`. Isso não equivale à validação física dos controles após a correção.

## Limitações e pendências

### Ajuste posterior: barra do player WebView

A barra “Ir ao player / Recarregar / Servidores” é independente dos controles nativos. O prazo de abertura de 25 segundos podia exibi-la e não havia recolhimento por inatividade. Em `tv_embed_player.dart`, foi acrescentado recolhimento após cinco segundos, renovado por teclas e toques. Menu/Voltar permitem acessar novamente as ações; quando o provedor foi encerrado, as opções de recuperação permanecem disponíveis. O temporizador é cancelado ao liberar o player.

O novo teste de regressão falhou antes da mudança pela permanência de “Servidores” e passou depois; os 13 testes de `tv_embed_player_test.dart` e a suíte Mobile completa de 198 testes passaram. `flutter analyze --no-pub` passou em Mobile e TV, assim como `git diff --check` nos arquivos desta alteração. Arquivos alterados nesta etapa: `tv_embed_player.dart`, `cinemax/test/tv_embed_player_test.dart` e este relatório. Esta alteração posterior ainda não está incluída no APK identificado acima e não foi validada fisicamente na TV.

- Não foi assistido o filme inteiro. Não se declara validada a recuperação de HTTP 401/403, pois esses erros não ocorreram na sessão observada.
- Na versão nova, o filme voltou a reproduzir em 1728 × 720. Após a pausa, a captura `pausa-depois.png` confirmou o vídeo sem controles e o log registrou `controls=hidden reason=inactivity panel=null paused=true`. A validação física completa dos ajustes de brilho e qualidade permanece pendente; o temporizador compartilhado possui testes unitários e compilação de release aprovados.
- A versão de teste ainda recebe o aviso de atualização destinado ao aplicativo oficial. O aviso foi dispensado; não foi executada atualização da versão oficial.
- Não foram instaladas dependências novas, nem feitos commits, push ou publicação.

Habilidades AAS utilizadas: systematic-debugging, flutter-expert, test-driven-development, lint-and-validate e code-review-checklist; ui-review como apoio à revisão de foco e layout. A habilidade ui-a11y foi examinada, mas seu escopo específico de StyleSeed não se aplica a este aplicativo.
