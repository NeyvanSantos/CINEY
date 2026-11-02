# Publicação oficial Android TV 1.0.49 — 01/11/2026

Publicação solicitada explicitamente apenas para Android TV. O Mobile permanece
em 1.0.48+45, sem novo APK, tag ou release. O endpoint `/releases/latest`
continua apontando para `v1.0.48` Mobile.

## Artefato publicado e conferido

| Campo | Valor |
| --- | --- |
| Tag | `tv-v1.0.49` |
| Commit da tag | `ec70796` |
| Commit das correções | `5ab0bc1` |
| Pacote | `com.ciney.tv` |
| Versão/build | `1.0.49+51` |
| Asset | `CiNey-v1.0.49-TV.apk` |
| Tamanho | 63939502 bytes |
| SHA-256 | `87e0a92fda4010c2349e872c628c9a403dd1bb9fd93fb981569a3461dae5e1e3` |
| Certificado SHA-256 | `5eb48ea48dcd267a2996f162624e8fc64442d362a45d6f5439f0a28c7e8900be` |
| Arquiteturas | `armeabi-v7a`, `arm64-v8a`, `x86_64` |
| Estado | Publicada, sem draft e sem prerelease |
| Autoria da release | `NeyvanSantos` |

[Download oficial](https://github.com/NeyvanSantos/CINEY/releases/download/tv-v1.0.49/CiNey-v1.0.49-TV.apk)
e [página da release](https://github.com/NeyvanSantos/CINEY/releases/tag/tv-v1.0.49).

Foi preparado um rascunho pela conta oficial, e o workflow anexou o APK assinado
e seu checksum, publicando-o somente depois da validação e compilação.
`make_latest: false` preservou a referência Mobile. As notas finais descrevem
as correções e a migração do canal de atualizações.

O publicador `node scripts/publish-tv.js 1.0.49` conferiu tamanho e SHA-256 do
download antes de substituir a cópia TV anterior. A conferência local repetiu
o hash e executou `apksigner verify --print-certs` e `aapt dump badging`,
confirmando assinatura, pacote, versão e arquiteturas. A cópia de distribuição
está em `releases/tv/`, com um único APK. O APK Mobile 1.0.48 manteve o hash
`95cb5975d7028d90f9c6b1e6e1f3d4c9e8adaa6340856af4e24ed156939d9263`.

## Correções incluídas

- Confirmação da parada do provedor antes de iniciar o player nativo, guarda
  contra autoplay tardio e pausa visual do WebView durante reprodução nativa.
- Persistência explícita dos cookies emitidos pelo provedor antes do handoff
  e liberação, sem alterar sua validade.
- Cursor e seleção do SuperFlix protegidos de camadas invisíveis de anúncios.
- Atualizador TV aceita e prioriza releases oficiais publicadas. Se não houver
  nenhuma oficial, mantém compatibilidade com as pré-releases antigas. Rascunhos
  e tags Mobile continuam separados. O comportamento do canal Mobile foi mantido.

O filtro antigo da TV ignorava lançamentos oficiais: duas regressões foram
observadas antes da correção e os nove testes de atualização/integridade passaram
depois. Versões TV antigas, inclusive 1.0.48, podem não detectar esta release;
é necessário baixar e instalar manualmente o APK para migrar ao canal oficial.

## Validação do commit publicado

[GitHub Actions — execução 41364959601](https://github.com/NeyvanSantos/CINEY/actions/runs/41364959601)
concluída com sucesso. O job de compilação usou o SHA retornado pelo job de
validação da tag.

| Verificação | Resultado |
| --- | --- |
| Análises Flutter Mobile, TV e core | Sem problemas |
| Flutter Mobile, incluindo testes compartilhados da TV | 202 aprovados |
| JavaScript de embeds, HLS, navegação e transporte | 67 aprovados |
| Política de notificações | 13 aprovados |
| Core Flutter | 17 aprovados |
| Host TV | 1 aprovado |
| Player engine | TypeScript aprovado, 9 testes e 1 integração aprovados |
| Nativo CastLite | BUILD SUCCESSFUL |
| Nativo TV | BUILD SUCCESSFUL |
| Compilação release e certificado | Aprovados |
| Download, SHA-256, assinatura e metadados | Aprovados |

## Limites conhecidos

Os testes físicos anteriores e suas limitações permanecem nos relatórios de
[fechamento](../correcao-fechamento-thor-2026-11-01.md),
[sessão](../preservacao-sessao-webview-2026-11-01.md) e
[cursor](../correcao-cursor-superflix-2026-11-01.md). A verificação humana
Cloudflare após reabrir a página impediu a última confirmação do cursor no APK
de teste; não foi respondida automaticamente. A memória gráfica da TV continua
alta, e não foi assistido o filme inteiro. A instalação do APK oficial 1.0.49 na
TV não fez parte desta publicação.

Arquivos de versão e inventário: `cinemax_tv/pubspec.yaml` e `releases/README.md`.
O código, testes e relatórios das correções foram consolidados no commit indicado.
Nenhuma dependência ou credencial foi alterada; o projeto permanece organizado,
com as validações executadas aprovadas.

Habilidades AAS utilizadas: `github-actions-templates`, `lint-and-validate`,
`secrets-management`, `systematic-debugging`, `flutter-expert`,
`test-driven-development`, `api-contract-testing` e `code-review-checklist`.
