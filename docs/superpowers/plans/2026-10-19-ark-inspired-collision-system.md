# Sistema de terreno e colisões inspirado em ARK: Survival Evolved

**Data:** 2026-10-19  
**Projeto:** Survive (Godot 4.3, Compatibility renderer)  
**Objetivo:** alinhar as colisões à geometria visível das ilhas e dos objetos, tornar os golpes localizados e manter o custo de física controlado.

## Pesquisa e limites da adaptação

### O que a pesquisa confirma

ARK: Survival Evolved usa mapas e terrenos preparados como conteúdo do mundo. O DevKit descreve a criação de mapas no editor e o fluxo de importar/exportar heightmaps; isso não sustenta a ideia de que as ilhas do jogo sejam criadas proceduralmente a cada partida. A referência útil para este projeto é a representação de paisagem e suas colisões, não copiar um suposto gerador procedural de ARK. [ARK DevKit: Creating New Maps](https://devkit.studiowildcard.com/getting-started/creating-new-maps)

A documentação de Landscape do Unreal Engine 4 descreve resolução de colisão separada da resolução visual e níveis de colisão por componente. Mip 0 é o mais preciso e caro; mips mais altos reduzem custo e precisão. A recomendação geral documentada é manter colisão complexa em mip 0 e usar mip 1 ou 2 para colisão simples, evitando mips altos quando a imprecisão passa a ficar perceptível. Esta é a inspiração para trocar visual e colisão juntos por níveis de detalhe no nosso terreno. [UE4 Landscape Collision Guide](https://dev.epicgames.com/documentation/en-us/unreal-engine/landscape-collision-guide?application_version=4.27)

### Restrições do projeto e escolha técnica

- As ilhas são malhas heightfield com recortes de caverna e usam `StaticBody3D` com `ConcavePolygonShape3D` gerado da malha. `HeightMapShape3D` é mais simples e rápido para terreno sem recortes, mas não representa cavernas, saliências ou overhangs; por isso não substitui a colisão atual neste projeto. [Godot 4.3: HeightMapShape3D](https://docs.godotengine.org/en/4.3/classes/class_heightmapshape3d.html)
- `ConcavePolygonShape3D` é pensado para geometria estática e tem custo superior ao de formas primitivas; deve ficar restrito ao terreno e às cavernas. Árvores, pedras, palmeiras e personagens usam cápsulas, cilindros ou esferas simples. [Godot 4.3: ConcavePolygonShape3D](https://docs.godotengine.org/en/4.3/classes/class_concavepolygonshape3d.html)
- A colisão é filtrada por camada e máscara. O mundo permanece na camada 1; uma camada 2 exclusiva a áreas de acerto permite golpes precisos sem fazer raios de interação atingirem hurtboxes. [Godot 4.3: Ray-casting](https://docs.godotengine.org/en/4.3/tutorials/physics/ray-casting.html)
- O corpo físico do animal continua sendo uma cápsula para movimento e bloqueio. Hurtboxes são `Area3D` independentes e não bloqueiam o jogador. Isso separa “onde o animal existe” de “onde o golpe acertou”.

## Situação observada antes da implementação

1. A V3 mostra terreno em três resoluções (7,5 m, 15 m e 30 m), mas deixa sempre a colisão em 15 m. Perto do jogador, os triângulos físicos portanto não coincidem com a superfície mostrada.
2. A pedra de fallback desenha três volumes e usa apenas uma esfera central como colisão.
3. A palmeira é um `Node3D` visual sem corpo de colisão.
4. O animal usa uma cápsula única para movimento e combate. O golpe converte altura aproximada em região, nunca acerta cabeça, e pode atingir partes que não correspondem ao ponto visual.
5. O recurso colhível desativa somente o nó de colisão principal, o que não é suficiente depois que a pedra passa a usar várias formas.

## Resultado pretendido

- Em cada ilha carregada, superfície desenhada e shape de colisão usam o mesmo nível de malha: perto 7,5 m; nível médio 15 m; distante 30 m. O shape muda somente quando o LOD muda.
- Terreno e cavernas continuam estáticos e com colisão côncava; recursos e personagens não passam a usar colisões trimesh.
- Pedras usam três esferas simples alinhadas às três massas visuais; troncos de árvores e palmeiras usam cilindros. Folhas/copa não bloqueiam locomoção.
- Ataques consultam hurtboxes da camada 2, com regiões `head`, `body` e `legs`. O acerto transmite a região real a `Animal.receive_hit`; a cápsula física do animal não intercepta o raio de ataque. Um segundo raio na camada World garante que paredes, rochas ou terreno bloqueiem o golpe.
- Interação, construção e movimento mantêm sua colisão com o mundo na camada 1.
- Sistemas de saves e a seleção de versão de geração continuam preservados. Esta alteração de colisões não troca nem migra saves.

## Critérios de aceite

1. Trocar LOD de uma ilha atualiza malha visível e colisão no mesmo ciclo de seleção, registrando o mesmo nível em ambas.
2. Ao minerar uma pedra, todas as suas formas físicas são desativadas e reativadas juntas.
3. Uma palmeira bloqueia o tronco e deixa passar entre as folhas.
4. O raycast de combate atinge uma hurtbox de animal e transmite sua região; não acerta o corpo físico genérico quando o raio não cruza uma hurtbox.
5. O raycast comum continua encontrando recursos e terreno e não é interceptado por áreas de acerto.
6. Não há colisores dinâmicos em formato de malha para recursos ou animais.
7. Não são alterados os dados históricos ou fingerprints das versões de geração/saves.

## Etapas de implementação — executadas nesta ordem

### Etapa 1 — manter LOD visual e físico sincronizados

- Guardar referência do `CollisionShape3D` de cada ilha V3.
- Ao criar ilha, derivar colisão da própria malha inicialmente selecionada, não forçar a malha intermediária.
- Quando mudar nível, selecionar/gerar uma malha, atribuí-la ao `MeshInstance3D` e gerar o shape físico dessa mesma malha; guardar `lod_level` nos dois nós para inspeção.
- Deixar o sistema antigo de V1/V2 seguir pelo caminho herdado sem mudanças.
- O algoritmo ainda terá uma troca de shape côncavo no evento de LOD; isso é intencional e só ocorre ao cruzar os limites de distância.

### Etapa 2 — tornar colliders de recursos representativos

- Expandir `Harvestable` para desativar e reativar todos os `CollisionShape3D` descendentes, incluindo formas compostas.
- Trocar a esfera única da pedra por três esferas simples sob o mesmo `StaticBody3D`, ajustadas aos volumes visuais.
- Adicionar à palmeira um corpo estático e um cilindro só para o tronco. A árvore existente já usa cilindro no tronco; manter a copa sem colisão.

### Etapa 3 — separar física do animal de regiões de golpe

- Preservar a cápsula física do `CharacterBody3D` (camada 1) para navegação.
- Criar áreas monitoráveis na camada 2 e sem máscara: uma esfera para cabeça, uma cápsula para corpo e formas cápsula curtas para as pernas.
- Gravar a região na metadata de cada área.
- Fazer o raio de combate consultar somente áreas, sem corpos; resolver a área ao `Animal` pai e enviar a região registrada para `receive_hit`.
- Antes de aplicar o golpe, consultar a camada World excluindo o próprio animal atingido; qualquer obstáculo mais próximo cancela o ataque.
- Manter o raio de interação inalterado na camada 1.

### Etapa 4 — registrar e revisar

- Revisar colisões, camadas, máscaras, nomes dos nós e compatibilidade do código com Godot 4.3.
- Fazer revisão estática do diff e procurar colisões/máscaras que possam bloquear interação ou movimento.
- Não alterar geração de ilhas/saves por motivos não relacionados a colisão.

## Decisões explícitas

- Não migrar as ilhas para `HeightMapShape3D`: as cavernas precisam de aberturas e a versão do projeto usa Godot 4.3.
- Não usar malha visual importada como colisão de pedra/palmeira. A colisão permanece simples, rápida e previsível mesmo quando `ImportedModelVariant` troca a aparência.
- Não criar collider para folhas. Elas são visuais e colidir com a copa aumenta bloqueio sem melhorar o ajuste do tronco.
- Não usar múltiplas áreas de hurtbox na camada World, para que os raios de interação não mudem de comportamento.
- Não editar os geradores históricos V1/V2 nem fingerprints dos saves.

## Fontes

- Studio Wildcard, [Creating New Maps (ARK DevKit)](https://devkit.studiowildcard.com/getting-started/creating-new-maps)
- Epic Games, [Landscape Collision Guide (Unreal Engine 4.27)](https://dev.epicgames.com/documentation/en-us/unreal-engine/landscape-collision-guide?application_version=4.27)
- Godot Engine, [HeightMapShape3D (4.3)](https://docs.godotengine.org/en/4.3/classes/class_heightmapshape3d.html)
- Godot Engine, [ConcavePolygonShape3D (4.3)](https://docs.godotengine.org/en/4.3/classes/class_concavepolygonshape3d.html)
- Godot Engine, [Ray-casting (4.3)](https://docs.godotengine.org/en/4.3/tutorials/physics/ray-casting.html)
