---
name: premiere-pro-uxp-plugin-master
description: Guia mestre, arquitetura completa, modelos de código e automação para criar, depurar e publicar qualquer extensão ou plugin UXP (JavaScript e Híbrido C++) para o Adobe Premiere Pro, incluindo o Removedor de Silêncios da Timeline.
---

# Premiere Pro UXP Plugin Master Skill - Guia Unificado

Esta skill é a referência técnica completa e unificada para criação, arquitetura, automação e publicação de plugins **UXP (Unified Extensibility Platform)** no **Adobe Premiere Pro** (suportando UXP v5+, v6+ com Híbridos C++, Premiere Pro v25.6+, v26.0+ e v26.2+).

---

## 1. Visão Geral da Arquitetura UXP no Premiere Pro

- **Ambiente JS**: Execução baseada em motor V8 moderno com suporte a `async/await`, `fetch`, `Promises` e CommonJS (`require`).
- **Módulos Core**:
  - `const ppro = require("premierepro");`: Acesso ao DOM do Premiere Pro (projetos, sequências, faixas de áudio/vídeo, clipes `TrackItem`, marcadores, metadados).
  - `const { entrypoints, shell, storage, pluginManager } = require("uxp");`: Controle de ciclo de vida do plugin, janelas, diálogos modais, comunicação IPC e sistema de arquivos.
- **Interface Gráfica (Spectrum UI e Variáveis de Tema)**:
  - Usar variáveis CSS nativas do host para herdar o tema do Premiere: `--uxp-host-background-color` e `--uxp-host-text-color`.
  - Definir `"enableSWCSupport": true` no manifesto para usar Spectrum Web Components nativos (`<sp-button>`, `<sp-slider>`, `<sp-textfield>`, `<sp-dropdown>`, `<sp-dialog>`).

---

## 2. Especificação do Manifesto Unificado (`manifest.json`)

### Modelo de Manifesto Completo (Versão 5 e 6 com C++ Híbrido e IPC Inter-Painéis):
```json
{
  "manifestVersion": 5,
  "id": "com.automação.removedordesilencios",
  "name": "Removedor de Silêncios UXP",
  "version": "1.0.0",
  "main": "index.html",
  "host": {
    "app": "premierepro",
    "minVersion": "26.0.0"
  },
  "requiredPermissions": {
    "localFileSystem": "fullAccess",
    "clipboard": "readAndWrite",
    "network": {
      "domains": "all"
    },
    "ipc": {
      "enablePluginCommunication": true
    },
    "enableAddon": true
  },
  "addon": {
    "name": "audio_processor.uxpaddon"
  },
  "entrypoints": [
    {
      "type": "panel",
      "id": "silenceRemoverPanel",
      "label": { "default": "Removedor de Silêncios" },
      "minimumSize": { "width": 400, "height": 500 },
      "maximumSize": { "width": 2000, "height": 2000 },
      "preferredDockedSize": { "width": 320, "height": 450 },
      "preferredFloatingSize": { "width": 450, "height": 600 },
      "icons": [
        { "width": 23, "height": 23, "path": "icons/dark.png", "scale": [1, 2], "theme": ["dark", "darkest"] },
        { "width": 23, "height": 23, "path": "icons/light.png", "scale": [1, 2], "theme": ["light", "lightest"] }
      ]
    },
    {
      "type": "command",
      "id": "quickSilenceCutCommand",
      "label": { "default": "Corte Rápido de Silêncios" }
    }
  ]
}
```

---

## 3. Detalhamento de Entrypoints (Panels e Commands) & Lifecycle Hooks JS (`main.js`)

Os entrypoints são registrados no JavaScript através de `uxp.entrypoints.setup()`.
- **Painéis (`panels`)**:
  - `create(rootNode)`: Inicializa o DOM raiz do painel.
  - `show(rootNode)`: Principal hook para renderizar e atualizar a interface sempre que o painel fica visível.
  - Comunicação Inter-Painéis: Habilitada via permissão `ipc.enablePluginCommunication`.
- **Comandos (`commands`)**: Funções diretas chamadas quando acionadas no menu *Window > UXP Plugins* ou por atalhos de teclado. Recebem o evento `executionInfo` (`uxpcommand`).

```javascript
const { entrypoints, pluginManager } = require("uxp");
const ppro = require("premierepro");

entrypoints.setup({
  plugin: {
    async create() {
      console.log("[UXP Plugin] Instância global do plugin criada.");
    },
    async destroy() {
      console.log("[UXP Plugin] Plugin destruído/encerrado.");
    }
  },
  panels: {
    silenceRemoverPanel: {
      async create(rootNode) {
        console.log("[UXP Panel] Painel criado no DOM.");
      },
      async show(rootNode) {
        console.log("[UXP Panel] Painel exibido para o usuário.");
        bindUIEvents(rootNode);
      },
      async hide(rootNode) {
        console.log("[UXP Panel] Painel minimizado/ocultado.");
      },
      async destroy(rootNode) {
        console.log("[UXP Panel] Painel destruído.");
      }
    }
  },
  commands: {
    quickSilenceCutCommand: async (executionInfo) => {
      console.log("[UXP Command] Executando comando direto via menu/atalho.", executionInfo);
      await executeQuickCut();
    }
  }
});

function bindUIEvents(root) {
  const btnProcess = root.querySelector("#btnProcessSilence");
  if (btnProcess) {
    btnProcess.addEventListener("click", handleSilenceRemoval);
  }
}
```

---

## 4. Algoritmo Completo do Removedor de Silêncios na Timeline

