# Survive — Documento de Design

> Nota: este é o rascunho de design. Ao sair do modo de planejamento, o documento
> definitivo será gravado em `docs/superpowers/specs/2026-10-17-survive-design.md`
> e versionado no projeto.

---

## 1. Intenção e o porquê

**Survive** é um jogo de sobrevivência low poly em primeira pessoa, no estilo ARK Survival
Evolved: o jogador nasce nu em um arquipélago infinito, coleta, caça, constrói e tenta
sobreviver o máximo possível. Não há missões, objetivoscripts ou fim — o único objetivo é
a duração da sobrevivência.

O 不同 que o diferencia do ARK:

- **Ilhas com personalidade.** O arquipélago é gerado proceduralmente e cada ilha é
  classificada como pacífica, hostil,毫 com desastres naturais, ou com habitantes. O
  jogador escolhe para onde ir e aceita o risco.
- **Mundo infinito.** Não existe limite de ilhas. A geração é contínua conforme o
  jogador explora, com descarte de chunks antigos (streaming).
- **Stress estrutural real.** Construções não são blocos decorativos: elas acumulam
  estresse,<Self*> colapsam, e furacões testam sua integridade.

---

## 2. Objetivos, não-objetivos e anti-objetivos

### Objetivos
- Sobreviver o máximo possível, com pressão crescente de fome, sede, energia e frio.
- Sistema de construção rico com variações de material, encaixe em grid e Estresse.
- Exploração de um arquipélago infinito com ilhas distintas entre si.
- 60fps estáveis no hardware de referência (ver §4).
- Rodar em PC (Linux/Windows) e Android (controles por joystick virtual).

### Não-objetivos (fora de escopo)
- Missões, objetivos ou história roteirizada.
- Sistema de clãs ou grupos.
- Veículos de guerra ou máquinas de guerra.
- Poções/magia: só consumíveis de comida.
- Pintura/customização de cor das construções.
- Clonagem/cópia de peças de construção.
- Saves em nuvem.
- Permissões por dono nas construções compartilhadas.

### Anti-objetivos (o que seria fracasso mesmo que "funcionasse")
- Um jogo que só roda no PC do desenvolvedor.
- Construção que é só decoração sem consequência (sem estresse, sem colapso).
- Mundo que acaba ou repete exatamente a mesma ilha.
- FPS travando em qualquer interação com constructs.

---

## 3. Restrições

### Hardware de referência (medido)

| Componente | Especificação |
|---|---|
| CPU | Intel Core i5-2400 @ 3.10GHz — 4 núcleos, **sem hyperthreading** |
| GPU | AMD Radeon HD 5430 (integrada, 2011) |
| RAM | 7,2 GB total, **~2 GB livres** |
| SO | Ubuntu 26.04.1 LTS, kernel 7.0 |

Consequências diretas:
- Multi-thread é fraco: o trabalho pesado precisa ser paralelo entre **4 threads**, não 8.
- A RAM é o recurso mais escasso. Streaming e descarte de chunks são obrigatórios.
- A GPU não aguenta sombras em tempo real, SSAO, bloom, ou 1080p nativo.

### Escolhas técnicas obrigatórias

- **Engine:** Godot 4 (a mais leve das opções Serious).
- **Renderer:** `Compatibility` (OpenGL 3.3). Não usar Forward+ nem Mobile.
- **Linguagem:** GDScript.
- **Resolução interna:** ~70% e escalar para a tela. Mais slider de 50%–100% nas
  configurações para o jogador ajustar.
- **Pós-processamento:** desligado. Sem bloom, sem SSAO, sem sombras dinâmicas.
- **Sombras:** não. Iluminação por luz direcional + hemisférica + bake.
- **Orçamento de assets (decisão do usuário: modelos low-poly prontos, com limites):**
  - Máximo **1.500 triângulos** por modelo de criatura/objeto.
  - Máximo **1 material** por malha, usando atlas de texturas.
  - Texturas **512×512** para criaturas/objetos, **1024×1024** só para terreno.
  - Instancing para plantas, pedras e itens repetidos.
  - LOD automático por distância em todas as criaturas.
- **Voz:** WebRTC com volume atenuado por distância (não a API de voz do Steam, que
  não expõe posição).

---

## 4. Mecânicas

### 4.1 Dificuldade

Escolhida na criação da partida e por mundo.

| | Fácil | Normal | Difícil |
|---|---|---|---|
| Vida | sim | sim | sim |
| Fome | sim (decai **devagar**) | sim | sim |
| Sede | não | sim (decai **devagar**) | sim |
| Energia | não | não | sim |
| Subida de nível | mais rápida | normal | mais lenta |

**Energia** (só no Difícil): consumida ao correr, nadar e bater. Sem energia →
fraqueza, lentidão e escurecimento da visão. Regenera com descanso e comida.

