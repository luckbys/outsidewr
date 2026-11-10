# HUD e interface

A interface usa painéis escuros translúcidos, texto claro, destaques dourados e as cores azul e coral das equipes. O placar tem recortes angulares e o minimapa inclui anéis. Em telas de 1000 a 1440 pixels de largura, a HUD reduz sua escala para manter a composição compacta da referência; abaixo disso, prioriza a leitura e reorganiza os painéis. O jogo continua exigindo teclado e mouse.

![HUD durante a partida](images/match.png)

## Partida

| Indicador | Origem e comportamento |
| --- | --- |
| Cabeçalho | Tempo da partida, onda atual, vida percentual das centrais e barricadas vivas de cada equipe |
| Próximo objetivo | Barricadas inimigas restantes; muda para a central quando ela fica vulnerável |
| Próxima tropa | Contagem até a próxima onda da simulação |
| Herói | Nome, retrato da equipe, vida atual/máxima e estado de movimento, combate, lentidão, mira de defesa, cura ou retorno |
| Vida baixa | Texto e borda destacados quando o herói vivo fica abaixo de 30% de vida |
| Alvo | Tipo e vida do inimigo selecionado; sem alvo, apresenta uma dica de avanço |
| Habilidades | Atalho, disponibilidade e segundos reais de recarga |
| Retorno | Tempo restante até o herói reaparecer na central |

O contador **Alvos** registra as eliminações creditadas ao jogador, incluindo minions e estruturas; **Quedas** conta as derrotas do jogador. Não representa apenas eliminações de heróis.

**Q / Impacto** causa dano em área e aplica lentidão de 35% por 1,5 s. **E / Avanço** usa a última direção apontada no mundo, preservando a mira ao clicar no botão da HUD. **B / Recuar** ordena que o herói caminhe até sua central; a cura continua dependendo da proximidade da base. Os botões das habilidades ficam desabilitados durante sua recarga, a pausa e a espera pelo retorno.

O **minimapa** mostra heróis, tropas, barricadas e centrais nas posições da partida. O círculo branco identifica o jogador; o traço dourado indica sua ordem de movimento ou ataque. Clique no mapa para ordenar movimento ou use **Shift + clique** para avançar atacando. Os limites da rota continuam sendo aplicados pelo controlador.

Quando uma defesa mira no jogador, a HUD destaca o cartão em coral e mostra **MIRA DA DEFESA / RECUE**. O cenário mostra a linha de mira e o alcance durante os 0,45 s de preparação do disparo. O painel de objetivo apresenta uma dica sobre essas regras ao passar o mouse. **Espaço** mantém a posição sem perseguir inimigos que saiam do alcance.

![HUD em uma janela de 800×600](images/hud-compact.png)

O botão **II** ou **Esc** abre a pausa e os controles. **Continuar / Esc** retoma a mesma partida. **F2** alterna a representação 3D/2D do cenário. Cliques nos painéis e na pausa são consumidos pela interface.

## Demonstração 3D

![Interface de exploração 3D](images/characters-3d.png)

A barra inferior permite alternar entre vista geral, centrais, personagens e barricadas. Os botões se distribuem em linhas conforme a janela; o cabeçalho indica a vista ativa e o zoom atual. Atalhos: **1–5** para enquadramentos, **N** para navegação e **H / ?** para a ajuda da câmera. **Jogar** abre a partida.

Essa interface acompanha o ambiente de exploração. A vida, as habilidades e os objetivos de combate pertencem à partida principal.

## Validar

```bash
bash tools/setup.sh
# Apenas os 23 testes de integração da HUD:
bash tools/godot.sh --headless --script tests/hud_smoke.gd
```

Os testes injetam eventos reais no viewport e consultam o estado da partida. A exportação Docker das duas cenas também foi inspecionada no Chromium nos três tamanhos de janela acima.