### A. Obter Projeto e Sequência Ativos
```javascript
async function getActiveSequence() {
  const project = await ppro.Project.getActiveProject();
  if (!project) throw new Error("Abra um projeto no Premiere Pro.");
  const sequence = await project.getActiveSequence();
  if (!sequence) throw new Error("Selecione uma sequência ativa na Timeline.");
  return sequence;
}
```

### B. Ler Faixas de Áudio e Clipes
```javascript
async function getSelectedAudioClips(sequence) {
  const audioTracks = await sequence.getAudioTracks();
  const clips = [];
  
  for (let i = 0; i < audioTracks.numTracks; i++) {
    const track = audioTracks[i];
    const items = await track.getTrackItems();
    for (let j = 0; j < items.numItems; j++) {
      const item = items[j];
      if (item.isSelected()) {
        clips.push(item);
      }
    }
  }
  return clips;
}
```

### C. Calcular e Aplicar Cortes nos Trechos Silenciosos
```javascript
async function removeSilenceFromClip(clip, thresholdDb = -35, minSilenceDurationSec = 0.3) {
  const startTime = clip.start;
  const endTime = clip.end;
  const inPoint = clip.inPoint;
  const outPoint = clip.outPoint;

  // Lógica de ajuste dos pontos de entrada e saída (In/Out) para remover lacunas de áudio
  // 1. Divide o intervalo em blocos válidos de fala
  // 2. Reposiciona inPoint/outPoint ou divide o clipe usando a ação nativa Add Edit (Ctrl+K)
}
```

---

## 5. Arquitetura de Plugins Híbridos em C++ (`UxpAddon.h`)

Para tarefas de alta performance de DSP de áudio (cálculo de RMS, FFT e análise de áudio nativa em milissegundos):

### A. Código C++ (`addon.cpp`):
```cpp
#include "UxpAddon.h"

// Função C++ nativa exportada para JS
addon_value AnalyzeAudioSilence(addon_env env, addon_callback_info info) {
    // Processamento nativo C++ de arquivo WAV/PCM
    return nullptr;
}

addon_value Init(addon_env env, addon_value exports) {
    // Exporta funções C++
    return exports;
}

void Terminate() {}

UXP_ADDON_INIT(Init);
UXP_ADDON_TERMINATE(Terminate);
```

### B. Organização das Pastas Binárias (`.uxpaddon`):
```text
native/win/x64/audio_processor.uxpaddon
native/mac/x64/audio_processor.uxpaddon
native/mac/arm64/audio_processor.uxpaddon
```

---

## 6. Ferramenta UXP Developer Tool (UDT) & Prototipagem Rápida

- **Modo Desenvolvedor**: Habilitar em `Configurações > Plugins > Modo Desenvolvedor` no Premiere Pro e no UDT.
- **Workflow Load & Watch**: Carrega a extensão e assiste alterações nos arquivos `.js`, `.html` e `.css`, atualizando a UI no Premiere em tempo real.
- **Debug Integrado**: Ícone `{ }` ativa o Inspetor Chrome DevTools (Console, Breakpoints, DOM, `Break on Start`).
- **Prototipagem no UXP Playground**: Testar trechos de código rapidamente na sandbox do UDT e exportar com o botão **Download (⬇️)**.
- **Workflows com Bundlers (Webpack/Vite)**: Configurar o diretório `dist/` nas opções avançadas (`••• > Advanced`) do UDT para evitar loops infinitos no Watch.

---

## 7. Diálogos Modais (`uxpShowModal`) e Estilização Host

Para exibir janelas de diálogo modais que bloqueiam a aplicação até a confirmação do usuário:
```html
<dialog id="silenceConfigDialog">
  <form method="dialog">
    <h2>Configurações do Removedor de Silêncios</h2>
    <label>Limite dB: <input type="number" id="dbThreshold" value="-35"/></label>
    <button id="btnCancel" value="cancel">Cancelar</button>
    <button id="btnConfirm" value="ok" type="submit">Processar</button>
  </form>
</dialog>
```

```javascript
async function promptSilenceConfig() {
  const dialog = document.getElementById("silenceConfigDialog");
  const result = await dialog.uxpShowModal();
  if (result === "ok") {
    const dbValue = document.getElementById("dbThreshold").value;
    return parseFloat(dbValue);
  }
  return null;
}
```

---

## 8. Comunicação entre Plugins (Inter-Plugin Communication - IPC)

Permite disparar comandos ou exibir painéis de outros plugins UXP instalados via `pluginManager`:
```javascript
const { pluginManager } = require("uxp");
const targetPlugin = Array.from(pluginManager.plugins).find(p => p.id === targetPluginId);
if (targetPlugin) {
  targetPlugin.invokeCommand("commandId", { action: "process" });
  targetPlugin.showPanel("panelId");
}
```

---

## 9. Distribuição e Empacotamento Comercial (`.ccx` & Marketplace)

### A. Processo de Empacotamento via UDT (Passo a Passo)
1. Verificar que o `id` no `manifest.json` é único e válido. Para publicação no Marketplace, o ID deve ser obtido no portal **Adobe Developer Distribution**.
2. Abrir o **UXP Developer Tool (UDT)** e localizar o plugin no workspace.
3. Clicar no ícone **`•••` (ellipsis)** ao lado do nome do plugin e selecionar **Package**.
4. Escolher o diretório de destino onde o arquivo `.ccx` será salvo.
5. Resultado: mensagem **"Package Success"** ou **"Details"** para inspecionar erros.

### B. Formato `.ccx` (Instalação por Duplo-Clique)
- O arquivo `.ccx` é internamente um arquivo ZIP padrão (instalado diretamente pelo app Creative Cloud Desktop).
- Diferente dos plugins CEP antigos (`.zxp`), pacotes UXP `.ccx` **não necessitam de certificado digital** nem carimbo de data/hora.
- Alternativa manual: Zipar os **conteúdos** da pasta do plugin (não a pasta pai) e renomear a extensão de `.zip` para `.ccx`.

