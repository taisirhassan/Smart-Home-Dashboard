import time
import json
import os
import ssl
from dotenv import load_dotenv
import paho.mqtt.client as mqtt
import random

load_dotenv()

# MQTT Broker settings
broker = os.getenv('AWS_IOT_ENDPOINT')  # Your AWS IoT Core endpoint
port = 8883  # Default MQTT over TLS/SSL port
topic = "home/sensors/temperature"  # Topic to publish to
client_id = f'python-mqtt-{random.randint(0, 1000)}' # Create a random client ID

# Paths to your certificates and private key from environment variables
ca_path = os.getenv('AWS_IOT_CA_PATH') # Replace with your CA certificate
cert_path = os.getenv('AWS_IOT_CERT_PATH') # Replace with your device certificate
key_path = os.getenv('AWS_IOT_PRIVATE_KEY_PATH') # Replace with your device private key


# Callback function for when a message is received
def on_message(client, userdata, message):
    print(f"Received message '{message.payload.decode()}' on topic '{message.topic}'")

# Callback function for when the client is connected
def on_connect(client, userdata, flags, rc):
    if rc == 0:
        print("Connected to MQTT Broker!")
        client.subscribe(topic)  # Subscribe to the topic after connecting
    else:
        print("Failed to connect, return code %d\n", rc)

# Connect to the MQTT broker
def connect_mqtt():
    client = mqtt.Client(client_id)
    client.tls_set(
        ca_certs=os.getenv("AWS_IOT_CA_PATH"),
        certfile=os.getenv("AWS_IOT_CERT_PATH"),
        keyfile=os.getenv("AWS_IOT_PRIVATE_KEY_PATH"),
        tls_version=ssl.PROTOCOL_TLSv1_2
    )
    client.on_connect = on_connect
    client.on_message = on_message  # Set the callback function for when a message is received
    client.connect(broker, port)
    return client

def publish(client):
    while True:
        # Simulate temperature
        temperature = random.randint(20, 30)
        temp_message = json.dumps({"temperature": temperature, "unit": "Celsius"})
        client.publish("home/sensors/temperature", temp_message)
        
        # Simulate humidity
        humidity = random.randint(30, 60)
        humidity_message = json.dumps({"humidity": humidity, "unit": "%"})
        client.publish("home/sensors/humidity", humidity_message)
        
        # Simulate light
        light = random.choice(['On', 'Off'])
        light_message = json.dumps({"light": light})
        client.publish("home/sensors/light", light_message)

        print(f"Published temperature: {temp_message}, humidity: {humidity_message}, light: {light_message}")
        
        time.sleep(5)  # Adjust sleep time as needed

def run():
    client = connect_mqtt()
    client.loop_start()
    publish(client)

if __name__ == '__main__':
    run()