# Morro em Disputa

Base jogável de um **MOBA 2D isométrico em Godot 4.6**, ambientado no Morro do Sol, uma favela brasileira fictícia. Dois lados disputam a mesma rota: **Polícia / Equipe Azul** e **Tráfico / Equipe Coral**.

![Partida no Morro do Sol](docs/images/match.png)

## Rodar com Docker

```bash
docker compose up --build -d
```

O jogo fica disponível por HTTP na **porta 8080** do host. O Dockerfile testa e exporta o projeto com Godot 4.6.3 e serve os arquivos com Nginx; não é necessário instalar Godot na hospedagem. Configure o domínio do seu provedor para encaminhar à porta 8080.

Consulte [execução e publicação com Docker](docs/DOCKER.md) para configuração de porta, logs, build sem Compose e uso em redes com proxy.

## Ambiente 3D independente

Abra [`scenes/demo_3d.tscn`](scenes/demo_3d.tscn) no Godot e pressione **F6** para explorar o Morro do Sol em 3D. Use WASD para mover a câmera, Q/E ou o botão direito para girar, a roda para zoom e Home para restaurar a vista. O mapa editável está em [`scenes/world/district_3d.tscn`](scenes/world/district_3d.tscn).

O **F5** continua abrindo o protótipo 2D. Após atualizar a imagem Docker, a demonstração é servida em **`/3d/`**, enquanto a partida 2D permanece em **`/`**. Veja [estrutura, controles e exportação 3D](docs/ENVIRONMENT_3D.md).

## Abrir e jogar

1. Instale o **Godot 4.6.x Standard**, com GDScript. A versão usada na validação foi **4.6.3**; não é necessário .NET.
2. Importe o arquivo [`project.godot`](project.godot) no gerenciador de projetos.
3. Pressione **F5** e escolha uma facção.
4. Acompanhe suas tropas, destrua as **duas torres inimigas** e depois a **central rival**. A central permanece protegida enquanto houver uma torre de sua equipe.

No terminal, com `godot` no PATH:

```bash
godot --editor --path .
# Ou execute diretamente:
godot --path .
```

## Controles

| Comando | Ação |
| --- | --- |
| Clique esquerdo ou direito no chão | Mover pelo corredor jogável |
| Clique em um inimigo | Aproximar e atacar automaticamente |
| WASD | Movimento nas direções da tela |
| Q / botão Impacto | Dano em área contra personagens e tropas; recarga de 7 s |
| E / botão Avanço | Avançar na direção do cursor; recarga de 5 s |
| Espaço | Parar o movimento |
| Esc | Pausar / continuar |

Um personagem parado ataca automaticamente rivais ao alcance. Ficar perto da sua central recupera vida. Após uma derrota, o personagem retorna à base em **8 segundos**. A partida termina quando uma central é destruída; a tela final permite escolher uma facção e recomeçar.

## O que já funciona

- Seleção das duas facções, com cores e personagens identificáveis.
- Mapa isométrico procedural: casas, lajes, caixas-d'água, antenas, varais, postes, fiação e quadra.
- Uma rota livre de obstáculos, duas torres e uma central por equipe.
- Herói jogável, herói adversário com IA simples e ondas de três tropas por lado a cada 14 s.
- Ataques automáticos, habilidades, vida, cura, derrota, retorno, vitória e reinício.
- HUD em português com minimapa, vida das centrais, cronômetro e recargas.

Esta versão é **local e para um jogador**, com arte geométrica provisória. As facções compartilham os mesmos atributos e habilidades. Ainda não há multiplayer, loja, itens, progressão de nível, áudio, múltiplas rotas, navegação entre casas ou arte final.

## Organização

```text
assets/                 Ícone e futuros sprites, áudio e fontes
scenes/main.tscn         Cena principal: mundo, unidades, efeitos e interface
resources/factions/     Dados editáveis de cada facção (.tres)
scripts/
  core/iso.gd           Projeção, seleção e limites de movimento
  data/                 Recursos de facção e regras de balanceamento
  actors/unit_actor.gd  Heróis, tropas, torres e centrais
  match/                Estado, comandos e simulação da partida
  world/                Cenário procedural e efeitos de combate
  ui/                   Interface, seleção, pausa e resultado
tests/                  Testes de simulação e entrada pela interface
tools/                  Execução na nuvem, preparação e captura visual
docs/                   Design, arquitetura e próximos passos
```

Para mudar vida, dano, velocidade e recargas, edite [`match_rules.gd`](scripts/data/match_rules.gd). Para mudar nomes e cores, abra os recursos em `resources/factions/` pelo Inspector. As regras de combate não dependem do desenho dos personagens.

## Validação

Não há pacotes externos nem serviços obrigatórios. Na nuvem, o helper mantém os diretórios graváveis do Godot fora do checkout:

```bash
bash tools/setup.sh
```

Esse comando importa o projeto e executa **62 verificações**: 29 de simulação, 7 de interface e 26 do ambiente 3D. Entre elas estão dano, fogo amigo, alcance, recargas, proteção da central, vitória, reinício, pausa, retorno, combate entre tropas, partida completa, seleção de facção, colisões 3D, câmera e uma rota de navegação entre as bases.

Para executar separadamente:

```bash
bash tools/godot.sh --headless --script tests/match_smoke.gd
bash tools/godot.sh --headless --script tests/input_smoke.gd
bash tools/godot.sh --headless --script tests/district_3d_smoke.gd
```

O teste de partida completa acelera o tempo e dirige um herói que avança e usa Q; ele verifica se esse comportamento consegue vencer em até 20 minutos simulados. Não substitui playtesting de equilíbrio ou teste de multiplayer.

Capturas opcionais, em uma máquina com display:

```bash
bash tools/godot.sh --audio-driver Dummy --script tools/capture_preview.gd -- /tmp/morro-preview
```

Mais detalhes: [design e evolução](docs/GAME_DESIGN.md), [arquitetura](docs/ARCHITECTURE.md) e [ambiente na nuvem](docs/CLOUD_ENVIRONMENT.md).

## Versão para navegador

```bash
bash tools/export_web.sh
```

A versão HTML5 foi executada e validada no Chromium. O pacote `builds/morro-em-disputa-web.zip` contém os arquivos para hospedagem estática; a pasta `builds/web/` contém o site pronto. Ainda é uma partida local contra bot.

A build HTML5 já foi enviada à branch remota `gh-pages`. Para liberar o site, abra **Settings → Pages**, escolha **Deploy from a branch → gh-pages → /(root)** e salve. A resposta do site público ainda não pôde ser validada neste ambiente.

O repositório também inclui um [workflow opcional de GitHub Pages](.github/workflows/publish-web.yml), executado apenas manualmente. Para outra hospedagem, envie os arquivos de `builds/web/` conforme as [instruções de publicação](docs/WEB.md).