### C. Canais de Distribuição
1. **Adobe Creative Cloud Marketplace**: Envio através do portal Adobe Developer Distribution (upload na aba **General**, não na aba "Plugin file"). Passa por revisão oficial da Adobe.
2. **Distribuição Direta / Enterprise**: Envio direto do arquivo `.ccx` para usuários finais ou equipes corporativas (duplo clique para instalar).
3. **Multi-Canal**: Para distribuição simultânea em Marketplace e canal direto, usar **IDs diferentes** no `manifest.json` de cada versão para evitar conflitos de validação no Creative Cloud Desktop.

---

## 10. Instalação de Plugins UXP

### A. Pré-requisito: Ativar Developer Mode
Para desenvolver ou carregar plugins custom, é necessário:
1. Ir em Premiere Pro → **Settings → Plugins** → marcar **"Enable developer mode"**.
2. **Reiniciar** o Premiere Pro obrigatoriamente.

### B. Métodos de Instalação por Canal

| Canal | Método |
|---|---|
| **Creative Cloud Marketplace** | Instalar via Creative Cloud Desktop app |
| **Independente (`.ccx`)** | Duplo-clique no arquivo `.ccx` (abre o CC Desktop automaticamente) |
| **Independente (`.ccx`)** | Linha de comando via ferramenta **UPIA** |
| **Enterprise** | Admin Console ou UPIA em pacotes gerenciados |

### C. Ferramenta UPIA (Unified Plugin Installer Agent)
Ferramenta de linha de comando para instalação automatizada/silenciosa. Substitui o antigo `ExManCmd` (depreciado).

**Caminhos do executável:**
```
# Windows
"C:\Program Files\Common Files\Adobe\Adobe Desktop Common\RemoteComponents\UPI\UnifiedPluginInstallerAgent\UnifiedPluginInstallerAgent.exe"

# macOS
/Library/Application Support/Adobe/Adobe Desktop Common/RemoteComponents/UPI/UnifiedPluginInstallerAgent/UnifiedPluginInstallerAgent.app/Contents/MacOS/UnifiedPluginInstallerAgent
```

**Uso:**
```bash
# Windows
UnifiedPluginInstallerAgent.exe /install "C:\caminho\para\plugin.ccx"

# macOS
UnifiedPluginInstallerAgent --install /caminho/para/plugin.ccx
```

### D. Deploy Enterprise (Admin Console)
1. Selecionar plugins do Marketplace durante criação de pacote no Admin Console.
2. Para plugins internos (não-Marketplace): habilitar **"create a folder for extensions and include the UPIA tool"** e colocar os `.ccx` na pasta gerada — serão instalados automaticamente no deploy.

### E. Regras Importantes
- **NUNCA** copiar manualmente arquivos de plugin para diretórios do sistema. Sempre usar CC Desktop ou UPIA para manter registros e databases de plugins corretos.
- Plugins só instalam se o aplicativo host (Premiere Pro) já estiver instalado na máquina alvo.

---

## 11. Distribuição Independente (Direta)

### A. Conceito
Distribuição independente é quando o desenvolvedor compartilha o arquivo `.ccx` diretamente com os usuários (via site próprio, GitHub, e-mail, lojas de terceiros, etc.), **sem passar pela revisão/aprovação da Adobe**.

### B. Regras de Plugin ID para Distribuição Independente
- O `id` no `manifest.json` é a chave de identificação única usada pelo sistema para desambiguar plugins durante a instalação.
- **Se você distribui via Marketplace E via canal independente**: usar **IDs diferentes** para cada canal.
  - **Marketplace**: o `id` deve ser obtido do portal Adobe Developer Distribution e **deve coincidir exatamente** com o da listagem, senão falha na validação.
  - **Independente**: pode usar um `id` diferente livremente.
- Isso é **especialmente crítico para plugins pagos**, evitando conflitos entre versões instaladas por canais diferentes.

### C. Vantagens da Distribuição Independente
- **Sem revisão da Adobe**: não precisa de aprovação oficial.
- **Controle total**: preço, licenciamento, atualizações e suporte direto.
- **Velocidade**: distribuição imediata após o empacotamento.

### D. Limitações
- Sem visibilidade no Creative Cloud Marketplace (marketing orgânico).
- O desenvolvedor é responsável por toda a infraestrutura de entrega e suporte.
- Erros de instalação (ex: "Error -1") podem ocorrer por software de segurança ou permissões de pasta — o plugin deve estar corretamente empacotado como `.ccx`.

---

## 12. Distribuição Enterprise (Organizacional)

### A. Método 1: Admin Console + Marketplace
Para plugins já publicados no Marketplace:
1. No **Adobe Admin Console**, criar um **pacote gerenciado** (Named User Licensing).
2. Navegar pela lista de plugins do Marketplace e selecionar os desejados.
3. Ao fazer deploy do pacote nas máquinas dos usuários, os plugins são instalados **automaticamente**.

### B. Método 2: Pacotes Gerenciados com `.ccx` Interno
Para plugins internos (não publicados no Marketplace):
1. No Admin Console, ao criar o pacote, habilitar a opção **"create a folder for extensions and include the UPIA tool"**.
2. Uma pasta é gerada dentro da estrutura do pacote.
3. Colocar os arquivos `.ccx` do plugin nessa pasta.
4. Ao fazer deploy, o **UPIA** incluso no pacote instala os plugins automaticamente junto com os apps Creative Cloud.

