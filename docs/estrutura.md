# Estrutura do código-fonte

O CiNey mantém uma base Flutter em `cinemax/` e um host Android TV em
`cinemax_tv/`. A TV importa a base por dependência local, por isso novas telas,
serviços, componentes e testes compartilhados devem ficar em `cinemax/`.

```text
.
├── cinemax/
│   ├── lib/
│   │   ├── main.dart            # Entrada mobile
│   │   ├── cinemax_app.dart     # Inicialização compartilhada
│   │   ├── core/               # Configuração, rotas, serviços e widgets
│   │   ├── features/           # Funcionalidades do aplicativo
│   │   └── plugin_engine/      # Contratos, modelos, plugins e fontes
│   ├── assets/                 # Recursos usados pelo aplicativo
│   ├── test/                   # Testes Flutter e JavaScript
│   ├── android/                # Host Android mobile
│   ├── ios/                    # Host iOS
│   └── regras/                 # Diretrizes comuns às duas variantes
├── cinemax_tv/
│   ├── lib/main.dart           # Inicializa a base com isTv: true
│   └── android/                # Host, launcher e recursos Android TV
├── receiver/                   # Receptor Google Cast compartilhado
├── scripts/                    # Publicação mobile
├── docs/
│   ├── estrutura.md            # Este mapa
│   ├── performance-optimization.md
│   └── images/                 # Imagens da documentação
├── releases/
│   ├── mobile/                 # Último APK mobile publicado, ignorado pelo Git
│   └── tv/                     # Último APK TV publicado, ignorado pelo Git
├── .github/workflows/           # Automação do GitHub
└── .agent/                     # Ferramentas e instruções de desenvolvimento
```

## Organização da base Flutter

| Caminho | Conteúdo |
| --- | --- |
| [`core/config/`](../cinemax/lib/core/config/) | Ambiente, tema, cores e tipografia. |
| [`core/routes/`](../cinemax/lib/core/routes/) | Rotas e navegação. |
| [`core/services/`](../cinemax/lib/core/services/) | Serviços comuns, como logs e atualizações. |
| [`core/widgets/`](../cinemax/lib/core/widgets/) | Componentes reutilizáveis e suporte a foco. |
| [`features/`](../cinemax/lib/features/) | Módulos `splash`, `onboarding`, `main_navigation`, `home`, `search`, `details`, `player`, `cast`, `downloads`, `extensions` e `profile`. |
| [`plugin_engine/`](../cinemax/lib/plugin_engine/) | Integração com catálogos e provedores de reprodução. |
| [`test/`](../cinemax/test/) | Verificação da implementação compartilhada, inclusive interações de TV. |

Dentro de cada funcionalidade, as telas ficam em `presentation/`. Serviços e
modelos específicos ficam junto do módulo quando necessários. Componentes e
serviços usados por vários módulos pertencem a `core/`.

## Documentação e ferramentas

- [Visão geral e comandos de execução](../README.md)
- [Host Android TV](../cinemax_tv/README.md)
- [Regras de desenvolvimento](../cinemax/regras/README.md)
- [Política de builds e releases](../cinemax/regras/04-politica-build-e-releases.md)
- [Notas de otimização](performance-optimization.md)
- [Configuração do receptor Google Cast](../receiver/README.md)
- [Organização dos APKs locais](../releases/README.md)

Os scripts de publicação estão em [`scripts/`](../scripts/). A imagem de apoio
à documentação fica em [`docs/images/captura-readme.png`](images/captura-readme.png).
Os assets carregados pelo app continuam em `cinemax/assets/`.

As pastas `build/`, `.dart_tool/` e os caches do Gradle são gerados pelas
ferramentas. As saídas de compilação não fazem parte do código-fonte nem devem
servir de arquivo histórico de versões. As cópias locais para instalação ficam
somente em `releases/`, com um APK publicado por variante. O histórico de
lançamentos permanece no GitHub.
