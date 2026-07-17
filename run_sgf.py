"""
SGF Frota - lancador do servidor em segundo plano.
Executado pela tarefa agendada 'SGF Frota' via pythonw (sem janela).
Serve o handler do servidor.py na porta recebida (padrao 80).
"""
import os
import sys

# pythonw.exe roda sem console: sys.stdout/sys.stderr sao None. O http.server
# escreve o log de acesso no stderr a cada requisicao (e o servidor.py usa
# print), o que estouraria e fecharia a conexao sem resposta. Redireciona
# para um arquivo de log antes de qualquer coisa.
BASE = os.path.dirname(os.path.abspath(__file__))
os.chdir(BASE)
if sys.stderr is None or sys.stdout is None:
    _log = open(os.path.join(BASE, "sgf_servidor.log"), "a", buffering=1, encoding="utf-8")
    if sys.stdout is None:
        sys.stdout = _log
    if sys.stderr is None:
        sys.stderr = _log

import servidor
from http.server import HTTPServer

port = int(sys.argv[1]) if len(sys.argv) > 1 else 80
httpd = HTTPServer(('0.0.0.0', port), servidor.SGFRequestHandler)
httpd.serve_forever()