### C. Método 3: UPIA via Linha de Comando (Deploy Silencioso)
Administradores podem usar o UPIA diretamente para instalação remota/silenciosa a qualquer momento (ver seção 10.C para caminhos e sintaxe).

### D. Controle de Permissões
- Configurar no Admin Console se os usuários podem **auto-instalar** plugins via CC Desktop ou se apenas administradores TI podem gerenciar o deploy.
- Plugins requerem que o app host (Premiere Pro) esteja no pacote ou já instalado na máquina alvo.
- Após deploy, pode ser necessário **reiniciar** o app host para ativar o plugin.

### E. Regra de IDs para Enterprise
- Se o mesmo plugin é distribuído internamente E no Marketplace, **usar IDs diferentes** no `manifest.json` de cada versão para evitar conflitos.

---

## 13. Recursos para Desenvolvedores

### A. Documentação Oficial & Referências de API
| Recurso | URL |
|---|---|
| **Hub Principal UXP** | https://developer.adobe.com/premiere-pro/uxp |
| **Premiere DOM API** (Sequences, Tracks, Clips, Markers, Project Items) | https://developer.adobe.com/premiere-pro/uxp/reference/premiere/ |
| **UXP JavaScript API** (Storage, Clipboard, OS, Runtime) | https://developer.adobe.com/premiere-pro/uxp/reference/uxp/ |
| **Changelog / What's New** | https://developer.adobe.com/premiere-pro/uxp/resources/changelog/ |

### B. Samples Oficiais (GitHub)
Repositório: **https://github.com/AdobeDocs/uxp-premiere-pro-samples**

| Sample | Descrição |
|---|---|
| `premiere-api` | Painel de referência completo — cobre projects, sequences, markers, metadata, effects, transitions, keyframes. **Ponto de partida recomendado.** |
| `metadata-handler` | Painel de workflow para gestão de metadata (cópia coluna-a-coluna, batch updates, export). |
| `oauth-workflow-sample` | Exemplo de fluxo OAuth 2.0 (authorization code). |

### C. Starters & Templates
- Ao clicar **Create Plugin** no UDT, selecionar templates built-in (ex: `premierepro-quick-starter`) que já vêm com `manifest.json`, HTML e JS pré-configurados.

### D. Recipes (Receitas Práticas)
Endereço: https://developer.adobe.com/premiere-pro/uxp/recipes/

| Categoria | Exemplos |
|---|---|
| **Filesystem** | Leitura/escrita de arquivos locais |
| **Network** | Fetch API, WebSockets |
| **Host Environment** | Detecção de OS, versão do app, runtime UXP |
| **UI/Styling** | CSS styling, criação de elementos HTML, eventos |

### E. Comunidade & Suporte
| Recurso | URL |
|---|---|
| **Fórum Oficial** | https://forums.creativeclouddeveloper.com/c/uxp-for-premiere-pro/105 |
| **Adobe Developer Blog** | https://developer.adobe.com/blog/ |

---

## 14. Fundamentos de APIs UXP (Core vs. Premiere DOM)

### A. Dois Tipos de APIs
O UXP fornece dois conjuntos complementares de APIs que são usados juntos:

| Tipo | Módulo | Propósito |
|---|---|---|
| **UXP Core APIs** | `require("uxp")` | UI (HTML/CSS/JS), filesystem, network, clipboard, shell, OS — **compartilhadas** entre todos os apps Adobe UXP |
| **Premiere APIs (DOM)** | `require("premierepro")` | Controlar projects, sequences, clips, markers, effects, transitions, keyframes — **específico do Premiere Pro** |

### B. Padrão de Acesso
```javascript
// Premiere Pro DOM API
const ppro = require("premierepro");

// UXP Core APIs (desestruturadas)
const { entrypoints, shell, os } = require("uxp");
```

### C. Módulos Core Principais
| Módulo | Uso |
|---|---|
| `entrypoints` | `entrypoints.setup()` — gerencia lifecycle e hooks de painéis/comandos |
| `shell` | `shell.openPath()` (abrir arquivo/pasta), `shell.openExternal()` (abrir URL no browser do SO) |
| `os` | Informações do sistema operacional |
| `storage` | Acesso persistente a arquivos e key-value store local do plugin |
| `clipboard` | Operações de copiar/colar |

### D. IntelliSense / Type Definitions (sem TypeScript)
```bash
npm install -D @adobe/premierepro
```
```javascript
/** @type {import('@adobe/premierepro').premierepro} */
const ppro = require("premierepro");
```
Isso habilita **autocomplete e type-checking** completo no VS Code / Cursor sem precisar de TypeScript.

### E. Regras Importantes
- APIs que acessam filesystem e network **devem ser declaradas** no `manifest.json` (permissions).
- Propriedades do DOM Premiere parecem síncronas, mas são **assíncronas internamente** — usar `await` quando necessário.
- Diferente do CEP antigo, **não existe bridge (`CSInterface`)** — tudo roda no mesmo ambiente JavaScript unificado.

---

## 15. Premiere DOM APIs — Hierarquia e Navegação

### A. Hierarquia do DOM
```
Application (app)
  └── Project
        ├── ProjectItem (assets, pastas no Project Panel)
        └── Sequence
              ├── VideoTrack(s)
              ├── AudioTrack(s)
              └── CaptionTrack(s)
                    └── TrackItem (clipes individuais na timeline)
```

### B. Navegação Básica
```javascript
const app = require("premierepro");

// Obter projeto ativo
const project = await app.getActiveProject();

// Obter sequência ativa
const sequence = await project.getActiveSequence();

// Obter tracks de áudio
const audioTrack = await sequence.getAudioTrack(0); // índice 0

// Obter items (clipes) do track
const trackItems = await audioTrack.getTrackItems();
```

