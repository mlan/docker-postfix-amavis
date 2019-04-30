#!/bin/sh -e

#
# config
#

docker_build_runit_root=${docker_build_runit_root-/etc/service}
postfix_sasl_passwd=${postfix_sasl_passwd-/etc/postfix/sasl-passwords}
postfix_virt_mailbox=${postfix_virt_mailbox-/etc/postfix/virt-users}
postfix_ldap_users_cf=${postfix_ldap_users_cf-/etc/postfix/ldap-users.cf}
postfix_ldap_alias_cf=${postfix_ldap_alias_cf-/etc/postfix/ldap-aliases.cf}
postfix_ldap_groups_cf=${postfix_ldap_groups_cf-/etc/postfix/ldap-groups.cf}
postfix_ldap_expand_cf=${postfix_ldap_expand_cf-/etc/postfix/ldap-groups-expand.cf}
amavis_cf=${amavis_cf-/etc/amavisd.conf}

#
# define environment variables
#

amavis_var="FINAL_VIRUS_DESTINY FINAL_BANNED_DESTINY FINAL_SPAM_DESTINY FINAL_BAD_HEADER_DESTINY"

#
# usage
#

usage() { echo "
USAGE
	mtaconf COMMAND FILE [command-options]

COMMAND
	modify <file> <parameter statement>
		if parameter is found modify its value
		uncomment parameter if needed
		We will keep eveyting that is after a '#' charater
		Examples:
		mtaconf modify /etc/clamav/clamd.conf Foreground yes
		mtaconf modify /etc/amavisd.conf \$sa_tag_level_deflt = -999;

	replace <file> <old-string> <new-string>
		match <old-string> and relpace it with <new-string>
		Examples:
		mtaconf replace /etc/amavisd.conf /var/run/clamav/clamd.sock /run/clamav/clamd.sock

	uncommentsection <file> <string>
		Remove all leading '#' starting with a line that matches <string> and
		ending with an empty line
		Examples:
		mtaconf uncommentsection /etc/amavisd.conf '# ### http://www.clamav.net/'

	comment <file> <string>
		Add leading '#' to line matching <string>
		Examples:
		mtaconf comment /etc/clamav/freshclam.conf UpdateLogFile

	removeline <file> <string>
		Remove line that matches <string>
		Examples:
		mtaconf removeline /etc/opendkim/opendkim.conf ^#Socket

	addafter <file> <match-string> <add-string>
		Add <add-string> after line matching <match-string>
		Examples:
		mtaconf addafter /etc/amavisd.conf '@local_domains_maps' '$inet_socket_bind = '\''127.0.0.1'\'';'

	uniquelines  <file>
		remove the last line of imediately following duplcate lines
		Examples:
		mtaconf uniquelines /etc/opendkim/opendkim.conf
FILE
	full path to file which will be edited in place
"
}

define_formats() {
	name=$(basename $0)
	f_norm="\e[0m"
	f_bold="\e[1m"
	f_red="\e[91m"
	f_green="\e[92m"
	f_yellow="\e[93m"
}

inform() {
	local status=$1
	shift
	if [ "$status" == "-1" -a -n "${VERBOSE+x}" ]; then
		status="0"
	fi
	case $status in
	0) echo -e "$f_bold${f_green}INFO ($name)${f_norm} $@" ;;
	1) echo -e "$f_bold${f_yellow}WARN ($name)${f_norm} $@" ;;
	2) echo -e "$f_bold${f_red}ERROR ($name)${f_norm} $@" && exit ;;
	esac
}

#
# general file manipulation commands, used both during build and run time
#

_escape() { echo "$@" | sed 's|/|\\\/|g' | sed 's|;|\\\;|g'  | sed 's|\$|\\\$|g' | sed "s/""'""/\\\x27/g" ;}

modify() {
	local cfg_file=$1
	shift
	local lhs="$1"
	shift
	local eq=
	local rhs=
	if [ "$1" = "=" ]; then
		eq="$1"
		shift
		rhs="$(_escape $@)"
	else
		rhs="$(_escape $@)"
	fi
	inform -1 's/.*('"$lhs"'\s*'"$eq"'\s*)[^#]+(.*)/\1'"$rhs"' \2/g' $cfg_file
	sed -ri 's/.*('"$lhs"'\s*'"$eq"'\s*)[^#]+(.*)/\1'"$rhs"' \2/g' $cfg_file
}

replace() {
	local cfg_file=$1
	local old="$(_escape $2)"
	local new="$(_escape $3)"
	inform -1 's/'"$old"'/'"$new"'/g' $cfg_file
	sed -i 's/'"$old"'/'"$new"'/g' $cfg_file
}

