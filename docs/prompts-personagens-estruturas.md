# Morro em Disputa: prompts de arte para personagens e estruturas

Guia de prompts para gerar personagens e estruturas com IA (Midjourney, DALL·E/GPT Image, Stable Diffusion/Flux, Leonardo etc.) mantendo a mesma linguagem visual do protótipo atual.

---

## 1. O que observei no jogo

Analisei o build publicado no repositório (Godot 4.6, renderer GL Compatibility) extraindo o `index.pck` e rodando o jogo no navegador.

**Premissa.** "Morro em Disputa" é um protótipo de MOBA isométrico ambientado no **Morro do Sol**, uma favela brasileira fictícia ("universo fictício"). Duas equipes disputam **uma única rota**: cada lado tem **duas torres** e uma **central** (o nexus). A central só pode ser atacada depois que as duas torres caem. Ondas de 3 tropas nascem a cada 14 s, e o herói volta à base para se curar e renascer (8 s).

**Facções.**

| | Equipe Azul | Equipe Coral |
|---|---|---|
| Nome | Polícia | Tráfico |
| Lado do mapa | Oeste | Leste |
| Herói atual | Agente | Olheiro |
| Base | Central Azul | Central Coral |
| Cor do time | `#57BDE8` (azul celeste) | `#F57A59` (coral) |

**Mecânicas do herói.** Clique para mover/atacar, WASD, **Q – Impacto** (dano em área, recarga 7 s) e **E – Avanço** (dash em direção ao cursor, recarga 5 s). Herói tem 420 PV.

**Estilo visual (o mais importante para os prompts).**
- **Tudo é desenhado por código**, sem sprites nem texturas: polígonos chapados, sem contorno, cada face de um volume levemente mais clara ou mais escura (luz vinda de cima/esquerda). É um visual **flat isométrico low‑poly, estilo diorama/maquete**, parecido com ilustração vetorial.
- **Câmera isométrica 2:1** (eixos 0.86 × 0.43, cerca de 26,6°), olhando de cima a partir do sul. O mapa inteiro cabe na tela como um "tabuleiro" com borda em degraus.
- **Personagens** são bonequinhos pequenos e atarracados (cerca de 45 px de altura numa tela de 1440×900): cabeça redonda, camisa na cor do time, calça escura, arma longa escura segurada na diagonal, sombra elíptica no chão, barra de vida e um anel dourado sob o herói controlado.
- **Torres** são pilares de concreto verde‑acinzentado sobre uma base de areia, com bandeirinha e esfera na cor do time no topo. **Centrais** são blocos mais largos sobre um piso tingido com a cor do time.
- **Cenário**: prédios de tijolo e reboco de 2 a 4 andares com janelas escuras quadradas, caixas d'água azuis, antenas de TV, postes de madeira com fios caídos, varal com roupas coloridas, quadra de futebol verde, rua asfaltada com faixa amarela tracejada, calçadas bege e uma placa "MORRO DO SOL".
- **Clima**: final de tarde quente e empoeirado, cores terrosas e dessaturadas, sobre um fundo petróleo escuro.

**Paleta extraída do código.**

| Uso | Cores |
|---|---|
| Tijolo e reboco | `#B36C4D` `#C48B62` `#A75C46` `#C5AC7B` `#CE9B6D` |
| Fachadas frias | `#62958B` `#899B86` |
| Chão, rua, calçada | `#828369` `#A79B78` `#585F58` `#64695F` `#C7B88B` |
| Caixa d'água | `#427387` `#6C9EAC` |
| Quadra | `#4B8672` com linhas `#D6D4AD` |
| Sombras e contornos internos | `#263B36` `#243E3D` `#1B302D` |
| Pele / cabelo (personagens) | `#C79B78` / `#254451` |
| Interface | fundo `#102B2C`, creme `#EFE7D2`, texto apagado `#99ADA3`, dourado `#E2BD78` |
| Times | Azul `#57BDE8`, Coral `#F57A59` |

**O que ainda não existe** e que os prompts abaixo propõem: mais heróis, inibidores, selva/monstros neutros (o mapa hoje é só uma rota), variações de árvores e props.

