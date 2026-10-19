# Decisões da migração Godot → Unity

Este registro cobre as decisões tomadas na Fase 0 e os pontos que precisam ser confirmados por código/teste antes de se tornarem contratos da migração. A versão Godot continua sendo referência e não deve ser modificada destrutivamente.

## Decisões de base

1. **Portar comportamento observável da build atual primeiro.** O código Godot e seus smoke tests definem a paridade da migração. Spec e roadmap definem lacunas e trabalho futuro, mas uma mecânica apenas descrita (por exemplo agricultura, montaria ou multiplayer) não será marcada como portada enquanto não existir no código atual.
2. **Manter compatibilidade dos saves e do mundo.** Preservar leitura lógica das versões de geração 1 e 2 e save format 1. Criar fixtures determinísticas para seeds representativas antes de substituir o gerador; qualquer mudança incompatível requer nova versão declarada e caminho de migração explícito.
3. **Adotar projeto Unity simples para hardware legado.** Recomendação para a Fase 1: Built-in Render Pipeline, sem pós-processamento e sem sombras em tempo real, sujeito à confirmação da versão LTS instalada. Evitar HDRP e dependências gráficas modernas. Usar qualidade baixa por padrão.
4. **Recriar hierarquias como componentes e prefabs.** Usar `Bootstrap`, `MainMenu` e `Game`; referências serializadas e dependências explícitas; ScriptableObjects para catálogos; estado de runtime fora dos assets imutáveis.
5. **Manter UI e regras desacopladas.** Escolher uGUI para aproximar a estrutura de menus atual e evitar misturar UI Toolkit com Canvas sem necessidade. Regras e validações ficam em serviços/componentes de gameplay.
6. **Usar Unity Input System com ações semânticas remapeáveis.** Começar pelos bindings efetivos em `project.godot`, inclusive `F5` para câmera e ferramentas 1–5 em `2–6`; adicionar uma ação Pause explícita para Escape. Não alterar silenciosamente esses atalhos para coincidir com o prompt.
7. **Gerar geometria em duas etapas.** Trabalho de seed, amostragem e arrays de vértices pode rodar fora da main thread quando seguro; criação de `GameObject`, `Mesh`, collider e assets Unity permanece na main thread. Cancelar resultados obsoletos ao descarregar chunks.
8. **Persistir em caminho da plataforma.** Usar `Application.persistentDataPath`, JSON versionado e gravação temporária/backup no mesmo diretório; validar antes da restauração e conservar saves incompatíveis/corrompidos para recuperação.
9. **Preservar procedência dos assets.** Migrar somente arquivos usados, manter `CREDITS.md`, manifestos e licenças, e conferir import settings Unity para modelos, texturas e áudio. O material Sonniss deve continuar associado aos termos e fonte descritos nos documentos atuais.
10. **Medir antes de declarar desempenho.** Capturar FPS, memória residente/gerenciada, duração por fase de geração, chunks e objetos ativos e custo/quantidade de atualizações de IA. A medição existente é referência parcial; não equivale a FPS GPU.

## Divergências que não serão ocultadas

- O gerador atual é finito, apesar de a documentação chamar o mundo de infinito. Deve-se portar primeiro o comportamento e IDs dos geradores existentes; infinitude exige novo desenho por coordenada/chunk e critério de identidade persistente.
- Regras atuais de construção não coincidem com a especificação: custo de reparo, melhorias, suporte e estresse. A paridade inicial seguirá o código; a regra desejada pela spec precisará virar uma mudança de gameplay versionada/testada, não uma “correção” silenciosa na conversão.
- Os bindings atuais divergem do prompt para câmera e slots de ferramenta. Preservar o legado até haver decisão explícita com teste.
- As necessidades de sobrevivência atuais são parciais, e vários módulos descritos no design ainda não existem. Não inventar estados de save nem declarar esses módulos concluídos.

## Confirmações técnicas para o início da Fase 1

- Identificar a instalação exata da Unity LTS disponível e confirmar se o projeto pode ser aberto/buildado nesse ambiente; durante a Fase 0 não foi encontrado `Unity`/`unity` nem `dotnet` no `PATH`.
- Definir versão mínima de Windows/Linux suportada pela instalação LTS disponível.
- Confirmar o caminho visual de UI (uGUI recomendado) e importar um pequeno subconjunto de assets para validar escala, materiais, esqueleto/animações e licenças antes da migração em massa.
- Definir fixtures de paridade do gerador para seeds `0`, `-42`, `12345`, `424242`, texto UTF-8 e seed padrão `55960`; armazenar fingerprint do layout, posições/IDs de recursos e resultados de terreno. Não depender do `System.Random` padrão para identidade persistente.
- Decidir se câmera e slots permanecem em F5/2–6 ou se uma migração deliberada usa setas/1–5; se mudar, documentar e testar UX e conflitos com construção.
