import os
import boto3

from telebot import TeleBot


def __get_bot_token():
    session = boto3.session.Session()
    client = session.client(service_name='ssm')
    response = client.get_parameter(Name=os.environ['token_parameter'], WithDecryption=True)
    return response['Parameter']['Value']


__token = __get_bot_token()


def init_bot():
    return TeleBot(__token)