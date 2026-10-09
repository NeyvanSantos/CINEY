# Publicação de 09/10/2026 — CiNey TV v1.0.26

Atualização solicitada pelo usuário para o canal Android TV, tag `tv-v1.0.26`.
A base compartilhada continua em `cinemax/`, consumida por `cinemax_tv/`.

## Mudanças

- Carregamento da TV com fundo preto, nome CiNey e indicador branco.
- Barra inferior nativa compacta com play/pause, posição, progresso azul e duração.
- Controles da TV ocultos durante o carregamento e com desaparecimento automático durante a reprodução.
- Correção da sintaxe do script de início de reprodução.
- Autoplay e limpeza da interface da WebView de contingência limitados ao modo TV; início manual, cancelamento, pausa e retomada do celular preservados.
- Seleção de releases TV extraída para um método testável, preservando o canal `tv-v` de pré-lançamentos.
- Uso da API atual de transparência no player e exclusão de caches Gradle do Git.

O fluxo nativo existente usa o player Android dentro do CiNey e mantém WebView
como contingência quando a captura de URL direta falha. A publicação não
comprova reprodução exclusivamente nativa em todos os provedores. Não houve
teste de reprodução nem medição de memória na TCL nesta entrega.

## APK

| Variante | Versão / build | Pacote | Tamanho em bytes |
| --- | --- | --- | --- |
| Android TV | 1.0.26 / 28 | `com.ciney.tv` | 88261256 |

Build local com Flutter 3.41.6, Dart 3.11.4 e Java 17:

```powershell
flutter build apk --release --no-tree-shake-icons --no-pub
```

O build usou um caminho ASCII temporário no Windows. SDK mínimo 24, SDK alvo
36 e bibliotecas ARM de 32 e 64 bits e x86_64.

Assinatura verificada com `apksigner verify`, igual à do APK oficial v1.0.25:

```text
5eb48ea48dcd267a2996f162624e8fc64442d362a45d6f5439f0a28c7e8900be
```

SHA-256 do APK:

```text
CiNey-v1.0.26-TV.apk
dd916b5cdbbe14efca122cf6830244d98c7c869c2cd39fad0d437e9638bc16db
```

Os quatro scripts empacotados (`embed_startup.js`, `embed_bridge.js`,
`embed_media_observer.js` e `playback_resume.js`) foram comparados por SHA-256
com os arquivos de origem. A versão, o código de build e o pacote foram
conferidos no manifesto compilado.

## Validação e limites

- Análise estática de `cinemax` e `cinemax_tv`: nenhum problema.
- 43 testes Flutter do player, continuidade de episódios, retomada, documento embed e atualizador: aprovados.
- 40 testes JavaScript da ponte, observador e início da reprodução: aprovados.
- Suíte Flutter completa: 134 testes aprovados e seis falhas nos testes de Cast já presentes no código anterior.
- Quatro falhas em `cast_dialog_test.dart`: ausência de implementação de WebView no ambiente de teste.
- Duas falhas em `native_cast_bridge_test.dart`: classificação de URL embed com query de mídia e identificação de MIME por extensão na query.
- Os arquivos de produção protegidos de Cast e esses dois arquivos de teste não foram alterados nesta release.
- `git diff --check`: aprovado.

A release TV é um pré-lançamento, com APK terminado em `-TV.apk`, conforme os
filtros do atualizador. O digest do asset remoto deve corresponder ao SHA-256
acima antes de tornar a release pública. A versão mobile permanece 1.0.21.

- [Release TV](https://github.com/NeyvanSantos/CINEY/releases/tag/tv-v1.0.26)
- [APK TV](https://github.com/NeyvanSantos/CINEY/releases/download/tv-v1.0.26/CiNey-v1.0.26-TV.apk)
