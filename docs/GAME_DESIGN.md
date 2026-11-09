# Morro em Disputa — documento inicial

## Visão

Um MOBA isométrico em uma favela brasileira fictícia, com leitura clara do combate, partidas centradas em objetivos e identidade visual brasileira. O nome e o cenário são provisórios. A primeira entrega é uma fatia jogável local para testar a rota antes de ampliar o escopo.

O Morro do Sol combina tijolo aparente, reboco colorido, lajes, caixas-d'água azuis, fiação, varais, becos e uma quadra. A arte atual é vetorial e gerada pelo código; os personagens e equipamentos são silhuetas provisórias.

## Equipes

| Lado | Identificação | Herói inicial | Base |
| --- | --- | --- | --- |
| Polícia | Azul, oeste | Agente | Central Azul |
| Tráfico | Coral, leste | Olheiro | Central Coral |

Não são reproduzidas organizações reais. A escolha é visual nesta versão: vida, dano, alcance, velocidade e habilidades são iguais. A IA rival tem ataque e movimentação automáticos; ainda não usa habilidades.

## Ciclo da partida atual

1. Escolher uma equipe e aparecer perto de sua central.
2. Acompanhar a primeira onda, que sai após 2 segundos. Novas ondas saem a cada 14 segundos.
3. Disputar espaço e eliminar tropas com ataques e Impacto.
4. Aproveitar a presença das tropas para pressionar as torres.
5. Destruir as duas torres rivais para liberar o dano à central.
6. Destruir a central e reiniciar pela tela de resultado.

O corredor jogável é contínuo e sem colisores intermediários. As casas são cenário. Recuar até a própria base recupera vida; morrer impõe 8 segundos de espera. Não há perda de recursos, compras ou experiência nesta fase.

## Habilidades

- **Impacto (Q):** 70 de dano em um raio lógico de 155 unidades; recarga de 7 s. Atinge heróis e tropas inimigas, sem danificar estruturas.
- **Avanço (E):** deslocamento de até 125 unidades em direção ao cursor; recarga de 5 s. Respeita os limites da rota.
- **Ataque básico:** automático quando há um alvo ao alcance. Um comando de movimento interrompe a perseguição; parado, o herói procura alvos próximos.

O protótipo não usa dano aleatório. A configuração inicial está concentrada em `MatchRules`.

## Próximas entregas sugeridas

### 1. Fechar a experiência de uma rota

- Playtesting dos tempos de avanço, cura, recarga e duração das partidas.
- Trocar as silhuetas por sprites com oito direções e animações de ataque e derrota.
- Inserir áudio, feedback de seleção, indicação de alcance e alvos mais legíveis.
- Extrair heróis para cenas próprias e separar habilidades em recursos reutilizáveis.
- Mapear controles em InputMap e criar opções de remapeamento e acessibilidade.

Critério de conclusão: as duas equipes conseguem jogar, vencer, perder e recomeçar uma partida completa com boa leitura dos objetivos.

### 2. Aprofundar o MOBA

- Heróis com funções diferentes: resistência, dano e suporte.
- Experiência, níveis, economia, itens e loja na base.
- Novas rotas, becos transitáveis, navegação e colisão com o cenário.
- Objetivos neutros e recursos de visão; IA que usa habilidades e recua.
- Migrar casas e trechos do mapa para cenas editáveis ou TileMapLayer.

Critério de conclusão: escolhas de composição, itens e movimentação produzem estratégias distintas.

### 3. Multiplayer

- Definir primeiro o tamanho das equipes e os limites de conexão esperados.
- Servidor autoritativo para movimento, dano, recargas e resultados.
- Comandos de jogador com identificação e validação pelo servidor.
- Replicação de estado, interpolação, entrada na partida e reconexão.
- Só então salas, autenticação, matchmaking e persistência de conta.

O código atual roda em um único processo. A separação entre coordenadas lógicas e desenho ajuda essa evolução, mas não implementa rede nem garante determinismo entre máquinas.
