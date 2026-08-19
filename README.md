# SGF — Sistema de Gestão de Frota

Sistema de controle de frota de unidade prisional: viagens (FCT), fila de vez de
motoristas, abastecimentos, manutenções, troca de óleo, checagem de viaturas,
mapa força e relatórios.

O sistema é **genérico para qualquer unidade** — o nome, cidade/UF e coordenadoria
que aparecem na tela e nos impressos são perguntados pelo instalador (ou editados
depois em `/opt/sgf/unidade.conf`), nunca fixados no código.

Aplicação de página única (`index.html`) servida por um servidor Python **sem
dependências externas** (somente biblioteca padrão). O banco de dados é um único
arquivo JSON (`sgf_dados.json`).

## Requisitos

- Debian 13 (trixie) — funciona em qualquer distro com Python 3
- Uma porta livre — o instalador sugere automaticamente (veja abaixo)

## Convivendo com GWOS, Samba e portal de sistemas na mesma máquina

É comum o SGF dividir servidor com outros projetos da unidade. Convenção de
portas, para não colidir:

| Porta | Sistema |
|---|---|
| 80 | portal-sistemas |
| 8080 | painel do GWOS |
| 8443 | portal-samba |
| **8091** | **SGF, quando 80 já está ocupada** |

O instalador cuida disso sozinho: sugere a **porta 80** (acesso só com o IP,
sem digitar porta — mais fácil para quem usa o sistema) quando ela está livre
nesta máquina, ou **8091** quando já há outro sistema nela. Se a porta
escolhida (sugerida ou digitada) estiver ocupada, ele avisa e pergunta outra
na hora — nunca é preciso reinstalar para trocar de porta.

Se a máquina já tem o firewall do Samba (`nftables`, política padrão de
bloqueio), a porta do SGF só é liberada automaticamente quando o Samba
"redetecta" o que existe nesta máquina — o que não acontece sozinho se o SGF
foi instalado **depois** do Samba. Rode uma vez:

```bash
cd /opt/smb && sudo bash scripts/atualizar_firewall.sh
```

Atualiza só o firewall (nftables/fail2ban) — não toca em usuários, RAID,
Samba nem no portal. Se esse script ainda não existir no `/opt/smb` (versão
mais antiga do repo), o caminho mais lento funciona igual:
`cd /opt/smb && sudo bash bootstrap.sh` — só demora mais, porque reprocessa
tudo.

## Instalação

```bash
git clone https://github.com/jpfagiani/sgf.git
cd sgf
sudo ./instalar.sh          # pergunta tudo interativamente
# ou: sudo ./instalar.sh 80   # força uma porta específica de início
```

O instalador pergunta, na ordem:

1. **Rede** — mostra as interfaces com IP desta máquina e a de rota padrão;
   opcionalmente define um **IP fixo** (valida IP/máscara/gateway, faz backup
   de `/etc/network/interfaces` antes de sobrescrever, aplica sem derrubar a
   sessão atual — o IP antigo só some no próximo reboot). Pular essa etapa
   (resposta padrão) mantém a rede como está: o SGF funciona igual em
   qualquer IP, fixar só evita que ele mude sozinho por DHCP.
2. **Identidade da unidade** — nome completo, cidade/UF e coordenadoria
   regional. Gravado em `/opt/sgf/unidade.conf` (fora do git — um `git pull`
   nunca conflita com isso). Numa reinstalação, os valores já gravados
   viram sugestão; basta apertar Enter para manter.
3. **Porta** — sugere 80 ou 8091 conforme o que já está instalado na
   máquina (veja seção acima); se a escolhida estiver ocupada, pergunta de
   novo ali mesmo.

O restante roda sozinho: instala o `python3` se faltar, copia a aplicação
para `/opt/sgf`, cria o usuário de serviço `sgf` (sem shell), instala e ativa
o serviço systemd `sgf` (sobe no boot, reinicia se cair), e agenda backup
diário do banco às 20h00 (`/opt/sgf/backups`, retém 30).

Acesse `http://IP-DO-SERVIDOR` (porta 80) ou `http://IP-DO-SERVIDOR:8091`
(ou a porta escolhida) na rede local — o instalador mostra o link exato ao
final. No primeiro acesso, se não houver banco, um padrão é criado com o
usuário **master** / senha **123456** — troque a senha e cadastre os
usuários reais em *Gerenciar Usuários*.

### Trocar o nome da unidade depois

```bash
sudo nano /opt/sgf/unidade.conf   # UNIDADE_NOME / UNIDADE_CIDADE_UF / UNIDADE_COORDENADORIA
```

Efeito imediato — não precisa reiniciar o serviço, só recarregar a página.

## Migrando os dados de uma instalação existente (ex.: Windows)

O banco inteiro é o arquivo `sgf_dados.json`. Duas opções:

- **Antes de instalar:** copie o `sgf_dados.json` para dentro da pasta clonada e
  rode o `instalar.sh` — ele detecta e migra (nunca sobrescreve um banco existente).
- **Depois de instalar:**

  ```bash
  sudo systemctl stop sgf
  sudo cp sgf_dados.json /opt/sgf/
  sudo chown sgf:sgf /opt/sgf/sgf_dados.json
  sudo systemctl start sgf
  ```

> O `sgf_dados.json` **não é versionado neste repositório** de propósito: contém
> dados pessoais (nomes, RGs, telefones) e senhas de usuários.

## Operação

```bash
systemctl status sgf          # situação do serviço
journalctl -u sgf -f          # logs em tempo real
sudo systemctl restart sgf    # reiniciar
sudo /opt/sgf/backup.sh       # backup manual do banco
```

Restaurar um backup: pare o serviço, copie o arquivo desejado de
`/opt/sgf/backups/` sobre `/opt/sgf/sgf_dados.json`, inicie o serviço.

## Desinstalar

```bash
sudo ./desinstalar.sh    # remove serviço e cron; PRESERVA /opt/sgf (dados)
```

## Segurança — leia antes de expor

Este sistema foi desenhado para **rede local confiável**. A autenticação é feita
no navegador e a API (`/api/dados`) entrega o banco completo a qualquer cliente
que alcance a porta — é assim que o painel funciona. Portanto:

- mantenha-o **somente na LAN** (não faça port-forward para a internet);
- restrinja o alcance por firewall/VLAN se a rede tiver visitantes;
- não há HTTPS — se precisar, coloque um proxy reverso (nginx/caddy) na frente.

O servidor bloqueia o download direto de `.json`, `.db`, `.py`, `.key`, `.log`
e `.bak` como arquivos estáticos.

## Estrutura

| Arquivo | Papel |
|---|---|
| `index.html` | A aplicação inteira (interface + lógica) |
| `servidor.py` | Servidor HTTP + API `/api/dados` (GET lê, POST grava com escrita atômica) |
| `run_sgf.py` | Lançador usado pelo systemd (`run_sgf.py <porta>`) |
| `sgf.service` | Unidade systemd (template — porta preenchida pelo instalador) |
| `instalar.sh` / `desinstalar.sh` | Instalação/remoção no Debian |
| `backup.sh` | Backup com retenção de 30 cópias |
| `unidade.conf` | Nome/cidade/coordenadoria da unidade (gerado pelo instalador em `/opt/sgf`, fora do git) |
