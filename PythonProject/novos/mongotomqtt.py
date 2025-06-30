import json
import time
import paho.mqtt.client as mqtt
from pymongo import MongoClient

# Conectar ao MongoDB
client = MongoClient("mongodb://localhost:27017/")
db = client["labirinto"]
collection_mov = db["movimentos"]
collection_som = db["nivel_som"]

# Conectar ao broker MQTT
broker = "broker.emqx.io"
mqtt_client = mqtt.Client()
mqtt_client.connect(broker, 1883, 60)
mqtt_client.loop_start()  # ✅ NECESSÁRIO para manter conexão ativa

# Número do jogador (usar o mesmo que nos outros scripts)
player_number = 20

# Loop contínuo para enviar dados não processados
while True:
    try:
        # Buscar movimentos não enviados
        movimentos = collection_mov.find({"enviado": False})
        for mov in movimentos:
            try:
                dados_str = json.dumps({k: v for k, v in mov.items() if k != "_id"})
                topico = f"mazemov_to_mysql_{player_number}"
                info = mqtt_client.publish(topico, dados_str, qos=1)
                info.wait_for_publish()
                print(f"📤 Movimento enviado para {topico}: {dados_str}")

                collection_mov.update_one({"_id": mov["_id"]}, {"$set": {"enviado": True}})
            except Exception as e:
                print(f"❌ Erro ao enviar movimento: {e}")

        # Buscar sons não enviados
        sons = collection_som.find({"enviado": False})
        for som in sons:
            try:
                dados_str = json.dumps({k: v for k, v in som.items() if k != "_id"})
                topico = f"mazesound_to_mysql_{player_number}"
                info = mqtt_client.publish(topico, dados_str, qos=1)
                info.wait_for_publish()
                print(f"📤 Som enviado para {topico}: {dados_str}")

                collection_som.update_one({"_id": som["_id"]}, {"$set": {"enviado": True}})
            except Exception as e:
                print(f"❌ Erro ao enviar som: {e}")

    except Exception as e:
        print(f"⚠️ Erro no loop principal: {e}")

    time.sleep(1)
