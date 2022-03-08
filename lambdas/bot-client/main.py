import os
import logging
import json

from datetime import datetime
from enum import Enum

from telebot.types import Update, ReplyKeyboardMarkup, KeyboardButton

from state import ConversationState, get_state, update_state, set_state, delete_state
from bot import init_bot
from reporting import send_report

logging.getLogger().setLevel(logging.INFO)
logger = logging.getLogger(__name__)


class IncidentCategory(Enum):
    AERIAL = "Aerial attack"
    GROUND = "Ground attack"


class LocationDetails(Enum):
    NEXT_TO_ME = "Right next to me"
    WALKING_DISTANCE = "5-10 minutes of walk from me"
    NOT_CLOSE = "Visible, but not close"
    NOT_SURE = "I am not sure"


bot = init_bot()


def start(message):
    markup = ReplyKeyboardMarkup(row_width=1, resize_keyboard=True)
    markup.add(KeyboardButton('Report incident location', request_location=True))
    bot.send_message(message.chat.id, "Report an incident by clicking the button bellow", reply_markup=markup)
    delete_state(message.from_user.id)


def location(message):
    markup = ReplyKeyboardMarkup(row_width=1, resize_keyboard=True)
    for incident_category in IncidentCategory:
        markup.add(KeyboardButton(incident_category.value))

    bot.send_message(message.chat.id, "What do you want to report?", reply_markup=markup)
    state = {"user": {"language_code": message.from_user.language_code, "id": message.from_user.id},
             "incident": {
                 "location": {
                     "lat": message.location.latitude, "long": message.location.longitude},
                 "timestamp": datetime.now().replace(microsecond=0).isoformat()}}
    set_state(message.from_user.id, ConversationState.CATEGORY, state)


def category(message, state):
    selected_category = IncidentCategory(message.text)
    state["incident"]["category"] = selected_category.value

    markup = ReplyKeyboardMarkup(row_width=1, resize_keyboard=True)
    for location_details in LocationDetails:
        markup.add(KeyboardButton(location_details.value))

    bot.send_message(message.chat.id, f"How close did the {selected_category.value.lower()} happen to you?",
                     reply_markup=markup)
    update_state(message.from_user.id, ConversationState.LOCATION_DETAILS, state)


def process_location_details(message, state):
    state["incident"]["location_details"] = LocationDetails(message.text).value
    bot.send_message(message.chat.id, f"Your report has been recorded and processed by the authorities.")
    bot.send_message(message.chat.id,
                     f"Advice for being close to {state['incident']['category'].lower()}, what to do, how to get to "
                     f"safety asap, what we recommend doing, etc.")
    bot.send_message(message.chat.id, f"Debug: {state}")
    start(message)

    response = send_report(state)
    logger.info(f"SQS Response: {response}")


def lambda_handler(event: dict, context):
    request = event["body"]
    if isinstance(request, str):
        request = json.loads(request)

    if request.get("setWebhook", False):
        bot.remove_webhook()
        webhook = f"{os.environ['domain']}/{os.environ['path_key']}/"
        logger.info(f"Set webhook to {webhook}")
        bot.set_webhook(url=webhook)
        return {'statusCode': 200, 'body': json.dumps(f'Webhook set to {webhook}')}
    elif request.get("sendDirectMessage", False):
        to_user = request["telegramUID"]
        bot.send_message(to_user, request["telegramUID"])
        return {'statusCode': 200}

    update = Update.de_json(request)
    if not update.message:
        return {'statusCode': 200}

    if update.message.text == '/start':
        start(update.message)
        return {'statusCode': 200}

    conv_state, state = get_state(update.message.from_user.id)
    if update.message.location:
        location(update.message)
    elif update.message.text in [inc.value for inc in IncidentCategory] and conv_state == ConversationState.CATEGORY:
        category(update.message, state)
    elif update.message.text in [loc.value for loc in
                                 LocationDetails] and conv_state == ConversationState.LOCATION_DETAILS:
        process_location_details(update.message, state)

    return {'statusCode': 200}
