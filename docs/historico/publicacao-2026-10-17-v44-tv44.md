# Publicação mobile e TV 1.0.44 — 17/10/2026

Publicação dos dois aplicativos autorizada pelo usuário. Tags `v1.0.44` e
`tv-v1.0.44` no commit `ec37799cd022b31bc7d4a887e10b85fb3e9a0d3d` da `main`.

## Correção

O ADB registrou aceite do carregamento às 18:03:04, consultas à playlist e aos
segmentos com HTTP 200, e falha `Invalid Request` / `IDLE idleReason=4` às
18:03:10. O caminho HTTP direto repassava `application/javascript` para segmentos
HLS, enquanto somente o caminho WebView identificava o conteúdo de vídeo.

O relay agora identifica TS, MP4 e WebVTT pelo conteúdo nos dois transportes.
Consultas HEAD de recursos HLS usam uma leitura inicial do corpo na origem e
respondem sem corpo ao receptor, com o mesmo tipo de mídia do GET. O prefixo é
reposto no fluxo para não perder bytes. Cabeçalhos, cookies e Range são preservados.

Mobile: `com.ciney.app`, 1.0.44+41. TV: `com.ciney.tv`, 1.0.44+46.
A variante TV acompanha a versão; ela não incorpora o motor CastLite mobile.

## Verificações locais

- 81 testes Gradle do motor nativo executados, sem falhas.
- 11 testes JavaScript do observador aprovados.
- APK debug integrado compilado com sucesso.
- `git diff --check` sem erros.
- Workflows e parser de assinatura preservados; evidências dos oito casos por
  workflow mantidas com os arquivos da publicação.

O celular desconectou do ADB antes da instalação. Não houve reteste da correção
em TV física ou emulador. Os testes automatizados não comprovam reprodução física.

Evidências e downloads: `%TEMP%/ciney-release44/`.

## Publicação verificada

- [CI](https://github.com/NeyvanSantos/CINEY/actions/runs/39069770330): aprovado,
  análise dos dois aplicativos sem problemas, testes Flutter, 40 testes JavaScript
  dos embeds e 13 testes do servidor aprovados.
- [Workflow mobile](https://github.com/NeyvanSantos/CINEY/actions/runs/39069818338)
  e [workflow TV](https://github.com/NeyvanSantos/CINEY/actions/runs/39069818386): sucesso.
- Downloads conferidos por tamanho, digest GitHub, arquivo `.sha256`, metadados
  do pacote e assinatura oficial única. ARMv7, ARM64 e x86_64 presentes.
- Oito casos do parser de certificado por workflow reexecutados e aprovados.
- Certificado SHA-256 de ambos:
  `5eb48ea48dcd267a2996f162624e8fc64442d362a45d6f5439f0a28c7e8900be`.
- Mobile estável e Latest; TV em pré-release pública, como exige seu atualizador.
- Downloads públicos sem autenticação: HTTP 200 em ambos.
- Cópias locais atualizadas em `releases/mobile/` e `releases/tv/`. Os APKs
  anteriores foram movidos para `%TEMP%/ciney-release44/previous-mobile/` e
  `previous-tv/`; nenhuma release remota anterior foi removida.

| Variante | Pacote | Versão / build | Tamanho |
| --- | --- | --- | --- |
| Mobile | `com.ciney.app` | 1.0.44 / 41 | 92.001.098 bytes |
| TV | `com.ciney.tv` | 1.0.44 / 46 | 63.366.111 bytes |

```text
d8113ef782d34613b38e2bd9c6becb183fcc0d6a66d22b802faf105e6e4c3c23  CiNey-v1.0.44.apk
6e5286d632bbbe96293cceab2bd54a6df90c7341f9294698db4e0c736b5e466c  CiNey-v1.0.44-TV.apk
```

## Downloads

- [Mobile 1.0.44](https://github.com/NeyvanSantos/CINEY/releases/download/v1.0.44/CiNey-v1.0.44.apk)
- [Android TV 1.0.44](https://github.com/NeyvanSantos/CINEY/releases/download/tv-v1.0.44/CiNey-v1.0.44-TV.apk)
