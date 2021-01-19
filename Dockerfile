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

ENV	SVDIR=/etc/service \
	DOCKER_PERSIST_DIR=/srv \
	DOCKER_BIN_DIR=/usr/local/bin \
	DOCKER_ENTRY_DIR=/etc/docker/entry.d \
	DOCKER_SSL_DIR=/etc/ssl \
	DOCKER_SPOOL_DIR=/var/spool/postfix \
	DOCKER_CONF_DIR=/etc/postfix \
	DOCKER_DIST_DIR=/etc/postfix.dist \
	DOCKER_SPAM_DIR=/etc/mail/spamassassin \
	DOCKER_MAIL_LIB=/var/mail \
	DOCKER_IMAP_DIR=/etc/dovecot \
	DOCKER_MILT_DIR=/etc/amavis \
	DOCKER_MILT_LIB=/var/amavis \
	DOCKER_DKIM_LIB=/var/db/dkim \
	DOCKER_AV_DIR=/etc/clamav \
	DOCKER_AV_LIB=/var/lib/clamav \
	DOCKER_SPAM_LIB=/var/lib/spamassassin \
	DOCKER_UNLOCK_FILE=/srv/etc/.docker.unlock \
	DOCKER_APPL_RUNAS=postfix \
	DOCKER_IMAP_RUNAS=dovecot \
	DOCKER_MILT_RUNAS=amavis \
	DOCKER_AV_RUNAS=clamav \
	ACME_POSTHOOK="postfix reload" \
	SYSLOG_LEVEL=5 \
	SYSLOG_OPTIONS=-SDt
ENV	DOCKER_ACME_SSL_DIR=$DOCKER_SSL_DIR/acme \
	DOCKER_APPL_SSL_DIR=$DOCKER_SSL_DIR/postfix \
	DOCKER_MILT_FILE=$DOCKER_MILT_DIR/amavisd.conf \
	DOCKER_AVNGN_FILE=$DOCKER_AV_DIR/clamd.conf \
	DOCKER_AVSIG_FILE=$DOCKER_AV_DIR/freshclam.conf \
	DOCKER_SPAM_FILE=$DOCKER_SPAM_DIR/local.cf \
	DOCKER_IMAP_PASSDB_FILE=$DOCKER_IMAP_DIR/virt-passwd

#
# Copy utility scripts including docker-entrypoint.sh to image
#

COPY	src/*/bin $DOCKER_BIN_DIR/
COPY	src/*/entry.d $DOCKER_ENTRY_DIR/

#
# Install
#
# Arrange persistent directories at /srv.
# Configure Runit, a process manager.
# Make postfix trust smtp clients on the same subnet,
# i.e., containers on the same network.
#

RUN	source docker-common.sh \
	&& source docker-config.sh \
	&& dc_persist_dirs \
	$DOCKER_APPL_SSL_DIR \
	$DOCKER_AV_DIR \
	$DOCKER_AV_LIB \
	$DOCKER_CONF_DIR \
	$DOCKER_DKIM_LIB \
	$DOCKER_IMAP_DIR \
	$DOCKER_SPAM_DIR \
	$DOCKER_MAIL_LIB \
	$DOCKER_MILT_DIR \
	$DOCKER_MILT_LIB \
	$DOCKER_SPAM_LIB \
	$DOCKER_SPOOL_DIR \
	&& mkdir -p $DOCKER_ACME_SSL_DIR \
	&& apk --no-cache --update add \
	runit \
	postfix \
	postfix-ldap \
#	cyrus-sasl-plain \ # moved back into libsasl
	cyrus-sasl-login \
	&& cp -rlL $DOCKER_CONF_DIR $DOCKER_DIST_DIR \
	&& docker-service.sh \
	"syslogd -nO- -l$SYSLOG_LEVEL $SYSLOG_OPTIONS" \
	"crond -f -c /etc/crontabs" \
	"postfix start-fg" \
	&& chown ${DOCKER_APPL_RUNAS}: ${DOCKER_PERSIST_DIR}$DOCKER_MAIL_LIB \
	&& mv $DOCKER_CONF_DIR/aliases $DOCKER_CONF_DIR/aliases.dist \
	&& postconf -e mynetworks_style=subnet \
	&& echo "This file unlocks the configuration, so it will be deleted after initialization." > $DOCKER_UNLOCK_FILE

#
# state standard smtp, smtps and submission ports
#

EXPOSE 25 465 587

#
# Rudimentary healthcheck
#

