

\# CiNey — Instruções permanentes para agentes de IA



\## 1. Utilização obrigatória do AAS



Este projeto utiliza o Agentic Awesome Skills (AAS).



As habilidades estão instaladas em:

`.agents/skills/`



Em TODA tarefa de desenvolvimento, análise, correção, revisão ou manutenção:



1\. Identifique quais habilidades do AAS são relevantes.

2\. Verifique quais estão realmente instaladas.

3\. Leia o SKILL.md das habilidades selecionadas antes de executar a tarefa.

4\. Aplique suas instruções durante o trabalho.

5\. Informe resumidamente quais habilidades foram utilizadas.

6\. Caso uma habilidade necessária não esteja instalada, informe isso sem inventar seu conteúdo.



Não carregue todas as habilidades indiscriminadamente.

Selecione as adequadas à tarefa.



\## 2. Seleção automática de habilidades



Utilize as seguintes habilidades conforme a necessidade:



\- brainstorming:

&#x20; Planejamento de funcionalidades e decisões técnicas.



\- flutter-expert:

&#x20; Desenvolvimento, otimização e manutenção Flutter/Dart.



\- systematic-debugging:

&#x20; Diagnóstico de erros, investigação de bugs e identificação da causa raiz.



\- test-driven-development:

&#x20; Implementação de correções e funcionalidades com testes de regressão quando aplicável.



\- code-review-checklist:

&#x20; Revisão da qualidade e segurança das alterações.



\- lint-and-validate:

&#x20; Análise estática, validação e testes.



\- api-contract-testing:

&#x20; Integração entre APIs, plugins, provedores e serviços.



\- auth-implementation-patterns:

&#x20; Autenticação, sessões e autorização.



\- secrets-management:

&#x20; Proteção de credenciais, tokens e informações sensíveis.



\- github-actions-templates:

&#x20; Manutenção de workflows, builds e processos de publicação.



\## 3. Regras específicas do CiNey



\- Respeite a arquitetura existente do projeto.

\- Preserve a compatibilidade entre Android Mobile e Android TV.

\- Respeite as regras existentes em cinemax/regras/.

\- Consulte a documentação técnica relevante antes de mudanças estruturais.

\- Não remova funcionalidades sem solicitação.

\- Não introduza dependências desnecessárias.

\- Não execute push, tags ou releases sem autorização explícita.

\- Não modifique arquivos fora do escopo solicitado.

\- Preserve as integrações do player, WebView e CastLite.



\## 4. Fluxo de trabalho



Para alterações de código:



1\. Entender a solicitação.

2\. Selecionar e carregar as habilidades apropriadas.

3\. Examinar apenas os arquivos e documentos necessários.

4\. Identificar riscos e dependências.

5\. Implementar a alteração solicitada.

6\. Executar verificações e testes pertinentes.

7\. Revisar o resultado e identificar possíveis regressões.



Para auditorias, respeite o modo somente leitura quando solicitado.



\## 5. Validação



Quando aplicável, utilize os comandos de validação documentados pelo CiNey:



Em cinemax/:

\- flutter analyze

\- flutter test --no-pub



Para testes das integrações JavaScript, consulte os comandos documentados no README.



Não afirme que um teste passou sem executá-lo.

Se não puder executar um teste, explique o motivo.



\## 6. Relatório final



Ao finalizar cada tarefa de desenvolvimento, informe:



\- Habilidades AAS utilizadas.

\- Arquivos modificados.

\- Problemas encontrados e resolvidos.

\- Testes executados e resultados.

\- Problemas ou riscos ainda existentes.



As instruções explícitas do usuário prevalecem sobre recomendações das habilidades, respeitando as regras de segurança aplicáveis.



