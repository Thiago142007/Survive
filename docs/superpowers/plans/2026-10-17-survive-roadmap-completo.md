# Survive — Roadmap Completo de Desenvolvimento

**Data:** 2026-10-17  
**Base:** conversa salva em `/tmp/session-55960e51-d8dc-4ec4-b10d-0bf2ab5a53a3.md`  
**Engine:** Godot 4.x, renderer `gl_compatibility`, GDScript  
**Plataformas:** PC primeiro; mobile depois, com joysticks virtuais  
**Meta:** 60 FPS no hardware de referência, com qualidade ajustável

## 1. Visão

Survive é um jogo de sobrevivência low-poly sério, inspirado no ciclo de coleta,
construção e sobrevivência de ARK. O jogador começa vulnerável em um arquipélago
procedural, coleta recursos, cria ferramentas, constrói uma base, explora ilhas,
caça ou evita animais e tenta sobreviver pelo maior tempo possível.

Não haverá missões obrigatórias nem campanha linear: a progressão vem da
sobrevivência, exploração, Research Tree e qualidade da base.

## 2. Decisões confirmadas pelo usuário

- Primeira pessoa como padrão, com alternância para segunda e terceira pessoa.
- Visual low-poly sério e realista, não cartunesco.
- Ilhas proceduralmente geradas entre 2.500 m e 25.000 m.
- Mundo infinito, com geração e descarte conforme a exploração.
- Distância entre ilhas entre 1.000 m e 5.000 m.
- Ilhas pacíficas, hostis, com habitantes e com desastres naturais.
- Animais são a fauna e os inimigos; à noite surgem animais mais perigosos.
- Foco somente em sobreviver e construir, sem missões e sem clãs.
- Single-player e multiplayer; single-player pode ser aberto para multiplayer.
- Construção cooperativa sem permissões de dono.
- Chat escrito e voz por proximidade; inimigos podem ouvir voz próxima.
- Barcos e jangadas; o jogador acompanha o barco ao saltar em movimento.
- Fácil: vida e fome; Normal: vida, fome e sede; Difícil: vida, fome, sede e energia.
- Research Points ganhos por nível e usados na Research Tree.
- Save automático, save ao sair, múltiplos mundos e exportação com dados dos jogadores.
- Morte perde itens; respawn aleatório entre 1 e 3 ilhas de distância.
- Inventário sem peso; cada stack comporta 100 itens.
- Ferimentos curam com tempo ou bandagens; fome e sede afetam desempenho.
- Agricultura com enxada, sementes e rega diária; água próxima irriga sozinha.
- Temperatura pouco sensível: frio depende do tempo; calor depende da proximidade.

## 3. Construção definida

- Fundação obrigatória antes das demais peças.
- Grid automático de 2 m; nenhuma peça fora do grid.
- Peças conectadas a terreno, fundação ou outra peça.
- Construção no ar é recusada, recolhe o item e mostra mensagem ao jogador.
- `R` gira no eixo X; `T` gira no eixo Y.
- 90 graus normalmente; `Shift + R/T` usa 15 graus.
- Fundações com pilares permitem construir reto em terreno irregular.
- Peças: parede, fundação, fundação com pilares, telhado, janela, espinho,
  alçapão, porta, escada, baú, cama, mesa, cadeira e tocha.
- Materiais com resistência diferente: madeira, pedra, metal e futuros tiers.
- Até 3 melhorias; cada uma custa 50% do custo original e adiciona a vida original.
- Martelo repara usando o material original.
- Destruição devolve somente 15% dos materiais.
- Stress aumenta gradualmente, cresce ao remover peças e pode derrubar a estrutura.
- Sem pintura, cópia/duplicação ou permissões de proprietário.

## 4. Estado atual auditado

### Já existe

- Projeto Godot com OpenGL Compatibility configurado.
- Movimento WASD, corrida, pulo e troca de câmera.
- Inventário com stacks de 100 e sem peso.
- Coleta básica de madeira e pedra com `E`.
- Fundação experimental com grid, ghost, rotação e custo.
- HUD básico com madeira, pedra, vida, fome e sede.
- Necessidades básicas e respawn local.
- Arquipélago procedural inicial com oceano e seis ilhas low-poly.
- Launcher `run_survive.sh`.

### Problemas observados na imagem atual

- Céu/ambiente cinza ocupa quase toda a tela.
- Terreno e água aparecem pretos.
- Árvores e pedras são primitivas cinzas sem leitura visual.
- Escala da ilha está ruim para testar a primeira experiência.
- HUD é texto cru, sem hierarquia visual.
- Ainda não há menu de criação de mundo ou escolha de dificuldade.

## 5. Fases de execução

### Fase 0 — Correção visual e diagnóstico jogável

1. Criar materiais low-poly estáveis para água, areia, solo, grama, tronco e pedra.
2. Corrigir luz direcional, ambiente e céu natural sem sombras dinâmicas.
3. Ajustar escala da ilha inicial e garantir horizonte de água legível.
4. Garantir que o jogador nasce sobre a ilha, sem cair ou nascer dentro da geometria.
5. Corrigir primeira/terceira pessoa e distância segura da câmera.
6. Criar HUD com painéis semitransparentes, crosshair e mensagens de interação.
7. Testar abrir, olhar, andar, pular, coletar e construir por pelo menos 5 minutos.

