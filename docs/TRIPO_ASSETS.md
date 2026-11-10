# Assets 3D pela API Tripo

O projeto inclui um cliente para a **Tripo API v3**, seguindo o `quick-start.pdf` fornecido nesta conversa. Ele gera modelos GLB, consulta as tarefas assíncronas e, para personagens, executa `rig-check → rig → retarget preset:walk`.

**Estado desta entrega:** a chave cadastrada como **`triploapi`** e o domínio **`openapi.tripo3d.ai`** estão disponíveis. A criação real de `house_brick` foi enviada à API e recusada com **HTTP 403, code 2010: créditos insuficientes**. Nenhum `task_id` ou GLB foi criado. A integração e o tratamento dessa resposta foram validados com testes offline; a geração real depende de disponibilizar créditos na conta da API.

## Configuração necessária

1. Para um ambiente novo, crie uma chave na [página API Keys da Tripo](https://developers.tripo3d.ai/pt/keys).
2. O cliente aceita **`TRIPO_API_KEY`** ou o cadastro existente **`triploapi`**. Não é necessário cadastrar outra chave. Para um ambiente novo, use um segredo com destino HTTPS **`openapi.tripo3d.ai`**. Não envie a chave pelo chat nem a coloque no código ou nos argumentos do terminal.
3. O domínio **`openapi.tripo3d.ai`** já foi liberado neste ambiente. O download pode usar outro domínio CDN retornado pela API; se ele for bloqueado, o cliente informa somente o hostname necessário, sem mostrar a URL assinada.
4. Disponibilize créditos na conta da API para resolver o erro **2010** observado. O PDF não informa preços: o plano abaixo lista tarefas, sem estimar custo em créditos ou dinheiro.

A ferramenta usa apenas a biblioteca padrão do Python 3. Não precisa instalar `requests`, SDKs ou plugins. Os segredos configurados pelo proxy do ambiente podem ser placeholders; o cliente utiliza a variável normalmente, sem tentar extrair seu valor real.

## Lote inicial

Os prompts completos e os parâmetros estão em [`tools/tripo_catalog.json`](../tools/tripo_catalog.json).

| ID | Asset | Etapas |
| --- | --- | --- |
| `house_brick` | Casa de tijolo aparente | Geração |
| `house_plaster` | Casa com reboco gasto | Geração |
| `barricade` | Concreto, sacos de areia e pneus | Geração |
| `water_tank` | Caixa-d'água azul com nervuras | Geração |
| `police_hero` | Herói da equipe azul | Geração, rig-check, rig, caminhada |
| `traffic_hero` | Herói da equipe coral | Geração, rig-check, rig, caminhada |
| `police_minion` | Minion da equipe azul | Geração, rig-check, rig, caminhada |
| `traffic_minion` | Minion da equipe coral | Geração, rig-check, rig, caminhada |

São **8 modelos e até 20 tarefas**. O catálogo usa `P2-20260801`, `face_limit=5000`, texturas habilitadas e rig `v3.0-20260909`, com `rig_type=biped` e `spec=mixamo`, conforme o PDF. Os personagens são solicitados em pose A, sem objetos nas mãos, para facilitar o rigging. Equipamentos adicionais e qualidade final deverão ser conferidos nos resultados reais.

## Gerar e retomar

```bash
# Mostrar o lote; não usa chave, rede ou créditos:
python3 tools/tripo_assets.py plan

# Começar por uma casa para revisar a qualidade e a escala:
python3 tools/tripo_assets.py generate --asset house_brick

# Gerar o restante do lote, reutilizando os resultados já concluídos:
python3 tools/tripo_assets.py generate --all

# Consultar o estado local sem rede:
python3 tools/tripo_assets.py status
```

As tarefas são executadas sequencialmente. O cliente limita as chamadas e consulta o andamento a cada 2 segundos. Os modelos são baixados imediatamente após a conclusão, pois `output.model_url` expira em 5 minutos.

O progresso fica em `builds/tripo/state.json`, ignorado pelo Git. Preserve esse arquivo para retomar o mesmo lote no mesmo ambiente ou ao transferir a execução. Ele guarda IDs de tarefas, etapas e hashes, sem chave ou URLs assinadas. As fontes intermediárias de personagens ficam em `builds/tripo/sources/`. Os GLBs finais ficam em **`assets/models/tripo/ID.glb`**.

Executar novamente o comando retoma tarefas existentes e não gera outra cópia de um asset concluído. Dois processos não podem usar o mesmo estado simultaneamente. Arquivos finais preexistentes sem histórico ou alterados por um artista não são sobrescritos. Para uma nova versão, preserve o GLB anterior e use outro arquivo `--state`.

Uma requisição claramente rejeitada, por exemplo por autenticação ou saldo, pode ser retomada após corrigir a causa. Se a conexão cair depois do envio e nenhum `task_id` for confirmado, o cliente interrompe a operação para evitar cobrança duplicada. Confira a tarefa no painel e associe seu ID existente:

```bash
python3 tools/tripo_assets.py adopt --asset house_brick --stage generate --task-id UUID_DA_TAREFA
python3 tools/tripo_assets.py generate --asset house_brick
```

O rig recebe o ID da geração original, e o retarget recebe o ID do rig. Um personagem que não passe no rig-check bípede mantém sua fonte para revisão, sem iniciar rig, animação ou regenerações automáticas.

## Usar no Godot e no Docker

Após baixar os modelos:

```bash
bash tools/setup.sh
```

Reinicie a cena com **F5** ou **F6** para carregar os novos assets. `TripoAssetLibrary` instancia os GLBs locais e os ajusta uniformemente à escala em metros, centralizados no chão. Casas e barricadas mantêm os colisores existentes. Os personagens mantêm sua lógica de combate, seleção e barras de vida; a caminhada importada usa o relógio da partida e congela durante a pausa.

Cada modelo disponível substitui seu correspondente procedural. Enquanto o arquivo não existir, a aparência atual permanece. A opção 2D em **F2** continua funcionando.

Faça novo build e deploy pelo Dockerfile para publicar os GLBs. A API é usada **somente durante a criação dos assets**: o jogo, a exportação web e o contêiner final não recebem a chave e não criam tarefas na Tripo.

## Verificações

```bash
python3 -m unittest discover -s tests -p 'test_tripo_assets.py' -v
bash tools/godot.sh --headless --script tests/tripo_assets_smoke.gd
```

São **24 testes Python com respostas simuladas** e **12 verificações Godot com cenas de teste locais**. Eles verificam o protocolo v3, retomada sem POST duplicado, download sem Authorization para a CDN, validação GLB, preservação de arquivos, normalização, animação manual e manutenção dos colisores. Os fixtures ficam em memória ou diretórios temporários; não são apresentados como modelos gerados pela Tripo.

A geração bem-sucedida, os domínios CDN e a qualidade visual dos GLBs ainda precisam ser validados após disponibilizar créditos. A leitura e a gravação automática da configuração retornaram `INVALID_ARGUMENT` nesta sessão; a chave e a liberação da rede foram reconhecidas posteriormente na configuração ativa.
