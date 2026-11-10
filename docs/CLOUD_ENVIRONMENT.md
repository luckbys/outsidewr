# Ambiente de desenvolvimento na nuvem

## Preparação reproduzível

O checkout fica em `/workspace/outsidewr`. Cada tarefa já tem um ambiente isolado: use esse checkout; não crie worktrees sem solicitação explícita.

O ambiente desta entrega oferece Godot **4.6.3 Standard** em `/usr/local/bin/godot`. O projeto não usa bibliotecas externas, extensões nativas, tokens, banco de dados ou serviços de aplicação. Para outra máquina, instale Godot 4.6.x de uma distribuição oficial, mantendo a verificação TLS e de integridade.

```bash
cd /workspace/outsidewr
bash tools/setup.sh
```

O helper `tools/godot.sh` encaminha os arquivos de dados, configuração e cache para `/workspace/.godot-runtime`. Isso evita os diretórios de HOME sem permissão de escrita nesta máquina. Fora de `/workspace`, usa um diretório sob o cache do usuário. `MORRO_RUNTIME_DIR` e `GODOT_BIN` permitem substituições explícitas.

O setup verifica a versão, importa os assets e roda quatro suítes de integração: simulação, entrada, ambiente 3D e HUD. Pode ser repetido sem alterar código, recursos ou regras de balanceamento. `.godot/` é cache local ignorado pelo Git; os arquivos `.uid` dos scripts devem acompanhar o projeto.

## Início de uma nova tarefa

1. Confirme o checkout e leia o README.
2. Execute `bash tools/setup.sh` se for preciso importar ou verificar o estado.
3. Com um desktop disponível, abra `bash tools/godot.sh --editor` e use F5; ou execute `bash tools/godot.sh` para iniciar o jogo.
4. Sem desktop, use os testes headless. Não apresente isso como sessão gráfica interativa.
5. Para gerar a versão HTML5, use `bash tools/export_web.sh`. A versão web e a publicação por hospedagem estática estão descritas em [WEB.md](WEB.md). O ambiente não oferece link público automático para um servidor HTTP local.
6. Para compilar e iniciar o servidor em Docker, siga [DOCKER.md](DOCKER.md). Nesta rede, forneça o bundle de CAs como secret no build e use `docker compose up -d --no-build`. A porta interna é 8080; confirme a saúde do contêiner e a resposta do jogo, sem presumir que o processo esteja ativo em uma nova tarefa.

As capturas desta entrega foram feitas com um display X11 virtual e o renderer Compatibility / Mesa llvmpipe. Esses processos temporários não são requisitos do jogo e não devem ser presumidos ativos em novas tarefas.

## Configuração e publicação

Instruções locais não publicam um ambiente. O serviço de configuração em nuvem deve confirmar separadamente a gravação de `install_script` e `start_skill`; a publicação é uma ação do produto nas configurações do ambiente. Um teste bem-sucedido nesta máquina não comprova restauração em uma nova tarefa.
