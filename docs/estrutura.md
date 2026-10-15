# Estrutura do código-fonte

O CiNey mantém um núcleo Flutter em `packages/ciney_core/`, um host mobile em
`cinemax/` e um host Android TV em `cinemax_tv/`. Os dois hosts dependem do núcleo.
Novas telas, serviços e componentes compartilhados devem ficar no núcleo. Os
testes compartilhados permanecem em `cinemax/test/`.

```text
.
├── cinemax/
│   ├── lib/
│   │   ├── main.dart            # Entrada mobile
│   │   ├── mobile/             # Adaptadores exclusivos de celular
│   │   ├── cinemax_app.dart    # Export de compatibilidade do núcleo
│   │   ├── core/              # Exports de compatibilidade
│   │   ├── features/          # Exports e scanner do celular
│   │   └── plugin_engine/     # Exports de compatibilidade
│   ├── test/                   # Testes Flutter e JavaScript
│   ├── packages/               # Plugins locais, como o observador de mídia embed
│   ├── android/                # Host Android mobile
│   ├── ios/                    # Host iOS
│   └── regras/                 # Diretrizes comuns às duas variantes
├── packages/ciney_core/
│   ├── lib/                    # Implementação compartilhada, fontes e players
│   └── assets/                 # Imagens e JavaScript dos dois hosts
├── cinemax_tv/
│   ├── lib/main.dart           # Inicializa a base com isTv: true
│   └── android/                # Host, launcher e recursos Android TV
├── scripts/                    # Publicação mobile
├── supabase/                   # Migrações, modelos de e-mail e testes das contas
├── docs/
│   ├── README.md               # Índice desta documentação
│   ├── estrutura.md            # Este mapa
│   ├── contas-supabase.md
│   ├── colecoes-de-filmes.md
│   ├── continuidade-episodios.md
│   ├── performance-optimization.md
│   ├── retomada-reproducao.md
│   ├── tv-player-engine.md
│   ├── historico/              # Publicações, testes e planos substituídos
│   │   ├── publicacao-*.md
│   │   ├── testes-android-2026-10-08.md
│   │   ├── teste-inicio-automatico-android-2026-10-08.md
│   │   ├── reproducao-nativa-tv-plano-substituido.md
│   │   └── images/testes-android-2026-10-08/
│   └── screenshots/            # Capturas reais do aplicativo, quando adicionadas
├── releases/
│   ├── mobile/                 # Último APK mobile publicado, ignorado pelo Git
│   └── tv/                     # Último APK TV publicado, ignorado pelo Git
├── .github/workflows/           # Automação do GitHub
```

## Organização da base Flutter

| Caminho | Conteúdo |
| --- | --- |
| [`core/config/`](../packages/ciney_core/lib/core/config/) | Ambiente, tema, cores e tipografia. |
| [`core/routes/`](../packages/ciney_core/lib/core/routes/) | Rotas e navegação. |
| [`core/services/`](../packages/ciney_core/lib/core/services/) | Serviços comuns, como logs e atualizações. |
| [`core/widgets/`](../packages/ciney_core/lib/core/widgets/) | Componentes reutilizáveis e suporte a foco. |
| [`features/`](../packages/ciney_core/lib/features/) | Módulos `auth`, `favorites`, `splash`, `onboarding`, `main_navigation`, `home`, `search`, `details`, `player`, `downloads`, `extensions` e `profile`. |
| [`plugin_engine/`](../packages/ciney_core/lib/plugin_engine/) | Integração com catálogos e provedores de reprodução. |
| [`test/`](../cinemax/test/) | Verificação da implementação compartilhada, inclusive interações de TV. |

Dentro de cada funcionalidade, as telas ficam em `presentation/`. Serviços e
modelos específicos ficam junto do módulo quando necessários. Componentes e
serviços usados por vários módulos pertencem a `core/`.

## Documentação e ferramentas

- [Índice da documentação](README.md)
- [Visão geral e comandos de execução](../README.md)
- [Host Android TV](../cinemax_tv/README.md)
- [Regras de desenvolvimento](../cinemax/regras/README.md)
- [Política de builds e releases](../cinemax/regras/04-politica-build-e-releases.md)
- [Notas de otimização](performance-optimization.md)
- [Coleções de filmes](colecoes-de-filmes.md)
- [Continuidade dos episódios](continuidade-episodios.md)
- [Retomada do filme no ponto de parada](retomada-reproducao.md)
- [Motor do player Android TV](tv-player-engine.md)
- [Histórico de publicações, testes e planos substituídos](historico/)
- [Configuração de contas e favoritos no Supabase](contas-supabase.md)
- [Organização dos APKs locais](../releases/README.md)

Os scripts estão em [`scripts/`](../scripts/). Os assets carregados pelos dois
apps ficam em `packages/ciney_core/assets/`. O script
`build-local-mobile-tv.ps1` gera variantes privadas em `outputs/`, separando os
APKs TV por arquitetura. Consulte a [separação dos hosts](separacao-mobile-tv.md).

As pastas `build/`, `.dart_tool/` e os caches do Gradle são gerados pelas
ferramentas. As saídas de compilação não fazem parte do código-fonte nem devem
servir de arquivo histórico de versões. As cópias locais para instalação ficam
somente em `releases/`, com um APK publicado por variante. O histórico de
lançamentos permanece no GitHub.
