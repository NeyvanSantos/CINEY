# Plano de Execução: Reprodução Nativa Direta e Clean na Android TV (ExoPlayer)

> **Plano histórico, substituído em 09/10/2026:** a implementação atual está em
> [CINEY Player Engine TV](docs/tv-player-engine.md). Ela usa iframe documentado
> para embeds e player nativo somente para mídia direta declarada. Os números de
> memória e as afirmações de causa raiz abaixo não foram medidos/confirmados na
> TCL nesta implementação; a extração em segundo plano não é o caminho TV atual.

**Slug da Tarefa:** `tv-native-playback`  
**Dispositivo Alvo:** Smart TV TCL 43s615 (Android TV / 1.5 GB RAM / SoC RTD2841)  
**Objetivo:** Eliminar a WebView pesada e poluída da tela da TV (que exibe botão de play gigante borrado e elementos HTML com controles quebrados), substituindo-a por **extração em segundo plano (Headless Media Sniffer)** e reprodução 100% direta no **Player Nativo (ExoPlayer / Chewie)** com interface limpa e foco de controle remoto (D-Pad).

---

## 1. Diagnóstico do Problema Atual

- **Causa Raiz:** O app na TV estava abrindo fontes embed (`isEmbed: true`) diretamente em uma `WebViewWidget` visível em primeiro plano.
- **Sintomas na TCL 43s615:**
  1. A página do provedor (SuperFlix / EmbedMovies) exibe botões HTML (`< Escolher outro vídeo`, `Reportar`, barra web).
  2. A política de autoplay do Android Webview bloqueia início automático sem toque, gerando um botão de Play gigante e borrado no centro da tela.
  3. O controle remoto D-Pad não consegue focar os elementos da página web.
  4. Alto consumo de memória RAM (250MB-400MB) na TV de 1.5 GB de RAM, causando travamentos e engasgos.

---

## 2. Arquitetura da Solução

```
[Seleção de Mídia na TV]
          │
          ▼
[PlayerScreen (Modo TV)]
          │
          ├── Exibe UI Nativa Elegante (Poster do Filme + Shimmer + "Carregando fluxo...")
          │
          ▼
[MediaStreamSniffer em Segundo Plano (Headless WebView Invisível)]
          │
          ├── Injeta hooks de rede (Fetch / XHR / MutationObserver)
          ├── Intercepta a URL direta do stream (.m3u8 / .mp4 com headers de Referer/Origin)
          │
          ├──► SUCESSO (1 a 3 segundos):
          │         │
          │         ▼
          │    Destrói a WebView de background (libera RAM da TV)
          │    Inicializa VideoPlayerController com a URL direta e headers
          │    Inicia reprodução no ExoPlayer Nativo (aceleração por hardware)
          │    Controles nativos do CiNey ativos (OK/Pause, Avançar/Voltar 10s, D-Pad 100%)
          │
          └──► FALLBACK (se sniffer expirar timeout de 8s):
                    │
                    ▼
               Ativa WebView com injeção de CSS Clean (oculta botões e barras do site)
               Executa auto-play programático via JavaScript
```

---

## 3. Plano de Tarefas e Quebra de Etapas

### Fase 1: Integração do Sniffer Headless na `PlayerScreen` para Modo TV
- [ ] No `player_screen.dart`, quando `widget.isTv == true` e a fonte for `isEmbed`:
  - Não renderizar a `WebViewWidget` visível na árvore de widgets.
  - Criar o controlador de sniffing invisível (`MediaStreamSniffer.createSnifferController`).
  - Carregar a URL da fonte (EmbedMovies ou SuperFlix) em background.
  - Exibir a tela nativa de carregamento do CiNey com poster, título e indicador de buffer.

### Fase 2: Transição Suave para o Player Nativo (ExoPlayer)
- [ ] Quando o `MediaStreamSniffer` disparar `onMediaFound`:
  - Capturar a URL direta (`.m3u8` ou `.mp4`) e os headers necessários (`Referer`, `Origin`, `User-Agent`).
  - Desalocar a WebView de background imediatamente para economizar a RAM da TV TCL 43s615.
  - Inicializar o `VideoPlayerController.networkUrl` com a URL e cabeçalhos capturados.
  - Iniciar a reprodução automática via aceleração por hardware nativa do Android.

### Fase 3: Fallback Limpo (Clean CSS & Autoplay)
- [ ] Caso o sniffer não intercepte o link direto em até 8 segundos:
  - Fazer fallback para a WebView, mas injetando CSS que oculta botões estranhos (`< Escolher outro vídeo`, `Reportar`, cabeçalhos) e script de autoclick no botão de play central.

### Fase 4: Validação e Testes
- [ ] Executar testes de unidade e widgets de player existentes (`flutter test test/player_episode_continuity_test.dart`).
- [ ] Verificar que não quebra o modo Mobile (no celular o usuário ainda pode interagir com touch se desejar).

---

## 4. Critérios de Sucesso
1. **Zero botões web na TV:** Tela do filme limpa, sem `< Escolher outro vídeo`, sem botão gigante de play borrado.
2. **D-Pad 100% Funcional:** Controle remoto pausa, reproduz, avança 10s, retrocede 10s e exibe barra de progresso nativa do CiNey.
3. **Leveza:** Redução drástica no uso de RAM e CPU na Smart TV TCL 43s615.
