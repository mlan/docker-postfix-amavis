ARG	DIST=alpine
ARG	REL=latest


#
#
# target: smtp
#
# postfix only
#
#

FROM	$DIST:$REL AS smtp
LABEL	maintainer=mlan

ENV	SYSLOG_LEVEL=4

#
# Copy utility scripts to image
#

COPY setup-runit.sh /usr/local/bin/.
COPY entrypoint.sh /usr/local/bin/.
COPY sa-learn.sh /usr/local/bin/.

#
# Install
#
# Configure Runit, a process manager
#
# Make postfix trust smtp clients on the same subnet, 
# i.e., containers on the same network.
#

RUN	apk --no-cache --update add \
	runit \
	postfix \
	postfix-ldap \
	&& ln -s /usr/local/bin/entrypoint.sh /usr/local/bin/mtaconf \
	&& setup-runit.sh \
	"syslogd -n -O /dev/stdout -l $SYSLOG_LEVEL" \
	"crond -f -c /etc/crontabs" \
	"postfix start-fg" \
	&& postconf -e mynetworks_style=subnet

#
# state standard smtp port
#

EXPOSE 25

#
# Rudimentary healthcheck
#

HEALTHCHECK CMD postfix status || exit 1

#
# Entrypoint, how container is run
#

ENTRYPOINT ["entrypoint.sh"]


#
#
# target: milter
#
# add anti-spam and anti-virus mail filters
#
#

FROM	smtp AS milter

#
# Install
#
# Configure Runit, a process manager
#
# Essential configuration of: amavis and clamav
# amavis ignores ipv4 unless it is bound to localhost
# make amavis use clamav
#

RUN	apk --no-cache --update add \
	amavisd-new \
	spamassassin \
	razor \
	clamav \
	clamav-libunrar \
	unzip \
	unrar \
	p7zip \
	ncurses \
	&& setup-runit.sh \
	"amavisd foreground" \
	"freshclam -d --quiet" \
	"-q clamd" \
	&& addgroup clamav amavis && addgroup amavis clamav \
	&& ln -sf /var/amavis/.spamassassin /root/.spamassassin \
	&& cp /etc/amavisd.conf /etc/amavisd.conf.dist \
	&& mtaconf addafter /etc/amavisd.conf '^$mydomain' '$inet_socket_bind = \x27127.0.0.1\x27; # limit to ipv4 loopback, no ipv6 support' \
	&& mtaconf uncommentsection /etc/amavisd.conf "# ### http://www.clamav.net/" \
	&& mtaconf replace /etc/amavisd.conf /var/run/clamav/clamd.sock /run/clamav/clamd.sock \
	&& mkdir /run/clamav && chown clamav:clamav /run/clamav \
	&& cp /etc/clamav/clamd.conf /etc/clamav/clamd.conf.dist \
	&& cp /etc/clamav/freshclam.conf /etc/clamav/freshclam.conf.dist \
	&& mtaconf modify /etc/clamav/clamd.conf Foreground yes \
	&& mtaconf modify /etc/clamav/clamd.conf LogSyslog yes \
	&& mtaconf modify /etc/clamav/clamd.conf LogFacility LOG_MAIL \
	&& mtaconf comment /etc/clamav/clamd.conf LogFile \
	&& mtaconf modify /etc/clamav/freshclam.conf Foreground yes \
	&& mtaconf modify /etc/clamav/freshclam.conf LogSyslog yes \
	&& mtaconf comment /etc/clamav/freshclam.conf UpdateLogFile \
	&& mtaconf modify /etc/clamav/freshclam.conf LogFacility LOG_MAIL

#
#
# target: auth
#
# add spf and opendkim
#
#

FROM	milter AS auth

#
# Install
#
# Configure Runit, a process manager
#
# Essential configuration of: opendkim
#

RUN	apk --no-cache --update add \
	opendkim \
	opendkim-utils \
	postfix-policyd-spf-perl \
	&& setup-runit.sh "opendkim -f" \
	&& addgroup postfix opendkim \
	&& mkdir /run/opendkim && chown opendkim:opendkim /run/opendkim \
	&& cp /etc/opendkim/opendkim.conf /etc/opendkim/opendkim.conf.dist \
	&& mtaconf removeline /etc/opendkim/opendkim.conf ^#Socket \
	&& mtaconf modify /etc/opendkim/opendkim.conf Socket local:/run/opendkim/opendkim.sock \
	&& mtaconf modify /etc/opendkim/opendkim.conf InternalHosts 172.16.0.0/12 \
	&& mtaconf modify /etc/opendkim/opendkim.conf PidFile /run/opendkim/opendkim.pid \
	&& mtaconf modify /etc/opendkim/opendkim.conf KeyFile /var/db/dkim/default.private \
	&& mtaconf addafter /etc/opendkim/opendkim.conf Canonicalization "UserID\t\t\topendkim" \
	&& mtaconf addafter /etc/opendkim/opendkim.conf UserID "UMask\t\t\t0111" \
	&& opendkim-genkey -D /var/db/dkim && chown -R opendkim:opendkim /var/db/dkim

#
#
# target: full
#
# add letsencrypt support via traefik
#
#

FROM	auth AS full

#
# Install
#

RUN	apk --no-cache --update add \
	inotify-tools \
	jq \
	openssl \
	util-linux \
	bash

#
# Copy utility scripts to image
#

#RUN	wget https://raw.githubusercontent.com/containous/traefik/master/contrib/scripts/dumpcerts.sh -O /usr/local/bin/dumpcerts.sh
#RUN chmod a+x /usr/local/bin/dumpcerts.sh
#RUN mtaconf modify /usr/local/bin/dumpcerts.sh "{acmefile}\")" "{acmefile}\" | fold -w 64)"

COPY dumpcerts.sh /usr/local/bin/.
