# 🔒 Regra 03: Proteção Inviolável do Sistema de Transmissão (Cast/DLNA/WVC)

> ⚠️ **PRIORIDADE MÁXIMA (P0) — REGRA BLOQUEANTE INVIOLÁVEL**  
> Os arquivos abaixo contêm a solução de engenharia reversa e proxy anti-camuflagem para transmissão. **NUNCA modifique estes arquivos sem a autorização expressa do usuário.**

---

## 1. Arquivos Protegidos Sob Bloqueio

| Arquivo | Componente / Responsabilidade |
|---------|-------------------------------|
| `lib/features/cast/services/web_cast_server.dart` | Servidor HTTP local + iframe wrapper (`getEmbedUrl`, rota `/embed`, `_getEmbedWrapperHtml`) |
| `lib/features/cast/presentation/cast_dialog.dart` | Roteamento de mídia direta vs. proxy de embed (`_openCastDevice`, `_castViaDlna`) |
| `android/app/src/main/kotlin/com/cinemax/cinemax/MainActivity.kt` | Validação de hosts seguros, `findExternalRedirectHost`, `isAllowedHost`, `openWebVideoCaster` |
| `lib/features/cast/services/native_cast_bridge.dart` | Ponte nativa PlatformChannel Flutter ↔ Android para Google Cast |

---

## 2. O Problema Técnico Resolvido (Contexto)

Os servidores de embed (ex.: `myembed.biz`, `superflix`, etc.) realizam **cloaking** baseado no cabeçalho HTTP `Sec-Fetch-Dest`:
- Se a requisição chega com `Sec-Fetch-Dest: document` (como ao abrir em um player externo ou WVC diretamente) → eles redirecionam para páginas falsas/maliciosas (ex.: `Investidor.blog`).
- Se a requisição chega com `Sec-Fetch-Dest: iframe` → eles entregam o player real e funcional (`playerflix.ink`).

### Como a solução funciona:
O `WebCastServer` local atua como proxy reverso servindo uma página intermediária que encapsula o player dentro de um `<iframe>`. Dessa forma, o cabeçalho correto é enviado e a transmissão funciona perfeitamente no Chromecast, DLNA e Web Video Caster.

---

## 3. Protocolo Mandatório para Agentes e Desenvolvedores

1. Caso qualquer tarefa demande alterações nos arquivos citados:
   - **PARE IMEDIATAMENTE** antes de editar.
   - Apresente ao usuário o motivo detalhado e exatamente quais linhas/métodos precisariam ser alterados.
   - Obtenha confirmação explícita antes de prosseguir.
2. Não tente "otimizar" ou remover a camada de proxy local achando que é redundante.
