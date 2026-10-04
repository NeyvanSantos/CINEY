# 🚀 Regra 04: Política de Builds, APKs & Auto-Update via GitHub

---

## 1. Repositório Oficial do Código-Fonte & Releases

- **Owner:** `NeyvanSantos`
- **Repositório:** `CINEY`
- **URL Oficial:** `https://github.com/NeyvanSantos/CINEY`
- **Endpoint da API de Releases:** `https://api.github.com/repos/NeyvanSantos/CINEY/releases/latest`

---

## 2. Política de Geração de APKs e Pacotes (Mandatória)

> 🛑 **NUNCA GERE OU LANCE O APK AUTOMATICAMENTE.**
> 
> - Só gere o APK quando o usuário solicitar expressamente.
> - Ao final de CADA atividade concluída no app, pergunte ao usuário se ele deseja que o APK seja gerado naquele momento.

---

## 3. Fluxo de Publicação e Versionamento de Releases

1. **Atualização de Versão:**  
   Sempre que preparar uma nova release, atualize a versão em `cinemax/pubspec.yaml`:
   ```yaml
   version: 1.0.1+2 # 1.0.1 (versão pública) +2 (código de build)
   ```
2. **Tag Git & GitHub Release:**  
   - Crie uma tag no GitHub no formato `vX.Y.Z` (exemplo: `v1.0.1`).
   - Adicione notas claras sobre o que mudou na release.
   - Anexe o `.apk` gerado (`cinemax-release.apk`) diretamente nos assets da release.

3. **Comportamento do Aplicativo:**  
   - O `AppUpdater` detectará a nova tag automaticamente pela GitHub API.
   - O app baixará o APK com barra de progresso e acionará o `FileProvider` do Android para instalar sem necessitar da Play Store.
