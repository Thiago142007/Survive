# Estado da migração Godot → Unity

**Atualizado:** 19/10/2026
**Fase autorizada pelo prompt:** Fase 0 — Auditoria
**Estado:** Fase 0 concluída; Fase 1 ainda não iniciada.

## Fase 0 — Auditoria

- [x] Ler o prompt de migração.
- [x] Auditar `project.godot`, scripts GDScript, cenas `.tscn`, testes, specs, planos, assets e documentos de licença.
- [x] Registrar inventário e divergências em `MIGRATION_INVENTORY.md`.
- [x] Registrar decisões e pontos técnicos pendentes em `MIGRATION_DECISIONS.md`.
- [x] Preservar as mudanças preexistentes do checkout Godot.
- [ ] Rodar a suite Godot: não executada; esta fase foi documental e o prompt pede começar somente pela auditoria. Além disso, nenhum teste foi solicitado separadamente.
- [ ] Compilar projeto Unity: não aplicável, pois ainda não há projeto Unity nesta etapa.

### Achados que afetam o plano

- A build Godot é 4.3 com Compatibility renderer. Não foi encontrado projeto Unity nem executável Unity/.NET no `PATH`; a versão LTS disponível precisa ser resolvida na Fase 1.
- Há controles, combate básico, geração procedural finita v1/v2, streaming por distância, saves com backup, menu/settings, fauna simples, inventário/crafting/pesquisa e construção básica.
- As maiores diferenças em relação ao design são: mundo finito, construção simplificada, ausência de agricultura/clima/temperatura, fauna sem ciclo dia/noite/LOD/montaria, sem barcos, sem multiplayer e sem ferramentas avançadas.
- A configuração atual da cena ativa sombras dinâmicas, embora o design para o hardware alvo as proíba.
- Os smoke tests oferecem bom material para uma suite Unity, mas são scripts acoplados à API Godot e precisam ser recriados, não convertidos mecanicamente.

## Checkout protegido

Na inspeção inicial, antes das alterações desta auditoria, `git status --short` já listava arquivos Godot modificados e conteúdo novo não rastreado (entre eles `project.godot`, cenas, scripts, testes, `assets/audio/`, `sounds/`, diagnósticos e planos). Esses arquivos foram preservados. Esta fase adicionou somente:

- `MIGRATION_INVENTORY.md`
- `MIGRATION_DECISIONS.md`
- `MIGRATION_STATUS.md`

Não houve alterações em `project.godot`, `.gd`, `.tscn`, assets ou testes existentes. Nenhum teste foi executado e nenhuma medição de FPS/memória foi produzida por esta auditoria.

## Próxima fase

A Fase 1 começa apenas após esta auditoria, seguindo o prompt: identificar a versão LTS instalada, criar a fundação Unity mínima com Input System, layers, qualidade e cenas `Bootstrap`, `MainMenu` e `Game`, mantendo o projeto Godot intacto. A primeira cena/prova deve importar apenas o mínimo necessário para confirmar que o projeto abre e compila no ambiente disponível.

## Como abrir/rodar/buildar

Ainda não existem arquivos Unity para abrir ou instruções de build válidas. Quando a Fase 1 criar o projeto, registrar aqui e em `MIGRATION_DECISIONS.md` os passos exatos para abrir no Editor e produzir builds Linux e Windows usando a instalação LTS realmente encontrada.

## Desempenho e diferenças finais

Ainda não há relatório de desempenho Unity nem diferenças de runtime medidas. Esses itens só podem ser preenchidos após implementar e medir os sistemas correspondentes no hardware de referência; o benchmark Godot atual não é um resultado de desempenho da Unity.