HEALTHCHECK CMD sv status ${SVDIR}/* && postfix status

#
# Entrypoint, how container is run
#

ENTRYPOINT ["docker-entrypoint.sh"]

#
# Have runit's runsvdir start all services
#

CMD	runsvdir -P ${SVDIR}


#
#
# target: base
#
# Install dovecot, a IMAP server
#
#

FROM	mini AS base

#
# Install
#
# Remove private key that dovecot creates.
#

RUN	apk --no-cache --update add \
	dovecot \
	dovecot-ldap \
	dovecot-lmtpd \
	jq \
	&& docker-service.sh "dovecot -F" \
	&& rm -f /etc/ssl/dovecot/* \
	&& addgroup $DOCKER_APPL_RUNAS $DOCKER_IMAP_RUNAS \
	&& addgroup $DOCKER_IMAP_RUNAS $DOCKER_APPL_RUNAS \
	&& source dovecot-common.sh \
	&& dc_dovecot_setup_docker

#
#
# target: full
#
# Install anti-spam, anti-virus mail filters and dkim.
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
# amavis: new name of amavisd-new
# perl-db: amavis dependency omitted since use of bdb is discouraged
#

RUN	apk --no-cache --update add \
	amavis \
	perl-db \
	spamassassin \
	perl-mail-spf \
	razor \
	clamav \
	clamav-libunrar \
	unzip \
	unrar \
	p7zip \
	ncurses \
	&& docker-service.sh \
	"amavisd foreground" \
	"freshclam -d --quiet" \
	"-q clamd" \
	&& source docker-common.sh \
	&& source docker-config.sh \
	&& mv /etc/amavisd.conf $DOCKER_MILT_DIR \
	&& dc_replace /usr/sbin/amavisd /etc/amavisd.conf $DOCKER_MILT_DIR/amavisd.conf \
	&& addgroup $DOCKER_AV_RUNAS $DOCKER_MILT_RUNAS \
	&& addgroup $DOCKER_MILT_RUNAS $DOCKER_AV_RUNAS \
	&& ln -sf $DOCKER_MILT_LIB/.spamassassin /root/.spamassassin \
	&& ln -sf $DOCKER_MILT_LIB/.razor /root/.razor \
	&& chown $DOCKER_MILT_RUNAS: ${DOCKER_PERSIST_DIR}$DOCKER_DKIM_LIB \
	&& chown $DOCKER_AV_RUNAS: ${DOCKER_PERSIST_DIR}$DOCKER_AV_LIB \
	&& dc_addafter $DOCKER_MILT_FILE '^$mydomain' '$inet_socket_bind = \x27127.0.0.1\x27; # limit to ipv4 loopback, no ipv6 support' \
	&& dc_addafter $DOCKER_MILT_FILE '^$inet_socket_bind' '$log_templ = $log_verbose_templ; # verbose log' \
	&& dc_addafter $DOCKER_MILT_FILE '^$log_templ' '# $sa_debug = 0; # debug SpamAssassin' \
	&& dc_uncommentsection $DOCKER_MILT_FILE "# ### http://www.clamav.net/" \
	&& dc_replace  $DOCKER_MILT_FILE /var/run/clamav/clamd.sock /run/clamav/clamd.sock \
	&& dc_modify   $DOCKER_MILT_FILE '\$pid_file' = '"/run/amavis/amavisd.pid";' \
	&& dc_addafter $DOCKER_SPAM_FILE 'lock_method' 'use_razor2 1' \
	&& mkdir /run/amavis && chown $DOCKER_MILT_RUNAS: /run/amavis \
	&& mkdir /run/clamav && chown $DOCKER_AV_RUNAS: /run/clamav \
	&& dc_modify  $DOCKER_AVNGN_FILE Foreground yes \
	&& dc_modify  $DOCKER_AVNGN_FILE LogSyslog yes \
	&& dc_modify  $DOCKER_AVNGN_FILE LogFacility LOG_MAIL \
	&& dc_comment $DOCKER_AVNGN_FILE LogFile \
	&& dc_modify  $DOCKER_AVSIG_FILE Foreground yes \
	&& dc_modify  $DOCKER_AVSIG_FILE LogSyslog yes \
	&& dc_comment $DOCKER_AVSIG_FILE UpdateLogFile \
	&& dc_modify  $DOCKER_AVSIG_FILE LogFacility LOG_MAIL \
	&& source amavis-common.sh \
	&& ac_amavis_setup_postfix
