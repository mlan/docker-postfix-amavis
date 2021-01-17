#!/bin/sh
#
# dovecot-common.sh
#
# Define variables and functions used during build. Source in Dockerfile.
#
# Defined in Dockerfile:
# DOCKER_IMAP_DIR DOCKER_APPL_RUNAS DOCKER_IMAP_PASSDB_FILE
#
DOVECOT_CF=${DOVECOT_CF-$DOCKER_IMAP_DIR/dovecot.conf}
DOVECOT_CD=${DOVECOT_CD-$DOCKER_IMAP_DIR/conf.d}

#
# Configure dovecot.
#
dc_dovecot_setup_docker() {
	dc_dovecot_setup_conf
	dc_dovecot_setup_master
#	dc_dovecot_setup_lmtp
}

#
# Configure dovecot local config.
#
dc_dovecot_setup_conf() {
	local example_conf=/usr/share/dovecot/example-conf
	mkdir -p $example_conf
	mv $DOCKER_IMAP_DIR/* $example_conf
	mkdir -p $DOVECOT_CD
	cat <<-!cat > $DOVECOT_CF
		!include conf.d/*.conf
		protocols = imap lmtp
	!cat
	cat <<-!cat > $DOCKER_IMAP_DIR/README
		You can find dovecot example config files here: $example_conf
	!cat
}

#
# Configure dovecot auth service.
# postconf virtual_transport=lmtp:unix:private/lmtp-dovecot
# https://workaround.org/ispmail/buster/let-postfix-send-emails-to-dovecot/
# https://doc.dovecot.org/settings/core/
#
dc_dovecot_setup_master() {
	cat <<-!cat > $DOVECOT_CD/10-master.conf
		disable_plaintext_auth = no
		auth_username_format = %n
		mail_location = mbox:/var/mail/%u
		first_valid_uid = 1
		mail_uid = $DOCKER_APPL_RUNAS
		mail_gid = $DOCKER_APPL_RUNAS
		service auth {
		unix_listener /var/spool/postfix/private/auth {
		mode  = 0660
		user  = $DOCKER_APPL_RUNAS
		group = $DOCKER_APPL_RUNAS
		}
		}
		service lmtp {
		unix_listener /var/spool/postfix/private/transport {
		mode  = 0660
		user  = $DOCKER_APPL_RUNAS
		group = $DOCKER_APPL_RUNAS
		}
		}
	!cat
}

#
# Configure dovecot lmtp.
#
dc_dovecot_setup_lmtp() {
	cat <<-!cat > $DOVECOT_CD/20-lmtp.conf
		protocol lmtp {
		postmaster_address = postmaster@domainname   # required
		}
	!cat
}
