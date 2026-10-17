# Publicação mobile e TV 1.0.43 — 17/10/2026

Publicação dos dois aplicativos autorizada pelo usuário, mantendo pendentes as
correções do relatório de segurança. Nenhuma migração ou configuração remota de
segurança foi alterada neste lançamento.

As tags `v1.0.43` e `tv-v1.0.43` apontam para o commit da `main`
`6826e389331413cf164c128c22e5054a57617a36`.

| Variante | Pacote | Versão / build | APK | Tamanho |
| --- | --- | --- | --- | --- |
| Mobile | `com.ciney.app` | 1.0.43 / 40 | `CiNey-v1.0.43.apk` | 92.001.098 bytes |
| TV | `com.ciney.tv` | 1.0.43 / 45 | `CiNey-v1.0.43-TV.apk` | 63.366.110 bytes |

## Alterações

- Notificações ganhou 16 dp de espaçamento abaixo do cartão de perfil no mobile.
- O motor CastLite incorporado ao mobile transfere mídia continuamente, usa
  spool em disco para o caminho WebView e permite retomada de bytes quando o
  servidor atende ao Range e aos validadores exigidos.
- Preservadas as variantes de qualidade; melhorada a seleção de áudio português
  nas playlists compatíveis.
- Recuperação de carregamentos e sessões Google Cast, preservando posição e
  respeitando pausa e conclusão da mídia.
- A variante TV recebeu atualização de versão/build. Ela não incorpora o motor
  CastLite do mobile nem apresenta a opção mobile de notificações push.

Notas públicas: [Mobile](../../releases/notes/1.0.43-mobile.md) e
[TV](../../releases/notes/1.0.43-tv.md).

## Verificação

- [CI](https://github.com/NeyvanSantos/CINEY/actions/runs/39045677167)
  aprovado: análise mobile/TV sem erros, 173 testes Flutter, 40 testes JavaScript
  de embeds e 13 testes do servidor.
- Motor CastLite: tarefa Gradle `:castlite_engine:testDebugUnitTest --offline`
  concluída; resultados locais de 80 testes sem falhas, reutilizados pelo cache
  da tarefa. Os 11 testes JavaScript do observador foram executados e passaram.
- Parser de certificados aprovado em oito casos por workflow, incluindo saída
  `V2 Signer`, assinantes divergentes e assinatura inválida.
- [Workflow mobile](https://github.com/NeyvanSantos/CINEY/actions/runs/39045824857)
  e [workflow TV](https://github.com/NeyvanSantos/CINEY/actions/runs/39045825000)
  concluídos com sucesso.
- Downloads publicados comparados com digest do GitHub, checksum `.sha256`,
  tamanho, assinatura e metadados de pacote/versão/build.
- Certificado único oficial em ambos:
  `5eb48ea48dcd267a2996f162624e8fc64442d362a45d6f5439f0a28c7e8900be`.
- ARMv7, ARM64 e x86_64 presentes; Android mínimo API 26. Downloads públicos
  retornaram HTTP 200 sem autenticação.
- Canal mobile confirmado em `v1.0.43`, estável e Latest; canal TV confirmado em
  `tv-v1.0.43`, pré-release pública, como exige o atualizador TV existente.

## RustDroid e limites

Foi reutilizado o painel RustDroid da janela existente, no AVD
`CiNey_Android14`, `emulator-5554`.

- Mobile oficial atualizado por cima de 1.0.42 para 1.0.43+40, com sessão
  preservada. Conferidas a separação visual do cartão e a abertura de Notificações.
- O início da opção Notificações passou de y=609 para y=637 na árvore de
  acessibilidade: diferença de 28 px, correspondente aos 16 dp neste dispositivo.
- APK TV 1.0.43+45 instalado temporariamente no mesmo AVD Phone e abriu sua tela
  de entrada. Foi enviado um comando de D-pad e capturada a árvore resultante;
  isso não comprova toda a navegação. A instalação temporária TV foi removida,
  pois não existia nesse AVD antes do teste. O mobile foi deixado aberto.
- A troca para `Television_1080p` foi recusada pelo bridge RustDroid por existir
  outra sessão ativa. Não foi aberta outra janela do editor nem alterada a extensão.
  **Não houve teste deste APK em AVD Android TV nesta publicação.**
- Sem teste de reprodução/transmissão em receptor físico. Os ensaios anteriores
  do motor, com 17 verificações no Android e fixtures sintéticas, estão descritos
  em `artifacts/rustdroid-cast-2026-10-17/README.md` e não comprovam reprodução
  em TV real.

Logs, downloads, assinaturas, metadados e capturas desta publicação estão em
`%TEMP%/ciney-release43/`. As cópias para instalação ficam em `releases/mobile/`
e `releases/tv/`; a versão anterior de cada pasta foi movida para o diretório
temporário de evidências. Nenhuma release anterior foi removida do GitHub.

```text
c13fd65e30aadba890237968f113953e9de0d63460e63174f4ab2e3326823946  CiNey-v1.0.43.apk
b63bb8f5574715626c6bce455cafc2588e5bb9e116e25d03215d39c2555a350e  CiNey-v1.0.43-TV.apk
```

## Downloads

- [Mobile 1.0.43](https://github.com/NeyvanSantos/CINEY/releases/download/v1.0.43/CiNey-v1.0.43.apk)
- [Android TV 1.0.43](https://github.com/NeyvanSantos/CINEY/releases/download/tv-v1.0.43/CiNey-v1.0.43-TV.apk)