### 4.2 Necessidades
- **Fome** e **sede** afetam velocidade de movimento e velocidade de regeneração de vida.
- **Regeneração de vida** ocorre ao longo do tempo quando as necessidades estão atendidas.
- **Temperatura** existe mas é pouco sensível:
  - **Frio** depende do tempo (duração da noite, chuva, tempestade, altitude).
  - **Calor** depende de **proximidade** (fogueira, tocha, sol). Tochas dentro de casa
    não superaquecem o jogador facilmente.
- **Ferimentos:** recuperam com o tempo ou com **bandagens**.

### 4.3 Progressão
- O jogador ganha níveis; ganhar nível concede **1 Research Point**.
- A velocidade de subida de nível **diminui** conforme a dificuldade.
- **Research Tree:** os Research Points desbloqueiam novas receitas e novos materiais
  (madeira → pedra → metal → etc.).
- O nível não dá dano direto — o poder vem do desbloqueio.

### 4.4 Ferramentas

| Ferramenta | Função |
|---|---|
| **Espada** | Maior dano corpo a corpo. |
| **Faca** | Dano baixo. Colhe folhas, fibras, etc. |
| **Lança** | Thrown: se acertar **perna ou cabeça**, tenta imobilizar. Também causa dano corpo a corpo **escalado pela velocidade do investida** — quanto mais rápido o jogador corre, mais dano. |
| **Picareta** | Coleta minérios e pedras. **Deforma o terreno** ao minerar pedras/rochas. Quebra construções de pedra e materiais duros. |
| **Machado** | Quebra árvores. Mais rápido contra construções de madeira. |
| **Arco** | Dispara flechas. |
| **Estilingue** | Arremessa pedras. Dano por velocidade do projétil e ponto de acerto. |
| **Enxada** | Ara o terreno e **planta sementes**: abóbora, trigo, beterraba, batata, cenoura. |
| **Pá** | Deforma o terreno cavando. Coleta terra, areia, cascalho, lama. |
| **Martelo** | Dano médio, velocidade média. **Dano alto contra construções, independente do material.** Também repara construções. |

### 4.5 Agricultura
- O jogador ara com a enxada e planta sementes.
- Cada planta tem um **regador** (1 uso por dia).
- Plantas plantadas **perto o suficiente de água se irrigam sozinhas**.
- Só é possível irrigar manualmente plantas que **precisam** de irrigação.
- Chuva fraca e chuva normal também irrigam.

### 4.6 Construção

**Colocação**
1. É obrigatória uma **fundação** antes de qualquer outra peça.
2. Peças encaixam no **grid** automaticamente. Não é permitido construir fora do grid.
3. Toda peça deve estar **conectada** a outra coisa — não é possível construir no ar.
4. Ao tentar colocar no ar (bug), a peça é recolhida e **apenas aquele jogador** recebe no
   chat: "não é possível construir no ar".
5. Ao segurar a peça, **R** rotaciona no eixo X (incrementos de 90°);
   **T** rotaciona no eixo Y; **Shift + R/T** usa incrementos de 15° em vez de 90°.
6. Não é permitido construir em terreno irregular/inclinado — para isso existem as
   **fundações com pilares**, que levelam o terreno para casas e construções retas.

**Peças:** Parede, Fundação, Fundação com pilares, Telhado, Janela, Armadilha de espinho,
Alçapão, Porta, Escada, Baú, Cama, Mesa, Cadeira, Tocha.

**Stress estrutural**
- Cada peça acumula **estresse** gradualmente (nunca quebra instantaneamente ao ser
  colocada).
- Peças removidas夜里 aumentam o estresse da estrutura restante.
- **Colapso** da estrutura inteira quando o estresse ultrapassa o limite.
- **Melhorias:** cada peça aceita no máximo **3 melhorias**. Cada melhoria custa **50%
  do valor de construção original** e **soma o valor original de vida padrão** à vida
  atual da peça. (Nível 0 = 1× vida; níveis 1–3 = 2×, 3×, 4× vida.)

**Reparo e destruição**
- O **martelo** repara a peça usando o **material original** usado na construção
  (parede de madeira repare com madeira).
- Ao destruir uma peça, ela **dropa 15% dos materiais**.
- Construções podem ser danificadas por inimigos e por desastres naturais.

**Terreno**
- Fundações podem ser conectadas para formar bases maiores.
- Peças podem ser conectadas para formar pontes e torres.

### 4.7 Mundo

- **Infinito**, geração contínua por chunks conforme o jogador explora.
- **Ilhas** entre **2.500 m e 25.000 m** de diâmetro.
- **Distância** entre ilhas entre **1.000 m e 5.000 m**.
- Sem água entre as ilhas — travessia por barco ou jangada.
- Fundações com pilares resolvem terreno irregular.

