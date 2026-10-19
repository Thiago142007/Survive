# Inventário da migração Godot → Unity

**Escopo desta auditoria:** Fase 0. Nenhum arquivo do jogo Godot foi alterado nesta fase. A auditoria cobre `project.godot`, scripts, cenas, testes, documentação e assets que existem no checkout em 19/10/2026.

## Resumo do estado encontrado

- Projeto atual: Godot 4.3, GDScript, renderer Compatibility (`gl_compatibility`), cena inicial `scenes/main.tscn`.
- Não existe projeto Unity (`Assets/`, `Packages/manifest.json`, `.asmdef`, `.csproj` ou cenas Unity). Também não foi encontrado executável `Unity`/`unity` nem `dotnet` no `PATH`. A versão LTS disponível no ambiente ainda precisa ser verificada na Fase 1.
- Conteúdo: 28 scripts GDScript em `scripts/`, 19 cenas `.tscn`, 30 smoke tests GDScript e 8 documentos de especificação/plano sob `docs/superpowers/`. Há ainda 2 ferramentas GDScript, documentação de áudio, manifesto de áudio, créditos, licenças, imagens de diagnóstico e arquivos de assets.
- O diretório de trabalho já tinha várias mudanças e arquivos não rastreados antes desta auditoria. Foram mantidos intactos. Ver lista e orientação em `MIGRATION_STATUS.md`.

## Estrutura Godot observada

| Área | Arquivos | Responsabilidade / estado presente |
|---|---|---|
| Core | `scripts/core/main.gd`, `save_manager.gd`, `settings_manager.gd`, `sound_manager.gd` | Estado do mundo e ciclo de jogo; autosave; snapshot e validação de saves; settings; pools de áudio e ambiência. `Main`, `SaveManager`, `SettingsManager` e `SoundManager` são autoloads. |
| Jogador | `scripts/player/player.gd`, `interaction.gd`, `character_presentation.gd` | `CharacterBody3D`; WASD, corrida, salto, mouse, três distâncias de câmera, ataque corpo a corpo, bloqueio, dano, respawn, fome/sede e energia condicional; raycast para coleta/domesticação; modelos de corpo e braços animados. |
| Mundo | `scripts/world/island_generator.gd`, `island_generator_v2.gd`, `world_seed.gd`, `harvestable.gd`, `imported_model_variant.gd` | Geradores v1/v2; layouts e terreno determinísticos; ilhas, biomas, cavernas, vegetação instanciada, recursos/fauna; streaming por distância; IDs e estado persistente; parser de seed FNV-1a em UTF-8 para seeds não numéricas. A cena usa o gerador v2; v1 permanece como compatibilidade. |
| Fauna | `scripts/fauna/animal.gd` | Estados de passeio, fuga, perseguição e morte; percepção por distância; dano, acerto por região, imobilização, drop e domesticação simples. |
| Inventário/crafting/progressão | `scripts/inventory/{inventory,item_data}.gd`, `scripts/crafting/crafting_system.gd`, `scripts/progression/research_system.gd` | Slots ordenados, stacks de 100 e estado serializável; `ItemData` como Resource; quatro receitas codificadas em dicionário; XP, nível, pontos e três nós de pesquisa. |
| Construção | `scripts/building/{build_piece,building_system}.gd` | Fundação, fundação com pilares, parede, telhado e porta; grid de 2 m, preview, custo, remoção, reparo, até três upgrades e avaliação periódica de suporte/estresse. |
| UI | `scripts/ui/*.gd`, `scripts/hud/hud.gd` | Menu, seletor e cartões de mundos, confirmação de exclusão, configurações, pausa, inventário, crafting, pesquisa e HUD. A maior parte usa CanvasLayer/uGUI Godot. |

### Cenas

`scenes/main.tscn` compõe a cena de jogo, jogador, gerador, HUD, menus e painéis. `scenes/player/player.tscn` compõe jogador, inventário, interação, construção, crafting, pesquisa e apresentação do personagem. As cenas restantes são `scenes/hud/hud.tscn`; UI `main_menu`, `pause_menu`, `inventory_ui`, `crafting_ui`, `research_ui`, `world_save_card`; fauna `animal`; mundo `ground`, `palm`, `rock`, `tree`; construção `foundation`, `pillar_foundation`, `wall`, `roof`, `door`.

## Mapeamento preliminar para Unity