### C. Classes Principais

| Classe | Descrição | Métodos Chave |
|---|---|---|
| **Application** | Raiz do DOM | `getActiveProject()` |
| **Project** | Projeto aberto | `getActiveSequence()`, `getProjectItems()` |
| **Sequence** | Sequência/timeline | `getAudioTrack(index)`, `getVideoTrack(index)`, `getCaptionTrack(index)` |
| **Track** | Trilha individual | `getTrackItems()` |
| **TrackItem** | Clipe na timeline | `.inPoint`, `.outPoint`, `.duration`, `.startTime`, `createSetEndAction()` |
| **ProjectItem** | Asset no Project Panel | `.name`, `.type`, `.getMediaPath()` |

### D. Padrão de Actions (Modificações)
Operações que modificam o projeto usam o padrão **Action**:
```javascript
// Exemplo: mudar o ponto final de um clipe
const action = trackItem.createSetEndAction(newTickTime);
await action.execute();
```
Actions encapsulam mudanças e permitem controle preciso sobre undo/redo.

### E. Versionamento de APIs
- **Premiere Version**: determina quais métodos do DOM estão disponíveis.
- **UXP Version**: determina quais APIs Core (filesystem, network) me estão disponíveis.
- Cada propriedade/método na documentação oficial possui coluna **"MIN VERSION"** indicando a versão mínima do Premiere Pro necessária.
```javascript
const { host } = require("uxp");
console.log(`Premiere: ${host.version}`);
```

---

## 16. Suporte a TypeScript & Autocomplete (IntelliSense)

### A. Instalação das Definições de Tipos
Para obter tipagem do Premiere DOM e UXP Core APIs:
```bash
npm install -D @adobe/premierepro @adobe/cc-ext-uxp-types
```

### B. Configuração para Projetos TypeScript (`tsconfig.json`)
```json
{
  "compilerOptions": {
    "target": "ES2020",
    "module": "CommonJS",
    "moduleResolution": "node",
    "types": ["@adobe/premierepro", "@adobe/cc-ext-uxp-types"]
  }
}
```

### C. Configuração para Projetos JavaScript Puro (`jsconfig.json`)
Se estiver usando JS puro sem transpilador, adicione `jsconfig.json` na raiz do projeto para ativar autocomplete no VS Code / Cursor:
```json
{
  "compilerOptions": {
    "types": ["@adobe/premierepro", "@adobe/cc-ext-uxp-types"]
  },
  "exclude": ["node_modules"]
}
```

### D. Padrões de Código com TypeScript
```typescript
import type { premierepro, Project, Sequence, TrackItem } from '@adobe/premierepro';

// Import de tempo de execução com casting de tipo
const ppro = require('premierepro') as premierepro;

async function getAudioClips(sequence: Sequence): Promise<TrackItem[]> {
  const track = await sequence.getAudioTrack(0);
  return await track.getTrackItems();
}
```

---

## 17. Suporte e Regras do ESLint (`@adobe/eslint-plugin-premierepro`)

### A. Instalação do Plugin ESLint
Para capturar erros específicos do Premiere Pro em tempo de desenvolvimento (evitando exceções em runtime):
```bash
npm install -D eslint @adobe/eslint-plugin-premierepro
```

### B. Configuração do `.eslintrc.json`
```json
{
  "env": {
    "es2021": true,
    "node": true
  },
  "plugins": [
    "@adobe/premierepro"
  ],
  "extends": [
    "plugin:@adobe/premierepro/recommended"
  ],
  "rules": {
    "@adobe/premierepro/no-async-in-transaction": "error",
    "@adobe/premierepro/require-undo-name": "warn"
  }
}
```

### C. Principais Regras Protegidas pelo Plugin
1. **`no-async-in-transaction`**: Impede o uso de callbacks assíncronos (`async/await`) dentro de funções de transação do Premiere Pro.
2. **`require-undo-name`**: Alerta quando chamadas a `executeTransaction()` não especificam uma string descritiva de Undo.
3. **Uso de Actions & Locks**: Garante que modificações no DOM ocorram dentro de blocos autorizados (`lockedAccess()` ou `executeTransaction()`).

---

## 18. Fundamentos de User Interface (UI) no UXP

### A. As 3 Abordagens para Construir UIs
Existem três maneiras primárias de criar interfaces no UXP:

1. **Spectrum Web Components (SWC)** *(Recomendado)*:
   - Componentes web modernos e abertos da Adobe (`sp-button`, `sp-textfield`, etc.).
   - Suporte completo a acessibilidade, temas dinâmicos (Dark/Light) e design responsivo.
2. **Spectrum UXP Widgets (Built-in)**:
   - Widgets nativos integrados ao runtime UXP, disponíveis sem instalação ou `import`.
   - Adaptação automática instantânea ao tema do Premiere Pro.
3. **HTML / CSS Padrão**:
   - Elementos web tradicionais (`<button>`, `<div>`, `<input>`).
   - Maior controle sobre customização CSS personalizada.

### B. Elementos e Tipografia Spectrum Principais
| Categoria | Tags Spectrum |
|---|---|
| **Tipografia** | `<sp-heading>`, `<sp-body>`, `<sp-detail>`, `<sp-label>` |
| **Controles de Ação** | `<sp-button>`, `<sp-action-button>`, `<sp-link>` |
| **Entrada de Dados** | `<sp-textfield>`, `<sp-textarea>`, `<sp-checkbox>`, `<sp-radio-group>`, `<sp-slider>` |
| **Seleção & Menus** | `<sp-dropdown>`, `<sp-menu>`, `<sp-menu-item>` |
| **Indicadores & Layout** | `<sp-progressbar>`, `<sp-divider>`, `<sp-icon>` |

