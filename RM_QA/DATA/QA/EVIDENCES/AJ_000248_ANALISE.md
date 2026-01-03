# AJ_000248 — CI: notificação opcional em FAIL do prepack gate

## Personas consultadas
- **QA Lead (Marina)** — quer visibilidade rápida das falhas do gate, mas sem spam em builds locais. Perguntas:
  - O payload mostra quais módulos falharam e o motivo resumido?
  - Como garantir que segredos de webhook não vazem nos logs?
- **DevOps (Rafael)** — foca em manutenção do pipeline. Perguntas:
  - O script precisa de dependências extras ou funciona com stdlib?
  - Dá para reutilizar o mesmo webhook para Slack/Discord sem reformatar?
- **Produtor (Luiza)** — quer saber impacto em cronograma. Perguntas:
  - A notificação dispara apenas em FAIL para evitar ruído?
  - Há link direto para o artefato `gate_<MODULE>.md` para leitura rápida?

## Respostas e informações levantadas
- O gate agora aceita `--notify-webhook` (ou env `RM_NOTIFY_WEBHOOK`) e envia JSON com `status`, contagem de falhas/avisos e uma prévia de até 5 findings. Nenhuma dependência extra além da stdlib.
- Segredos não são logados: o URL é lido de env e o envio é best-effort, reportando erro apenas como WARN no stderr.
- O payload é genérico (JSON simples) para permitir encapsular no formato exigido por Slack/Discord via gateway; se o canal exigir formato específico, o webhook intermediário deve fazer a adaptação.
- Notificação padrão só ocorre em **FAIL**; `--notify-on-pass` opt-in cobre casos em que o time quer telemetria de verde contínuo.
- O caminho `--md-out` é incluído no payload como `details_md`, permitindo apontar para o artefato `gate_<MODULE>.md` gerado no workflow.

## Conclusão
- A solução atende o escopo do AJ (avisar somente em FAIL, sem bloquear builds locais) e preserva segurança dos segredos.
- Ponto aberto para follow-up: adicionar templates específicos por canal (Slack block kit / Discord embed) e opção de retries com backoff quando o webhook estiver indisponível.