| Godot atual | Destino de migração previsto | Observações de compatibilidade |
|---|---|---|
| `project.godot`, autoloads | Projeto Unity, cena `Bootstrap`, serviços compostos e persistentes | Não copiar o padrão de singletons sem necessidade. Cena e lifecycle passam a ser explícitos. |
| `CharacterBody3D`, câmera e raycast | `CharacterController` (a validar em movimento/collision parity), câmera filha e `Physics.Raycast` | Valores de velocidade, sensibilidade, alturas e limites de câmera devem vir dos scripts/cena. |
| `Node3D` / scripts de gameplay | GameObjects, componentes C# e eventos/interfaces tipados | Manter estado runtime separado de definições estáticas e usar namespaces. |
| `PackedScene` / `.tscn` | Prefabs e cenas Unity | Recriar hierarquia, colliders, layers, materiais e referências; não há conversor automático considerado. |
| `Resource` / `ItemData` | `ScriptableObject` | Receitas, itens, ferramentas, peças, criaturas e pesquisas devem tornar-se assets de dados, conforme o prompt. |
| `CanvasLayer`, `Control` | Canvas + uGUI ou UI Toolkit | Escolher uma solução e manter regras de jogo fora da UI. Inventário customizado atual requer revisão visual, não tradução direta. |
| `InputMap` | Unity Input System | Mapear ações verificadas abaixo; salvar overrides/remapeamento. |
| signals | C# events/interfaces/event bus tipado | Evitar dependência de cena global por caminho de nó. |
| `FastNoiseLite`, `ArrayMesh`, `MultiMeshInstance3D` | Gerador determinístico próprio; `Mesh`/`MeshCollider`; instancing/`Graphics.DrawMeshInstanced` conforme versão LTS | Chamadas de API de Unity para objetos e recursos ficam na main thread; worker deve produzir apenas dados puros. Ver decisão sobre determinismo. |
| `user://` e JSON | `Application.persistentDataPath`, JSON e gravação temporária/backup atômica | IDs seguros, migrações por versão e nenhuma referência a caminho absoluto. |
| AudioStreamPlayers em pool | `AudioSource` em pools limitados e AudioMixer | Preservar semântica espacial/local, camadas ambiente e limites existentes. |

## Teclas atuais confirmadas em `project.godot`

| Ação Godot | Binding configurado | Nota de migração |
|---|---|---|
| movimento | W/A/S/D | Corresponde ao prompt. |
| pulo | Space | Corresponde. |
| interação | C | Corresponde; explicitamente preservada nos planos de save/menu. |
| inventário | E | Corresponde. |
| crafting | K | Corresponde. |
| pesquisa | Y | Corresponde. |
| ataque / bloqueio | F / B | Corresponde. |
| corrida | Shift físico | Corresponde. |
| rotação / remover / melhorar / reparar / ciclar peça | R / T / X / U / H / Q | Corresponde; R/T aceitam Shift para incremento fino de 15°. |
| colocar fundação / confirmar | 1 / Enter | Ação `place_foundation` também inicia/encerra modo de construção; Enter confirma preview. |
| selecionar ferramentas 1–5 | teclas 2–6 | Deslocamento intencional: `1` já inicia construção. O prompt lista ferramentas `1–5`; é necessário escolher compatibilidade ou redefinir ações com teste dedicado. |
| alternar câmera | F5 (physical keycode 4194336) | Diverge do prompt, que lista seta para cima; o plano de Fase 1 mais antigo diz V. Preservar F5 inicialmente ou aprovar decisão de design antes de trocar. |
| pausa / cancelar | `ui_cancel` padrão do Godot (Escape) | Não aparece como ação personalizada na seção `[input]`; o menu escuta o mapeamento embutido do Godot. Recriar como ação Unity explícita. |

## Persistência e versões

- `SaveManager` registra `SAVE_FORMAT_VERSION = 1`, `WORLD_GENERATION_VERSION = 2`, saves individuais JSON em `user://saves`, cópia de backup, gravação temporária, validação estrutural e thumbnails JPEG de 480×270.
- `Main` captura metadados do mundo, seed/origem da seed, dificuldade, personagem, jogador, inventário, pesquisa, construções, configuração do gerador e overlays de recursos/animais; aplica a validação antes de mutar estado.
- O formato não é serialização da árvore de cena. A geração determinística é a base e IDs persistentes registram alterações.
- O inventário mantém IDs desconhecidos no round trip; construções salvam posição/rotação/escala, saúde, melhorias e estresse; animais e recursos usam IDs persistentes.
- São suportadas no código as versões de geração 1 e 2. A versão de formato de save tem versão 1; migração de formato futura ainda não existe.