---

## 2. Como usar

1. Copie o **bloco de estilo base** (seção 3) e cole **depois** da descrição do assunto.
2. Acrescente o **bloco do time** (azul ou coral) quando o objeto pertencer a uma equipe.
3. Acrescente o **bloco de formato** do tipo de asset (sprite de personagem, estrutura, prop, sprite sheet).
4. Use o **prompt negativo** em ferramentas que aceitam (SD, Flux, Leonardo). No Midjourney, use `--no` com os mesmos termos.
5. Para manter consistência entre gerações: fixe a seed, use a mesma imagem de referência (um print do jogo) como *style reference* (`--sref` no Midjourney, IP‑Adapter no SD) e gere primeiro um "personagem âncora" para usar de referência dos próximos.

**Tamanhos recomendados para o Godot.** O jogo roda em 1440×900 com stretch `canvas_items`. Gere em 1024×1024 e reduza:
- Tropas: 64 px de altura (frame 64×64).
- Heróis: 96 px de altura (frame 128×128).
- Monstros neutros: pequenos 96×96, chefes 256×256.
- Torres: 128×256. Inibidor: 192×192. Central: 384×384.
- Prédios e props: múltiplos de um losango de 128×64 (tile 2:1).

Gere sempre com **fundo transparente** (ou chroma key liso `#FF00FF` para recortar), ponto de apoio no centro da base do losango.

---

## 3. Blocos reutilizáveis

### 3.1 Estilo base (sempre incluir)

```
flat isometric low-poly game art, 2:1 isometric projection, camera 30 degrees from above,
clean vector shapes with no outlines, flat colored faces with soft top-left lighting,
each face a slightly lighter or darker tone, miniature diorama look, warm dusty late
afternoon light, muted earthy palette of terracotta brick, sand beige, sage grey-green
and deep teal shadows (#B36C4D, #C48B62, #C5AC7B, #899B86, #62958B, #263B36),
simple readable silhouettes, minimal detail, brazilian hillside favela setting,
stylized and fictional, mobile MOBA asset, crisp edges, no text
```

### 3.2 Time Azul (Polícia, oeste)

```
team color sky blue #57BDE8 as the dominant accent on clothing, flags and lights,
secondary dark navy #243E3D, cool and orderly feeling
```

### 3.3 Time Coral (Tráfico, leste)

```
team color coral orange #F57A59 as the dominant accent on clothing, flags and lights,
secondary dark brown #7D4C3B, warm and improvised feeling
```

### 3.4 Neutro (selva, monstros, props)

```
no team colors, natural greens #4B8672 and #294C43, earthy browns, small accents of
warm gold #E2BD78 for magical or valuable elements
```

### 3.5 Formatos

**Sprite de personagem**
```
single character, full body, chibi proportions about 3 heads tall, stocky body,
round head, facing down-right toward the camera in isometric 3/4 view, centered,
soft elliptical shadow under feet, isolated on transparent background, game sprite
```

**Sprite sheet de personagem**
```
character turnaround sprite sheet, same character in 8 isometric directions
(S, SE, E, NE, N, NW, W, SW), consistent proportions and colors, evenly spaced grid,
transparent background
```
Variações de animação: troque por `idle pose`, `walk cycle 6 frames`, `attack pose firing`, `casting area slam`, `dash motion blur`, `knocked down pose`.

**Estrutura**
```
single isometric building asset, sitting on a flat diamond-shaped ground tile,
whole structure visible, centered, isolated on transparent background, game structure
```

**Prop**
```
single small isometric prop, centered on a tiny diamond ground patch, isolated on
transparent background
```

### 3.6 Prompt negativo

```
realistic, photorealistic, 3d render with textures, gritty, gore, blood, real police
insignia, real gang symbols, real brand logos, text, letters, watermark, outlines,
heavy black lines, anime, pixel art, perspective camera, fisheye, cluttered background,
children, minors
```

