# Cursor e seleção de servidores do SuperFlix — 01/11/2026

## Causa confirmada na TV

Na tela de Thor: Ragnarok, `superflixapi.fun/filme/284053`, o menu estava
coberto por um anúncio invisível. A inspeção da página identificou um link
externo vazio para `budgetezy.org`, dentro de um DIV fixo que ocupava todo o
viewport (aproximadamente 961×541 CSS pixels), com `z-index: 2147483647`, fundo
preto e opacidade 0.01. O link e o contêiner capturavam o hit-test do ponteiro.

`__cineyTvPrepareMenu(document)` retornava false porque `elementFromPoint`
encontrava o anúncio em vez dos botões. A proteção contra interferência em
players e desafios escondia também o cursor nesse caso. Não era apenas
ausência de foco ou mudança da cor do ponteiro.

## Correção

Em `packages/ciney_core/assets/player/tv_remote_navigation.js`, o hit-test de
menus reconhecidos passa a desativar somente a captura de ponteiro de:

- links externos vazios, sem filhos, transparentes, sem imagem de fundo, que
  cobrem praticamente todo o viewport;
- contêineres DIV fixos, vazios, com opacidade até 0.05 e um único filho que
  corresponda ao link externo vazio.

A mudança usa `pointer-events: none`, sem seguir o anúncio ou remover a página.
Links do próprio provedor, links visíveis, imagens, iframes, players e domínios
Cloudflare não são tratados como essas camadas. A lógica continua restrita ao
menu reconhecido na origem e rota esperadas. Também se confirma o hit-test no
ponto do cursor antes de solicitar o toque nativo: um menu parcialmente coberto
não pode enviar o clique para outra camada.

## Testes e evidências

Em `cinemax/test/tv_remote_navigation_test.cjs`, as regressões para anúncio vazio
e clique indevido em menu parcialmente coberto falharam antes da correção.
O teste do contêiner de 1% de opacidade também falhou antes de esse segundo
nível ser tratado. A suíte cobre Principal, Alternativo, repetição de OK,
movimento do cursor, iframe sobre o menu, Cloudflare e conteúdo visível.

- Suíte JavaScript completa dos embeds, transporte, HLS e navegação: 67 aprovados.
- `flutter analyze --no-pub`: Mobile e TV sem problemas.
- Build local release, lint vital e 17 testes nativos release: aprovados.
- `git diff --check`: aprovado.
- Os testes Flutter de widget não foram repetidos nesta tarefa: a alteração
  produtiva é somente JavaScript, validada por sua suíte dedicada.

Na página original, a desativação temporária das duas camadas observadas fez
`__cineyTvPrepareMenu` retornar true. As setas moveram o cursor laranja com borda
branca do Principal até o Alternativo. A captura
`outputs/diagnostico-thor-2026-11-01/cursor-causa-confirmada.png` registra o cursor.
Essa etapa confirmou a causa na página real, antes da instalação final.

O APK com a correção permanente foi instalado com `adb install -r` no pacote
separado `com.ciney.tv.lite_test`, preservando dados. Ao reabrir o SuperFlix,
uma nova verificação Cloudflare exibiu erro de carregamento. Foi solicitada ao
usuário a confirmação humana para completar o teste do menu após a atualização.
Essa verificação não foi respondida nem alterada automaticamente.

SHA-256 do APK instalado:
`fa1916fdd58d7f2674239ef18ea552f35b9dbe856092428d724dabf92b3ac265`.

Não houve mudanças no código Dart/Kotlin/Java nesta tarefa, novas dependências,
commit, push, tag ou publicação oficial. As correções anteriores foram
preservadas; novos testes e documentação permanecem nas pastas do projeto.

Habilidades AAS: `systematic-debugging`, `flutter-expert`,
`test-driven-development`, `api-contract-testing`, `code-review-checklist` e
`lint-and-validate`. `ui-review` foi examinada, mas seu fluxo específico de
StyleSeed/Tailwind não se aplica a este script de navegação do player.