## Assets e licenças identificados

- Modelos: rochas, frutas, palmeiras, arbustos, folhagem, flores, gravetos e personagens. Os formatos de origem encontrados incluem GLTF/GLB, FBX, DAE, JPEG/JPG/PNG. A pasta `assets/` inclui metadados `.import` do Godot; estes não são assets Unity e não devem ser copiados como configuração final.
- Personagens: modelos masculinos/femininos Quaternius (CC0) e braços PSX FPS de heyheythere (CC BY 4.0; atribuição obrigatória em `CREDITS.md`).
- Áudio: 25 OGG, 5 WAV; manifesto em `docs/audio_manifest.tsv`; Kenney Impact Sounds e RPG Audio são CC0, Sonniss GDC 2026 rege clipes de ambiente/UI. Preservar os termos e procedência em `docs/third_party/` e `CREDITS.md`.
- `sounds/extracted/` tem arquivos locais de origem Sonniss e está fora do Git/importação do Godot segundo `docs/AUDIO_ASSETS.md`; só os arquivos selecionados e licenciados em `assets/audio/` devem entrar no build.
- Recursos visuais incluem imagens de diagnóstico de geração e arte/UI em `assets/ui/`; documentar quais entram no jogo e manter licenças.
- Não foi encontrado um registro de polígonos/materials por asset nem LODs Unity prontos. Quantidade/limites devem ser medidos na importação.

## Testes existentes (30 smoke scripts)

Os scripts cobrem intenção funcional e regressões, não são testes Unity portáveis automaticamente:

- Core, saves e fluxo: `smoke_main_menu`, `smoke_main_menu_save_flows`, `smoke_world_save_card`, `smoke_save_manager`, `smoke_save_round_trip`, `smoke_generation_save_versions`, `smoke_world_save_registry`, `smoke_autosave_lifecycle`, `smoke_pause_save_flow`, `smoke_settings`.
- Mundo e determinismo: `smoke_world_seed`, `smoke_world`, `smoke_procedural_islands_v2`, `smoke_v2_seed_diversity`, `smoke_v2_fingerprint`, `smoke_v2_streaming`, `smoke_island_shapes`.
- Jogador e apresentação: `smoke_phase2`, `smoke_sprint`, `smoke_camera_toggle`, `smoke_character_assets`, `smoke_character_presentation`, `smoke_first_person_actions`.
- Gameplay/UI restantes: `smoke_building`, `smoke_fauna`, `smoke_migrated_animal_streaming`, `smoke_inventory_ui`, `smoke_game_audio`, `smoke_game_audio_events`, `smoke_imported_models`.

Há 2 ferramentas de diagnóstico: `tools/benchmark_world_generation.gd` e `tools/render_world_generation_maps.gd`. O benchmark mede tempo de geração e memória estática no processo em modo headless e reconhece que não mede FPS nem chamadas de desenho da GPU.

## Gaps e divergências entre código, documentação e prompt