> Observação de tom: o próprio jogo se apresenta como universo fictício. Para os heróis e tropas, mantenha tudo estilizado, sem insígnias reais (BOPE, PM, facções), sem violência gráfica e sempre com personagens adultos. Isso também evita bloqueios de moderação nos geradores.

---

## 4. Personagens

Monte o prompt como: **[assunto] + estilo base + bloco do time + formato**.

### 4.1 Heróis existentes

**Agente (Polícia / Azul)** – herói atual, lutador de média distância.
```
a stylized adult police agent hero, sky blue short-sleeve uniform shirt with dark
tactical vest, dark navy cargo pants and boots, dark cap, holding a long dark rifle
diagonally across the body, confident stance, small blue shoulder light
```

**Olheiro (Tráfico / Coral)** – herói atual, espelho do Agente.
```
a stylized adult lookout hero, coral orange t-shirt, dark bermuda shorts and sneakers,
coral bandana on the head, radio hanging from the belt, holding a long dark rifle
diagonally, alert watchful stance, one hand raised as if signaling
```

### 4.2 Novos heróis sugeridos (3 por time, em espelho)

| Função | Azul | Coral |
|---|---|---|
| Tanque | Sargento Escudo | Laje |
| Mobilidade/assassino | Motopatrulha | Mototáxi |
| Suporte/controle | Perita | Grafiteira |

**Sargento Escudo (Azul, tanque)**
```
a large stocky adult riot officer hero, big rectangular sky blue riot shield with a
simple star emblem, heavy padded armor, helmet with visor up, short baton,
wide grounded stance
```

**Laje (Coral, tanque)**
```
a huge broad-shouldered adult construction worker hero, coral tank top, cement dust on
dark pants, carrying a slab of concrete as a shield and a sledgehammer, work boots
```

**Motopatrulha (Azul, mobilidade)**
```
an adult police motorcyclist hero standing beside a small sky blue patrol motorbike,
helmet under arm, light vest, sleek fast pose
```

**Mototáxi (Coral, mobilidade)**
```
an adult moto-taxi rider hero sitting on a small dented motorbike, coral numbered vest,
open-face helmet, leaning forward ready to speed off
```

**Perita (Azul, suporte)**
```
an adult forensic expert heroine, sky blue lab vest over dark clothes, glasses, holding
a tablet, a small round surveillance drone hovering above her shoulder with a blue light
```

**Grafiteira (Coral, suporte)**
```
an adult street artist heroine, coral hoodie, paint-stained overalls, spray can in each
hand, colorful paint splashes around her feet, playful pose
```

**Retrato para a HUD** (o painel do herói hoje mostra só uma letra no círculo):
```
[descrição do herói], bust portrait inside a circle, facing 3/4 left, flat vector
style, plain dark teal background #102B2C, thin team-colored ring
```

### 4.3 Tropas (minions)

Hoje: bonequinho com camisa do time, calça escura, boné e arma longa. Sugiro 3 tipos por onda.

**Tropa corpo a corpo**
- Azul: `a small stocky adult police trooper minion, sky blue shirt, dark pants, cap, short baton and small round shield`
- Coral: `a small stocky adult lookout minion, coral t-shirt, dark shorts, bandana, wooden plank as a club`

**Tropa à distância** (o modelo atual)
- Azul: `a small stocky adult police trooper minion, sky blue shirt, dark vest, cap, holding a long dark rifle diagonally`
- Coral: `a small stocky adult lookout minion, coral t-shirt, cap backwards, holding a long dark rifle diagonally`

**Tropa de cerco** (aparece a cada 3 ondas)
- Azul: `a small armored police van minion seen in isometric view, sky blue stripes, roof light bar, compact toy-like proportions`
- Coral: `a small beat-up pickup truck minion seen in isometric view, coral painted doors, mattress and barricade on the back, compact toy-like proportions`

Acrescente ao final: `simpler and smaller than a hero, very readable silhouette at 64 pixels`.

### 4.4 Monstros da selva (neutros)

O mapa ainda não tem selva. Uma ideia que casa com o cenário: o topo do morro encosta na **mata atlântica**, e os neutros vêm do **folclore brasileiro** misturado com a fauna urbana. Use o bloco **Neutro** (3.4).

