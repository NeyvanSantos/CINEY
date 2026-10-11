# Publicação de 09/10/2026 — CiNey Mobile v1.0.21 e Android TV v1.0.24

O usuário autorizou a geração e publicação dos APKs de celular e Android TV.
As tags `v1.0.21` e `tv-v1.0.24` apontam para o lançamento oficial.

### Resumo das Melhorias Desta Versão:
- **Autenticação Android TV com 2 Modos:** Agora a tela de login na TV oferece a escolha clara e intuitiva entre pareamento via QR Code e entrada manual com usuário/senha.
- **Navegação D-Pad Corrigida no Login TV:** Seleção e foco visual 100% responsivos no controle remoto da TV tanto nos cards de seleção quanto na tela de pareamento e nos campos de entrada manual.
- **Otimização Extrema para Baixa Conexão (Poucos Megabits):**
  - Imagens de catálogo e backdrops do TMDB dimensionados especificamente para TV (`w342` posters e `w780` backdrops), reduzindo drasticamente o consumo de banda (>75% de economia).
  - Novo "Modo Poucos Megabits" (ativo por padrão na TV) com compressão gzip/deflate forçada nos cabeçalhos de streaming, timeouts estendidos para conexões instáveis e buffer de rede otimizado.

| Variante | Versão / build | Pacote | Tamanho em bytes |
| --- | --- | --- | --- |
| Celular | 1.0.21 / 23 | `com.ciney.app` | 87764108 |
| Android TV | 1.0.24 / 26 | `com.ciney.tv` | 87867700 |

### Hashes SHA-256 dos APKs Oficiais:

```text
CiNey-v1.0.21.apk
35c8d25906287f6fe375b63ee540bc2fe2512d65a970f39c26d059e009ddc229

CiNey-v1.0.24-TV.apk
5634a0bbba73bf298c429bb6143121a6feda83f497422a1dd42f37764b47847a
```

O endpoint `/releases/latest` aponta para `v1.0.21`. O canal da TV encontra
`tv-v1.0.24` como o pré-lançamento de maior versão com prefixo `tv-v`.
Os nomes dos APKs correspondem aos filtros do atualizador automático.

- [APK para celular](https://github.com/NeyvanSantos/CINEY/releases/download/v1.0.21/CiNey-v1.0.21.apk)
- [APK para Android TV](https://github.com/NeyvanSantos/CINEY/releases/download/tv-v1.0.24/CiNey-v1.0.24-TV.apk)
