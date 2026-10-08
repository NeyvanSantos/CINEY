# Publicação de 08/10/2026 — retomada no servidor salvo

O usuário autorizou a geração e publicação dos APKs de celular e Android TV.
As tags `v1.0.20` e `tv-v1.0.23` apontam para o commit
`84181e88d9ab2f267b6f8063070740ad8e0c99c6`.
Os builds foram feitos em um worktree limpo com caminho sem acentos,
Flutter 3.41.6 e Java 17, usando `flutter build apk --release`.
As alterações locais pendentes de Cast não fazem parte desse commit.

| Variante | Versão / build | Pacote | Tamanho em bytes |
| --- | --- | --- | --- |
| Celular | 1.0.20 / 22 | `com.ciney.app` | 86505960 |
| Android TV | 1.0.23 / 25 | `com.ciney.tv` | 86609558 |

Ambos têm SDK mínimo 24 e SDK alvo 36, com bibliotecas para ARM de 32 e 64 bits
e x86_64. A assinatura oficial foi conferida com `apksigner verify`:

```text
5eb48ea48dcd267a2996f162624e8fc64442d362a45d6f5439f0a28c7e8900be
```

Os arquivos do player dentro dos APKs correspondem às fontes desse commit.
O digest dos assets publicados no GitHub corresponde ao SHA-256 local:

```text
CiNey-v1.0.20.apk
054c7c98286f03dd888af65163516b0501aeefa58258196684b5aefdf98de08b

CiNey-v1.0.23-TV.apk
26294971f4255c12c0a0fc5600b17afe77b74d3a2587325c2e648d1b13bb9fdb
```

O endpoint `/releases/latest` aponta para `v1.0.20`. O canal da TV encontra
`tv-v1.0.23` como o pré-lançamento de maior versão com prefixo `tv-v`.
Os nomes dos APKs correspondem aos filtros do atualizador existente.

- [APK para celular](https://github.com/NeyvanSantos/CINEY/releases/download/v1.0.20/CiNey-v1.0.20.apk).
- [APK para Android TV](https://github.com/NeyvanSantos/CINEY/releases/download/tv-v1.0.23/CiNey-v1.0.23-TV.apk).

Não houve nova rodada de testes de reprodução no dispositivo nesta publicação,
conforme solicitado. Os resultados anteriores e os limites de validação estão
no [relatório do início automático](teste-inicio-automatico-android-2026-10-08.md).
Os dois erros anteriores no teste do atualizador e as informações de depreciação
do player permanecem documentados naquele relatório; ambos os builds de release
compilaram com sucesso.
