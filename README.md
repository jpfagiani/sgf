# SGF — Sistema de Gestão de Frota

Sistema de controle de frota do Centro de Detenção Provisória de Nova Independência/SP:
viagens (FCT), fila de vez de motoristas, abastecimentos, manutenções, troca de óleo,
checagem de viaturas, mapa força e relatórios.

Aplicação de página única (`index.html`) servida por um servidor Python **sem
dependências externas** (somente biblioteca padrão). O banco de dados é um único
arquivo JSON (`sgf_dados.json`).

## Requisitos

- Debian 13 (trixie) — funciona em qualquer distro com Python 3
- Porta 80 livre (ou informe outra porta na instalação)

## Instalação

```bash
git clone https://github.com/jpfagiani/sgf.git
cd sgf
sudo ./instalar.sh          # porta 80
# ou: sudo ./instalar.sh 8080
```

O instalador:

1. instala o `python3` se faltar;
2. copia a aplicação para `/opt/sgf`;
3. cria o usuário de serviço `sgf` (sem shell);
4. instala e ativa o serviço systemd `sgf` (sobe no boot, reinicia se cair);
5. agenda backup diário do banco às 20h00 (`/opt/sgf/backups`, retém 30).

Acesse `http://IP-DO-SERVIDOR` na rede local. No primeiro acesso, se não houver
banco, um padrão é criado com o usuário **master** / senha **123456** — troque a
senha e cadastre os usuários reais em *Gerenciar Usuários*.

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
