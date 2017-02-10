FROM jruby:9.1-jre-alpine

MAINTAINER Jeremy Winters jeremy.winters@full360.com

RUN apk add --no-cache \
      bash \
      wget \
      git

#set time zone
RUN mv /etc/localtime /etc/localtime.bak ; ln -s /usr/share/zoneinfo/UTC /etc/localtime

# Install runner.sh and related scripts
ADD docker/runner.sh /usr/sbin/runner.sh
RUN chown root:root /usr/sbin/runner.sh; chmod 755 /usr/sbin/runner.sh

USER root

RUN gem install sneaql-standard
ENV JRUBY_OPTS=-J-Xmx1024m

# Set the ENTRYPOINT
ENTRYPOINT ["/usr/sbin/runner.sh"]