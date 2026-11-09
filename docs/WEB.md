# Jogar pelo navegador

O projeto tem um preset **Web**, com Godot 4.6.3, WebGL 2 e WebAssembly. O jogo continua local contra um bot; abrir por uma URL não cria multiplayer.

Para executar na hospedagem usando Dockerfile, veja [DOCKER.md](DOCKER.md). `docker compose up --build -d` compila o projeto e inicia o servidor na porta 8080.

## Gerar a versão web

```bash
bash tools/export_web.sh
```

São gerados:

- `builds/web/`: site estático completo, com `index.html`, runtime e jogo.
- `builds/morro-em-disputa-web.zip`: pacote para enviar a uma hospedagem HTML5.

O script instala apenas o template web oficial sem threads (aproximadamente 9,6 MB compactados), por HTTPS, a partir do arquivo de templates da versão 4.6.3 no GitHub oficial do Godot. Ele usa requisições parciais para evitar baixar os 1,25 GB de templates para outras plataformas. Verifica os CRCs do membro do arquivo remoto e de todos os arquivos dentro do template. Não baixa o arquivo completo e, portanto, não afirma verificar o SHA-512 do arquivo de 1,25 GB. A exportação seguinte reaproveita o template já verificado em `.godot/web_templates/`.

O template não usa threads, SharedArrayBuffer ou extensões nativas. Não exige os cabeçalhos COOP/COEP. Os caminhos dos arquivos são relativos, permitindo hospedar o jogo em uma subpasta. O runtime `.wasm` tem cerca de 37,7 MB sem compressão; a hospedagem pode comprimi-lo no transporte.

## Hospedagem

Envie **todos os arquivos de `builds/web/`**, mantendo os nomes e a posição relativa, para uma hospedagem de site estático com HTTPS. Configure `.wasm` como `application/wasm` e não transforme requisições de arquivos inexistentes em páginas HTML.

Não basta enviar apenas `index.html`. Não use `file://` para jogar; o navegador precisa carregar o runtime e o pacote por HTTP(S). Nesta versão, os controles foram preparados para computador com mouse e teclado.

## GitHub Pages

A versão web foi enviada para a branch remota **`gh-pages`** de `luckbys/outsidewr`, no commit `04da0bc6988a150b0a3acda184bc51895d2aa456`. A referência remota foi confirmada por Git. Essa branch contém somente os arquivos do site; o código do projeto continua no checkout de desenvolvimento.

Para liberar a hospedagem dessa versão:

1. Abra [Settings → Pages](https://github.com/luckbys/outsidewr/settings/pages).
2. Em **Build and deployment**, escolha **Deploy from a branch**.
3. Selecione **gh-pages** e **/(root)**, e salve.
4. Aguarde a publicação e abra o endereço indicado pelo GitHub.

O endereço convencional esperado após a ativação é `https://luckbys.github.io/outsidewr/`. A ativação e a resposta pública desse endereço não puderam ser confirmadas nesta máquina: tanto a API do Pages quanto o domínio do site são bloqueados pelo proxy (CONNECT 403).

### Automatizar futuras versões

Como alternativa opcional para quem usar GitHub Pages, o workflow `.github/workflows/publish-web.yml` está preparado para importar, testar, exportar e publicar a partir do código-fonte. Ele só executa manualmente e não publica ao enviar alterações para `main`. A hospedagem externa escolhida para o projeto pode receber diretamente os arquivos de `builds/web/`. A execução remota do workflow ainda não foi verificada. Para usar essa alternativa:

1. Envie os arquivos do projeto e do workflow para a branch `main` do repositório.
2. Em **Settings → Pages → Build and deployment**, escolha **GitHub Actions**.
3. Execute manualmente **Publicar jogo no GitHub Pages** na aba **Actions**.
4. Use o link exibido no ambiente `github-pages` após o job de publicação terminar com sucesso.

O workflow fixa a versão do Godot e confere o SHA-512 do editor Linux contra o valor oficial registrado na configuração. Usa os Actions oficiais do GitHub para armazenar o artefato e publicar.

## Validação realizada nesta máquina

- Exportação release concluída.
- Site servido por HTTP estático, sem cabeçalhos de isolamento.
- Chromium carregou o runtime WebAssembly e renderizou o jogo.
- Seleção de equipe, deslocamento, Q, pausa e continuação exercitados pelo navegador.
- Capturas inspecionadas e ausência de erros de JavaScript ou de scripts Godot.

Isso confirma a versão web nesta máquina e o envio dos arquivos à branch de publicação, não que o site público esteja ativo. O ambiente atual não oferece um publicador de URL/port forwarding, e os acessos à API `api.github.com` e ao site `luckbys.github.io` são bloqueados pelo proxy (CONNECT 403). O acesso Git ao repositório, que usa outra rota, funciona. Alterar apenas a saída de rede não cria um link público: ainda é necessário ativar a hospedagem.