addafter() {
	local cfg_file=$1
	local startline="$(_escape $2)"
	local new="$(_escape $3)"
	inform -1 '/'"$startline"'/!{p;d;}; $!N;s/\n\s*$/\n'"$new"'\n/g' $cfg_file
	sed -i '/'"$startline"'/!{p;d;}; $!N;s/\n\s*$/\n'"$new"'\n/g' $cfg_file
#	sed -ri '$!N;s/('"$startline"'.*\n)\s*$/\1\n'"$new"'\n/g;x;x' $cfg_file
#	sed -ri 'N;s/('"$startline"'.*)\n\s*$/\1\n'"$new"'\n/g' $cfg_file
#	sed -i '/'"$startline"'/a '"$new" $cfg_file
}

comment() {
	local cfg_file=$1
	local string="$2"
	inform -1 '/^'"$string"'/s/^/#/g' $cfg_file
	sed -i '/^'"$string"'/s/^/#/g' $cfg_file
}

uncommentsection() {
	local cfg_file=$1
	local startline="$(_escape $2)"
	inform -1 '/^'"$startline"'$/,/^\s*$/s/^#*//g' $cfg_file
	sed -i '/^'"$startline"'$/,/^\s*$/s/^#*//g' $cfg_file
}

removeline() {
	local cfg_file=$1
	local string="$2"
	inform -1 '/'"$string"'.*/d' $cfg_file
	sed -i '/'"$string"'.*/d' $cfg_file
}
uniquelines() {
	local cfg_file=$1
	inform -1 '$!N; /^(.*)\n\1$/!P; D' $cfg_file
	sed -ri '$!N; /^(.*)\n\1$/!P; D' $cfg_file
}

#
# run time commands
#

