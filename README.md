# Canvas Sync

Sincroniza atividades e prazos do Canvas LMS com o Google Calendar.

## O que o projeto faz

1. Consulta o Planner do Canvas pela API oficial.
2. Busca o nome das disciplinas e os links das atividades.
3. Gera um arquivo `.ics` local.
4. Cria ou atualiza tarefas e quizzes no Google Calendar.
5. Usa um identificador estável para evitar eventos duplicados.
6. Registra cada execução em `sync.log`.

O projeto não acessa o Canvas por automação de navegador. Ele usa a API oficial e não envia mensagens para o WhatsApp.

## Aviso de uso

Este é um projeto independente e não é afiliado, patrocinado ou endossado
pela PUC-Campinas, pela Instructure/Canvas ou pelo Google.

O projeto usa as APIs oficiais do Canvas e do Google Calendar. Cada usuário é
responsável por configurar suas próprias credenciais, autorizar o acesso e
cumprir as políticas da instituição, do Canvas, do Google e as leis aplicáveis.

Os dados acadêmicos obtidos são privados e devem ser usados somente para a
finalidade autorizada pelo próprio usuário. Não inclua tokens, credenciais,
dados de disciplinas, logs ou arquivos gerados no repositório.

Não use o projeto para contornar autenticação, acessar dados de terceiros,
sobrecarregar as APIs ou remover avisos e marcas proprietárias. Consulte a
[política da API do Canvas](https://www.instructure.com/policies/canvas-api-policy)
antes de distribuir ou modificar o uso do projeto.

Use por sua própria conta e risco. Este aviso não constitui aconselhamento
jurídico.

## Requisitos

- Windows;
- PowerShell 5.1 ou superior;
- GCC disponível no `PATH` (ou MSYS2 UCRT64);
- Uma conta do Canvas com acesso à API;
- Um projeto no Google Cloud com a Google Calendar API ativada;
- Credenciais OAuth para aplicativo desktop.

## Configuração do Canvas

Crie um token pessoal no Canvas e configure-o no PowerShell. Nunca coloque o
token em arquivos do projeto:

```powershell
$env:CANVAS_TOKEN = 'SEU_TOKEN_DO_CANVAS'
```

Para deixar a variável disponível ao Agendador de Tarefas:

```powershell
[Environment]::SetEnvironmentVariable('CANVAS_TOKEN', 'SEU_TOKEN_DO_CANVAS', 'User')
```

Feche e abra o PowerShell depois desse comando. O token deve ser revogado e
gerado novamente se for exposto.

## Configuração do Google Calendar

1. Abra o [Google Cloud Console](https://console.cloud.google.com/).
2. Crie ou selecione um projeto.
3. Ative a **Google Calendar API**.
4. Configure a tela de consentimento OAuth como **Externo**.
5. Adicione sua conta Google como usuário de teste.
6. Crie um cliente OAuth do tipo **Aplicativo para computador**.
7. Baixe o JSON e renomeie-o para `client_secret.json`.
8. Coloque o arquivo na raiz deste projeto.

O arquivo `client_secret.json` está no `.gitignore`. Nunca publique esse arquivo
nem `google-token.json`.

## Executar manualmente

Pelo PowerShell:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\run-sync.ps1
```

Ou dê duplo clique em:

```text
run-sync.bat
```

Na primeira execução, o navegador abrirá para autorizar o Google Calendar.
Depois, o token de atualização será salvo localmente em `google-token.json`.

## Automatizar no Windows

Registre uma tarefa diária com o Agendador de Tarefas, usando o caminho
completo de `run-sync.ps1`. O computador precisa estar ligado ou a tarefa deve
estar configurada para executar assim que voltar a ficar disponível.

O log ficará em:

```text
sync.log
```

## Arquivos gerados e privados

Estes arquivos são ignorados pelo Git e não devem ser publicados:

- `client_secret.json`;
- `google-token.json`;
- `canvas-items.tsv`;
- `canvas-events.ics`;
- `calendar.exe`;
- `sync.log`.

## Licença

Este projeto é fornecido para fins educacionais e uso pessoal.
