import mariadb
import paho.mqtt.client as mqtt
import time
from datetime import datetime  # ✅ Novo import

# Configurações do banco
db_config = {
    "host": "localhost",
    "user": "root",
    "password": "",
    "database": "labirinto"
}

# Conecta ao MQTT
mqtt_client = mqtt.Client()
mqtt_client.connect("broker.emqx.io", 1883)

while True:
    try:
        conn = mariadb.connect(**db_config)
        cursor = conn.cursor(dictionary=True)

        cursor.execute("""
            SELECT ID, Msg, Sala, IDJogo
            FROM mensagens
            WHERE atuadorAcionado = 0 AND Msg IN ('fechar portas', 'ativar gatilho', 'abrir portas')
        """)
        mensagens = cursor.fetchall()

        for msg in mensagens:
            id_msg = msg["ID"]
            tipo_msg = msg["Msg"]
            sala = msg["Sala"] if msg["Sala"] is not None else 0
            jogo = msg["IDJogo"] if msg["IDJogo"] is not None else 0

            # Define o payload com base no tipo de mensagem
            if tipo_msg == "fechar portas":
                payload = "{Type: CloseAllDoor, Player: 20}"
            elif tipo_msg == "abrir portas":
                payload = "{Type: OpenAllDoor, Player: 20}"
            elif tipo_msg == "ativar gatilho":
                payload = "{Type: Score, Player: 20, Room: " + str(sala) + "}"
            else:
                continue

            mqtt_client.publish("pisid_mazeact", payload)
            print(f"📤 [{datetime.now().strftime('%Y-%m-%d %H:%M:%S')}] MQTT enviado: {payload}")

            # Marca como atuador acionado
            cursor.execute("UPDATE mensagens SET atuadorAcionado = 1 WHERE ID = ?", (id_msg,))

            # Aumenta tentativas e pontuação apenas para 'ativar gatilho'
            if tipo_msg == "ativar gatilho" and sala != 0 and jogo != 0:
                cursor.execute("""
                    UPDATE ocupacaolabirinto
                    SET tentativas = tentativas + 1
                    WHERE Sala = ? AND IDJogo = ?
                """, (sala, jogo))

                cursor.execute("""
                    UPDATE jogo
                    SET Pontuacao = Pontuacao + 1
                    WHERE IDJogo = ?
                """, (jogo,))

            conn.commit()

        cursor.close()
        conn.close()

    except Exception as e:
        print(f"❌ Erro: {e}")

    time.sleep(0.1)
