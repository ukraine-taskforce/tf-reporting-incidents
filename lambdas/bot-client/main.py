import os
import logging
import json

from datetime import datetime

from telebot.types import Update, ReplyKeyboardMarkup, KeyboardButton

from state import ConversationState, get_state, update_state, set_state, delete_state
from bot import init_bot
from reporting import send_report
from network import from_telegram_network, is_direct_invocation

logging.getLogger().setLevel(logging.INFO)
logger = logging.getLogger(__name__)

bot = init_bot()

START, INCIDENT, DISTANCE, TIME, END, ERROR = "start", "incident", "distance", "time", "end", "error"
CONV_STATE_TO_CATEGORY = {
    ConversationState.START: START,
    ConversationState.LOCATION: START,
    ConversationState.CATEGORY: INCIDENT,
    ConversationState.LOCATION_DETAILS: DISTANCE,
    ConversationState.TIME: TIME
}


class ConversationHandler:
    def __init__(self, message):
        self.message = message
        self.language_code = message.from_user.language_code
        self.chat_id = message.chat.id
        self.user_id = message.from_user.id
        self.conversation = json.loads(open("conversation.json").read())
        logger.info(self.conversation)

    def __list_messages(self, category, state=None, reply_markup_category=None):
        result = []
        if state is None:
            state = {}

        for message in self.conversation[category]["message"]:
            text = None
            for conditional_text in message.get("conditional_text", []):
                if eval(conditional_text["condition"].format(state=state)):
                    text = conditional_text["text"].get(self.language_code, conditional_text["text"]["en"])
                    break
            if text is None:
                text = message["text"].get(self.language_code, message["text"]["en"])

            result.append((text, {}))

        reply_markup_block = self.conversation[reply_markup_category or category]
        if "reply_markup" not in reply_markup_block:
            return result

        markup = ReplyKeyboardMarkup(row_width=1, resize_keyboard=True)
        for button in reply_markup_block["reply_markup"]:
            if "condition" in button and not eval(button["condition"].format(state=state)):
                continue

            markup.add(KeyboardButton(button["text"].get(self.language_code, button["text"]["en"]),
                                      **button.get("kwargs", {})))

        result.append((result.pop()[0], {"reply_markup": markup}))
        return result

    def __get_button_id(self, category, button_text):
        for button in self.conversation[category].get("reply_markup", []):
            if button["text"].get(self.language_code, button["text"]["en"]) == button_text:
                return button["id"]

    def get_reply_options(self, category):
        for button in self.conversation[category].get("reply_markup", []):
            yield button["text"].get(self.language_code, button["text"]["en"])

    def start(self):
        for message_text, kwargs in self.__list_messages(START):
            bot.send_message(self.chat_id, message_text, **kwargs)

        delete_state(self.user_id)

    def location(self):
        state = {"user": {"language_code": self.language_code, "id": str(self.user_id)},
                 "incident": {
                     "location": {
                         "lat": self.message.location.latitude, "lon": self.message.location.longitude},
                     "timestamp": datetime.now().replace(microsecond=0).isoformat()}}

        for message_text, kwargs in self.__list_messages(INCIDENT, state):
            bot.send_message(self.chat_id, message_text, **kwargs)

        set_state(self.user_id, ConversationState.CATEGORY, state)

    def category(self, state):
        selected_category = self.__get_button_id(INCIDENT, self.message.text)
        state["incident"]["type"] = selected_category

        for message_text, kwargs in self.__list_messages(DISTANCE, state):
            bot.send_message(self.chat_id, message_text, **kwargs)

        update_state(self.user_id, ConversationState.LOCATION_DETAILS, state)

    def process_location_details(self, state):
        state["incident"]["distance"] = self.__get_button_id(DISTANCE, self.message.text)

        for message_text, kwargs in self.__list_messages(TIME, state):
            bot.send_message(self.chat_id, message_text, **kwargs)

        update_state(self.user_id, ConversationState.TIME, state)

    def process_time_details(self, state):
        state["incident"]["time"] = self.__get_button_id(TIME, self.message.text)

        for message_text, kwargs in self.__list_messages(END, state):
            bot.send_message(self.chat_id, message_text, **kwargs)

        self.start()

        response = send_report(state)
        logger.info(f"SQS Response: {response}")

    def process_unknown_prompt(self, conv_state: ConversationState, state):
        for message_text, kwargs in self.__list_messages(ERROR, state,
                                                         CONV_STATE_TO_CATEGORY.get(conv_state)):
            bot.send_message(self.chat_id, message_text, **kwargs)


def lambda_handler(event: dict, context):
    request = event["body"]
    if isinstance(request, str):
        request = json.loads(request)

    if request.get("setWebhook", False) and is_direct_invocation(event):
        bot.remove_webhook()
        webhook = f"{os.environ['domain']}/{os.environ['path_key']}/webhook/"
        bot.set_webhook(url=webhook)
        return {'statusCode': 200}

    if event.get('rawPath') == f"/{os.environ['path_key']}/send_message/":
        to_user = request["telegramUID"]
        bot.send_message(to_user, request["text"])
        return {'statusCode': 200}

    if event.get('rawPath') != f"/{os.environ['path_key']}/webhook/":
        return {'statusCode': 404}

    if not from_telegram_network(event["headers"]["x-forwarded-for"]):
        return {'statusCode': 403}

    update = Update.de_json(request)
    if not update.message:
        return {'statusCode': 200}

    conv_handler = ConversationHandler(update.message)
    if update.message.text == '/start':
        conv_handler.start()
        return {'statusCode': 200}

    conv_state, state = get_state(update.message.from_user.id)
    if update.message.location:
        conv_handler.location()
    elif update.message.text in conv_handler.get_reply_options(INCIDENT) and conv_state == ConversationState.CATEGORY:
        conv_handler.category(state)
    elif update.message.text in conv_handler.get_reply_options(
            DISTANCE) and conv_state == ConversationState.LOCATION_DETAILS:
        conv_handler.process_location_details(state)
    elif update.message.text in conv_handler.get_reply_options(TIME) and conv_state == ConversationState.TIME:
        conv_handler.process_time_details(state)
    else:
        conv_handler.process_unknown_prompt(conv_state, state)

    return {'statusCode': 200}
