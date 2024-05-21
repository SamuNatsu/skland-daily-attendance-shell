# Base image
FROM alpine:latest

# Install dependencies
RUN apk update && apk add --no-cache jq openssl

# Copy file
COPY attendance.sh .
RUN chmod +x attendance.sh

# Add task
RUN crontab -l | { cat; echo "0 0 * * * /attendance.sh"; } | crontab -

# Start command
CMD crond -f
