# APKs locais

Esta pasta deve guardar **somente o último APK publicado de cada variante** para
instalação local. Os binários são ignorados pelo Git e não acompanham um clone
do repositório.

| Variante | Pasta | Último lançamento mantido nesta organização |
| --- | --- | --- |
| Mobile | `mobile/` | `CiNey-v1.0.48.apk` |
| Android TV | `tv/` | `CiNey-v1.0.48-TV.apk` |

Os APKs anteriores foram substituídos após conferir os novos downloads, hashes
e assinatura oficial. Consulte a [verificação mobile e TV 1.0.45](../docs/historico/publicacao-2026-10-20-v45-tv45.md).

Ao guardar uma nova versão publicada, substitua apenas o APK anterior da mesma
variante e atualize a tabela. Mantenha um único APK em cada pasta, com o nome
correspondente ao asset publicado. Não acumule cópias na raiz, dentro dos
projetos Flutter ou em pastas de build.

O histórico completo de versões e seus downloads permanece nas
[releases oficiais do GitHub](https://github.com/NeyvanSantos/CINEY/releases).
A limpeza local não remove releases, tags ou arquivos do GitHub.

Esta pasta armazena downloads; builds e publicações seguem a
[política de builds e releases](../cinemax/regras/04-politica-build-e-releases.md).
