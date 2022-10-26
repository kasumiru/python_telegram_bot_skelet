# -*- coding: utf-8 -*-
telegram_token = 'telegram_bot_token_PLACEHOLDER'
tcp_port = 8811

import json

try:
    import requests
except Exception as e:
    import pip
    pip.main(['install', 'requests'])
    import requests

try:
    import bottle
except Exception as e:
    import pip
    pip.main(['install', 'bottle'])
    import bottle

try:
    import telebot
except Exception as e:
    import pip
    pip.main(['install', 'pyTelegramBotAPI'])
    import telebot

BOT_URL = 'https://api.telegram.org/bot' + telegram_token
tb  = telebot.TeleBot(telegram_token)

def get_chat_id(data):
    chat_id = data['message']['chat']['id']
    return chat_id

def get_message(data):
    message_text = data
    message_text = data['message']['text']
    return message_text

def send_message(chat_id,text):
    if len(text) >= 4080:
        for x in range(0, len(text), 4080):
            tb.send_message(chat_id, '`{}`'.format(text[x:x+4080]), parse_mode="markdown")
        return bottle.response
    else:
        tb.send_message(chat_id, '`{}`'.format(text), parse_mode="markdown")
        return bottle.response
    return bottle.response

@bottle.post('/')
def main():
    data = bottle.request.json
    try:
        if isinstance(data,dict):
            chat_id = get_chat_id(data)
        else:
            print('payload is not json!')
            return bottle.response
    except Exception as e:
        print('Error in get chat_id!')
        print(e)
        return bottle.response

    print(f'Chat_id = {chat_id}')

    try:
        incoming_text = get_message(data)
    except Exception as e:
        print('MyException: ', e)
        return bottle.response

    send_message(chat_id,f'You message: {incoming_text}')
    return bottle.response

bottle.run(host='localhost', port=tcp_port, debug=True)
