import os
import boto3

from telebot import TeleBot


def __get_bot_token():
    session = boto3.session.Session()
    client = session.client(service_name='secretsmanager')
    response = client.get_secret_value(SecretId=os.environ['token_parameter'])
    return response['SecretString']


__token = __get_bot_token()


def init_bot():
    return TeleBot(__token)
