# Rodar o jogo com Docker

O Dockerfile compila a versão HTML5 a partir do código do projeto e serve o jogo com Nginx na porta **8080**. A máquina que executa o contêiner precisa de Docker; não precisa instalar Godot ou Python no host.

A raiz `/` abre a partida 2D e `/3d/` abre a demonstração independente do ambiente 3D. As duas versões são exportadas no build da imagem. Para os controles de exploração e a organização do cenário, veja [ENVIRONMENT_3D.md](ENVIRONMENT_3D.md).

## Com Docker Compose

Na raiz do repositório:

```bash
docker compose up --build -d
docker compose ps
```

O serviço publica a porta 8080 do contêiner na porta 8080 do host. Configure seu domínio ou proxy da hospedagem para encaminhar as requisições para essa porta. Para publicar em outra porta do host:

```bash
PORT=8090 docker compose up --build -d
```

`PORT` controla apenas a porta publicada pelo Compose. O servidor dentro do contêiner continua ouvindo em **8080**.

Para acompanhar logs e encerrar:

```bash
docker compose logs -f game
docker compose down
```

## Apenas Dockerfile

```bash
docker build -t morro-em-disputa:local .
docker run --rm -p 8080:8080 morro-em-disputa:local
```

Em um painel de hospedagem com suporte a Dockerfile, selecione a raiz deste repositório como contexto de build, o arquivo `Dockerfile` e a porta interna **8080**. Configure o domínio e o HTTPS no painel ou no proxy da hospedagem.

### EasyPanel

No serviço da aplicação:

1. Selecione a branch com o Dockerfile (`codex/morro-em-disputa`, enquanto as alterações não forem integradas à branch principal) e execute o deploy.
2. Em **Domínios**, confira se o domínio aponta para esse serviço, com caminho `/` e porta de destino **8080**.
3. Use **HTTP** na conexão do proxy ao contêiner. O HTTPS do domínio é terminado pelo EasyPanel; o Nginx interno atende HTTP.
4. Salve a configuração e abra o domínio HTTPS novamente.

A imagem anuncia somente `8080/tcp` para evitar que a detecção automática escolha a porta 80. O encaminhamento de um domínio já cadastrado precisa ser conferido no painel, mesmo depois de atualizar a imagem.

Linhas de log com `127.0.0.1`, `Wget` e `GET /index.html` são requisições do healthcheck. Elas confirmam a resposta interna do HTML. Ao abrir o domínio no navegador, o log deve mostrar também as requisições do navegador para a página, `index.js`, `index.wasm` e `index.pck`. Se aparecer apenas o Wget, verifique o domínio e o encaminhamento no painel.

Se o HTML abrir e o carregamento travar, confira o erro mostrado na página ou no Console/Network do navegador. O Godot exige HTTPS no acesso público e suporte a WebGL 2. Verifique se os arquivos `.wasm` e `.pck` retornam 200; não troque essas respostas por HTML.

## O que a imagem faz

1. O estágio de build instala Godot **4.6.3**, verificando o SHA-512 oficial do editor. Seleciona o editor conforme a arquitetura da máquina de build (`amd64` ou `arm64`).
2. Instala Fontconfig e fontes do sistema pelo APT, mantendo a verificação de pacotes.
3. Executa os testes do jogo e exporta HTML5 com o template oficial sem threads.
4. Copia apenas o site exportado para a imagem final de Nginx, executada sem root.

Godot, Python, fontes, ferramentas e código-fonte não acompanham a imagem final. O primeiro build precisa de acesso ao Docker Hub, ao repositório Debian e aos downloads oficiais do Godot no GitHub. Builds seguintes reaproveitam as etapas que não mudaram.

O servidor fornece `application/wasm`, comprime os arquivos grandes, pede revalidação do cache e retorna 404 para arquivos inexistentes. Não precisa de COOP/COEP, pois o template não usa threads. O healthcheck consulta o HTML do jogo diretamente pelo loopback. O Compose usa sistema de arquivos somente leitura e um diretório temporário em memória para o Nginx.

A imagem foi compilada e executada em `linux/amd64` nesta entrega. A seleção de editor para builds em `arm64` está configurada, mas essa arquitetura ainda não foi executada nesta máquina.

## Verificação HTTP

Com o contêiner em execução, rode o teste apontando para o endereço HTTP do serviço:

```bash
python3 tests/web_http_smoke.py http://127.0.0.1:8080
```

O teste verifica HTML, cache, tipo e tamanho do WebAssembly, o pacote Godot, gzip válido e a resposta 404. A inspeção de jogabilidade no navegador é uma verificação adicional; uma porta aberta sozinha não comprova que o jogo carregou.

## Build em uma rede com CA de proxy

O Dockerfile aceita o secret opcional `proxy_ca`, usado apenas durante as etapas de download. Em ambientes gerenciados com inspeção TLS, passe o bundle de CAs confiáveis, incluindo a CA do proxy:

```bash
docker build \
  --secret id=proxy_ca,src=/etc/ssl/certs/ca-certificates.crt \
  -t morro-em-disputa:local .
docker compose up -d --no-build
```

O bundle não é copiado para a imagem. Preserve as configurações de proxy e as credenciais de registry fornecidas pelo ambiente. Não desative a verificação TLS. O Compose padrão não exige esse secret, para funcionar também em redes comuns.

O contêiner entrega a partida local contra bot pelo navegador. Multiplayer e provisionamento de domínio público não fazem parte desse servidor estático.
