# PLAN: Estratégia de Teste Seguro Antes do Lançamento Oficial (Staging & Beta Testing)

> **Data:** 13/10/2026  
> **Status:** Proposto / Planejamento  
> **Objetivo:** Estabelecer um fluxo onde apenas você (ou testadores autorizados) possa testar e validar versões atualizadas do **CiNey** e do **CastLite** antes de liberar a atualização pública para todos os clientes.

---

## 1. Como o Sistema Atual Funciona (Diagnóstico)

No CiNey atual (`cinemax/lib/core/services/app_updater.dart`):
1. O app consulta `https://api.github.com/repos/NeyvanSantos/CINEY/releases/latest`.
2. O endpoint `/latest` da API do GitHub:
   - **Retorna apenas Releases Estáveis oficiais**.
   - **Ignora automaticamente** qualquer release marcada como `Pre-release` ou `Draft`.
3. No código:
   - Se `data['prerelease'] == true`, o app **rejeita** a atualização e não exibe para os clientes.

Isso significa que o mecanismo nativo do GitHub e do app já possui a fundação perfeita para canais de teste isolados!

---

## 2. Modelos de Teste Antecipado Viáveis

### Modelo A: Teste via ADB Local / Sideloading (Imediato, Zero Mudança no Backend)
- **Como funciona:**
  - Sempre que finalizarmos uma nova funcionalidade, geramos o APK de teste e instalamos diretamente no seu aparelho via ADB (`adb install -r`) ou disponibilizamos o arquivo `.apk` em uma pasta de staging.
  - Você testa no seu celular com tranquilidade.
  - Só quando você der o comando explícito: *"Aprovado, pode lançar a Release"*, o robô cria a tag e o Release estável no GitHub com o APK oficial.
- **Vantagens:** 100% seguro, nenhum cliente sequer sonha que há uma versão nova antes da sua aprovação.

---

### Modelo B: Canal Beta / Pre-Release no GitHub (Recomendado para Testes Remotos)
- **Como funciona:**
  - Lançamos uma release marcada como **"Set as a pre-release"** (tag `vX.Y.Z-beta` ou `test-vX.Y.Z`).
  - Clientes comuns nunca recebem essa versão (o GitHub `/releases/latest` não a entrega).
  - Adicionamos no menu Perfil do CiNey uma opção oculta (ou com clique quádruplo na versão): **"Canal de Atualizações: [Estável / Beta]"**.
  - Apenas o seu usuário (com canal Beta ativo) baixa essa versão antecipada diretamente pela interface do app.
- **Vantagens:** Permite que você teste a atualização OTA (pelo próprio diálogo do app) sem arriscar os clientes normais.

---

### Modelo C: Filtro por Conta de Administrador via Supabase
- **Como funciona:**
  - No Supabase, sua conta de usuário tem uma flag especial (ex: `role: 'admin'` ou `is_tester: true`).
  - O `AppUpdater` envia o ID do usuário ou checa na tabela `app_versions`:
    - Se o usuário for admin, busca a versão de teste.
    - Se for usuário comum, busca apenas a versão estável aprovada.
- **Vantagens:** Controle centralizado na nuvem, você pode autorizar amigos ou testadores adicionais sem recompilar o app.

---

## 3. Matriz Comparativa

| Critério | Modelo A (ADB / Local) | Modelo B (GitHub Pre-Release) | Modelo C (Admin Supabase) |
| :--- | :---: | :---: | :---: |
| **Complexidade** | Mínima (Já pronta) | Baixa (Poucas linhas) | Média |
| **Risco para clientes** | 0% (Impossível vazar) | 0% (Protegido por API) | 0% (Protegido por Auth) |
| **Testa fluxo de Auto-Update** | ❌ Não | ✅ Sim | ✅ Sim |
| **Dependência de PC/Cabo** | Sim (USB/Wi-Fi ADB) | Não (Direto no app) | Não (Direto no app) |

---

## 4. Plano de Execução Proposto

1. **Etapa 1 (Políticas de Git & Release):**
   - Nunca disparar build de release final com tag `vX.Y.Z` antes do teste manual passar.
   - Criar script/comando `/pre-release` ou `stage-release` para gerar APK de validação.
2. **Etapa 2 (Canal Beta no CiNey):**
   - Adicionar chave de preferência no SharedPreferences: `update_channel` (`stable` vs `beta`).
   - No perfil, habilitar alternância para modo testador com confirmação de PIN ou clique contínuo.
3. **Etapa 3 (Validação E2E):**
   - Testar o fluxo completo: Criar pre-release ➔ celular de teste recebe ➔ celular cliente ignora ➔ aprovar ➔ promover a estável ➔ clientes recebem.
