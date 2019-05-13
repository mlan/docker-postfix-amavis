ARG	DIST=alpine
ARG	REL=latest


#
#
# target: mta
#
# postfix only
#
#

FROM	$DIST:$REL AS mta
LABEL	maintainer=mlan

ARG	SYSLOG_LEVEL=4

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

RUN	apk --update add \
	runit \
	postfix \
	postfix-ldap \
	&& if [ -n "$(apk search -x cyrus-sasl-plain)" ]; then apk add \
	cyrus-sasl-plain \
	cyrus-sasl-login \
	; fi \
	&& ln -s /usr/local/bin/entrypoint.sh /usr/local/bin/conf \
	&& setup-runit.sh \
	"syslogd -n -O /dev/stdout -l $SYSLOG_LEVEL" \
	"crond -f -c /etc/crontabs" \
	"postfix start-fg" \
	&& mkdir -p /var/mail && chown postfix: /var/mail \
	&& cp /etc/postfix/main.cf /etc/postfix/main.cf.dist \
	&& cp /etc/postfix/master.cf /etc/postfix/master.cf.dist \
	&& postconf -e mynetworks_style=subnet \
	&& rm -rf /var/cache/apk/* \
	&& cp /etc/postfix/main.cf /etc/postfix/main.cf.build \
	&& cp /etc/postfix/master.cf /etc/postfix/master.cf.build

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
# target: mda
#
# add dovecot
#
#

FROM	mta AS mda

#
# Install
#

RUN	apk --no-cache --update add dovecot \
	&& setup-runit.sh "dovecot -F" \
	&& addgroup postfix dovecot && addgroup dovecot postfix \
	&& conf imgcfg_dovecot_passwdfile


#
#
# target: milter
#
# add anti-spam and anti-virus mail filters
# as well as dkim and spf
#
#

FROM	mda AS milter

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
	perl-mail-spf \
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
	&& mkdir -p /var/db/dkim && chown amavis: /var/db/dkim \
	&& cp /etc/amavisd.conf /etc/amavisd.conf.dist \
	&& conf addafter /etc/amavisd.conf '^$mydomain' '$inet_socket_bind = \x27127.0.0.1\x27; # limit to ipv4 loopback, no ipv6 support' \
	&& conf addafter /etc/amavisd.conf '^$inet_socket_bind' '$log_templ = $log_verbose_templ; # verbose log' \
	&& conf uncommentsection /etc/amavisd.conf "# ### http://www.clamav.net/" \
	&& conf replace /etc/amavisd.conf /var/run/clamav/clamd.sock /run/clamav/clamd.sock \
	&& conf modify /etc/amavisd.conf '\$pid_file' = '"$MYHOME/amavisd.pid";' \
	&& conf imgcfg_amavis_postfix \
	&& mkdir /run/clamav && chown clamav:clamav /run/clamav \
	&& cp /etc/clamav/clamd.conf /etc/clamav/clamd.conf.dist \
	&& cp /etc/clamav/freshclam.conf /etc/clamav/freshclam.conf.dist \
	&& conf modify /etc/clamav/clamd.conf Foreground yes \
	&& conf modify /etc/clamav/clamd.conf LogSyslog yes \
	&& conf modify /etc/clamav/clamd.conf LogFacility LOG_MAIL \
	&& conf comment /etc/clamav/clamd.conf LogFile \
	&& conf modify /etc/clamav/freshclam.conf Foreground yes \
	&& conf modify /etc/clamav/freshclam.conf LogSyslog yes \
	&& conf comment /etc/clamav/freshclam.conf UpdateLogFile \
	&& conf modify /etc/clamav/freshclam.conf LogFacility LOG_MAIL \
	&& cp /etc/amavisd.conf /etc/amavisd.conf.build \
	&& cp /etc/clamav/clamd.conf /etc/clamav/clamd.conf.build \
	&& cp /etc/clamav/freshclam.conf /etc/clamav/freshclam.conf.build \
	&& cp /etc/postfix/main.cf /etc/postfix/main.cf.build \
	&& cp /etc/postfix/master.cf /etc/postfix/master.cf.build


#
#
# target: full
#
# add letsencrypt support via traefik
# add tzdata to allow time zone to be configured
#
#

FROM	milter AS full

#
# Install
#

RUN	apk --no-cache --update add \
	inotify-tools \
	jq \
	openssl \
	util-linux \
	bash \
	tzdata

#
# Copy utility scripts to image
#

COPY dumpcerts.sh /usr/local/bin/.