postconf_relay() {
	local hostauth=${1-$SMTP_RELAY_HOSTAUTH}
	local host=${hostauth% *}
	local auth=${hostauth#* }
	if [ -n "$host" ]; then
		inform 0 "Using SMTP relay: $host"
		postconf -e relayhost=$host
		if [ -n "$auth" ]; then
			postconf -e smtp_sasl_auth_enable=yes
			postconf -e smtp_sasl_password_maps=hash:$postfix_sasl_passwd
			postconf -e smtp_sasl_security_options=noanonymous
			echo "$hostauth" > $postfix_sasl_passwd
			postmap hash:$postfix_sasl_passwd
		fi
	else
		inform 0 "No SMTP relay defined"
	fi
}

postconf_amavis() {
	if apk info amavisd-new &>/dev/null
	then
	inform 0 "Configuring postfix-amavis"
	postconf -e content_filter=smtp-amavis:[localhost]:10024
	postconf -M "smtp-amavis/unix=smtp-amavis unix - - n - 2 smtp"
	postconf -P "smtp-amavis/unix/smtp_data_done_timeout=1200"
	postconf -P "smtp-amavis/unix/smtp_send_xforward_command=yes"
	postconf -P "smtp-amavis/unix/disable_dns_lookups=yes"
	postconf -P "smtp-amavis/unix/smtp_tls_security_level=none"
	postconf -P "smtp-amavis/unix/smtp_tls_wrappermode=no"
	postconf -P "smtp-amavis/unix/max_use=20"
	postconf -M "localhost:10025/inet=localhost:10025 inet n - n - - smtpd"
	postconf -P "localhost:10025/inet/content_filter="
	postconf -P "localhost:10025/inet/local_recipient_maps="
	postconf -P "localhost:10025/inet/relay_recipient_maps="
	postconf -P "localhost:10025/inet/smtpd_restriction_classes="
	postconf -P "localhost:10025/inet/smtpd_delay_reject=no"
	postconf -P "localhost:10025/inet/smtpd_client_restrictions=permit_mynetworks,reject"
	postconf -P "localhost:10025/inet/smtpd_helo_restrictions="
	postconf -P "localhost:10025/inet/smtpd_sender_restrictions="
	postconf -P "localhost:10025/inet/smtpd_recipient_restrictions=permit_mynetworks,reject"
	postconf -P "localhost:10025/inet/smtpd_data_restrictions=reject_unauth_pipelining"
	postconf -P "localhost:10025/inet/smtpd_end_of_data_restrictions="
	postconf -P "localhost:10025/inet/mynetworks=127.0.0.0/8"
	postconf -P "localhost:10025/inet/smtpd_error_sleep_time=0"
	postconf -P "localhost:10025/inet/smtpd_soft_error_limit=1001"
	postconf -P "localhost:10025/inet/smtpd_hard_error_limit=1000"
	postconf -P "localhost:10025/inet/smtpd_client_connection_count_limit=0"
	postconf -P "localhost:10025/inet/smtpd_client_connection_rate_limit=0"
	postconf -P "localhost:10025/inet/receive_override_options=no_header_body_checks,no_unknown_recipient_checks"
	postconf -P "pickup/unix/content_filter="
	postconf -P "pickup/unix/receive_override_options=no_header_body_checks"
	fi
}

mtaconf_amavis() {
	local domain=${MAIL_DOMAIN-$(hostname -d)}
	if apk info amavisd-new &>/dev/null; then
		inform 0 "Configuring amavis"
		modify /etc/amavisd.conf '\$mydomain' = "'"$domain"';"
#		modify /etc/amavisd.conf '\$sa_tag_level_deflt' = '-999;'
#		modify /etc/mail/spamassassin/local.cf use_bayes 1
#		modify /etc/mail/spamassassin/local.cf bayes_auto_learn 1
	fi
}

postconf_opendkim() {
	if apk info opendkim &>/dev/null
	then
	inform 0 "Configuring postfix-opendkim"
	postconf -e milter_default_action=accept
	postconf -e milter_protocol=2
	postconf -e non_smtpd_milters=unix:/run/opendkim/opendkim.sock
	postconf -e smtpd_milters=unix:/run/opendkim/opendkim.sock
	postconf -P "localhost:10025/inet/receive_override_options=no_header_body_checks,no_unknown_recipient_checks,no_milters"
	fi
}

mtaconf_opendkim() {
	local cfgfile=/etc/opendkim/opendkim.conf
	local dbdir=/var/db/dkim
	local user=opendkim
	local bits=${DKIM_KEYBITS-2048}
	local domain=${MAIL_DOMAIN-$(hostname -d)}
	local selector=${DKIM_SELECTOR-default}
	local keyfile=$dbdir/$selector.private
	local keystring="$DKIM_PRIVATEKEY"
	local email=${POSTMASTER-postmaster}@$domain
	if [ -e $cfgfile ]; then
		inform 0 "Setting dkim selector and domain to $selector and $domain"
		modify $cfgfile Domain $domain
		modify $cfgfile Selector $selector
		modify $cfgfile ReportAddress $email
		modify $cfgfile KeyFile $keyfile
		if [ -n "$keystring" ]; then
			if [ -e $keyfile ]; then
				inform 1 "Overwriting private dkim key here $keyfile"
			else
				inform 0 "Writing private dkim key here $keyfile"
			fi
			if echo "$keystring" | grep "PRIVATE KEY" - > /dev/null; then
				echo "$keystring" fold -w 64 >> $keyfile
			else
				echo "-----BEGIN RSA PRIVATE KEY-----" > $keyfile
				echo "$keystring" | fold -w 64 >> $keyfile
				echo "-----END RSA PRIVATE KEY-----" >> $keyfile
			fi
		fi
		if [ ! -e $keyfile ]; then
			inform 1 "Generating private dkim key here $keyfile"
			opendkim-genkey --directory=$dbdir --bits=$bits --selector=$selector --domain=$domain
		fi
		if [ -n "$(find $dbdir ! -user $user -print -exec chown -h $user: {} \;)" ]; then
			inform 0 "Changed owner to $user for some files in $dbdir"
		fi
	fi
}

update_dkimkey() {
	# you can call this function using optional args: bits
	local defbits=${DKIM_KEYBITS-2048}
	local bits=${1-$defbits}
	local dbdir=/var/db/dkim
	local domain=${MAIL_DOMAIN-$(hostname -d)}
	local selector=${DKIM_SELECTOR-default}
	inform 0 "Generating new private dkim signing key $dbdir/$selector.private"
	opendkim-genkey --directory=$dbdir --bits=$bits --selector=$selector --domain=$domain
	inform 0 "Please update the domain TXT record according to:"
	cat $dbdir/$selector.txt
}

postconf_spf() {
	if apk info postfix-policyd-spf-perl &>/dev/null
	then
	inform 0 "Configuring postfix-spf"
	postconf -e policyd-spf_time_limit=3600s
	postconf -e "smtpd_recipient_restrictions=permit_sasl_authenticated, permit_mynetworks, reject_unauth_destination, check_policy_service unix:private/policyd-spf"
	postconf -M "policyd-spf/unix=policyd-spf unix - n n - - spawn user=nobody argv=/usr/bin/postfix-policyd-spf-perl"
	fi
}

postconf_ldap_map() {
	local server_host="$LDAP_HOST"
	local search_base="$1"
	local result_attribute="$2"
	local query_filter="$3"
	local bind_dn="$LDAP_BIND_DN"
	local bind_pw="$LDAP_BIND_PW"
	cat <<-!cat
		server_host = $server_host
		search_base = $search_base
		version = 3
		scope = sub
		result_attribute = $result_attribute
		query_filter = $query_filter
	!cat
	if [ -n "$bind_dn" ]; then
	cat <<-!cat
		bind = yes
		bind_dn = $bind_dn
		bind_pw = $bind_pw
	!cat
	fi
}

postconf_ldap() {
	if [ -n "$LDAP_HOST" -a -n "$LDAP_USER_BASE" -a -n "$LDAP_QUERY_FILTER_USER" ]; then
		inform 0 "Configuring postfix-ldap"
		postconf alias_database=
		postconf virtual_mailbox_domains='$mydomain'
		postconf alias_maps=
		postconf virtual_mailbox_maps=ldap:$postfix_ldap_users_cf
		postconf_ldap_map "$LDAP_USER_BASE" mail "$LDAP_QUERY_FILTER_USER" > $postfix_ldap_users_cf
		if [ -n "$LDAP_QUERY_FILTER_ALIAS" ]; then
			postconf_ldap_map "$LDAP_USER_BASE" mail "$LDAP_QUERY_FILTER_ALIAS" > $postfix_ldap_alias_cf
			if [ -n "$LDAP_GROUP_BASE" -a -n "$LDAP_QUERY_FILTER_GROUP" -a -n "$LDAP_QUERY_FILTER_EXPAND" ]; then
				postconf virtual_alias_maps="ldap:$postfix_ldap_alias_cf, ldap:$postfix_ldap_groups_cf, ldap:$postfix_ldap_expand_cf"
				postconf_ldap_map "$LDAP_GROUP_BASE" memberUid "$LDAP_QUERY_FILTER_GROUP" > $postfix_ldap_groups_cf
				postconf_ldap_map "$LDAP_GROUP_BASE" mail "$LDAP_QUERY_FILTER_EXPAND" > $postfix_ldap_expand_cf
			else
				postconf virtual_alias_maps=ldap:$postfix_ldap_alias_cf
			fi
		fi
	fi
}

postconf_mbox() {
	local emails="${1-$MAIL_BOXES}"
	if [ -n "$emails" ]; then
		inform 0 "Configuring postfix-virt-mailboxes"
		for email in $emails; do
			echo $email ${email#*@}/${email%@*} >> $postfix_virt_mailbox
		done
		postconf alias_database=
		postconf virtual_mailbox_domains='$mydomain'
		postconf alias_maps=
		postconf virtual_mailbox_maps=hash:$postfix_virt_mailbox
		postmap hash:$postfix_virt_mailbox
	fi
}

#postconf_transport() {
#	if [ -n "$DAGENT_TRANSPORT" ]; then
#		inform 0 "Configuring postfix-transport"
#		postconf -e virtual_transport=$DAGENT_TRANSPORT
#	fi
#}

mtaupdate_cert() {
	# we are potentially updating $SMTPD_TLS_CERT_FILE and $SMTPD_TLS_KEY_FILE
	# here so we need to run this func before postconf_tls and postconf_envvar
	ACME_FILE=${ACME_FILE-/acme/acme.json}
	if [ -x $(which dumpcerts.sh) -a -f $ACME_FILE ]; then
		inform 0 "Configuring acme-tls"
		HOSTNAME=${HOSTNAME-$(hostname)}
		ACME_TLS_DIR=${ACME_TLS_DIR-/tmp/ssl}
		ACME_TLS_CERT_FILE=$ACME_TLS_DIR/certs/${HOSTNAME}.crt
		ACME_TLS_KEY_FILE=$ACME_TLS_DIR/private/${HOSTNAME}.key
		SMTPD_TLS_DIR=${SMTPD_TLS_DIR-/etc/postfix/ssl}
		export SMTPD_TLS_CERT_FILE=${SMTPD_TLS_CERT_FILE-$ACME_TLS_CERT_FILE}
		export SMTPD_TLS_KEY_FILE=${SMTPD_TLS_KEY_FILE-$ACME_TLS_KEY_FILE}
		local runit_dir=$docker_build_runit_root/acme
		mkdir -p $SMTPD_TLS_DIR $ACME_TLS_DIR $runit_dir
		cat <<-! > $runit_dir/run
			#!/bin/bash -e
			
			# redirect stdout/stderr to syslog
			exec 1> >(logger -p mail.info)
			exec 2> >(logger -p mail.notice)
			
			dump() {
			  dumpcerts.sh $ACME_FILE $ACME_TLS_DIR
			}
			dump
			while true; do
			  inotifywait -e modify $ACME_FILE
			  dump
			done
		!
		chmod +x $runit_dir/run
	fi
}

postconf_tls() {
	if [ -n "$SMTPD_TLS_CERT_FILE" -o -n "$SMTPD_TLS_ECCERT_FILE" ]; then
		inform 0 "Activating incoming tls"
		postconf -e smtpd_use_tls=yes
	fi
}

postconf_edh() {
	# this takes a long time. run this manually once the container is up by:
	# mtaconf postconf_edh
	if apk info openssl &>/dev/null; then
		inform 0 "Configuring postfix-edh"
		SMTPD_TLS_DIR=${SMTPD_TLS_DIR-/etc/postfix/ssl}
		cd $SMTPD_TLS_DIR
#		umask 022
		openssl dhparam -out dh512.tmp 512 && mv dh512.tmp dh512.pem
		openssl dhparam -out dh1024.tmp 1024 && mv dh1024.tmp dh1024.pem
		openssl dhparam -out dh2048.tmp 2048 && mv dh2048.tmp dh2048.pem
		chmod 644 dh512.pem dh1024.pem dh2048.pem
		cd - &>/dev/null
		postconf -e smtpd_tls_dh1024_param_file=$SMTPD_TLS_DIR/dh2048.pem
		postconf -e smtpd_tls_dh512_param_file=$SMTPD_TLS_DIR/dh512.pem
	fi
}

_amavis_envvar() {
	# allow amavis parameters to be modified using environment variables
	local env_var="$1"
	local lcase_var="$2"
	local env_val
	if [ -z "${amavis_var##*$env_var*}" ]; then
		env_val="$(eval echo \$$env_var)"
		inform 0 "Setting amavis parameter $lcase_var = $env_val"
		modify $amavis_cf '\$'$lcase_var = "$env_val;"
	fi
}

postconf_envvar() {
	# some postfix parameters start with a digit and may contain dash "-"
	# and so are not legal variable names
	local env_vars="$(export -p | sed -r 's/export ([^=]+).*/\1/g')"
	local lcase_var env_val
	for env_var in $env_vars; do
		lcase_var="$(echo $env_var | sed 's/\(.*\)/\L\1/')"
		if [ "$(postconf -H $lcase_var 2>/dev/null)" == "$lcase_var" ]; then
			env_val="$(eval echo \$$env_var)"
			inform 0 "Setting postfix parameter $lcase_var = $env_val"
			postconf $lcase_var="$env_val"
		fi
		_amavis_envvar $env_var $lcase_var
	done
}

mtaconf_nolog() {
	if apk info clamav &>/dev/null; then
		inform 0 "Configuring no logs for clam"
		comment /etc/clamav/freshclam.conf UpdateLogFile /var/log/clamav/freshclam.log
		comment /etc/clamav/clamd.conf LogFile /var/log/clamav/clamd.log
	fi
}

mtaupdate_sa() {
	if apk info spamassassin &>/dev/null; then
		inform 0 "Updating rules for spamassassin"
		( sa-update ) &
	fi
}

loglevel() {
	if [ -n "$SYSLOG_LEVEL" -a $SYSLOG_LEVEL -ne 4 ]; then
		setup-runit.sh "syslogd -n -O /dev/stdout -l $SYSLOG_LEVEL"
	fi
}

#
# allow functions to be accessed on cli
#

cli_and_exit() {
	if [ "$(basename $0)" = mtaconf ]; then
		local cmd=$1
		if [ -n "$cmd" ]; then
			shift
			inform -1 "CMD:$cmd ARG:$@"
			$cmd "$@"
		else
			usage
		fi
		exit 0
	fi
}

#
# allow command line interface
#

define_formats
cli_and_exit "$@"

#
# configure services
#

postconf_relay
postconf_amavis
mtaconf_amavis
#mtaconf_nolog
postconf_mbox
postconf_ldap
#postconf_transport
postconf_opendkim
mtaconf_opendkim
postconf_spf
mtaupdate_cert
postconf_tls
postconf_envvar

#
# Download rules for spamassassin at start up.
# There is also an daily cron job that updates these.
#

loglevel
mtaupdate_sa

#
# start services
#

exec runsvdir -P $docker_build_runit_root

