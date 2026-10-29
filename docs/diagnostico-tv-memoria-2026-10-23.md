# Diagnostico fisico da TV - 2026-10-23

TV: 192.168.100.130:5555, Smart_TV C06. Pacote com.ciney.tv.lite_test.

Durante o relato de travamento: MemTotal 939628 kB; MemAvailable 43784 kB; GL mtrack 346204 kB; TOTAL PSS 428929 kB; SwapPss 76191 kB. top mostrou kswapd0 87.5% e 45% de iowait no agregado informado pelo top (400% corresponde a quatro nucleos). Os contadores pswpin e pswpout cresceram entre leituras. Logcat repetiu erros do lowmemorykiller ao ler zoneinfo. Esses erros sao do sistema e nao demonstram por si so a causa do consumo do app.

A conexao ADB caiu antes da comparacao controlada. Apos reconectar, dumpsys meminfo nao encontrou o processo do app; MemAvailable subiu para 297768 kB. Nao foi um teste A/B controlado e nao comprova vazamento. Nao atribuir GL mtrack exclusivamente ao cache de imagens: inclui recursos graficos cuja origem precisa ser medida.

Conclusao: pressao severa de memoria e paginacao sao um gargalo comprovado na amostra. Rede, codec e quadros perdidos do filme ainda nao foram isolados. Handoff HLS nativo nao confirmado. Proximo passo: medir cache Flutter e memoria grafica por etapa (Home, detalhes, WebView, video, saida), com dados de buffering e decoder, antes de alterar o mecanismo de renderizacao.
