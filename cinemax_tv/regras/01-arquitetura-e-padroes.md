# 🏛️ Regra 01: Arquitetura & Padrões de Código

---

## 1. Organização de Pastas (Clean Feature-First)

Todo o código dentro de `cinemax/lib/` segue a convenção orientada a features:

```text
lib/
├── core/                       # Código compartilhado global
│   ├── config/theme/           # AppColors, AppTheme, AppTypography
│   ├── routes/                 # app_router.dart (GoRouter)
│   ├── services/               # AppLogger, AppUpdater, etc.
│   └── widgets/                # GlassCard, GradientPoster, UpdateDialog, etc.
├── features/                   # Módulos funcionais independentes
│   ├── <nome_da_feature>/
│   │   ├── models/             # Entidades e modelos de dados
│   │   ├── presentation/       # Telas (Screens) e Widgets da feature
│   │   └── services/           # Lógica de negócio, repositórios locais e APIs
└── plugin_engine/              # Motor modular de extensões de catálogo e streaming
```

---

## 2. Gerenciamento de Estado

- **Padrão Oficial:** `flutter_riverpod` com ou sem `riverpod_annotation`.
- Evite criar `StatefulWidget` com estado espalhado complexo quando um `Notifier` ou `StreamProvider` for mais adequado.
- Gerenciamento local simples (ex.: animações de tela, controladores de foco) pode utilizar `StatefulWidget`.

---

## 3. Roteamento e Navegação

- Toda navegação deve ser declarada em `lib/core/routes/app_router.dart` usando `go_router`.
- Para navegações entre abas inferiores (Home, Busca, Downloads, Perfil), use `StatefulShellRoute.indexedStack`.
- Para telas de fluxo direto ou modais (Player, Detalhes, Extensões, Logs), utilize `parentNavigatorKey: _rootNavigatorKey` para cobrir a barra de navegação inferior.

---

## 4. Sistema Centralizado de Logs (`AppLogger`)

> 🚫 **PROIBIDO O USO DE `print()` OU `debugPrint()` SOLTOS NO CÓDIGO!**

Todo evento do ciclo de vida da aplicação deve ser emitido pelo `AppLogger`:

```dart
// Debug
AppLogger.debug('Parâmetros da requisição: $params', tag: 'NETWORK');

// Informação
AppLogger.info('Usuário iniciou reprodução do vídeo: $title', tag: 'PLAYER');

// Aviso
AppLogger.warn('Fonte lenta ou instável detectada', tag: 'STREAM');

// Erro (com stackTrace opcional)
AppLogger.error('Falha ao obter catálogo: $error', tag: 'PLUGINS', stackTrace: stack);

// Sucesso
AppLogger.success('Download da atualização concluído com sucesso', tag: 'UPDATER');
```

**Motivo:** O CineMax conta com uma tela integrada de diagnóstico e monitoramento em tempo real (`/logs`), permitindo debugar streams, conexões e extensões diretamente no app.

---

## 5. Qualidade de Código & Análise Estática

- Todo código adicionado deve passar no `flutter analyze` com **zero erros e zero warnings**.
- Utilize `const` em construtores de widgets sempre que possível para preservar a taxa de quadros (60/120 fps).
- Nunca ignore exceções com blocos `catch` vazios.
