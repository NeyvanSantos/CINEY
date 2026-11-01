# Publicação oficial Mobile e TV 1.0.48 — 01/11/2026

Publicação solicitada explicitamente pelo usuário. As correções locais de catálogo,
busca, extensões, histórico, player e CastLite foram consolidadas no commit
`871a8ad`. Os publicadores oficiais incrementaram as versões e enviaram main e tags.

| Variante | Tag | Pacote | Build | Asset | Bytes | SHA-256 |
| --- | --- | --- | --- | --- | --- | --- |
| Mobile | `v1.0.48` | `com.ciney.app` | 45 | `CiNey-v1.0.48.apk` | 91962200 | `95cb5975d7028d90f9c6b1e6e1f3d4c9e8adaa6340856af4e24ed156939d9263` |
| TV | `tv-v1.0.48` | `com.ciney.tv` | 50 | `CiNey-v1.0.48-TV.apk` | 63938749 | `67042a324c544e31f71d12c22697840cbd806622baf0d8d830c3b118642c5b68` |

Ambas foram publicadas sem draft e sem prerelease. A TV usa `make_latest: false`;
o endpoint `/releases/latest` foi conferido e retorna `v1.0.48` Mobile.
Os dois APKs incluem `armeabi-v7a`, `arm64-v8a` e `x86_64`.

## Validação e assinatura

- Análise Flutter de Mobile, TV e core sem problemas no GitHub Actions.
- Mobile: 198 testes; core: 17; host TV: 1.
- JavaScript de embeds: 59; política de notificações: 13.
- Player engine: TypeScript validado, 9 testes e 1 teste de integração aprovados.
- Gradle: testes nativos CastLite e TV com `BUILD SUCCESSFUL` nos dois fluxos.
- Builds release concluídos, com certificado conferido antes da publicação.
- Downloads conferidos contra tamanho remoto, digest do asset e arquivo `.sha256`.
- `apksigner verify --print-certs` e `aapt dump badging` executados localmente.
- Certificado SHA-256 de ambos, igual aos APKs oficiais 1.0.47 e à variável do
  repositório: `5eb48ea48dcd267a2996f162624e8fc64442d362a45d6f5439f0a28c7e8900be`.
- Cópias anteriores substituídas em `releases/mobile/` e `releases/tv/`, mantendo
  somente o último APK de cada variante.

## Falha inicial e retomada

A validação inicial bloqueou corretamente a publicação: `bash gradlew` falhou
porque os wrappers Android dos hosts Flutter são ignorados pelo Git. O commit
`fc85b5a` acrescentou `flutter build apk --debug --config-only --no-pub` antes dos
testes nativos, preparando wrapper e configuração sem gerar APK nessa etapa.

As tags não foram movidas nem sobrescritas. Os workflows foram acionados a partir
da main corrigida, com `version_tag` apontando para as tags originais. O CI validou
o código dessas tags e os jobs de publicação usaram o SHA retornado pela validação.

- [Mobile: execução](https://github.com/NeyvanSantos/CINEY/actions/runs/41331742963)
- [TV: execução](https://github.com/NeyvanSantos/CINEY/actions/runs/41331745383)
- [Release Mobile](https://github.com/NeyvanSantos/CINEY/releases/tag/v1.0.48)
- [Release TV](https://github.com/NeyvanSantos/CINEY/releases/tag/tv-v1.0.48)

## Limitações

A análise Mobile local passou, mas `flutter test --no-pub` local não iniciou
devido a uma referência de cache ao disco inexistente `X:`. As suítes completas
passaram nos ambientes limpos do GitHub. Não houve instalação ou teste físico
dos APKs oficiais nesta publicação; permanecem os limites de validação de
provedores e dispositivos registrados nos relatórios anteriores. O npm reportou
duas vulnerabilidades nas dependências do player engine (uma baixa e uma
moderada); não foram alteradas dependências nesta publicação.

Habilidades AAS utilizadas: `github-actions-templates`, `lint-and-validate`,
`secrets-management` e `systematic-debugging`.
