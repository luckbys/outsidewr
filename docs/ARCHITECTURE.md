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

Tropas e heróis automáticos mantêm o alvo enquanto ele está vivo dentro do raio de detecção. Barricadas e centrais não se movem: `defense_target()` prioriza tropas ao adquirir um alvo e considera a retaliação contra heróis. `notify_hostile_action()` é chamado apenas depois de um dano válido; dano aliado e dano rejeitado pela proteção da central não provocam retaliação.

Ataques de personagens aplicam dano imediatamente. Defesas preparam o disparo durante `DEFENSE_WINDUP`, revalidando alvo e alcance antes de aplicar dano. Os traços não são projéteis físicos. Os temporizadores de preparação, retaliação e lentidão avançam somente com a simulação, respeitando a pausa.

`UnitActor.Order` separa movimento, avanço com ataque, ataque explícito e posição mantida. O destino do avanço com ataque é preservado durante o combate. `hold_position()` cancela a perseguição sem reiniciar a recarga do ataque. Heróis automáticos usam `ai_retreating` para manter a decisão de recuar até a recuperação mínima, sem alternar a cada quadro perto do limiar de vida.

`UnitActor.died` comunica derrotas ao controlador. As unidades mortas saem da lista após o passo de simulação. O jogador morto permanece oculto até ser substituído no retorno, para manter uma referência válida na interface.

As duas barricadas protegem a central de sua equipe. Tanto a seleção automática de alvo quanto a aplicação de dano verificam essa regra. Destruir a central altera o estado para `FINISHED` e encerra o avanço da partida.

## Dados

- `FactionData`: Resource com identificadores, textos, cor e ponto de retorno.
- `resources/factions/*.tres`: configurações de Polícia e Tráfico, editáveis no Inspector.
- `MatchRules`: constantes de tempo, habilidades e atributos por função.
- `UnitActor.Role`: herói, tropa, barricada e central.

Personagens compartilham um script nesta versão. Quando houver heróis com habilidades próprias, extraia estatísticas e habilidades para Resources e cenas específicas, mantendo o controle da partida fora dessas cenas.

## Interface

`match_hud.gd` consulta o estado real do controlador e organiza os painéis conforme o tamanho do viewport. `hud_theme.gd` compartilha cores e estilos entre a partida e a demonstração 3D. `ability_button.gd` desenha atalhos, disponibilidade e recargas; `tactical_minimap.gd` projeta unidades e converte cliques em comandos pela transformação inversa.

Os cartões e botões consomem eventos do mouse para evitar comandos no mundo sob a interface. `aim_position` guarda a última direção apontada no mapa; o botão Avanço usa essa posição. `command_retreat()` e `toggle_pause()` centralizam as ações usadas pelo teclado e pela HUD.

O viewport usa escala de conteúdo desativada para manter o texto legível em pixels da janela. O mundo 2D continua calculando seu próprio enquadramento. A barra da demonstração 3D usa `HFlowContainer` para distribuir os botões em linhas.

## Verificação e limites

`tests/match_smoke.gd` carrega a cena real e testa comandos e uma partida acelerada. `tests/input_smoke.gd` injeta eventos no viewport para testar seleção e controles pelo caminho da interface. Uma falha resulta em código de saída 1.

`tests/hud_smoke.gd` verifica o layout em 1440×900, 800×600 e 480×800, a conversão de cliques no minimapa, bloqueio de comandos sob painéis e durante a pausa, direção do avanço, recuo, recargas, objetivos e os atalhos da demonstração 3D.

`tests/mechanics_smoke.gd` verifica as ordens pelo controlador e pelo viewport, efeitos na distância percorrida, preparação e cancelamento de tiros, prioridades e expiração da retaliação, recuo e cura do bot. Também joga partidas completas de ambas as facções usando apenas comandos e habilidades públicos.

`tools/capture_preview.gd` produz imagens do menu e da partida com um renderer real. O modo headless importa e testa o código, mas não valida pixels. O teste visual exige um display X11/Wayland ou equivalente.

A partida 2D usa movimento limitado ao corredor e ataques imediatos. Servidor de partida, persistência, física de projéteis e áudio ainda não foram implementados. A busca de alvos percorre a lista de unidades; uma expansão grande exigirá particionamento espacial e medição de desempenho.

## Apresentação 3D

O ambiente 3D tem colisões de terreno, casas e barricadas, com uma faixa de navegação livre dos bloqueios. `character_visual_3d.gd` controla a aparência e as articulações dos modelos, reutilizando materiais entre instâncias. `unit_preview_3d.gd` conduz a patrulha visual dos minions. Esses componentes de demonstração não aplicam dano nem executam outra simulação de combate.

`barricade_3d.gd` instancia uma malha compartilhada de concreto com perfil inclinado, criada por `FieldGeometry3D`. As defesas do jogo 2D usam `UnitActor.Role.BARRICADE`, mantendo o identificador 2 e os atributos da defesa anterior. Os controles e a organização das cenas estão documentados em [ENVIRONMENT_3D.md](ENVIRONMENT_3D.md).
