import re
import json
import datetime
import paho.mqtt.client as mqtt
from pymongo import MongoClient
import mariadb  # ✅ Alterado para mariadb

# Conectar ao MongoDB
client = MongoClient("mongodb://localhost:27017/")
db = client["labirinto"]
collection_mov = db["movimentos"]
collection_som = db["nivel_som"]
player_number = 20

# Conectar ao MariaDB (base de dados em nuvem)
try:
    mysql_conn = mariadb.connect(
        host="194.210.86.10",
        user="aluno",
        password="aluno",
        database="maze"
    )
    mysql_cursor = mysql_conn.cursor()
except mariadb.Error as e:
    print(f"❌ Erro ao conectar ao MariaDB: {e}")
    exit(1)

# Corrigir JSON (adiciona aspas às chaves e converte aspas simples em duplas)
def corrigir_json(mensagem):
    mensagem = re.sub(r'(\{|,)\s*([A-Za-z_][A-Za-z0-9_]*)\s*:', r'\1 "\2":', mensagem)
    mensagem = mensagem.replace("'", '"')
    return mensagem

# Verificar se duas salas estão conectadas (corridor) CORREDOR SO NUMA DIRECAO??
def salas_conectadas(origem, destino):
    query = """
        SELECT 1 FROM corridor 
        WHERE rooma = ? AND roomb = ?
    """
    mysql_cursor.execute(query, (origem, destino))
    return mysql_cursor.fetchone() is not None

# Callback de conexão ao broker
def on_connect(client, userdata, flags, rc):
    if rc == 0:
        print("✅ Conectado ao broker.")
        client.subscribe(f"pisid_mazemov_{player_number}",qos=1)
        client.subscribe(f"pisid_mazesound_{player_number}",qos=1)
        print(f"📡 Subscrito aos tópicos pisid_mazemov_{player_number} e pisid_mazesound_{player_number}")
    else:
        print(f"❌ Falha ao conectar, código de retorno: {rc}")

# Callback de recebimento de mensagens
def on_message(client, userdata, msg):
    try:
        mensagem_original = msg.payload.decode("utf-8")
        print(f"\n📩 Mensagem recebida do tópico {msg.topic}: {mensagem_original}")

        mensagem_corrigida = corrigir_json(mensagem_original)
        dados = json.loads(mensagem_corrigida)

        # Verificação de tipos esperados
        for k, v in dados.items():
            if k in ["SalaOrigem", "SalaDestino", "Room", "Sound"]:
                if isinstance(v, str) and v.isdigit():
                    dados[k] = int(v)
                elif not isinstance(v, (int, float)):
                    print(f"⚠️ Valor inválido para '{k}': {v}")
                    return

        # Se for mensagem de som
        if "mazesound" in msg.topic:
            valor_som = dados.get("Sound", None)
            hora = dados.get("Hour", None)

            if valor_som in [None, "", 0] or valor_som < 0 or valor_som > 23:
                print(f"❌ Erro de sensor: valor de som inválido ({valor_som})")
                return

            dados["enviado"] = False
            collection_som.insert_one(dados)
            print("✅ Nível de som armazenado no MongoDB.")

        # Se for mensagem de movimento
        elif "mazemov" in msg.topic:
            origem = dados.get("SalaOrigem", 0)
            destino = dados.get("SalaDestino", 0)

            if not isinstance(origem, int) or not isinstance(destino, int):
                print("❌ Valores inválidos para SalaOrigem ou SalaDestino.")
                return

            if origem == 0 or destino == 0 or salas_conectadas(origem, destino):
                dados["enviado"] = False
                collection_mov.insert_one(dados)
                print("✅ Movimento armazenado no MongoDB.")
            else:
                print("⚠️ Movimento inválido descartado: salas não conectadas.")

    except json.JSONDecodeError as e:
        print(f"❌ Erro de JSON: {e}\nMensagem corrigida: {mensagem_corrigida}")
    except Exception as e:
        print(f"⚠️ Erro ao processar a mensagem: {e}")

# Configurar e conectar ao MQTT
client_mqtt = mqtt.Client()
client_mqtt.enable_logger()
client_mqtt.on_connect = on_connect
client_mqtt.on_message = on_message

broker = "broker.emqx.io"
client_mqtt.connect(broker, 1883, 60)

# Iniciar loop principal
print("🕐 Aguardando mensagens (CTRL+C para sair)...")
try:
    client_mqtt.loop_forever()
except KeyboardInterrupt:
    print("🚪 Encerrando...")
    client_mqtt.disconnect()
    mysql_cursor.close()
    mysql_conn.close()
