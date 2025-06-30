import json
import time
import mariadb
import paho.mqtt.client as mqtt

# Variáveis globais
mydb = None
cursor = None
ID_JOGO_ATUAL = None

# Função para conectar ao MySQL com retry automático
def conectar_mysql():
    global mydb, cursor, ID_JOGO_ATUAL
    while True:
        try:
            mydb = mariadb.connect(
                host="localhost",
                user="root",
                password="",
                database="labirinto"
            )
            cursor = mydb.cursor()
            print("✅ Conectado ao MySQL.")

            # Obter o último IDJogo
            cursor.execute("SELECT MAX(IDJogo) FROM jogo")
            resultado = cursor.fetchone()
            ID_JOGO_ATUAL = resultado[0]
            if ID_JOGO_ATUAL is None:
                print("❌ Nenhum jogo encontrado na base de dados.")
                exit(1)
            else:
                print(f"🆕 Jogo ativo com ID: {ID_JOGO_ATUAL}")
            break
        except mariadb.Error as e:
            print(f"⏳ Erro ao conectar ao MySQL: {e}")
            print("🔁 Tentando reconectar em 5 segundos...")
            time.sleep(5)

# Inserir som com tentativa de reconexão
def inserir_som_no_mysql(dados, id_jogo):
    while True:
        try:
            query = "INSERT INTO sound (Hora, Sound, IDJogo) VALUES (?, ?, ?)"
            valores = (dados["Hour"], dados["Sound"], id_jogo)
            cursor.execute(query, valores)
            mydb.commit()
            print(f"📥 Som inserido: {valores}")
            time.sleep(0.5)
            break
        except mariadb.Error as e:
            print(f"❌ Erro ao inserir som: {e}")
            conectar_mysql()

# Inserir movimento com tentativa de reconexão
def inserir_movimento_no_mysql(dados, id_jogo):
    while True:
        try:
            query = """
                INSERT INTO medicoespassagens (
                    Hora, SalaOrigem, SalaDestino, Marsami, Status, IDJogo
                ) VALUES (NOW(), ?, ?, ?, ?, ?)
            """
            valores = (
                dados["RoomOrigin"],
                dados["RoomDestiny"],
                dados["Marsami"],
                dados["Status"],
                id_jogo
            )
            cursor.execute(query, valores)
            mydb.commit()
            print(f"📥 Movimento inserido: {valores}")
            time.sleep(1)
            break
        except mariadb.Error as e:
            print(f"❌ Erro ao inserir movimento: {e}")
            conectar_mysql()

# Callback MQTT
def on_message(client, userdata, msg):
    try:
        mensagem = msg.payload.decode("utf-8")
        dados = json.loads(mensagem)

        if "mazemov" in msg.topic:
            inserir_movimento_no_mysql(dados, ID_JOGO_ATUAL)
        elif "mazesound" in msg.topic:
            inserir_som_no_mysql(dados, ID_JOGO_ATUAL)

    except Exception as e:
        print(f"❌ Erro ao processar a mensagem: {e}")

# Conectar ao MySQL
conectar_mysql()

# Configurar MQTT
topicnumber = 20
broker = "broker.emqx.io"
client_mqtt = mqtt.Client()
client_mqtt.on_message = on_message
client_mqtt.connect(broker, 1883, 60)

client_mqtt.subscribe(f"mazemov_to_mysql_{topicnumber}", qos=2)
print(f"📡 Subscrito a: mazemov_to_mysql_{topicnumber}")

client_mqtt.subscribe(f"mazesound_to_mysql_{topicnumber}", qos=2)
print(f"📡 Subscrito a: mazesound_to_mysql_{topicnumber}")

print("🕐 Aguardando mensagens...")
client_mqtt.loop_forever()