**Barcos e jangadas**
- Se o jogador pular enquanto o barco está em movimento, ele **acompanha o barco**
  em vez de ficar para trás (inércia de embarcação).

**Tipos de ilha** (classificação por geração)
| Tipo | Descrição |
|---|---|
| Pacífica | Sem inimigos. Recursos e animalsPeaceful. |
| Hostil | Fauna hostil. Mais perigosa à noite. |
| Desastre natural | Sofre furacões, tempestades com raios, incêndios. |
| Com habitantes | NPCsibo que habitam a ilha. |
| Feynman | Pequena chance de conter inimigos fantasianos ou dinossauros. |

**Fauna** — mistura de animais realistas (maioria das ilhas) com pequena chance de
criaturas fantasiosas e dinossauros em algumas ilhas. Os inimigos **são** os animais.
À noite aparecem **animais mais perigosos**.

**Ciclo dia/noite** — a noite traz fauna mais perigosa.

**Animais** podem ser caçados, domesticados e montados.

### 4.8 Clima
| Fenômeno | Efeito |
|---|---|
| Chuva fraca | Chuvisco. Irriga plantações. |
| Chuva normal | Igual à fraca, porém mais forte. |
| Tempestade | Chance de raios. Causam incêndios, quebram construções, matam animais e jogadores, destroem plantações. |
| Furacão / desastre | Ao atingir uma construção, testa a **integridade estrutural** (stress) para decidir se ela aguenta. |

### 4.9 Combate
- Corpo a corpo e à distância.
- **Bloqueio e desvio** de ataques.
- Uso do **ambiente**: empurrar inimigos de penhascos, usar armadilhas.
- **Armaduras** e equipamentos de proteção.
- **Armas de fogo e explosivos.**
- **Consumíveis** (comidas) recuperam atributos. **Sem poções.**
- Sem habilidades especiais ou combos.

### 4.10 Morte e respawn
- Ao morrer, o jogador **perde todos os itens**.
- Renasce em uma ilha **aleatória**, entre **1 e 3 ilhas de distância** do local da morte.

### 4.11 Inventário
- **Sem limite de peso.**
- **Stack de 100 itens.**

---

## 5. Multiplayer

- Dois modos: **Single Player** e **Multiplayer**.
- Um mundo Single Player pode ser **aberto para multiplayer** a qualquer momento.
- **Multiplayer:** os jogadores podem **construir juntos na mesma base**.
- **Transporte:** Steamworks, usando o app **SpaceWar** (App ID 480).
- **Chat escrito.**
- **Voz por proximidade:** WebRTC, volume atenuado por distância. **Inimigos hostis
  também ouvem** a voz do jogador.
- Sem permissões por dono nas construções.
- Sem sistema de clãs.

---

## 6. Saves e mundos

- **Save automático** contínuo. O **botão de sair também salva**.
- O jogador pode criar **múltiplos mundos** e alternar entre eles.
- Cada mundo tem: **nome**, **descrição**, **seed**, **dificuldade**, **permissões de
  acesso** (público, privado, apenas amigos), **número máximo de jogadores**.
- **Exportar e importar mundos**, incluindo os dados dos jogadores (estilo Minecraft).
- Sem save em nuvem.

### Parâmetros de geração configuráveis
Seed, dificuldade, nome, descrição, permissões, nº máximo de jogadores.

### NÃO configuráveis (definidos pelo design)
Tamanho/diâmetro das ilhas, distância entre ilhas, frequência de ilhas, tamanho do
mundo / nº de ilhas (infinito), tipo de clima ou disastes.

---

## 7. Câmera
- **1ª pessoa** por padrão.
- Troca para **2ª e 3ª pessoa** a qualquer momento.

---

## 8. Arquitetura técnica

### Módulos (Godot 4, GDScript, renderer Compatibility)

| Módulo | Responsabilidade |
|---|---|
| `core/` | Game loop, estados, save/load, config. |
| `world/` | Geração procedural de chunks, classificação de ilhas, streaming. |
| `world/chunk_streamer.gd` | Carrega/gera/descarta chunks ao redor do jogador. |
| `world/island_generator.gd` | Gera a ilha a partir do seed; aplica biomas e tipo. |
| `player/` | Movement (1ª/2ª/3ª pessoa), necessidades, temperatura, energia, ferimentos. |
| `building/` | Grid, encaixe, fundação obrigatória, rotação, estresse, melhorias, reparo, colapso. |
| `inventory/` | Slots, stacks de 100, sem peso, craft. |
| `crafting/` | Crafting por combinação e crafting direto. |
| `research/` | Níveis, Research Points, Research Tree. |
| `combat/` | Corpo a corpo, ranged, bloqueio/desvio, dano por velocidade, armaduras. |
| `creatures/` | Fauna, IA, domesticar, montar, agressividade noturna. |
| `climate/` | Chuva, tempestade, raios, furacão, temperatura. |
| `farming/` | Enxada, plantio, irrigação, crescimento. |
| `transport/` | Barco e jangada, inércia de embarque. |
| `net/` | Multiplayer (GodotSteam/SpaceWar), chat, voz WebRTC por proximidade. |
| `worlds/` | Gerenciador de mundos, export/import, metadados. |

