---
trigger: always_on
---

# 🔒 REGRA DE PROTEÇÃO: Sistema de Transmissão (Cast/Chromecast/WVC)

> **PRIORIDADE MÁXIMA (P0)** — Esta regra é INVIOLÁVEL.

## Arquivos Protegidos

Os seguintes arquivos contêm a correção crítica do sistema de transmissão (proxy iframe para contornar a camuflagem anti-cópia do `myembed.biz` → `Investidor.blog`). **NUNCA** devem ser modificados sem autorização explícita do usuário:

| Arquivo | Motivo da Proteção |
|---------|-------------------|
| `lib/features/cast/services/web_cast_server.dart` | Servidor HTTP local + iframe wrapper (`getEmbedUrl`, `/embed` route, `_getEmbedWrapperHtml`) |
| `lib/features/cast/presentation/cast_dialog.dart` | Lógica de roteamento: mídia direta vs. embed proxy (`_openCastDevice`, `_castViaDlna`) |
| `android/app/src/main/kotlin/com/cinemax/cinemax/MainActivity.kt` | Validação de hosts permitidos, `findExternalRedirectHost`, `isAllowedHost`, `openWebVideoCaster` |
| `lib/features/cast/services/native_cast_bridge.dart` | Bridge nativa Flutter ↔ Android para Cast |

## Funções/Métodos Críticos (NUNCA alterar sem permissão)

### `web_cast_server.dart`
- `getEmbedUrl()` — Gera URL local com iframe wrapper
- `_getEmbedWrapperHtml()` — HTML do wrapper iframe que contorna a proteção anti-cópia
- Rota `/embed` no `_handleRequest()`

### `cast_dialog.dart`
- `_openCastDevice()` — Lógica que diferencia mídia direta de embed e roteia pelo proxy
- `_castViaDlna()` — Validação de fontes embed para DLNA

### `MainActivity.kt`
- `allowedEmbedHosts` — Lista de hosts permitidos
- `findExternalRedirectHost()` — Detector de redirects maliciosos
- `isAllowedHost()` — Validação de hosts locais/permitidos
- `openWebVideoCaster()` — Abertura do WVC com validação de segurança

## Protocolo Obrigatório

1. **ANTES** de qualquer modificação nos arquivos listados acima, o agente **DEVE**:
   - Informar ao usuário **exatamente** o que pretende alterar
   - Explicar **por que** a alteração é necessária
   - Listar **quais funções/métodos** serão afetados
   - **AGUARDAR aprovação explícita** do usuário antes de executar

2. **Mesmo correções de bugs, refatorações, ou melhorias** nesses arquivos precisam de aprovação.

3. **Se outro agente ou skill solicitar alteração** nesses arquivos, o pedido deve ser **bloqueado** e redirecionado ao usuário para aprovação.

4. **Exceção única:** Correções de erros de compilação (syntax errors) que impeçam o build podem ser feitas, mas devem ser reportadas imediatamente ao usuário.

## Contexto da Correção Protegida

O `myembed.biz` usa uma técnica de cloaking baseada no header `Sec-Fetch-Dest`:
- Se `Sec-Fetch-Dest: document` → redireciona para `Investidor.blog` (página falsa)
- Se `Sec-Fetch-Dest: iframe` → serve o player real (`playerflix.ink`)

A solução implementada usa o `WebCastServer` local como proxy, servindo uma página HTML que carrega o embed dentro de um `<iframe>`, garantindo que o header correto seja enviado. **Esta solução é frágil e qualquer alteração pode quebrar a transmissão.**
