# 💎 Regra 06: Integridade, Organização e Finalização Profissional

> **PRIORIDADE MÁXIMA (P0) — REGRA MANDATÓRIA**  
> Todo agente de IA ou desenvolvedor deve obrigatoriamente seguir este protocolo antes de concluir qualquer resposta ou entrega.

---

## 1. Diretriz de Conclusão do Código-Fonte

> **"Sempre no final de cada alteração, deixe o código-fonte sólido, organizado, devidas pastas em certos lugares, sem quebrar nada. O projeto tem que estar profissional, e ao final, diga que fez isso."**

---

## 2. Checklist Obrigatório de Finalização

Antes de dar uma tarefa por concluída, execute mentalmente e no terminal o seguinte roteiro de validação:

- [ ] **1. Integridade Funcional:**  
  Nenhuma funcionalidade existente foi quebrada, alterada indevidamente ou regredida.
- [ ] **2. Organização Estrutural:**  
  Novos arquivos foram criados rigorosamente em suas respectivas pastas (`core/`, `features/<feature>/presentation|services|models`, etc.), sem arquivos soltos ou fora de padrão.
- [ ] **3. Código Sólido & Zero Lints:**  
  O código passa na análise estática sem quebrar a compilação (`flutter analyze` sem erros críticos).
- [ ] **4. Padrão Visual & Arquitetural:**  
  Respeitou o Design System, Clean Architecture, injeção de dependências e sistema de logs (`AppLogger`).
- [ ] **5. Limpeza de Artefatos Temporários:**  
  Nenhum arquivo de teste descartável, log solto ou temporário foi deixado no repositório.

---

## 3. Protocolo de Comunicação Obrigatório

Ao finalizar o atendimento ao usuário, o agente **DEVE OBRIGATORIAMENTE declarar de forma clara e explícita** que:
1. Validou o código-fonte;
2. Deixou o projeto sólido, limpo e estruturado em suas devidas pastas;
3. Garantiu que nada foi quebrado e que o projeto permanece em nível profissional.