| Acampamento | Monstro | Papel sugerido |
|---|---|---|
| Pequeno | Capivaras | Ouro fácil, grupo de 3 |
| Pequeno | Urubus do lixão | Grupo voador de 3 |
| Médio | Vira‑lata Caramelo Alfa | Bônus de velocidade |
| Buff | Curupira | Bônus de regeneração/dano |
| Buff | Saci | Bônus de mobilidade |
| Chefe | Mapinguari | Objetivo de equipe |
| Chefe | Mula sem Cabeça | Objetivo de equipe |

**Capivaras**
```
a group of three chubby capybaras, one big and two small, calm sleepy expression,
sitting on a patch of grass
```

**Urubus do lixão**
```
three scruffy black vultures perched on a pile of trash bags and a broken crate,
wings half open, comic grumpy look
```

**Vira‑lata Caramelo Alfa**
```
a large scruffy caramel-colored street dog, oversized and muscular, glowing warm gold
collar, standing guard on a pile of bricks, friendly but fierce
```

**Curupira (buff)**
```
the Curupira from brazilian folklore, small forest spirit with flaming orange hair and
backwards feet, leafy clothing, glowing green aura, standing among ferns and roots
```

**Saci (buff)**
```
the Saci from brazilian folklore, one-legged mischievous spirit with a red cap and a
pipe, swirling small wind tornado around his leg, jumping pose
```

**Mapinguari (chefe)**
```
the Mapinguari from brazilian folklore, a giant shaggy sloth-like beast with one eye and
a mouth on its belly, mossy fur, standing in a clearing of jungle ruins, imposing but
stylized, boss monster
```

**Mula sem Cabeça (chefe)**
```
the headless mule from brazilian folklore, dark brown mule with fire bursting from its
neck instead of a head, glowing gold horseshoes, rearing on hind legs, boss monster
```

Para chefes, troque o formato por `large boss creature, roughly three times the size of a hero` e gere a área ao redor separadamente como estrutura (`jungle clearing with stone ruins and fallen trees`).

---

## 5. Estruturas

Monte o prompt como: **[assunto] + estilo base + bloco do time + formato "Estrutura"**.

### 5.1 Torres

Hoje: pilar de concreto verde‑acinzentado sobre base de areia com bandeira e esfera do time no topo. As versões abaixo mantêm o pilar como forma principal e dão identidade a cada lado.

**Torre Azul – Guarita de vigilância**
```
a tall narrow concrete watchtower, sage grey-green walls, small guard booth on top with
sky blue roof, a searchlight and a small sky blue flag, sandbags at the base, on a sandy
diamond base
```

**Torre Coral – Laje fortificada**
```
a tall narrow stack of unfinished brick floors, exposed rebar on top, blue water tank,
coral flag on a pole, string of coral lights, improvised plywood barricade at the base,
on a sandy diamond base
```

**Variações de estado** (acrescente ao fim):
- `intact, clean`
- `damaged, cracks and missing bricks, small smoke`
- `destroyed, collapsed rubble pile, broken flag on the ground`

Para **torre externa x interna**: a externa é a versão acima; a interna acrescenta `taller, reinforced with metal plates, two flags`.

### 5.2 Inibidor (novo)

Fica entre a última torre e a central. Se destruído, as tropas inimigas ficam mais fortes.

- **Azul:** `a compact fortified checkpoint gate, concrete barriers, sky blue boom barrier, radio antenna with a glowing sky blue orb on top`
- **Coral:** `a compact barricade of tires, oil drums and corrugated metal, coral painted, a speaker on a pole with a glowing coral orb on top`

### 5.3 Central / Nexus

Hoje: bloco largo sobre piso tingido com a cor do time.

**Central Azul**
```
a wide two-story community police base building, sage and white plaster walls, sky blue
trim and roof, rooftop antenna mast, flag pole with large sky blue flag, glowing sky blue
beacon on the roof, small fenced yard, ground tinted soft blue
```

