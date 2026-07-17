import os
import json
import shutil
import socket
import tempfile
import threading
from http.server import HTTPServer, BaseHTTPRequestHandler

PORT = 5000
DB_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'sgf_dados.json')
db_lock = threading.Lock()

def get_local_ip():
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        s.connect(('10.255.255.255', 1))
        IP = s.getsockname()[0]
    except Exception:
        IP = '127.0.0.1'
    finally:
        s.close()
    return IP

def obter_dados_padrao():
    return {
        "motoristas": [
            { "nome": "Cláudio Mendonça", "rg": "12.345.678-9", "categoria": "D", "telefone": "(11) 99999-1111", "ativo": True, "viajaSP": True, "viajaInterior": True },
            { "nome": "Juliana Peixoto", "rg": "98.765.432-1", "categoria": "B", "telefone": "(11) 99999-2222", "ativo": True, "viajaSP": True, "viajaInterior": False },
            { "nome": "Carlos Silva", "rg": "45.123.890-X", "categoria": "E", "telefone": "(11) 99999-3333", "ativo": True, "viajaSP": False, "viajaInterior": True }
        ],
        "viaturas": [
            { "veiculo": "Caminhonete", "modelo": "Chevrolet S10", "placa": "ABC-1234" },
            { "veiculo": "Sedan", "modelo": "Toyota Corolla", "placa": "SGF-2026" }
        ],
        "servicos": [
            { "nome": "Entrega / Logística" },
            { "nome": "Manutenção de Campo" },
            { "nome": "Reunião / Visita Comercial" },
            { "nome": "Administrativo" }
        ],
        "viagensFCT": [],
        "historicoVez": [],
        "pulos": [],
        "servidores": [],
        "trocasOleo": [],
        "abastecimentos": [],
        "manutencoes": [],
        "checksViatura": [],
        "usuarios": [{ "login": "master", "nome": "Administrador Master", "senha": "MTIzNDU2", "nivel": "Master" }],
        "pos_sp": 0,
        "pos_interior": 0,
        "mapaForca": []
    }

class SGFRequestHandler(BaseHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        super().end_headers()

    def do_OPTIONS(self):
        self.send_response(200, "OK")
        self.end_headers()

    def do_GET(self):
        path = self.path.split('?')[0]
        
        if path == '/api/dados':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json; charset=utf-8')
            self.end_headers()
            
            with db_lock:
                if os.path.exists(DB_FILE):
                    try:
                        with open(DB_FILE, 'r', encoding='utf-8') as f:
                            data = f.read()
                            # Validar se o JSON está integro, caso contrário reconstrói do padrão
                            json.loads(data)
                            self.wfile.write(data.encode('utf-8'))
                            return
                    except Exception as e:
                        print(f"Erro ao ler banco de dados JSON: {e}. Restaurando dados padrão.")
                
                # Se não existir ou estiver corrompido, gera o padrão
                default_data = obter_dados_padrao()
                with open(DB_FILE, 'w', encoding='utf-8') as f:
                    json.dump(default_data, f, indent=2, ensure_ascii=False)
                self.wfile.write(json.dumps(default_data).encode('utf-8'))
            return

        # Servir arquivos estáticos
        if path in ('/', '/index.html'):
            filename = 'index.html'
            content_type = 'text/html; charset=utf-8'
        elif path == '/logo.png':
            filename = 'logo.png'
            content_type = 'image/png'
        elif path == '/logo_pp.png':
            filename = 'logo_pp.png'
            content_type = 'image/png'
        else:
            # Limpar caminhos para evitar path traversal
            safe_path = os.path.basename(path)
            # Nunca servir o banco de dados, código-fonte ou logs como arquivo estático
            if safe_path.endswith(('.json', '.db', '.key', '.log', '.py', '.bak')):
                self.send_error(403, "Acesso negado")
                return
            if safe_path and os.path.exists(os.path.join(os.path.dirname(__file__), safe_path)):
                filename = safe_path
                if safe_path.endswith('.html'):
                    content_type = 'text/html; charset=utf-8'
                elif safe_path.endswith('.png'):
                    content_type = 'image/png'
                else:
                    content_type = 'application/octet-stream'
            else:
                self.send_error(404, "Arquivo não encontrado")
                return

        file_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), filename)
        if os.path.exists(file_path):
            self.send_response(200)
            self.send_header('Content-Type', content_type)
            self.end_headers()
            with open(file_path, 'rb') as f:
                self.wfile.write(f.read())
        else:
            self.send_error(404, "Arquivo não encontrado")

    def do_POST(self):
        if self.path == '/api/dados':
            content_length = int(self.headers.get('Content-Length', 0))
            post_data = self.rfile.read(content_length)
            
            try:
                # Validar se o payload recebido é um JSON válido antes de salvar
                payload = json.loads(post_data.decode('utf-8'))
                
                with db_lock:
                    # Escrita atômica para evitar corrupção de arquivos
                    dir_name = os.path.dirname(DB_FILE)
                    with tempfile.NamedTemporaryFile('w', dir=dir_name, delete=False, encoding='utf-8') as tf:
                        json.dump(payload, tf, indent=2, ensure_ascii=False)
                        tempname = tf.name
                    
                    # Substitui o arquivo original de forma atômica
                    shutil.move(tempname, DB_FILE)

                self.send_response(200)
                self.send_header('Content-Type', 'application/json; charset=utf-8')
                self.end_headers()
                self.wfile.write(json.dumps({"status": "ok"}).encode('utf-8'))
                return
            except Exception as e:
                print(f"Erro ao salvar dados recebidos: {e}")
                self.send_error(400, "Dados JSON inválidos ou erro de gravação")
                return
        else:
            self.send_error(404, "Rota não encontrada")

def run():
    server_address = ('0.0.0.0', PORT)
    httpd = HTTPServer(server_address, SGFRequestHandler)
    local_ip = get_local_ip()
    
    print("=" * 70)
    print(" SGF - Sistema de Gestão de Frota está ATIVO na rede local!")
    print("-" * 70)
    print(f" Para acessar de outros computadores da mesma rede, digite:")
    print(f" http://{local_ip}:{PORT}/")
    print("-" * 70)
    print(f" Para acessar nesta máquina servidora local, digite:")
    print(f" http://localhost:{PORT}/")
    print("=" * 70)
    
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nServidor finalizado pelo usuário.")
        httpd.server_close()

if __name__ == '__main__':
    run()
