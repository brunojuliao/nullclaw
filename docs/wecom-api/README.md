# WeCom API Docs Snapshot

Copia local (HTML) da documentacao oficial do WeCom para consulta offline durante o MVP do canal.

## Arquivos baixados

- `90664-dev-guide.html` - guia inicial e fluxo de chamadas.
- `91039-access-token.html` - obtencao e uso de access_token.
- `90236-send-message.html` - envio de mensagens por aplicacao.
- `90239-message-format.html` - formatos XML de mensagens/eventos recebidos.
- `90930-callback-config.html` - configuracao de callback.
- `91770-webhook-bot.html` - webhook de mensagem push (bot).

## Fonte oficial

- https://developer.work.weixin.qq.com/document/

## Atualizar snapshot

Executar no root do repo:

```bash
mkdir -p docs/wecom-api && cd docs/wecom-api
curl -L 'https://developer.work.weixin.qq.com/document/path/90664' -o 90664-dev-guide.html
curl -L 'https://developer.work.weixin.qq.com/document/path/91039' -o 91039-access-token.html
curl -L 'https://developer.work.weixin.qq.com/document/path/90236' -o 90236-send-message.html
curl -L 'https://developer.work.weixin.qq.com/document/path/90239' -o 90239-message-format.html
curl -L 'https://developer.work.weixin.qq.com/document/path/90930' -o 90930-callback-config.html
curl -L 'https://developer.work.weixin.qq.com/document/path/91770' -o 91770-webhook-bot.html
```
