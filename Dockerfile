# Base image
FROM alpine:latest

# Environment variables
ENV DOCKER=∞X3XckwT1ztOA2da∞
ENV TZ=Asia/Shanghai

# Install dependencies
RUN apk add --no-cache bash curl jq openssl tzdata

# Copy file
COPY attendance.sh .
RUN chmod +x attendance.sh

# Add task
RUN echo '# min   hour    day     month   weekday command' >/etc/crontabs/root
RUN echo '0       5       *       *       *       /attendance.sh' >>/etc/crontabs/root

# Start command
CMD /attendance.sh