**Central Coral**
```
a wide three-story self-built brick house with a rooftop slab, coral painted top floor,
water tanks, satellite dish, colorful clothesline, large coral flag on the roof, glowing
coral beacon, ground tinted soft coral
```

**Estados:** `intact` / `shield active, translucent team-colored dome` / `half destroyed, smoke` / `destroyed, rubble and fallen flag`.

### 5.4 Prédios do cenário (casario)

São o que mais aparece no mapa. Gere vários e varie só cor e altura.
```
a small isometric favela house, [2|3|4] stories, [terracotta brick #B36C4D | ochre
plaster #C48B62 | sand #C5AC7B | sage #899B86 | teal #62958B] walls, square dark windows
in a grid, flat roof slab with [a blue water tank | a tv antenna | a small rooftop
terrace | exposed rebar], slight color variation per floor
```

### 5.5 Árvores e vegetação

```
a stylized low-poly mango tree, round chunky canopy in two greens #4B8672 and #294C43,
thick brown trunk, soft round shadow
```
Variações: `banana tree with big flat leaves`, `tall palm tree`, `jabuticaba tree with dark fruits on the trunk`, `cluster of ferns and bushes`, `potted plants on a stair step`, `bamboo grove for the jungle edge`.

### 5.6 Props do mapa

Todos com o formato "Prop":
- `wooden utility pole with crossbar and sagging black cables`
- `blue plastic rooftop water tank`
- `clothesline with colorful shirts between two poles`
- `pile of black trash bags and a broken crate`
- `small street food cart with a striped umbrella`
- `concrete stairway with a metal handrail going up a slope`
- `small outdoor bar table with plastic chairs`
- `stack of red bricks and a cement bag`
- `parked old motorbike`
- `small chapel with a cross`
- `football court goal post with torn net`
- `fountain shrine marking the jungle camp entrance`
- `street sign board, blank, no text` (o texto "MORRO DO SOL" se aplica no Godot)

### 5.7 Elementos de chão e terreno

```
seamless isometric ground tile, 2:1 diamond, [cracked asphalt with dashed yellow line |
beige concrete sidewalk | packed dirt path | short grass | team plaza tinted sky blue |
team plaza tinted coral], flat colors, tileable edges
```

---

## 6. Exemplo completo pronto para colar

Torre Coral, intacta, para Midjourney:
```
a tall narrow stack of unfinished brick floors, exposed rebar on top, blue water tank,
coral flag on a pole, string of coral lights, improvised plywood barricade at the base,
on a sandy diamond base, intact, clean, flat isometric low-poly game art, 2:1 isometric
projection, camera 30 degrees from above, clean vector shapes with no outlines, flat
colored faces with soft top-left lighting, each face a slightly lighter or darker tone,
miniature diorama look, warm dusty late afternoon light, muted earthy palette of
terracotta brick, sand beige, sage grey-green and deep teal shadows, simple readable
silhouettes, minimal detail, brazilian hillside favela setting, stylized and fictional,
mobile MOBA asset, crisp edges, no text, team color coral orange #F57A59 as the dominant
accent, single isometric building asset sitting on a flat diamond-shaped ground tile,
whole structure visible, centered, isolated on plain background
--ar 1:2 --style raw --no realistic, outlines, text, gore, perspective
```

Agente em sprite sheet, para Stable Diffusion/Flux:
```
Prompt: a stylized adult police agent hero, sky blue short-sleeve uniform shirt with
dark tactical vest, dark navy cargo pants and boots, dark cap, holding a long dark rifle
diagonally, [estilo base], [time azul], character turnaround sprite sheet, same
character in 8 isometric directions, consistent proportions, evenly spaced grid,
transparent background
Negative: [prompt negativo]
```

---

## 7. Próximo passo sugerido

Como o jogo hoje desenha tudo por código, trocar para sprites exige ajustar `unit_actor.gd` (personagens, torres e central) e `district.gd` (cenário) para usar `Sprite2D`/`AnimatedSprite2D` no lugar das chamadas `draw_*`. Vale começar só pelos heróis e torres, que é onde a arte mais muda a leitura do jogo.