**Aceite:** nenhuma área preta inesperada, nenhum objeto sem leitura e jogo jogável.

### Fase 1 — Loop de sobrevivência sólido

1. Tela de novo mundo com nome, descrição, seed e dificuldade.
2. Aplicar Easy/Normal/Hard de verdade às necessidades.
3. Fome, sede, energia, saúde, ferimentos e regeneração configuráveis.
4. Comidas, água potável, fogueira, bandagens e efeitos de debilitação.
5. Inventário visual completo e hotbar de ferramentas, comida e construções.

**Aceite:** iniciar um mundo, obter comida/água, sobreviver, debilitar e morrer.

### Fase 2 — Coleta, ferramentas e crafting

1. Dados de itens centralizados em Resources.
2. Machado, faca, picareta, pá, enxada, martelo, espada, lança, arco e estilingue.
3. Recursos com vida, dano por ferramenta, respawn e deformação simples.
4. Crafting direto e receitas combinadas.
5. Research Tree com Research Points persistentes por mundo.

**Aceite:** cada ferramenta tem função clara e o jogador cria ferramentas básicas.

### Fase 3 — Construção modular e stress

1. Catálogo de peças e variantes madeira/pedra/metal.
2. Ghost verde/vermelho, conectores, validação e custo.
3. Fundações, pilares, paredes, portas, janelas e telhados.
4. Stress por tempo, distância do apoio e remoção de peças.
5. Melhorias, reparo com martelo, drop de 15% e colapso determinístico.

**Aceite:** construir, melhorar, danificar, reparar, remover e colapsar uma casa.

### Fase 4 — Mundo procedural e streaming

1. Seed reproduzível e biomas.
2. Ilhas com tamanho, clima, recursos e perigo próprios.
3. Streaming por chunks e descarte de chunks distantes.
4. Ilhas pacíficas, hostis, de desastre e com habitantes.
5. Respawn por grafo de vizinhança entre 1 e 3 ilhas.

**Aceite:** explorar gera ilhas novas sem repetição óbvia e sem vazamento de memória.

### Fase 5 — Fauna, combate e domesticação

1. Animais pacíficos, predadores diurnos e noturnos.
2. Percepção por visão, som e voz.
3. Combate corpo a corpo e à distância com hitboxes.
4. Lança com dano por velocidade e imobilização por região.
5. Bloqueio, esquiva, armadura, armadilhas, caça, domesticação e montaria.

**Aceite:** animal pode ser encontrado, atacar, receber dano, morrer e dar recursos.

### Fase 6 — Agricultura, clima e temperatura

1. Terreno arável e sementes de abóbora, trigo, beterraba, batata e cenoura.
2. Crescimento por dia, regador e irrigação perto de água.
3. Chuvisco, chuva normal, tempestade e furacão.
4. Raios, incêndios e dano a plantações, animais, jogador e construções.
5. Temperatura por frio/tempo e calor/proximidade.

**Aceite:** clima muda agricultura e risco sem temperatura irritante.

### Fase 7 — Barcos e exploração

1. Jangada e barco evoluído.
2. Vida, colisão e movimento de embarcação.
3. Compensação de movimento para o jogador acompanhar o barco.
4. Natação e queda na água.
5. Recursos raros que justificam explorar ilhas distantes.

**Aceite:** viajar entre duas ilhas e saltar em movimento funciona corretamente.

### Fase 8 — NPCs, menus e saves

1. Habitantes com rotinas simples.
2. Menu, lista e criação de mundos.
3. Save automático periódico e save ao sair.
4. Exportação/importação com mundo e dados de jogadores.
5. Recuperação segura de save corrompido.

**Aceite:** dois mundos podem coexistir, ser reabertos e exportados sem mistura.

### Fase 9 — Multiplayer

1. Autoridade do mundo e replicação de jogadores.
2. Construção cooperativa e inventários separados.
3. Abrir single-player para multiplayer.
4. Steamworks/SpaceWar para sessão e convites.
5. Chat escrito e voz por proximidade via WebRTC.
6. Voz alimenta a percepção de inimigos.

**Aceite:** dois jogadores entram, veem movimento, coletam, constroem e salvam.

### Fase 10 — Mobile e otimização

1. Joystick virtual esquerdo para movimento e direito para câmera.
2. Botões contextuais para pular, atacar, interagir, construir e inventário.
3. Escala de resolução, qualidade e distância configuráveis.
4. Pooling de fauna, recursos e efeitos.
5. Profiling no hardware de referência e teste de 60 FPS.
6. Empacotamento Linux, Windows e Android.

**Aceite:** PC mantém 60 FPS alvo e mobile funciona sem teclado/mouse.

## 6. Regras técnicas

- Sem sombras dinâmicas, SSAO, bloom ou pós-processamento pesado.
- Materiais simples e atlas quando assets reais forem adicionados.
- Instancing/pooling para vegetação, pedras, itens e fauna repetidos.
- Nenhuma alocação grande em `_process` ou `_physics_process`.
- Toda feature precisa de teste headless e teste executando o jogo.
- Toda mudança visual deve ser validada visualmente.
- Corrigir primeiro bugs que impedem leitura ou controle.
- Manter o jogo jogável ao fim de cada fase.

## 7. Próximo trabalho

Começar pela Fase 0: corrigir materiais, iluminação, escala da ilha, posição da
câmera e HUD; validar visualmente essa primeira cena antes de sistemas maiores.

