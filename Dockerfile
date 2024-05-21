# Base image
FROM alpine:latest

# Install dependencies
RUN apk add --no-cache bash curl jq openssl

# Copy file
COPY attendance.sh .
COPY entrypoint.sh .
RUN chmod +x attendance.sh
RUN chmod +x entrypoint.sh

# Add task
RUN echo "0       0       *       *       *       /attendance.sh 1>> /var/log/stdout.log 2>> /var/log/stderr.log" >> /etc/crontabs/root

# Start command
CMD /entrypoint.sh