### C. Suporte a Temas (Light / Dark Modes)
- Componentes Spectrum adaptam-se automaticamente quando o usuário altera o tema de cor nas preferências do Premiere Pro.
- Para HTML/CSS customizado, utilize variáveis CSS ou observe mudanças de tema via UXP API para manter consistência visual.

---

## 19. Starters & Samples Oficiais (Exemplos Práticos)

### A. Repositório Oficial no GitHub
- **URL**: [AdobeDocs/uxp-premiere-pro-samples](https://github.com/AdobeDocs/uxp-premiere-pro-samples)
- **Pré-requisitos**: Premiere Pro 25.2+, UXP Developer Tool (UDT), Node.js LTS (18+).

### B. Principais Exemplos Disponíveis

| Sample | Descrição Técnica & Casos de Uso |
|---|---|
| **`premiere-api`** | Painel de referência completo com testes para projects, sequences, markers, metadata, effects, transitions e keyframes. **Excelente base para consultar sintaxes de API.** |
| **`metadata-handler`** | Painel de produção para gestão de metadados em lote: cópia entre colunas, prefixos/sufixos, exportação de marcadores e listas. |
| **`oauth-workflow-sample`** | Demonstra fluxo completo de autenticação OAuth 2.0 (Authorization Code Flow) integrando com serviços externos (ex: Dropbox) usando servidor auxiliar Node.js. |

### C. Como Testar e Carregar os Samples
1. Clonar o repositório ou baixar a pasta do sample.
2. Abrir o **UXP Developer Tool (UDT)**.
3. Clicar em **Add Plugin** e selecionar o `manifest.json` do sample escolhido.
4. Clicar em **Load** (ou **Load & Watch**) para rodar diretamente no Premiere Pro ativo.

---

## 20. Code Recipes (Receitas de Código Rápidas)

### A. Operações com Sistema de Arquivos (Filesystem Deep Dive)

#### 1. Modelo de Sandbox e Esquemas de URIs
O UXP restringe acessos a locais seguros via esquemas de URI:
- **`plugin:/`**: Pasta de instalação do plugin (**Somente Leitura**).
- **`plugin-data:/`**: Armazenamento persistente exclusivo do plugin (**Leitura/Escrita**).
- **`plugin-temp:/`**: Pasta temporária do plugin para arquivos transitórios (**Leitura/Escrita**).
- **`file:/`**: Arquivos fora do sandbox do plugin (**Exige permissão `"fullAccess"`**).

#### 2. Permissões no `manifest.json`
```json
{
  "requiredPermissions": {
    "localFileSystem": "request" // "plugin" | "request" | "fullAccess"
  }
}
```
- `"plugin"`: Acesso apenas às pastas `plugin:/`, `plugin-data:/` e `plugin-temp:/`.
- `"request"`: Permite abrir seletores de arquivo (`getFileForOpening`, `getFileForSaving`) para o usuário escolher.
- `"fullAccess"`: Acesso direto ao sistema de arquivos nativo do SO via caminhos absolutos.

#### 3. As Duas APIs de Filesystem
1. **API `localFileSystem` (Baseada em Objetos)**:
```javascript
const { storage } = require("uxp");
const fs = storage.localFileSystem;

// Seleção interativa
const file = await fs.getFileForOpening({ allowMultiple: false });
if (file) {
  const content = await file.read();
}

// Acesso a diretório de dados do plugin
const dataFolder = await fs.getDataFolder();
const myFile = await dataFolder.createFile("settings.json", { overwrite: true });
await myFile.write(JSON.stringify({ volume: 80 }));
```

2. **API `fs` (Baseada em Caminhos/Strings)**:
```javascript
const fs = require("uxp").storage.localFileSystem;
// Exemplo de escrita rápida no plugin-data
const data = await fs.readFile("plugin-data:/settings.json", { encoding: "utf-8" });
```


### B. Requisições de Rede (Network & APIs Deep Dive)

#### 1. Configuração de Permissões no `manifest.json`
O acesso de rede é **desativado por padrão**. É obrigatório declarar as permissões:

- **Recomendado (Domínios Específicos)**:
```json
{
  "requiredPermissions": {
    "network": {
      "domains": [
        "https://api.exemplo.com",
        "http://localhost:3000"
      ]
    }
  }
}
```

- **Acesso Irrestrito**:
```json
{
  "requiredPermissions": {
    "network": {
      "domains": "all"
    }
  }
}
```

#### 2. APIs de Rede Suportadas
1. **`fetch`** *(Recomendado)*:
```javascript
try {
  const res = await fetch("https://api.exemplo.com/dados");
  const json = await res.json();
} catch (e) {
  console.error("Erro na requisição HTTP:", e);
}
```
2. **`XMLHttpRequest` (XHR)**: Suportado para legados.
3. **`WebSocket`**: Suportado para comunicação bidirecional em tempo real.

#### 3. Regras e Cuidados Práticos
- **CORS**: UXP respeita políticas de CORS padrão da web. Servidores externos devem retornar cabeçalhos `Access-Control-Allow-Origin`.
- **Servidores Locais**: Para acessar `localhost` ou IPs da rede local, o endereço completo com protocolo e porta deve estar listado em `domains` (ex: `http://localhost:8080`).


### C. Informações do Ambiente Host (Host Environment)
- Detectar OS, versão do aplicativo host (Premiere Pro), versão do runtime UXP e idioma.
```javascript
const { host, versions } = require("uxp");
console.log(`OS: ${host.uiLocale}, Premiere: ${host.version}, UXP: ${versions.uxp}`);
```

### D. Depuração e Notificações (Debugging)
- Uso de `console.log`, `console.error` inspecionados via UXP Developer Tool.
- Caixas de diálogo simples (`alert`, `confirm`, `prompt`) para interações diretas com o usuário.

### E. Interação com Processos Externos (External Processes Deep Dive)

#### 1. Segurança e Restrições do Sandbox
Por razões de segurança, o UXP **não permite execução direta de processos ou scripts de terminal arbitrários** (como `child_process.exec` do Node.js). A interação externa é mediada pelo módulo `shell`.

#### 2. Módulo `shell`
```javascript
const { shell } = require("uxp");
```

- **`shell.openPath(path, developerText)`**: Abre um arquivo ou pasta no aplicativo padrão do sistema (ex: PDF no leitor, arquivo `.txt` no editor).
```javascript
await shell.openPath("plugin-data:/relatorio.pdf", "Abrindo o relatório PDF exportado.");
```

- **`shell.openExternal(url, developerText)`**: Abre URLs ou esquemas registrados no aplicativo padrão (ex: navegador ou aplicativo de e-mail).
```javascript
await shell.openExternal("https://meusite.com/suporte", "Redirecionando para a página de suporte.");
```

#### 3. Permissões no `manifest.json` (`launchProcess`)
É obrigatório declarar quais extensões de arquivo ou esquemas de URL o plugin tem permissão de abrir:
```json
{
  "requiredPermissions": {
    "launchProcess": {
      "extensions": [".pdf", ".csv", ".txt"],
      "schemes": ["https", "mailto"]
    }
  }
}
```

#### 4. Consentimento do Usuário
Sempre que `openPath` ou `openExternal` é chamado, o sistema operacional/UXP exibe uma caixa de diálogo solicitando permissão do usuário. O parâmetro `developerText` serve para informar ao usuário o motivo da ação.

### F. Operações com a Área de Transferência (Clipboard Deep Dive)

#### 1. Configuração no `manifest.json`
O acesso ao clipboard é bloqueado por padrão. Declare a permissão sob `requiredPermissions`:
```json
{
  "requiredPermissions": {
    "clipboard": "readAndWrite" // Opções: "read" | "readAndWrite"
  }
}
```

#### 2. API `navigator.clipboard`
Com a permissão ativa, utilize os métodos assíncronos padrão da web:
```javascript
// Escrever texto no clipboard
await navigator.clipboard.writeText("Texto para a área de transferência");

// Ler texto do clipboard
const text = await navigator.clipboard.readText();
```

---

### G. Informações do Ambiente Host e Versões (Host Info Deep Dive)

#### 1. Módulos `host` e `versions`
```javascript
const { host, versions } = require("uxp");
```

#### 2. Propriedades de `host`
- `host.name`: Nome do aplicativo host (ex: `"Premiere Pro"`).
- `host.version`: Versão exata do Premiere Pro em execução (ex: `"25.2.0"`).
- `host.uiLocale`: Idioma da interface do usuário (ex: `"pt_BR"`, `"en_US"`).

#### 3. Propriedades de `versions`
- `versions.uxp`: Versão do runtime UXP integrado (ex: `"8.1.0"`).
- `versions.plugin`: Versão do próprio plugin definida no `manifest.json`.

#### 4. Exemplo de Verificação de Compatibilidade
```javascript
function isFeatureSupported() {
  const uxpVer = parseFloat(versions.uxp.split(".").slice(0, 2).join("."));
  return uxpVer >= 8.1;
}
```

---

### H. Estilização CSS e Temas (CSS Styling & Theme Awareness Deep Dive)

#### 1. Suporte CSS no UXP Runtime
O UXP suporta padrão CSS moderno com layout de motor nativo:
- **Flexbox & Grid**: Suporte completo para layouts responsivos (`display: flex`, `display: grid`).
- **Propriedades Tipográficas**: `font-family`, `font-size`, `line-height`, `letter-spacing`.
- **Estilos Globais e Inline**: Suporte a arquivos `.css` externos ou `<style>` internos.

#### 2. Consciência de Tema (Theme Awareness)
Para acompanhar a troca de temas do Premiere Pro (Dark, Darkest, Light, Lightest):
- **Componentes Spectrum**: Adaptam-se **automaticamente** ao tema do aplicativo sem código adicional.
- **Detecção via JS (HTML/CSS Customizado)**:
```javascript
// Acessar o tema atual
const currentTheme = document.theme;
console.log(`Tema ativo: ${currentTheme}`);

// Escutar mudanças de tema pelo usuário nas preferências do Premiere
window.addEventListener("themechange", (event) => {
  console.log("Novo tema detectado:", event.theme);
  // Atualizar variáveis de estilo personalizadas se necessário
});
```

#### 3. Variáveis CSS Spectrum Nativas
O UXP expõe variáveis CSS do sistema Spectrum para alinhar cores e espaçamentos aos padrões da Adobe:
```css
.meu-painel-custom {
  background-color: var(--spectrum-global-color-gray-100);
  color: var(--spectrum-global-color-gray-800);
  padding: var(--spectrum-global-dimension-size-200);
  font-family: var(--spectrum-global-font-family);
}
```

---

### I. Manipulação de Elementos HTML e DOM (HTML Elements Deep Dive)

#### 1. Manipulação com APIs DOM Padrão
No runtime UXP, é possível criar, modificar e escutar eventos em elementos UI usando JavaScript clássico:
```javascript
// Criar elemento dinamicamente (Spectrum ou HTML nativo)
const btn = document.createElement("sp-button");
btn.textContent = "Iniciar Processamento";
btn.setAttribute("variant", "cta");

// Adicionar manipulador de eventos
btn.addEventListener("click", async () => {
  console.log("Botão clicado!");
});

// Anexar ao container do painel
document.getElementById("app-container").appendChild(btn);
```

#### 2. Elementos Não Suportados / Comportamento Diferenciado no UXP
Algumas tags HTML de navegadores tradicionais **não são suportadas ou são tratadas de forma diferente** no UXP:
- Tags de estrutura de página inteira (`<html>`, `<head>`, `<body>`, `<script>`, `<style>`) não são gerenciadas como em um browser convencional; o conteúdo do painel vive no nó-raiz (`rootNode`) retornado pelo entrypoint.
- Recomenda-se manipular conteúdo textual com `.textContent` em vez de `.innerHTML` por segurança e performance.

#### 3. Diferença Crucial: HTML DOM vs. Premiere Pro DOM
- **HTML DOM**: Gerencia a interface visual do plugin (`document`, `createElement`, `sp-button`, eventos de UI).
- **Premiere Pro DOM**: Gerencia o projeto de vídeo (`require("premierepro")`, `getActiveSequence()`, tracks, clipes, marcadores).

---

### J. Manipulação de Eventos HTML (HTML Events Deep Dive)

#### 1. Abordagem Recomendada: `addEventListener`
O uso de `addEventListener()` é a forma recomendada para manipular interações no UXP:
```javascript
const slider = document.querySelector("sp-slider");

// Evento "input": dispara em tempo real enquanto o usuário arrasta o slider
slider.addEventListener("input", (evt) => {
  console.log("Valor em tempo real:", evt.target.value);
});

// Evento "change": dispara quando o usuário solta o controle ou muda o foco
slider.addEventListener("change", (evt) => {
  console.log("Novo valor confirmado:", evt.target.value);
});
```

#### 2. Principais Tipos de Eventos Suportados
- **`click`**: Clique em botões (`sp-button`), links ou itens interativos.
- **`input`**: Alteração contínua de valores em caixas de texto (`sp-textfield`) e sliders (`sp-slider`).
- **`change`**: Confirmação de alteração em seletores (`sp-dropdown`, `<select>`) ou perda de foco.
- **`CustomEvent`**: Comunicação personalizada entre partes da interface do plugin:
```javascript
const customEvt = new CustomEvent("silenceProcessed", { detail: { count: 12 } });
document.dispatchEvent(customEvt);
```

#### 3. Atenção aos Inline Handlers (`onclick="..."`)
- O uso de atribuição inline (ex: `<button onclick="doSomething()">`) é **desencorajado** por questões de segurança.
- Se for estritamente necessário usar inline handlers, o `manifest.json` **precisa habilitar**:
```json
{
  "requiredPermissions": {
    "allowCodeGenerationFromStrings": true
  }
}
```
*Boas práticas: Sempre utilizar `addEventListener()` e evitar inline handlers.*

---

### K. Módulos JavaScript e Organização de Código (JS Modules Deep Dive)

#### 1. Sistema de Módulos: CommonJS
No ambiente UXP nativo, a organização de arquivos JavaScript utiliza o padrão **CommonJS** (`require` / `module.exports`), em vez dos ES Modules (`import` / `export`):

- **Exportando um Módulo (`utils/silenceDetector.js`)**:
```javascript
function detectSilence(audioBuffer, threshold) {
  // Lógica de cálculo de áudio
  return [];
}

module.exports = {
  detectSilence
};
```

- **Importando um Módulo (`main.js`)**:
```javascript
// OBRIGATÓRIO: incluir caminho relativo completo e a extensão .js
const { detectSilence } = require("./utils/silenceDetector.js");
const ppro = require("premierepro");
const { entrypoints } = require("uxp");
```

#### 2. Regras Críticas para Requisição de Módulos Locais
- **Extensão `.js` Obrigatória**: Diferente do Node.js tradicional, o UXP exige declarar expressamente a extensão `.js` na string de `require()` (ex: `./helpers.js`, não `./helpers`).
- **Caminho Relativo**: Deve iniciar com `./` ou `../`. O UXP não faz busca de módulos em caminhos globais do sistema.
---

## 21. Perguntas Frequentes (FAQ & Transição CEP para UXP)

### A. Por que mudar de CEP (ExtendScript) para UXP?
1. **Performance**: O CEP usava CEF (Chromium) + Node.js separado, consumindo muita memória. O UXP é um runtime leve nativo da Adobe com consumo mínimo de RAM e inicialização instantânea.
2. **Ambiente Unificado**: No CEP, a UI rodava em JS e o Premiere em ExtendScript (via bridge `CSInterface.evalScript`). No UXP, a UI e as chamadas ao Premiere DOM rodam no **mesmo ambiente JavaScript**.
3. **Plugins Híbridos C++**: Suporte nativo a extensões C++ (`.uxpaddon`) para tarefas pesadas de processamento (ex: DSP de áudio), algo impossível no CEP.

### B. Transição de Código Síncrono para Assíncrono
- No ExtendScript, todas as chamadas eram bloqueantes e síncronas.
- No UXP, o Premiere DOM opera assincronamente em segundo plano. Contudo, **getters e setters de propriedades simples foram projetados para responder de forma síncrona**, facilitando a migração sem exigir `await` em cada leitura simples de propriedade.

### C. O que fazer se uma API do CEP ainda não existir no UXP?
- O UXP está em evolução contínua. Para recursos legados que ainda não possuem equivalente direto no Premiere DOM UXP, a Adobe recomenda relatar nos [fóruns oficiais da comunidade de desenvolvedores UXP](https://forums.creativeclouddeveloper.com/c/uxp-for-premiere-pro/105) para priorização da API.












