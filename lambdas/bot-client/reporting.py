import json
import os

import boto3


def __get_sqs_client():
    return boto3.client("sqs")


__client = __get_sqs_client()
__url = os.environ['sqs_url']


def send_report(data):
    return __client.send_message(QueueUrl=__url, MessageBody=json.dumps(data))
