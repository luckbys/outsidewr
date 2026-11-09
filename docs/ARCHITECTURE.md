# Arquitetura inicial

## Cena e responsabilidades

`scenes/main.tscn` monta o mundo, uma camada de unidades com ordenação por Y, efeitos e uma interface em CanvasLayer. `MatchController` coordena a partida; `UnitActor` controla comportamento e desenho de cada unidade; a interface observa a partida e envia comandos.

```text
MatchController
├── World                 posição e escala para caber na janela
│   ├── District          cenário determinístico, seed 2026
│   ├── Actors            UnitActor; ordenação visual por Y
│   └── Effects           traços de ataque e anéis temporários
└── Interface / HUD       menu, minimapa, ações, pausa, resultado
```

## Coordenadas

As posições de jogo são `Vector2` em um plano lógico. `Iso.project()` converte esse plano para a tela; `Iso.unproject()` converte cliques de volta. Alcance, dano, IA e deslocamento usam exclusivamente o plano lógico. A escala do mundo não altera atributos ou distâncias de combate.

`Iso.WALK_RECT` delimita a rota. O protótipo limita o movimento a esse retângulo; ainda não tem pathfinding ou colisão de personagens. Não adicione obstáculos à rota sem implementar a navegação correspondente.

## Simulação

`MatchController.simulate(delta)` é o ponto único de avanço: cronômetro, ondas, recargas, retorno dos heróis, unidades, cura, efeitos e limpeza. O `_process()` encaminha o delta, respeitando seleção inicial, pausa e fim da partida. Os testes podem desativar esse processamento e avançar o mesmo código em passos explícitos.

As unidades procuram o inimigo vivo mais próximo dentro de seu raio de detecção. Barricadas e centrais não se movem. Os ataques aplicam dano imediatamente; os traços são apenas efeitos visuais, não projéteis físicos.

`UnitActor.died` comunica derrotas ao controlador. As unidades mortas saem da lista após o passo de simulação. O jogador morto permanece oculto até ser substituído no retorno, para manter uma referência válida na interface.

As duas barricadas protegem a central de sua equipe. Tanto a seleção automática de alvo quanto a aplicação de dano verificam essa regra. Destruir a central altera o estado para `FINISHED` e encerra o avanço da partida.

## Dados

- `FactionData`: Resource com identificadores, textos, cor e ponto de retorno.
- `resources/factions/*.tres`: configurações de Polícia e Tráfico, editáveis no Inspector.
- `MatchRules`: constantes de tempo, habilidades e atributos por função.
- `UnitActor.Role`: herói, tropa, barricada e central.

Personagens compartilham um script nesta versão. Quando houver heróis com habilidades próprias, extraia estatísticas e habilidades para Resources e cenas específicas, mantendo o controle da partida fora dessas cenas.

## Verificação e limites

`tests/match_smoke.gd` carrega a cena real e testa comandos e uma partida acelerada. `tests/input_smoke.gd` injeta eventos no viewport para testar seleção e controles pelo caminho da interface. Uma falha resulta em código de saída 1.

`tools/capture_preview.gd` produz imagens do menu e da partida com um renderer real. O modo headless importa e testa o código, mas não valida pixels. O teste visual exige um display X11/Wayland ou equivalente.

A partida 2D usa movimento limitado ao corredor e ataques imediatos. Servidor de partida, persistência, física de projéteis e áudio ainda não foram implementados. A busca de alvos percorre a lista de unidades; uma expansão grande exigirá particionamento espacial e medição de desempenho.

## Apresentação 3D

O ambiente 3D tem colisões de terreno, casas e barricadas, com uma faixa de navegação livre dos bloqueios. `character_visual_3d.gd` controla a aparência e as articulações dos modelos, reutilizando materiais entre instâncias. `unit_preview_3d.gd` conduz a patrulha visual dos minions. Esses componentes de demonstração não aplicam dano nem executam outra simulação de combate.

`barricade_3d.gd` instancia uma malha compartilhada de concreto com perfil inclinado, criada por `FieldGeometry3D`. As defesas do jogo 2D usam `UnitActor.Role.BARRICADE`, mantendo o identificador 2 e os atributos da defesa anterior. Os controles e a organização das cenas estão documentados em [ENVIRONMENT_3D.md](ENVIRONMENT_3D.md).
