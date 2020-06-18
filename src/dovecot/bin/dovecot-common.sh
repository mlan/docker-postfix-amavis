#!/bin/sh
#
# dovecot-common.sh
#
# Define variables and functions used during build. Source in Dockerfile.
#
# Defined in Dockerfile:
# DOCKER_IMAP_DIR DOCKER_APPL_RUNAS DOCKER_IMAPPASSWD_FILE
#
DOVECOT_CF=${DOVECOT_CF-$DOCKER_IMAP_DIR/dovecot.conf}

#
# Configure dovecot to use passwd-file.
#
dc_dovecot_setup_passwdfile() {
	cat <<-!cat > ${1-$DOVECOT_CF}
		ssl = no
		disable_plaintext_auth = no
		auth_mechanisms = plain login
		passdb {
		    driver = passwd-file
		    args = ${2-$DOCKER_IMAPPASSWD_FILE}
		}
		userdb {
		    driver = static
		    args = uid=500 gid=500 home=/home/%u
		}
		service auth {
		    unix_listener /var/spool/postfix/private/auth {
		        mode  = 0660
		        user  = $DOCKER_APPL_RUNAS
		        group = $DOCKER_APPL_RUNAS
		    }
		}
	!cat
}
