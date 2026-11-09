# Ambiente 3D — Morro do Sol

Esta etapa adiciona uma base 3D independente em **Godot 4.6.3**, usando o renderer **Compatibility**. O protótipo 2D e seus comandos continuam como entrada padrão do projeto.

![Vista geral do ambiente 3D](images/environment-3d.png)

## Abrir a demonstração

No editor, abra `scenes/demo_3d.tscn` e pressione **F6**. Para editar o mapa, abra `scenes/world/district_3d.tscn`. A cena do distrito é um módulo de ambiente; a câmera e a interface de exploração pertencem à demonstração.

No terminal:

```bash
bash tools/godot.sh res://scenes/demo_3d.tscn
```

O **F5** continua iniciando o jogo 2D. O botão **Abrir jogo 2D** da demonstração também leva à cena original.

## Exploração

| Comando | Ação |
| --- | --- |
| WASD | Deslocar a câmera nas direções da tela |
| Q / E | Girar a vista |
| Arrastar com o botão direito | Ajustar rotação e inclinação |
| Roda do mouse | Aproximar ou afastar |
| Arrastar com o botão do meio | Deslocar a vista |
| Home / Vista geral | Restaurar o enquadramento inicial |
| Central Azul / Central Coral | Enquadrar o objetivo correspondente |
| Ver navegação | Mostrar o corredor navegável em azul translúcido |

## Organização da cena

```text
District3D
├── Terrain               terreno, colisão, rua e calçadas
├── Buildings             22 instâncias editáveis de casas
├── Decoration            quadra, postes e bancos
├── Lighting              DirectionalLight3D e WorldEnvironment
├── Navigation
│   ├── Lane              NavigationRegion3D e malha inicial da rota
│   └── Preview           visualização opcional da área navegável
└── PointsOfInterest      centrais, torres, nascimentos e centro
```

`1 unidade Godot = 1 metro`. O terreno mede **70 × 50 m**. A rua tem **8 m** de largura e uma faixa inicial navegável de **60 × 8 m**. O chão transitável está perto de `Y = 0`; pequenas espessuras dos pisos e a malha de navegação usam deslocamentos de centímetros para evitar sobreposição visual.

O oeste é identificado por azul e o leste por coral. As posições são `Marker3D` com nomes explícitos; essa etapa não conecta esses marcadores à simulação de combate 2D.

## Módulos editáveis

- `scenes/world/modules/house_block_3d.tscn`: corpo, laje, janelas, porta, caixa-d'água e antena. No Inspector, ajuste `footprint`, `building_height`, `facade_material` e `water_tank`. Um script `@tool` atualiza dimensões e colisão no editor e na execução.
- `scenes/world/modules/landmark_3d.tscn`: marcador visual de central ou torre, com texto, cor e altura ajustáveis.
- Materiais de fachada são compartilhados pelos módulos. Os modelos são primitivas nativas do Godot; não há dependências de modelos ou texturas externos.

As casas possuem colisão simplificada. A navegação inicial cobre somente a rota central livre; a quadra e as vielas laterais são cenário nesta etapa. A malha é criada ao carregar a região e sincronizada de forma assíncrona pelo servidor de navegação. Alterar o traçado ou colocar obstáculos na rota exigirá revisar essa malha.

## Navegador e Docker

Para gerar a demonstração web separadamente:

```bash
bash tools/export_web.sh Web3D
```

Saídas: `builds/web-3d/` e `builds/morro-em-disputa-3d-web.zip`. O preset `Web3D` ativa a feature `demo_3d`, cuja sobrescrita de `run/main_scene` inicia a demonstração. O preset `Web` continua iniciando a partida 2D.

O Dockerfile exporta as duas versões. Após compilar e fazer deploy da imagem atualizada, o caminho **`/`** abre o jogo 2D e **`/3d/`** abre a demonstração. Ambos usam a porta interna **8080** e os mesmos requisitos de HTTPS e WebGL 2. A imagem mantém dois pacotes web independentes, incluindo seus runtimes, para permitir abrir cada versão diretamente.

## Validação e limites

```bash
bash tools/setup.sh
# Apenas o ambiente 3D:
bash tools/godot.sh --headless --script tests/district_3d_smoke.gd
```

O setup executa as **36 verificações existentes** e **26 verificações do ambiente 3D**, totalizando **62**. A suíte 3D carrega a demonstração real, verifica grupos, módulos, dimensões, colisões, marcadores, câmera e uma rota entre os nascimentos consultada pelo `NavigationServer3D`.

A demonstração também foi exportada e executada no Chromium com WebGL 2, com inspeção visual e comandos de câmera. Os testes headless verificam estrutura e comportamento; a validação no navegador verifica a renderização.

Esta entrega é um ambiente de exploração com arte provisória. Personagens 3D, combate, navegação de tropas, integração dos objetivos com as regras da partida e a expansão para becos transitáveis ficam para as próximas etapas.
