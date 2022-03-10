import ipaddress
import requests
import logging

logging.getLogger().setLevel(logging.INFO)
logger = logging.getLogger(__name__)


__telegram_cidr_endpoint = "https://core.telegram.org/resources/cidr.txt"


def __define_telegram_network():
    response = requests.get(__telegram_cidr_endpoint)
    for line in response.text.splitlines():
        yield ipaddress.ip_network(line.strip())


__telegram_networks = set(__define_telegram_network())
logger.info(f"Telegram network: {__telegram_networks}")


def from_telegram_network(address):
    for network in __telegram_networks:
        if ipaddress.ip_address(address) in network:
            return True

    return False
