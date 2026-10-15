# Publicação mobile e TV 1.0.41 — 15/10/2026

Publicação dos dois APKs autorizada pelo usuário após a preparação das
notificações. Código na `main`: `e390fb67f6646df208e3d67cd9cd765b4f2d9566`.
As tags `v1.0.41` e `tv-v1.0.41` apontam para esse mesmo commit.

| Variante | Pacote | Versão / build | APK | Tamanho |
| --- | --- | --- | --- | --- |
| Mobile | `com.ciney.app` | 1.0.41 / 38 | `CiNey-v1.0.41.apk` | 92.003.330 bytes / 87,74 MiB |
| TV | `com.ciney.tv` | 1.0.41 / 43 | `CiNey-v1.0.41-TV.apk` | 63.369.031 bytes / 60,43 MiB |

Ambos mantêm a assinatura oficial, Android mínimo 8 / API 26 e as arquiteturas
ARMv7, ARM64 e x86_64. O Firebase está no mobile; o manifesto da TV continua
sem componentes Firebase ou Activity CastLite.

## Conteúdo

O mobile inclui Perfil → Notificações, preferências por categoria, registro do
aparelho associado à conta, teste individual e destinos permitidos ao tocar no
aviso. A TV recebe a atualização do núcleo compartilhado e mantém os avisos
dentro do aplicativo. As notas públicas estão em
[mobile](../../releases/notes/1.0.41-mobile.md) e
[TV](../../releases/notes/1.0.41-tv.md).

Na publicação, **os disparos automáticos gerais estavam desligados**. A verificação do
servidor retornou `configured: true`, `mode: off`, `validation_only: true`
durante esta publicação. O teste individual pode ser feito no mobile após
atualizar, entrar na conta e permitir notificações. Não houve teste físico de
entrega FCM nem de reprodução/transmissão em TV durante a publicação.

Ainda em 15/10/2026, o usuário confirmou o recebimento do aviso e autorizou a
ativação. O servidor passou a `NOTIFICATIONS_MODE=live`, com credencial validada
e worker executado com sucesso. As notas públicas foram atualizadas. Não foi
necessário gerar outro APK; os detalhes estão na
[documentação de notificações](../notificacoes-automaticas.md).

## Evidências

- [CI](https://github.com/NeyvanSantos/CINEY/actions/runs/38784812681): análise mobile/TV e testes aprovados no commit publicado.
- [Workflow mobile](https://github.com/NeyvanSantos/CINEY/actions/runs/38785118782): compilação, certificado e publicação concluídos com sucesso.
- [Workflow TV](https://github.com/NeyvanSantos/CINEY/actions/runs/38785118325): compilação, certificado e publicação concluídos com sucesso.
- Localmente: 173 testes Flutter, 40 testes JavaScript dos embeds e 13 testes do servidor passaram. O parser de certificado passou nos oito casos por workflow.
- APKs oficiais baixados; tamanho, SHA-256 do asset GitHub, arquivo `.sha256`, assinatura v2 e metadados conferidos com `aapt`/`apksigner`.
- Um único certificado em cada APK: `5eb48ea48dcd267a2996f162624e8fc64442d362a45d6f5439f0a28c7e8900be` (SHA-256), igual ao configurado no repositório e ao das versões oficiais anteriores.
- Downloads públicos retornaram HTTP 200 sem autenticação. O canal mobile `/releases/latest` aponta para `v1.0.41`; a seleção do canal TV aponta para `tv-v1.0.41`.
- Os arquivos foram guardados em `releases/mobile/` e `releases/tv/`, substituindo somente os APKs 1.0.40 locais correspondentes. Logs e metadados detalhados ficam em `.work/dependency-separation/release41-downloads/`, ignorado pelo Git.

SHA-256 dos APKs:

```text
038a391268e5b5bb6dde79e5ef64097f8daa1b7575e5d1cab08f8bb45cc51dbe  CiNey-v1.0.41.apk
6d3289bac99162edc5a528b845961aba1a9b7c9f257a1a6075f39e4f115cc9c1  CiNey-v1.0.41-TV.apk
```

## Downloads

- [Mobile 1.0.41](https://github.com/NeyvanSantos/CINEY/releases/download/v1.0.41/CiNey-v1.0.41.apk)
- [Android TV 1.0.41](https://github.com/NeyvanSantos/CINEY/releases/download/tv-v1.0.41/CiNey-v1.0.41-TV.apk)

A TV mantém `prerelease: true`, o canal público usado pelos atualizadores TV
existentes. O mobile permanece estável e como versão mais recente.
