ARG	DIST=alpine
ARG	REL=latest


#
#
# target: mini
#
# postfix only
#
#

FROM	$DIST:$REL AS mini
LABEL	maintainer=mlan

ENV	DOCKER_RUNSV_DIR=/etc/service \
	DOCKER_PERSIST_DIR=/srv \
	DOCKER_BIN_DIR=/usr/local/bin \
	DOCKER_ENTRY_DIR=/etc/docker/entry.d \
	DOCKER_SOURCE_DIR=/usr/local/bin \
	SYSLOG_LEVEL=5 \
	SYSLOG_OPTIONS=-SDt

#
# Copy utility scripts including entrypoint.sh to image
#

COPY	src/*/bin $DOCKER_BIN_DIR/
COPY	src/*/entry.d $DOCKER_ENTRY_DIR/
COPY	src/*/source.d $DOCKER_SOURCE_DIR/

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
	&& setup-runit.sh \
	"syslogd -nO- -l$SYSLOG_LEVEL $SYSLOG_OPTIONS" \
	"crond -f -c /etc/crontabs" \
	"postfix start-fg" \
	&& mkdir -p /var/mail && chown postfix: /var/mail \
	&& mkdir -p /etc/ssl/postfix \
	&& source docker-logger.sh \
	&& source postfix-common.sh \
	&& imgcfg_mvfile dist /etc/postfix/aliases \
	&& imgcfg_cpfile dist /etc/postfix/main.cf /etc/postfix/master.cf \
	&& postconf -e mynetworks_style=subnet \
	&& rm -rf /var/cache/apk/* \
	&& imgcfg_cpfile bld /etc/postfix/main.cf /etc/postfix/master.cf \
	&& imgdir_persist /etc/postfix /etc/ssl /var/spool/postfix /var/mail

#
# state standard smtp, smtps and submission ports
#

EXPOSE 25 465 587

#
# Rudimentary healthcheck
#

HEALTHCHECK CMD sv status ${DOCKER_RUNSV_DIR}/* && postfix status

#
# Entrypoint, how container is run
#

ENTRYPOINT ["entrypoint.sh"]

#
# Have runit's runsvdir start all services
#

CMD	runsvdir -P ${DOCKER_RUNSV_DIR}


#
#
# target: base
#
# add dovecot
#
#

FROM	mini AS base

#
# Install
# remove private key that dovecot creates
#

RUN	apk --no-cache --update add \
	dovecot \
	jq \
	&& setup-runit.sh "dovecot -F" \
	&& rm -f /etc/ssl/dovecot/* \
	&& addgroup postfix dovecot && addgroup dovecot postfix \
	&& source docker-logger.sh \
	&& source postfix-common.sh \
	&& imgcfg_dovecot_passwdfile \
	&& imgdir_persist /etc/dovecot \
	&& mkdir -p /etc/ssl/acme \
	&& imgcfg_runit_acme_dump

#
#
# target: full
#
# add anti-spam and anti-virus mail filters
# as well as dkim and spf
# add tzdata to allow time zone to be configured
#
#

FROM	base AS full

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
	&& mkdir -p /etc/amavis && mv /etc/amavisd.conf /etc/amavis \
	&& mkdir /run/amavis && chown amavis: /run/amavis \
	&& source docker-logger.sh \
	&& source docker-common.sh \
	&& source postfix-common.sh \
	&& dc_replace /usr/sbin/amavisd /etc/amavisd.conf /etc/amavis/amavisd.conf \
	&& imgcfg_cpfile dist /etc/amavis/amavisd.conf /etc/clamav/clamd.conf /etc/clamav/freshclam.conf \
	&& addgroup clamav amavis && addgroup amavis clamav \
	&& ln -sf /var/amavis/.spamassassin /root/.spamassassin \
	&& mkdir -p /var/amavis/.razor && chown amavis: /var/amavis/.razor \
	&& ln -sf /var/amavis/.razor /root/.razor \
	&& mkdir -p /var/db/dkim && chown amavis: /var/db/dkim \
	&& dc_addafter /etc/amavis/amavisd.conf '^$mydomain' '$inet_socket_bind = \x27127.0.0.1\x27; # limit to ipv4 loopback, no ipv6 support' \
	&& dc_addafter /etc/amavis/amavisd.conf '^$inet_socket_bind' '$log_templ = $log_verbose_templ; # verbose log' \
	&& dc_addafter /etc/amavis/amavisd.conf '^$log_templ' '# $sa_debug = 0; # debug SpamAssassin' \
	&& dc_uncommentsection /etc/amavis/amavisd.conf "# ### http://www.clamav.net/" \
	&& dc_replace /etc/amavis/amavisd.conf /var/run/clamav/clamd.sock /run/clamav/clamd.sock \
	&& dc_modify /etc/amavis/amavisd.conf '\$pid_file' = '"/run/amavis/amavisd.pid";' \
	&& imgcfg_amavis_postfix \
	&& mkdir /run/clamav && chown clamav: /run/clamav \
	&& dc_modify /etc/clamav/clamd.conf Foreground yes \
	&& dc_modify /etc/clamav/clamd.conf LogSyslog yes \
	&& dc_modify /etc/clamav/clamd.conf LogFacility LOG_MAIL \
	&& dc_comment /etc/clamav/clamd.conf LogFile \
	&& dc_modify /etc/clamav/freshclam.conf Foreground yes \
	&& dc_modify /etc/clamav/freshclam.conf LogSyslog yes \
	&& dc_comment /etc/clamav/freshclam.conf UpdateLogFile \
	&& dc_modify /etc/clamav/freshclam.conf LogFacility LOG_MAIL \
	&& imgcfg_cpfile bld /etc/amavis/amavisd.conf /etc/clamav/clamd.conf \
		/etc/clamav/freshclam.conf /etc/postfix/main.cf /etc/postfix/master.cf \
	&& imgdir_persist /etc/amavis /etc/mail /etc/clamav \
		/var/amavis /var/db/dkim /var/lib/spamassassin /var/lib/clamav
