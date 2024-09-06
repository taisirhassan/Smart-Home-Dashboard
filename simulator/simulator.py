import time
import json
import random
import os
import logging
from concurrent.futures import ThreadPoolExecutor
from awscrt import mqtt, io
from awsiot import mqtt_connection_builder
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Set up logging
logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)

class IoTDevice:
    def __init__(self, device_id, device_type, mqtt_connection):
        self.device_id = device_id
        self.device_type = device_type
        self.mqtt_connection = mqtt_connection

    def generate_telemetry(self):
        if self.device_type == "thermostat":
            return {
                "temperature": round(random.uniform(18.0, 26.0), 1),
                "humidity": round(random.uniform(30.0, 60.0), 1),
                "set_point": round(random.uniform(20.0, 24.0), 1)
            }
        elif self.device_type == "light":
            return {
                "status": random.choice(["ON", "OFF"]),
                "brightness": random.randint(0, 100)
            }
        elif self.device_type == "security_camera":
            return {
                "status": random.choice(["ACTIVE", "STANDBY"]),
                "motion_detected": random.choice([True, False])
            }

    def publish_telemetry(self):
        while True:
            telemetry = self.generate_telemetry()
            message = {
                "device_id": self.device_id,
                "device_type": self.device_type,
                "timestamp": int(time.time()),
                "data": telemetry
            }
            topic = f"devices/{self.device_type}/{self.device_id}/telemetry"
            self.mqtt_connection.publish(
                topic=topic,
                payload=json.dumps(message),
                qos=mqtt.QoS.AT_LEAST_ONCE
            )
            print(f"Published: {message}")
            time.sleep(random.uniform(5, 15))  # Simulate random intervals

def create_and_run_device(device_config, mqtt_connection):
    device = IoTDevice(**device_config, mqtt_connection=mqtt_connection)
    device.publish_telemetry()

if __name__ == "__main__":
    # AWS IoT Core configuration
    endpoint = os.environ.get('IOT_ENDPOINT')
    cert_filepath = os.environ.get('CERTIFICATE_PATH')
    pri_key_filepath = os.environ.get('PRIVATE_KEY_PATH')
    ca_filepath = os.environ.get('ROOT_CA_PATH')

    if not all([endpoint, cert_filepath, pri_key_filepath, ca_filepath]):
        raise ValueError("Missing required environment variables. Please set IOT_ENDPOINT, CERTIFICATE_PATH, PRIVATE_KEY_PATH, and ROOT_CA_PATH.")

    logger.info(f"Endpoint: {endpoint}")
    logger.info(f"Certificate Path: {cert_filepath}")
    logger.info(f"Private Key Path: {pri_key_filepath}")
    logger.info(f"CA Path: {ca_filepath}")

    # Create a default event loop group
    event_loop_group = io.EventLoopGroup(1)
    host_resolver = io.DefaultHostResolver(event_loop_group)
    client_bootstrap = io.ClientBootstrap(event_loop_group, host_resolver)

    # Create a single MQTT connection
    mqtt_connection = mqtt_connection_builder.mtls_from_path(
        endpoint=endpoint,
        cert_filepath=cert_filepath,
        pri_key_filepath=pri_key_filepath,
        ca_filepath=ca_filepath,
        client_bootstrap=client_bootstrap,
        client_id="iot_simulator",
        clean_session=False,
        keep_alive_secs=30,
        on_connection_interrupted=lambda connection, error, **kwargs: logger.error(f"Connection interrupted. error: {error}"),
        on_connection_resumed=lambda connection, return_code, session_present, **kwargs: logger.info("Connection resumed. return_code: {} session_present: {}".format(return_code, session_present)),
    )

    logger.info(f"Connecting to {endpoint}...")
    connect_future = mqtt_connection.connect()
    
    try:
        connect_result = connect_future.result(timeout=10)  # Wait for 10 seconds
        logger.info(f"Connected with result: {connect_result}")
    except Exception as e:
        logger.error(f"Connection failed: {str(e)}")
        raise

    logger.info("Connected!")

    # Device configurations
    devices = [
        {"device_id": "thermostat1", "device_type": "thermostat"},
        {"device_id": "light1", "device_type": "light"},
        {"device_id": "camera1", "device_type": "security_camera"}
    ]

    # Run devices in parallel
    with ThreadPoolExecutor(max_workers=len(devices)) as executor:
        executor.map(lambda config: create_and_run_device(config, mqtt_connection), devices)