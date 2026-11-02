# Persistência da sessão do provedor no WebView — 01/11/2026

Solicitação: preservar uma verificação já concluída manualmente no SuperFlix.

## Diagnóstico e limites

O host já aceita cookies, permite cookies de terceiros e usa DOM storage. Não
foi encontrada limpeza de cookies ou de armazenamento local durante a troca de
servidor. O documento externo também mantém a mesma origem superior sintética
entre filmes. Não há evidência suficiente para atribuir toda nova solicitação
de CAPTCHA a uma perda de cookies pelo CiNey.

Faltava uma solicitação explícita para gravar os cookies do WebView no
armazenamento persistente antes do handoff e da liberação do provedor. Foi
acrescentada essa garantia de persistência, sem exportar valores ou alterar
cookies emitidos pelo servidor.

O [Cloudflare documenta](https://developers.cloudflare.com/cloudflare-challenges/challenge-types/challenge-pages/challenge-passage/)
que a validação pode ser representada por `cf_clearance` e tem duração definida
pelo responsável pelo site. O CiNey não altera esse prazo, não responde ao
desafio automaticamente e não reutiliza tokens descartáveis. Se o fornecedor
exigir nova confirmação, ela continua necessária. Cookies particionados e
domínios permanecem sob o controle normal do WebView. As instalações oficial e
de teste possuem dados separados.

## Alterações desta tarefa

- `packages/ciney_core/lib/features/player/tv/tv_embed_host.dart`: chama
  `persistSession` antes de preparar cabeçalhos para o player nativo e antes de
  remover o observador/liberar a página.
- `cinemax/packages/embed_media_observer/android/src/main/java/com/ciney/embedmedia/TvWebViewHandler.java`:
  implementa `persistSession` somente para WebViews anexados, usando
  `CookieManager.flush()`. Também tenta persistir antes da liberação do engine;
  falha nessa tentativa não impede a limpeza de recursos nem registra valores.
- `cinemax/test/tv_embed_player_test.dart`: teste da ordem dos comandos,
  idempotência da liberação e liberação mesmo com falha no armazenamento.

A [API Android](https://developer.android.com/reference/android/webkit/CookieManager#flush())
define `flush()` como a gravação no armazenamento persistente dos cookies
acessíveis pelo CookieManager. Não é feito backup próprio de cookies, alteração
de User-Agent, extensão da validade ou cópia entre domínios/perfis.

## Verificações

- O teste da ordem de persistência falhou antes da implementação, por não haver
  chamada `persistSession`, e passou depois. Uma primeira execução usou um mock
  com resposta de tipo incorreto; ele foi corrigido antes da falha comportamental
  usada como regressão.
- `flutter analyze --no-pub`: Mobile e TV sem problemas.
- `flutter test --no-pub`: Mobile, 200 aprovados; host TV, 1 aprovado.
- Gradle JDK 17, offline, testes nativos debug: 17 aprovados; Java compilado.
- Build local release com `-NativeTests`: 17 testes nativos e build aprovados.
- `git diff --check`: aprovado.

O APK ARM de teste foi instalado com `adb install -r` em
`com.ciney.tv.lite_test`, preservando dados, e o app foi aberto. SHA-256:
`fec0755d05673e8d1119be0be2e7b4df3ea5cd59145789f76a7f9be4e9ae8303`.
A instalação oficial foi preservada. Não foi realizada uma nova confirmação
Cloudflare nem comprovada a dispensa de desafios após reinicialização da TV.

Os testes de canal verificam a solicitação e a ordem da persistência; não
reproduzem o algoritmo de armazenamento do Chromium nem comprovam que o
Cloudflare dispensará um desafio futuro. Não foram lidos ou registrados valores
reais de cookies. A validação remota continua sendo decisão do provedor.

Habilidades AAS aplicadas: `systematic-debugging`, `flutter-expert`,
`auth-implementation-patterns`, `test-driven-development`, `api-contract-testing`,
`secrets-management`, `code-review-checklist` e `lint-and-validate`.

As correções anteriores do player foram preservadas. Não houve commit, push,
tag ou publicação oficial nesta tarefa. Os arquivos continuam nas pastas
existentes de fonte, testes e documentação.
