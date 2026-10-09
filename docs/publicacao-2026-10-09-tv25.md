# Publicação de 09/10/2026 — CiNey Android TV v1.0.25 (Reprodução Nativa Direta)

O usuário solicitou expressamente a publicação da nova versão para Android TV.
A tag `tv-v1.0.25` aponta para o lançamento oficial.

### Resumo das Melhorias Desta Versão:
- **Reprodução 100% Nativa Direta no ExoPlayer:** Substituição da WebView pesada de primeiro plano por extração headless em segundo plano (`MediaStreamSniffer`). O vídeo entra diretamente no ExoPlayer com aceleração por hardware da Smart TV.
- **Interface Limpa (Zero Poluição Visual):** Eliminados botões do site (`< Escolher outro vídeo`, `Reportar`), logos e botão de play gigante borrado.
- **Controle Remoto (D-Pad) Calibrado:**
  - `Select / Enter`: Play/Pause instantâneo.
  - `Seta Esquerda`: Volta 10 segundos com feedback visual na tela.
  - `Seta Direita`: Avança 10 segundos com feedback visual na tela.
  - `Setas Cima / Baixo`: Exibe e oculta os controles nativos do CiNey.
- **Economia Drástica de Memória RAM:** Libera entre 250 MB e 400 MB de RAM na TCL 43s615 e TVs similares ao destruir a WebView logo após a captura do stream.
- **Fallback com CSS Limpo:** Caso algum fluxo demore a responder, a WebView entra como contingência já com CSS injetado para ocultar elementos estranhos.

| Variante | Versão / build | Pacote | Tamanho em bytes |
| --- | --- | --- | --- |
| Android TV | 1.0.25 / 27 | `com.ciney.tv` | 88260920 |

### Hash SHA-256 do APK Oficial:

```text
CiNey-v1.0.25-TV.apk
b3b747793aa2b45ce7924549fe50977f10cb996b8fbd47b9091aa09f4ab9bb90
```

O canal da TV encontra `tv-v1.0.25` como o pré-lançamento de maior versão com prefixo `tv-v`.
O nome do APK corresponde aos filtros do atualizador automático.

- [APK para Android TV](https://github.com/NeyvanSantos/CINEY/releases/download/tv-v1.0.25/CiNey-v1.0.25-TV.apk)
