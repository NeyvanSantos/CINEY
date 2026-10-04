# 🎨 Regra 02: UI/UX & Design System CineMax

---

## 1. Identidade Visual e Filosofia de Design

O CineMax possui uma interface com estética **Dark Glassmorphism Premium**, focada em imersão cinematográfica para dispositivos móveis e TVs.

### Cores Oficiais (`AppColors`):
- **Background Principal:** `#0A0A1A` (`AppColors.background`)
- **Superfícies & Cards:** `#151530` (`AppColors.surface`), `#1C1C3A` (`AppColors.surfaceLight`)
- **Cor Primária de Destaque:** `#FF6B00` Laranja Intenso TLN+ (`AppColors.primary`)
- **Gradiente Primário:** `AppColors.primaryGradient` (Laranja #FF6B00 → Âmbar #FF9500)
- **Acentos Secundários:** `#7B2FF7` Roxo Neon (`AppColors.accent`)
- **Sucesso:** `#00E676` | **Aviso:** `#FFD600` | **Erro:** `#FF5252`

---

## 2. Regras Estritas de Componentização

1. **Uso do `GlassCard`:**  
   Sempre que criar cards de conteúdo, listas de configurações ou modais, utilize o componente oficial [GlassCard](file:///g:/Filmes%20e%20S%C3%A9ries%20%28Criado%20por%20Ney%29/cinemax/lib/core/widgets/glass_card.dart) com desfoque de fundo e borda translúcida.

2. **Tipografia Consistente (`AppTypography`):**  
   Não defina `TextStyle` com fontes avulsas ou tamanhos arbitrários sem necessidade. Utilize os tokens de `AppTypography` (`displayMedium`, `headlineLarge`, `headlineMedium`, `labelLarge`, `bodySmall`).

3. **Microanimações Suaves:**  
   Telas e cards principais devem utilizar `flutter_animate` com entradas orgânicas (fade, slide sutil ou shimmer no carregamento). Nunca utilize animações que causem engasgos ou atrasem a navegação do usuário.

4. **Proibição de Cores Genéricas:**  
   Não utilize cores padrão do Flutter (como `Colors.blue`, `Colors.red`, `Colors.green`) em botões ou ícones de destaque. Sempre faça referência a `AppColors`.
