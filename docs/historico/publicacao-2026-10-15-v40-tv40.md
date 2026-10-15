# Publicação mobile e TV 1.0.40 — 15/10/2026

Publicação para todos autorizada explicitamente pelo usuário após a integração
CastLite e a separação entre mobile, TV e `packages/ciney_core`.

Código publicado: commit `ec106cf1799d8504ba91374d6b66e7a51e1f4e30`, na `main`.
As tags mobile e TV apontam para esse mesmo commit.

| Variante | Pacote | Versão / build | APK universal | Tamanho |
| --- | --- | --- | --- | --- |
| Mobile | `com.ciney.app` | 1.0.40 / 37 | `CiNey-v1.0.40.apk` | 91.417.629 bytes / 87,18 MiB |
| TV | `com.ciney.tv` | 1.0.40 / 42 | `CiNey-v1.0.40-TV.apk` | 63.368.937 bytes / 60,43 MiB |

Ambos exigem Android 8 (API 26) e incluem ARMv7, ARM64 e x86_64. Usam a
assinatura oficial, sem sufixo de teste nem alteração dos IDs instalados.

## Verificação

- [CI](https://github.com/NeyvanSantos/CINEY/actions/runs/38772869328): concluída com sucesso; análise mobile/TV, testes Flutter e JavaScript aprovados. A validação local registrou 171 testes Flutter e 40 JavaScript.
- [Workflow mobile](https://github.com/NeyvanSantos/CINEY/actions/runs/38773199918): compilação, certificado e publicação concluídos com sucesso.
- [Workflow TV](https://github.com/NeyvanSantos/CINEY/actions/runs/38773199751): compilação, certificado e publicação concluídos com sucesso.
- O parser do certificado passou em oito casos por workflow: formatos numerado e V2, repetição do mesmo certificado, certificados distintos, incorreto, ausente, assinatura inválida e linha sem prefixo.
- APKs baixados do GitHub, com tamanho e SHA-256 iguais aos assets e respectivos arquivos `.sha256`.
- Metadados dos APKs, Android mínimo, arquiteturas e assinatura v2 conferidos com `aapt` e `apksigner`.
- Um único certificado oficial em ambos: `5eb48ea48dcd267a2996f162624e8fc64442d362a45d6f5439f0a28c7e8900be` (SHA-256).
- Activity CastLite presente somente no mobile. TV sem câmera, `FOREGROUND_SERVICE_CONNECTED_DEVICE`, modelos de scanner ou asset nativo do observador CastLite; assets do núcleo presentes.
- Downloads públicos retornaram HTTP 200 sem autenticação. `/releases/latest` aponta para `v1.0.40`; a seleção pública TV aponta para `tv-v1.0.40`.
- Notas de cada versão atualizadas a partir de `releases/notes/1.0.40-mobile.md` e `releases/notes/1.0.40-tv.md`.

SHA-256 dos APKs:

```text
d219a24cb11f25a2c2e08b2aba3ad2ce0e2f6801f6b0a8890f9e12460c73e408  CiNey-v1.0.40.apk
a7c9b413389248e806fffbf07a0914d823f0bb3decf53249e4142553d51bf3d4  CiNey-v1.0.40-TV.apk
```

## Canais e downloads

- Mobile: [release v1.0.40](https://github.com/NeyvanSantos/CINEY/releases/tag/v1.0.40), [APK](https://github.com/NeyvanSantos/CINEY/releases/download/v1.0.40/CiNey-v1.0.40.apk).
- TV: [release tv-v1.0.40](https://github.com/NeyvanSantos/CINEY/releases/tag/tv-v1.0.40), [APK](https://github.com/NeyvanSantos/CINEY/releases/download/tv-v1.0.40/CiNey-v1.0.40-TV.apk).

A release mobile é estável. A TV mantém `prerelease: true`, como exigido pelos
atualizadores TV já distribuídos; é o canal público de atualização dessa
variante. Marcar essa release TV como estável a retiraria desse canal e poderia
interferir no `/latest` usado pelo mobile.

Os APKs oficiais baixados foram guardados em `releases/mobile/` e
`releases/tv/`, substituindo somente os instaladores anteriores da respectiva
variante. Os APKs privados e divididos por arquitetura continuam separados em
`outputs/`. Os logs e metadados da auditoria ficam em
`.work/dependency-separation/`, ignorado pelo Git.

## Limite da validação

A interface e a navegação foram conferidas no BlueStacks usando os pacotes
privados da fase local. Não foi feito teste de atualização dos pacotes oficiais
instalados nem de reprodução em TV física nesta publicação. Imagem, áudio,
legendas, desempenho e transmissão por protocolo ainda dependem dessa
validação; os testes e a assinatura não comprovam esses comportamentos.
