# Publicação mobile e TV 1.0.45 — 20/10/2026

Publicação dos dois aplicativos autorizada pelo usuário. Mobile `com.ciney.app`,
versão 1.0.45+42; TV `com.ciney.tv`, versão 1.0.45+47.

## Alterações

- Mobile: Voltar e Trocar servidor ocultos no início dos embeds; um toque
  revela os botões por quatro segundos sem impedir a interação com o fornecedor.
- TV: observação HLS nos frames, preparação nativa com sessão preservada,
  foco laranja e navegação por D-pad nas opções de áudio e servidores.
- TV: entrega do foco ao fornecedor e recuperação por recarga/troca de fonte.
- O pacote debug de testes `com.ciney.tv.local` não modifica a identidade ou o
  canal de atualização da versão pública.

## Validação de reprodução anterior à publicação

[Relatório local](../tv-hls-validation-2026-10-20.md): HLS local AES-128 e
EmbedMovies reproduziram no AVD Android TV do RustDroid, com pausa, avanço e
retomada. O SuperFlix apresentou erro em `Object.init` no código do fornecedor;
sua reprodução não foi aprovada. Não houve teste em TV física.

## Publicação

- Commit das duas tags: `cdf5e3868a3cb3f100be3197bb7ee85743a01d61`.
- [CI](https://github.com/NeyvanSantos/CINEY/actions/runs/39520029377): sucesso.
  Análise mobile e TV sem problemas; 178 testes Flutter e 47 testes JavaScript
  também passaram localmente. A CI executou os testes de notificações existentes.
- [Workflow mobile](https://github.com/NeyvanSantos/CINEY/actions/runs/39520285293): sucesso.
- [Workflow TV](https://github.com/NeyvanSantos/CINEY/actions/runs/39520285437): sucesso.

Downloads públicos sem autenticação retornaram HTTP 200. Tamanho, digest
GitHub e arquivo `.sha256` conferidos nos dois APKs. Assinatura oficial única:
`5eb48ea48dcd267a2996f162624e8fc64442d362a45d6f5439f0a28c7e8900be`.
Ambos contêm ARMv7, ARM64 e x86_64; Android mínimo 26, sem flag de debug.

| Variante | Pacote | Versão / build | Tamanho | SHA-256 |
| --- | --- | --- | --- | --- |
| Mobile | `com.ciney.app` | 1.0.45 / 42 | 92.103.871 bytes | `222621eb3dbadb249df8077fb99cd9fb596435e2f1e89284615c9813e9ef3eab` |
| TV | `com.ciney.tv` | 1.0.45 / 47 | 63.616.744 bytes | `b7636a6f5cd9d2a7c410e9fff35790c2b1288e3141cc24c4c7370eb49dfe47a2` |

Mobile confirmado como estável e Latest; TV como pré-release pública, conforme
o filtro de seu atualizador. Autor das duas releases: `NeyvanSantos`.
As notas registram a limitação observada no SuperFlix.

Os APKs verificados estão em `releases/mobile/` e `releases/tv/`. As cópias
anteriores foram movidas para `%TEMP%/ciney-release45/previous-mobile/` e
`previous-tv/`; nenhuma release remota anterior foi removida.

## RustDroid com os APKs públicos

Mobile instalado por atualização no AVD `CiNey_Android14`, na mesma janela
VS Code do projeto. Pacote e versão 1.0.45+42 confirmados no Android. O catálogo
abriu com a sessão preservada. No player EmbedMovies, imagens da introdução
avançaram e os botões Voltar e Trocar servidor estavam inicialmente ocultos,
apareceram após um toque e voltaram a sumir sem interação. Capturas locais:
`outputs/release45-mobile-home.png`, `release45-mobile-controls-hidden.png`,
`release45-mobile-controls-visible.png` e `release45-mobile-controls-hidden-again.png`.
Esta observação não confirma o áudio nem a reprodução de um filme inteiro.

TV instalada por atualização no AVD `Television_1080p`, reutilizando a mesma
janela/painel do RustDroid. Pacote público e versão 1.0.45+47 confirmados.
O catálogo abriu com a sessão preservada. Somente teclas D-pad levaram ao
conteúdo e moveram o destaque laranja entre Principal, Alternativo e Dublado.
Capturas locais: `outputs/release45-tv-home.png`, `release45-tv-menu.png`,
`release45-tv-server-focus.png` e `release45-tv-audio-focus.png`.

Pelo menu de recuperação e pelo seletor de servidores, também operados com
D-pad, a fonte foi trocada para EmbedMovies. O HLS abriu no player nativo do
APK público com imagem e duração 02:25:00. O controle de mídia pausou em 00:27,
a seta direita avançou para 00:37 ainda pausado e a retomada levou a 00:41.
Capturas locais: `outputs/release45-tv-embedmovies.png`,
`release45-tv-native-pause.png`, `release45-tv-native-seek.png` e
`release45-tv-native-resume.png`. Não houve validação de áudio, filme inteiro
ou TV física nesta publicação.

## Downloads

- [Mobile 1.0.45](https://github.com/NeyvanSantos/CINEY/releases/download/v1.0.45/CiNey-v1.0.45.apk).
- [Android TV 1.0.45](https://github.com/NeyvanSantos/CINEY/releases/download/tv-v1.0.45/CiNey-v1.0.45-TV.apk).
