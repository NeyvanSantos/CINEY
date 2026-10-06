# 📜 Regras de Desenvolvimento e Código-Fonte — CineMax

> **Guia Obrigatório de Diretrizes Técnicas, Arquiteturais e de Segurança.**  
> Qualquer agente de IA ou desenvolvedor humano que atue no código-fonte do **CineMax** DEVE ler e seguir rigorosamente as regras documentadas nesta pasta.

Estas diretrizes são compartilhadas por `cinemax/` e `cinemax_tv/`. Esta pasta
é a referência única para ambas as variantes. Consulte também o
[mapa do código-fonte](../../docs/estrutura.md).

---

## 🗂️ Estrutura das Regras

| Arquivo | Descrição | Nível de Prioridade |
|---------|-----------|---------------------|
| [01-arquitetura-e-padroes.md](01-arquitetura-e-padroes.md) | Clean Architecture, Riverpod, GoRouter, Logging obrigatório e boas práticas de Dart | **P1 (Obrigatório)** |
| [02-ui-ux-design-system.md](02-ui-ux-design-system.md) | Design System CineMax, Glassmorphism, AppColors, AppTypography e animações | **P1 (Obrigatório)** |
| [03-protecao-cast-e-streaming.md](03-protecao-cast-e-streaming.md) | 🔒 **Proteção Inviolável do Sistema de Transmissão** (Chromecast, DLNA, WebCastServer, WVC) | **P0 (Inviolável / Bloqueante)** |
| [04-politica-build-e-releases.md](04-politica-build-e-releases.md) | Repositório oficial (`NeyvanSantos/CINEY`), auto-update via GitHub Releases e política de APK sob demanda | **P0 (Regra Estrita)** |
| [05-plugin-engine.md](05-plugin-engine.md) | Arquitetura modular de extensões, resolução de streams e isolamento de provedores | **P1 (Obrigatório)** |
| [06-finalizacao-e-qualidade.md](06-finalizacao-e-qualidade.md) | 💎 **Integridade, Organização e Padrão Profissional Obrigatório** ao final de cada alteração | **P0 (Mandatório)** |

---

## ⚡ Princípios Fundamentais (TL;DR)

1. **Finalização Sólida e Profissional Obrigatória:** Sempre no final de cada alteração, deixe o código-fonte sólido, organizado, com os arquivos em suas devidas pastas, sem quebrar nada. O projeto tem que estar impecável e profissional, e o agente/desenvolvedor deve obrigatoriamente reportar ao final que cumpriu este procedimento.
2. **Nunca use `print()` solto no código:** Utilize sempre `AppLogger.info()`, `AppLogger.warn()`, `AppLogger.error()` ou `AppLogger.debug()`.
3. **Nunca altere os arquivos de Cast sem autorização explícita:** Os arquivos do proxy de transmissão possuem proteções contra cloaking de provedores e são críticos.
4. **Nunca gere APKs automaticamente:** Builds de APK só devem ser gerados sob solicitação expressa do usuário.
5. **Respeite o Design System Oficial:** Fundo escuro premium (`AppColors.background`), destaque Laranja CineMax (`AppColors.primary`), efeitos `GlassCard` e tipografia `AppTypography`.
6. **Código Limpo e Testado:** Sempre rode `flutter analyze` após qualquer alteração para garantir zero lints e erros de compilação.
