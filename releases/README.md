# APKs locais

Esta pasta deve guardar **somente o último APK publicado de cada variante** para
instalação local. Os binários são ignorados pelo Git e não acompanham um clone
do repositório.

| Variante | Pasta | Último lançamento mantido nesta organização |
| --- | --- | --- |
| Mobile | `mobile/` | `CiNey-v1.0.20.apk` |
| Android TV | `tv/` | `CiNey-v1.0.23-TV.apk` |

As cópias anteriores `mobile/CiNey-v1.0.18.apk` e `tv/CiNey-v1.0.21-TV.apk`
ainda aguardam limpeza: a revisão automática bloqueou a exclusão local nesta
publicação anterior. Os APKs 1.0.19 e 1.0.22 foram substituídos pelos novos
lançamentos. Confira a [verificação da publicação](../docs/publicacao-2026-10-08-v20.md).

Ao guardar uma nova versão publicada, substitua apenas o APK anterior da mesma
variante e atualize a tabela. Mantenha um único APK em cada pasta, com o nome
correspondente ao asset publicado. Não acumule cópias na raiz, dentro dos
projetos Flutter ou em pastas de build.

O histórico completo de versões e seus downloads permanece nas
[releases oficiais do GitHub](https://github.com/NeyvanSantos/CINEY/releases).
A limpeza local não remove releases, tags ou arquivos do GitHub.

Esta pasta armazena downloads; builds e publicações seguem a
[política de builds e releases](../cinemax/regras/04-politica-build-e-releases.md).
