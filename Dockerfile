FROM alpine:3.23
RUN apk add --no-cache bash
COPY entrypoint.sh /entrypoint.sh
COPY cleanup.sh /cleanup.sh
ENTRYPOINT ["/entrypoint.sh"]
