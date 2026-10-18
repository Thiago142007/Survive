# Survive — Integração de Pacotes de Áudio e VFX

**Data:** 2026-10-17  
**Engine:** Godot 4.3, renderer Compatibility  
**Escopo:** primeira camada reutilizável de áudio e efeitos visuais do jogo

## 1. Objetivo

Integrar pacotes gratuitos CC0 ou MIT para dar resposta audiovisual aos fluxos já
existentes de exploração, coleta, combate, construção e interface, evitando criar
todo o conteúdo do zero. A integração deve permanecer leve o bastante para o
hardware de referência e não pode mudar o comportamento das mecânicas atuais.

## 2. Restrições

- Usar somente conteúdo gratuito com licença CC0 ou MIT.
- Registrar origem, licença e arquivos selecionados no repositório.
- Manter compatibilidade com Godot 4.3 e o renderer `gl_compatibility`.
- Preferir `CPUParticles3D` com baixa contagem e vida curta para evitar dependência
  de recursos recentes ou efeitos caros de GPU.
- Usar pools limitados para impedir crescimento ilimitado de players e partículas.
- Preservar as alterações não relacionadas já presentes no diretório de trabalho.

## 3. Pacotes selecionados

### VFX

- **Kenney Particle Pack** — CC0, texturas de partículas reutilizáveis em efeitos
  de poeira, lascas, faíscas e impactos.
  - Fonte: <https://kenney.nl/assets/particle-pack>

### Áudio

- **Kenney Impact Sounds** — CC0, impactos físicos.
  - Fonte: <https://kenney.nl/assets/impact-sounds>
- **Kenney RPG Audio** — CC0, passos e ações físicas adequadas ao jogo.
  - Fonte: <https://kenney.nl/assets/rpg-audio>
- **Kenney Interface Sounds** — CC0, cliques e confirmações de interface.
  - Fonte: <https://kenney.nl/assets/interface-sounds>
- **100 CC0 SFX #2**, do OpenGameArt — CC0, complemento para madeira, pedra,
  água, vento e trovão quando os pacotes Kenney não oferecerem uma amostra adequada.
  - Fonte: <https://opengameart.org/content/100-cc0-sfx-2>

Somente os arquivos efetivamente usados serão mantidos no produto final. Os ZIPs
originais poderão ficar fora da pasta importada do Godot para evitar custo de importação,
mas sua procedência e licença serão documentadas.

## 4. Arquitetura

Um autoload `EffectsManager` centralizará o catálogo e a reprodução dos efeitos.
Os sistemas de gameplay solicitarão efeitos por identificador sem conhecer caminhos
de arquivo, detalhes das partículas ou configuração de áudio.

O gerenciador terá:

- catálogo de efeitos com identificadores semânticos, como `wood_hit`, `stone_hit`,
  `animal_hit`, `build_place`, `player_hurt` e `ui_confirm`;
- pool limitado de `AudioStreamPlayer3D` para sons posicionais;
- pool limitado de `AudioStreamPlayer` para interface e feedback local;
- instanciação controlada de cenas VFX reutilizáveis e autodestrutivas;
- seleção aleatória entre amostras equivalentes, com pequenas variações de volume
  e pitch;
- falha segura: identificadores ou recursos ausentes geram aviso de desenvolvimento,
  mas não interrompem o jogo.

O projeto terá buses `Master`, `SFX`, `Ambience` e `UI`. Ambientes contínuos usarão
players dedicados e não concorrerão com efeitos curtos do pool.

## 5. Integrações iniciais

### Jogador e combate

- Som de ataque sem acerto.
- Impacto visual e sonoro ao acertar criatura.
- Som e feedback visual ao receber dano.
- Som de morte/respawn local.
- Passos básicos durante movimento no solo, com intervalo dependente de caminhada
  ou corrida.

### Coleta

- Impacto e partículas distintos para madeira e pedra.
- Som de coleta concluída.
- O efeito ocorre na posição do objeto coletado antes que seus visuais sejam ocultos.

### Construção

- Confirmação audiovisual ao colocar uma peça.
- Poeira e som ao remover ou colapsar uma peça.
- Feedback sonoro para melhoria e reparo.
- A lógica de custo, suporte e estresse permanece inalterada.

### Interface e ambiente

- Clique, confirmação e erro nos principais botões e ações de menu.
- Camada ambiente leve de oceano/vento, com volume conservador.
- Nenhuma música será adicionada nesta entrega.

## 6. Fluxo de dados

Os sinais existentes continuarão sendo a principal fronteira entre gameplay e
apresentação. Quando faltar um sinal adequado, será criado um evento pequeno e
específico, sem mover regras de jogo para o gerenciador de efeitos.

Exemplo:

1. o jogador acerta uma criatura;
2. a regra de dano é processada normalmente;
3. o sistema solicita `animal_hit` na posição do acerto;
4. o gerenciador escolhe uma amostra, reproduz o áudio 3D e instancia o VFX;
5. os recursos retornam ao pool ou são descartados ao terminar.

## 7. Desempenho

- Limitar simultaneamente os sons espaciais e os VFX ativos.
- Reutilizar players de áudio em vez de criar um nó por evento.
- Usar partículas de curta duração, materiais simples e sem iluminação quando possível.
- Não usar bloom, pós-processamento, colisão de partículas ou shaders dependentes de
  Forward+.
- Evitar carregamento síncrono durante eventos de gameplay: o catálogo será preparado
  durante a inicialização.

## 8. Testes e critérios de aceite

### Testes automatizados

- Todos os recursos do catálogo carregam no Godot 4.3.
- Os buses exigidos existem.
- Pools respeitam seus limites e reutilizam players.
- Efeitos desconhecidos ou ausentes não encerram a execução.
- Coleta, combate, dano e construção continuam executando suas regras e solicitam
  os efeitos esperados.

### Validação gráfica e jogável

- Abrir o projeto com Godot 4.3 em Compatibility sem erro de importação ou shader.
- Jogar os fluxos de andar/correr, coletar madeira e pedra, acertar uma criatura,
  receber dano, colocar/remover/reparar construção e usar o menu.
- Confirmar que áudio e VFX aparecem nos eventos corretos, sem acúmulo ilimitado de nós.
- Confirmar que efeitos espaciais atenuam com distância e sons de UI permanecem 2D.
- Observar logs durante a sessão; qualquer falha deve ser corrigida e toda a bateria
  relevante deve ser repetida.

## 9. Fora de escopo

- Música dinâmica.
- Sistema completo de superfícies para passos.
- Clima avançado, fogo persistente, explosões e armas de fogo.
- Controles de volume na interface; os buses deixam essa evolução preparada.
- Substituição dos modelos, animações ou mecânicas existentes.

## 10. Resultado esperado

Ao final, a versão atual do jogo terá feedback audiovisual coerente nos seus principais
fluxos, usando assets externos com licença segura e uma infraestrutura reutilizável para
as fases seguintes, sem sacrificar a compatibilidade com o hardware de referência.
