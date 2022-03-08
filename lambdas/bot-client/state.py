import os

import boto3
import json

from enum import Enum


def __initialize_table():
    db = boto3.resource('dynamodb')
    return db.Table(os.environ['incident_state_table_name'])


__incident_intermediate_state = __initialize_table()


class ConversationState(Enum):
    START = 0
    LOCATION = 1
    CATEGORY = 2
    LOCATION_DETAILS = 3


def get_state(user_id):
    response = __incident_intermediate_state.get_item(Key={'UserID': user_id})
    item = response.get('Item', {})
    return ConversationState(item.get('ConvState', ConversationState.START.value)), json.loads(
        item.get('UserData', '{}'))


def set_state(user_id, state: ConversationState, data):
    __incident_intermediate_state.put_item(Item={
        'UserID': user_id,
        'ConvState': state.value,
        'UserData': json.dumps(data)
    })


def update_state(user_id, state: ConversationState, data):
    __incident_intermediate_state.update_item(Key={
        'UserID': user_id
    }, UpdateExpression='SET ConvState = :val1, UserData = :val2', ExpressionAttributeValues={
        ':val1': state.value,
        ':val2': json.dumps(data)
    })


def delete_state(user_id):
    __incident_intermediate_state.delete_item(Key={
        'UserID': user_id
    })
