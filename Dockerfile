FROM debian:bullseye-slim

RUN apt-get update && apt-get install -y \
    php8.2-fpm php8.2-cli php8.2-mbstring php8.2-xml \
    php8.2-zip php8.2-curl php8.2-gd php8.2-sqlite3 \
    caddy git curl wget sqlite3 supervisor

COPY install.sh /tmp/install.sh
RUN chmod +x /tmp/install.sh && /tmp/install.sh

EXPOSE 80 443 8080

CMD ["supervisord", "-n"]
