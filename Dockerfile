FROM bash:5

WORKDIR /bot
COPY telegram_alert.sh /bot/telegram_alert.sh

RUN chmod +x /bot/telegram_alert.sh

CMD ["bash", "/bot/telegram_alert.sh"]
