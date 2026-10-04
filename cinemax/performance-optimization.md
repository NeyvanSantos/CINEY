# Otimizacao de performance e estabilidade

## Objetivo
Reduzir travamentos, jank, consumo de memória e tempo percebido no CineMax sem alterar contratos de reprodução ou navegação.

## Tarefas
- [x] Medir a linha de base com `flutter analyze`, testes e auditoria mobile -> registrar falhas reais antes de editar.
- [x] Mapear reconstruções, listas, imagens e chamadas de rede nas telas de Home, busca e detalhes -> escolher apenas gargalos comprovados.
- [x] Otimizar o ciclo de vida do player e do WebView -> garantir dispose, cancelamento e troca de fonte sem retenção.
- [x] Melhorar cache, concorrência e estados de carregamento -> evitar trabalho duplicado e telas sem feedback.
- [x] Ajustar acessibilidade e interação Android -> manter alvos de toque, erros recuperáveis e navegação previsível.
- [x] Adicionar testes de regressao para os caminhos alterados -> cobrir carga, erro, retry e descarte.
- [x] Validar com analyze, testes e build debug -> comparar com a linha de base.

## Feito quando
- O projeto passa em `flutter analyze` e nos testes existentes.
- Não há novos vazamentos conhecidos de controllers, timers, subscriptions ou WebViews.
- As telas principais mantêm comportamento e navegação atuais.
- A APK debug compila e inicia no dispositivo Android conectado.

## Pendencia externa

O celular não estava listado no ADB ao final da validação (`adb devices` sem dispositivos), então a reinstalação e a leitura de logcat no aparelho precisam ser repetidas após reconectar o USB.