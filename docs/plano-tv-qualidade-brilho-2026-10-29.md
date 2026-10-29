# Qualidade real e brilho no player TV

Escopo autorizado: melhorar a seleção/indicação de qualidade e fontes, manter reprodução estável e acrescentar brilho na lateral do player Android TV. Mobile e CastLite preservam seus contratos; não haverá publicação.

## Decisões

- Manter Media3/SurfaceView e HTTP nativo com sessão do navegador apenas quando necessária. A TV tem aproximadamente 918 MiB de RAM; não aumentar o buffer por tentativa.
- Mostrar resolução do vídeo e opções suportadas de suas faixas, com Automática como padrão. 1080p só aparece quando a mídia o oferece. Retirar a promessa fixa de 1080p antes de resolver a fonte.
- Adicionar ações Qualidade, Brilho e Servidores na lateral direita, acessíveis por toque e D-pad. Voltar fecha primeiro o painel; Menu continua abrindo servidores.
- Brilho ajusta os pixels por `media3-effect` da mesma versão do player. O pipeline de efeitos só será habilitado ao primeiro ajuste para não impor esse custo à reprodução padrão. A primeira ativação pode reabrir o decodificador preservando posição, pausa e qualidade.
- Brilho inicia em Original por sessão e tem intensidade limitada. Falha do processamento deve retornar à imagem original com aviso, preservando a reprodução.
- Testar as políticas de seleção e limites de brilho em JVM, as indicações no Flutter e a integração no aparelho. Documentar separadamente testes automatizados, físicos e limitações externas.

## Alternativas e limites

O brilho da janela Android não garante controle do painel físico da TV. Uma camada branca sobre o filme reduz contraste; por isso será usada a transformação real do vídeo. Trocar toda a biblioteca de reprodução acrescentaria risco sem corrigir fontes limitadas a 240p/720p. Não inventar URLs 1080p nem contornar validações dos provedores.

A disponibilidade e a maior resolução variam por título/player interno. Verificar alternativas acessíveis dos dois provedores e registrar o que de fato existe. A comparação física deve incluir qualidade original, brilho ativo, pausa, busca e continuidade; qualquer custo de memória/quadros será medido.