| Tema | Documentado / solicitado | Implementado observado | Consequência para a migração |
|---|---|---|---|
| Escopo desta etapa | O prompt solicita somente a Fase 0 agora | Nenhum projeto Unity existe | Esta entrega é auditoria; não deve ser apresentada como migração completa. |
| Mundo infinito | Specs/roadmap descrevem arquipélago infinito e dimensões/distâncias maiores | V2 gera uma lista finita de ilhas em área limitada (`WATER_SIZE = 12000` herdado); streaming carrega ilhas geradas nas proximidades, não expande um mundo infinito | Necessário decidir e implementar geração por coordenadas/chunks antes de afirmar infinitude. Preservar geradores atuais para versões de save. |
| Escala | Design pede ilhas de 2,5–25 km e separação de 1–5 km | V2 amostra raios geralmente na faixa aproximada de 175–620 m e usa espaçamento próprio; config de ring até 6 km | Documentação de design não é parâmetro exato da build atual. Criar fixtures/decisões para conversão. |
| Sombras | Projeto e specs determinam sem sombras dinâmicas | `scenes/main.tscn` define `DirectionalLight3D.shadow_enabled = true` | Divergência concreta com o orçamento para hardware fraco; avaliar no Unity e validar visualmente. |
| Spawn | Design diz spawn seguro em terreno | O spawn do jogador é `Vector3(0,2,0)`; gerador usa ilha central e cria terreno com spawn clearance, mas não há prova na auditoria de spawn por raycast/altura real | Teste de integração deve confirmar posição sobre a ilha e ausência de queda/clip. |
| Construção | Spec requer fundação prévia, conectores, peças variadas e colapso estrutural por stress | Só há cinco tipos; suporte é checagem direta pela peça abaixo, terreno é aproximado por `y <= 0.1`; sem conectores, malha de conexão robusta ou colapso de estrutura inteira; stress periódico só adiciona stress a peças sem caminho | Reimplementar validação e grafo de conectividade; preservar diferenças de regras em testes de paridade. |
| Custos de construção | Design: upgrade custa 50% do valor original; +vida original; reparo pelo material original | Custo é calculado arredondando 50% por recurso e conserto em 25%; não há tipo de material por variante implementado de forma abrangente | Regras observáveis atuais e desenho pretendido divergem; decisão registrada em `MIGRATION_DECISIONS.md`. |
| Sobrevivência | Docs incluem temperatura, ferimentos, comida/água, cura e atributos | Código atual cobre saúde, fome, sede e energia no hard; não há temperatura, ferimentos, itens de comida/água ou efeitos de debilitação | Necessário portar apenas o comportamento presente e separar features futuras do design. |
| Agricultura/clima | Specs incluem culturas, irrigação, chuva, tempestades, raios, incêndios e furacões | Não há scripts/cenas desses sistemas; agricultura aparece como nó de pesquisa planejado | Não afirmar que a pesquisa desbloqueia gameplay. |
| Fauna | Design inclui fauna noturna, áudio/percepção, montaria e LOD | Predadores e pacíficos básicos; `active_period` é dado, não há ciclo dia/noite, audição, montaria, pooling ou LOD observável | Criar escopo incremental; montar pool e métricas em fase posterior. |
| Projéteis/combate avançado | Spec: arco, lança, estilingue, bloqueio/desvio, armadura, armadilhas | Ataque corpo a corpo, bloqueio simples e regiões de acerto em fauna; sem arma de distância, armadura, esquiva ou armadilha | Gaps de gameplay, não conversão de API. |
| Multiplayer/transporte | Specs planejam multiplayer, voz, chat e barcos | Nenhum sistema correspondente; opção Multiplayer no menu está desativada | Fora do mínimo jogável single-player; não prometer na migração inicial. |
| Catálogo de dados | Prompt exige ScriptableObjects para itens, receitas, pesquisa, construção e criaturas | Apenas `ItemData` é um Resource; receitas/pesquisas/custos são dicionários no código | Criar assets de dados Unity e validar referências/IDs. |
| Gerador em worker | Prompt exige geração pesada fora da main thread quando seguro | Geração atual faz mesh e colocação procedural em caminhos síncronos; não há worker/threading Unity | Implementar geração em fases: dados puros em worker, objetos Unity na main thread. |
| Métricas | Prompt pede FPS, memória, geração, objetos ativos e custo de IA | Diagnóstico atual mede tempo/contagem de instâncias e memória estática headless; HUD tem contador FPS opcional; custo de IA por si não está instrumentado | Instrumentar de forma comparável na Unity e rodar no hardware alvo antes de afirmar desempenho. |
| Entrada | Prompt sugere seta para cima para câmera e numeração 1–5 de ferramentas | Código: F5 câmera; 1 construção; ferramentas em 2–6 | Ver tabela de bindings; o comportamento legado deve ser preservado até decisão/teste explícito. |
| Versão Unity | Prompt pede LTS existente no ambiente | Nenhum executável Unity foi encontrado no `PATH` durante a auditoria | Confirmar instalação/versão no início da Fase 1; não inventar uma versão ou resultado de compilação. |

## Documentos considerados

- Spec: `docs/superpowers/specs/2026-10-17-survive-design.md`.
- Specs: `2026-10-17-audio-vfx-integration-design.md`, `2026-10-18-centered-world-selector-design.md`, `2026-10-18-save-system-main-menu-and-player-models-design.md`.
- Planos: `2026-10-17-fase-1.md`, `2026-10-17-survive-roadmap-completo.md`, `2026-10-17-audio-vfx-integration.md`, `2026-10-18-centered-world-selector.md`, `2026-10-18-character-models-first-person-hands.md`, `2026-10-18-main-menu-save-flows.md`, `2026-10-18-save-persistence.md`, `2026-10-19-procedural-islands-v2.md`.
- Assets/licenças: `docs/AUDIO_ASSETS.md`, `docs/audio_manifest.tsv`, `docs/third_party/*`, `CREDITS.md`.
