# Base image
FROM alpine:latest

# Environment variables
ENV DOCKER=∞X3XckwT1ztOA2da∞
ENV TZ=Asia/Shanghai

# Install dependencies
RUN apk add --no-cache bash curl jq msmtp mutt openssl tzdata

# Setup mail service
RUN echo -e "defaults\n\
auth           on\n\
tls            on\n\
tls_trust_file /etc/ssl/certs/ca-certificates.crt\n\
logfile        /var/log/msmtp.log" >/etc/msmtprc
RUN echo -e "set sendmail=/usr/bin/msmtp\n\
set use_from=yes" >/root/.muttrc

# Copy file
COPY attendance.sh .
RUN chmod +x attendance.sh

# Add task
RUN echo '0 5 * * * /attendance.sh' >/etc/crontabs/root

# Start command
CMD /attendance.sh