### Estratégia de 60fps
1. **Renderer Compatibility**, sem pós-processamento e sem sombras.
2. **Resolução interna ~70%** com escalonamento.
3. **Streaming de chunks** com descarte agressivo do que está longe.
4. **Instancing** de plantas, pedras, itens.
5. **LOD** por distância em criaturas e construções.
6. **Multithreading** com no máximo 4 workers (limitado pelos 4 núcleos sem HT).
7. **Orçamento de assets** (§3) respeitado rigorosamente.
8. Sem alocação de objetos em laços de frame (pools de objetos).

---

## 9. Fases de implementação

### Fase 1 — Fundação e loop básico
- Projeto Godot 4, renderer Compatibility, config de 70% de resolução.
- Grid de construção, fundação obrigatória, colocar/rotacionar/remover.
- Inventário com stack de 100, sem peso.
- Coleta de recursos básica (madeira, pedra, fibra).
- Movimentação 1ª/2ª/3ª pessoa.

### Fase 2 — Ferramentas e terreno
- Todas as 10 ferramentas com funções distintas.
- Deformação de terreno (picareta, pá).
- Quebra de árvores/pedras/construções.

### Fase 3 — Construção avançada
- Todas as peças (parede, telhado, janela, porta, escada, baú, cama, mesa, cadeira,
  tocha, armadilha de espinho, alçapão, fundação com pilares).
- Sistema de estresse, colapso, melhorias (3×), reparo com martelo, 15% drop.

### Fase 4 — Mundo procedural
- Geração de chunks infinitos.
- Ilhas 2.500–25.000 m, distâncias 1.000–5.000 m.
- Classificação de ilhas (pacífica/hostil/desastre/habitantes/fantasma).
- Streaming e descarte.

### Fase 5 — Sobrevivência
- Fome, sede, energia, temperatura, ferimentos, regeneração.
- Três dificuldades.
- Morte, perda de itens, respawn 1–3 ilhas.

### Fase 6 — Progressão
- Níveis e Research Points (velocidade por dificuldade).
- Research Tree e receitas desbloqueáveis.
- Materiais progressivos (madeira → pedra → metal).

### Fase 7 — Fauna e combate
- Fauna realista + criaturas fantasiosas/dinossauros (pequena chance).
- Domesticar, montar.
- Corpo a corpo, ranged, bloqueio/desvio, armaduras, armas de fogo, explosivos.

### Fase 8 — Clima e agricultura
- Chuva fraca/normal, tempestade com raios e incêndios, furacão com teste estrutural.
- Temperatura (frio por tempo, calor por proximidade).
- Enxada, plantio, irrigação (manual 1×/dia e automática perto d'água).

### Fase 9 — Transporte
- Barco e jangada com inércia de embarque.

### Fase 10 — Multiplayer
- SpaceWar/Steamworks, mundo Single Player → multiplayer, construir junto.
- Chat escrito, voz por proximidade (WebRTC) que inimigos ouvem.

### Fase 11 — Mundos e saves
- Save automático, botão de sair salva.
- Múltiplos mundos com nome/descrição/seed/dificuldade/permissões/max jogadores.
- Export/import de mundos com dados de jogadores.

---

## 10. Chamadas do cuestionário (minhas, a conferir)

1. **Godot 4 + renderer Compatibility + GDScript** — o usuário pediu "o mais leve".
2. **Resolução interna ~70% escalonada** — escolhido para garantir 60fps.
3. **Voz via WebRTC com volume por distância**, não voz do Steam — a API de voz do
   Steam não expõe posição, o que inviabiliza a voz por proximidade.
4. **Modelos low-poly prontos, com orçamento rígido** (§3) — escolhido pelo usuário,
   apesar do custo em RAM/GPU; o orçamento é o que mantém o 60fps.
5. **GodotSteam (GDExtension) para SpaceWar** — caminho padrão para Steamworks em Godot.
6. **Sem poções**, só consumíveis de comida.
7. **Sem permissões por dono** nas construções compartilhadas.
8. **Tamanho/distância/frequência de ilhas não configuráveis** — mantidos como
   especificação fixa de design.

## 11. Em aberto para o usuário
- Nada bloqueante. As decisões acima estão prontas para aprovação antes de codificar.