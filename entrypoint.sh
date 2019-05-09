#!/bin/sh -e

#
# config
#

docker_build_runit_root=${docker_build_runit_root-/etc/service}
postfix_sasl_passwd=${postfix_sasl_passwd-/etc/postfix/sasl-passwords}
postfix_virt_mailbox=${postfix_virt_mailbox-/etc/postfix/virt-users}
postfix_virt_domain=${postfix_virt_domain-/etc/postfix/virt-domains}
postfix_virt_mailroot=${postfix_virt_mailroot-/var/mail}
postfix_virt_mailuser=${postfix_virt_mailuser-postfix}
postfix_ldap_users_cf=${postfix_ldap_users_cf-/etc/postfix/ldap-users.cf}
postfix_ldap_alias_cf=${postfix_ldap_alias_cf-/etc/postfix/ldap-aliases.cf}
postfix_ldap_groups_cf=${postfix_ldap_groups_cf-/etc/postfix/ldap-groups.cf}
postfix_ldap_expand_cf=${postfix_ldap_expand_cf-/etc/postfix/ldap-groups-expand.cf}
postfix_smtpd_tls_dir=${postfix_smtpd_tls_dir-/etc/postfix/ssl}
amavis_cf=${amavis_cf-/etc/amavisd.conf}
amavis_dkim_dir=${amavis_dkim_dir-/var/db/dkim}
amavis_dkim_user=${amavis_dkim_user-amavis}
dovecot_users=${dovecot_users-/etc/dovecot/virt-passwd}
dovecot_cf=${dovecot_cf-/etc/dovecot/dovecot.conf}
#dovecot_cf=${dovecot_cf-/etc/dovecot/conf.d/99-docker.conf}

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
	if ([ "$status" = "-1" ] && [ -n "${VERBOSE+x}" ]); then
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

postconf_dovecot() {
	local clientauth=${1-$SMTPD_SASL_CLIENTAUTH}
	# dovecot need to be installed
	if (apk info dovecot &>/dev/null && [ -n "$clientauth" ]); then
		inform 0 "Enabling client SASL via submission"
		# create client passwd file used for autentication
		for entry in $clientauth; do
			echo $entry >> $dovecot_users
		done
		# enable sasl auth on the submission port
		postconf -e smtp_sasl_security_options=noanonymous
		postconf -e smtpd_sasl_auth_enable=yes
		postconf -M "submission/inet=submission inet n - n - - smtpd"
		postconf -P "submission/inet/smtpd_sasl_auth_enable=yes"
		postconf -P "submission/inet/smtpd_sasl_type=dovecot"
		postconf -P "submission/inet/smtpd_sasl_path=private/auth"
		postconf -P "submission/inet/smtpd_sasl_security_options=noanonymous"
		postconf -P "submission/inet/smtpd_client_restrictions=permit_sasl_authenticated,reject"
		postconf -P "submission/inet/smtpd_recipient_restrictions=reject_non_fqdn_recipient,reject_unknown_recipient_domain,permit_sasl_authenticated,reject"
	fi
}

doveadm_pw() { doveadm pw -p $1 ;}

modify_dovecot_conf() {
	# configure dovecot to use passwd-file
	[ -e ${1-$dovecot_cf} ] && cp $dovecot_cf $dovecot_cf.dist
	cat <<-!cat > ${1-$dovecot_cf}
		ssl = no
		disable_plaintext_auth = no
		auth_mechanisms = plain login
		passdb {
		    driver = passwd-file
		    args = ${2-$dovecot_users}
		}
		userdb {
		    driver = static
		    args = uid=500 gid=500 home=/home/%u
		}
		service auth {
		    unix_listener /var/spool/postfix/private/auth {
		        mode  = 0660
		        user  = $postfix_virt_mailuser
		        group = $postfix_virt_mailuser
		    }
		}
	!cat
	[ -e ${1-$dovecot_cf} ] && cp $dovecot_cf $dovecot_cf.build
}

postconf_domains() {
	# configure domains if we have recipients
	local domains=${MAIL_DOMAIN-$(hostname -d)}
	if [ -n "$domains" ] && ([ -n "$LDAP_HOST" ] || [ -n "$MAIL_BOXES" ]); then
		inform 0 "Configuring postfix for domains $domains"
		if [ $(echo $domains | wc -w) -gt 1 ]; then
			for domain in $domains; do
				echo "$domain #domain" >> $postfix_virt_domain
			done
			postconf virtual_mailbox_domains=hash:$postfix_virt_domain
			postmap  hash:$postfix_virt_domain
		else
			postconf mydomain=$domains
			postconf virtual_mailbox_domains='$mydomain'
		fi
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

mtaconf_amavis_domain() {
	local domains=${MAIL_DOMAIN-$(hostname -d)}
	local domain_main=$(echo $domains | sed 's/\s.*//')
	local domain_extra=$(echo $domains | sed 's/[^ ]* *//' | sed 's/[^ ][^ ]*/"&"/g' | sed 's/ /, /g')
	if apk info amavisd-new &>/dev/null; then
		inform 0 "Configuring amavis for domains $domains"
		modify $amavis_cf '\$mydomain' = "'"$domain_main"';"
		if [ $(echo $domains | wc -w) -gt 1 ]; then
			modify $amavis_cf '@local_domains_maps' = '( [".$mydomain", '$domain_extra'] );'
		fi
	fi
}

mtaconf_amavis_dkim() {
	# generate and activate dkim domainkey.
	# incase of multi domain generate key for first domain only, but accept it
	# to be used for all domains specified.
	local domains=${MAIL_DOMAIN-$(hostname -d)}
	local domain_main=$(echo $domains | sed 's/\s.*//')
	local user=$amavis_dkim_user
	local bits=${DKIM_KEYBITS-2048}
	local selector=${DKIM_SELECTOR-default}
	local keyfile=$amavis_dkim_dir/$domain_main.$selector.privkey.pem
	local txtfile=$amavis_dkim_dir/$domain_main.$selector._domainkey.txt
	local keystring="$DKIM_PRIVATEKEY"
	if apk info amavisd-new &>/dev/null; then
		inform 0 "Setting dkim selector and domain to $selector and $domain_main"
		# insert config statements just before last line
		local lastline="$(sed -i -e '$ w /dev/stdout' -e '$d' $amavis_cf)"
		cat <<-!cat >> $amavis_cf
			dkim_key("$domain_main", "$selector", "$keyfile");
			@dkim_signature_options_bysender_maps = ( { "." => { ttl => 21*24*3600, c => "relaxed/simple" } } );
			
			
			$lastline
		!cat
		#nl $amavis_cf | tail -n 20
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
			local message="$(amavisd genrsa $keyfile $bits 2>&1)"
			inform 1 "$message"
			amavisd showkeys $domain_main > $txtfile
			#amavisd testkeys $domain_main
		fi
		if [ -n "$(find $amavis_dkim_dir ! -user $user -print -exec chown -h $user: {} \;)" ]; then
			inform 0 "Changed owner to $user for some files in $dbdir"
		fi
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

update_opendkimkey() {
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
	if apk info postfix-policyd-spf-perl &>/dev/null; then
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
	if ([ -n "$LDAP_HOST" ] && [ -n "$LDAP_USER_BASE" ] && [ -n "$LDAP_QUERY_FILTER_USER" ]); then
		inform 0 "Configuring postfix-ldap"
		postconf alias_maps=
		postconf alias_database=
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
		if [ -z "$VIRTUAL_TRANSPORT" ]; then # need local mail boxes
			mkdir -p $postfix_virt_mailroot
			chown $postfix_virt_mailuser: $postfix_virt_mailroot
			postconf virtual_mailbox_base=$postfix_virt_mailroot
			postconf virtual_uid_maps=static:$(id -u $postfix_virt_mailuser)
			postconf virtual_gid_maps=static:$(id -g $postfix_virt_mailuser)
		fi
	fi
}

postconf_mbox() {
	local emails="${1-$MAIL_BOXES}"
	if [ -n "$emails" ]; then
		inform 0 "Configuring postfix-virt-mailboxes"
		for email in $emails; do
			echo $email $email >> $postfix_virt_mailbox
#			echo $email ${email#*@}/${email%@*} >> $postfix_virt_mailbox
#			if [ -z "$VIRTUAL_TRANSPORT" ]; then # need local mail boxex
#				mkdir -m 777 -p $postfix_virt_mailroot/${email#*@}
#			fi
		done
		postconf alias_maps=
		postconf alias_database=
		postconf virtual_mailbox_maps=hash:$postfix_virt_mailbox
		postmap hash:$postfix_virt_mailbox
		if [ -z "$VIRTUAL_TRANSPORT" ]; then # need local mail boxex
			mkdir -p $postfix_virt_mailroot
			chown $postfix_virt_mailuser: $postfix_virt_mailroot
			postconf virtual_mailbox_base=$postfix_virt_mailroot
			postconf virtual_uid_maps=static:$(id -u $postfix_virt_mailuser)
			postconf virtual_gid_maps=static:$(id -g $postfix_virt_mailuser)
		fi
	fi
}

mtaupdate_cert() {
	# we are potentially updating $SMTPD_TLS_CERT_FILE and $SMTPD_TLS_KEY_FILE
	# here so we need to run this func before postconf_tls and postconf_envvar
	ACME_FILE=${ACME_FILE-/acme/acme.json}
	if ([ -x $(which dumpcerts.sh) ] && [ -f $ACME_FILE ]); then
		inform 0 "Configuring acme-tls"
		HOSTNAME=${HOSTNAME-$(hostname)}
		ACME_TLS_DIR=${ACME_TLS_DIR-/tmp/ssl}
		ACME_TLS_CERT_FILE=$ACME_TLS_DIR/certs/${HOSTNAME}.crt
		ACME_TLS_KEY_FILE=$ACME_TLS_DIR/private/${HOSTNAME}.key
		export SMTPD_TLS_CERT_FILE=${SMTPD_TLS_CERT_FILE-$ACME_TLS_CERT_FILE}
		export SMTPD_TLS_KEY_FILE=${SMTPD_TLS_KEY_FILE-$ACME_TLS_KEY_FILE}
		local runit_dir=$docker_build_runit_root/acme
		mkdir -p $postfix_smtpd_tls_dir $ACME_TLS_DIR $runit_dir
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
	if ([ -n "$SMTPD_TLS_CERT_FILE" ] || [ -n "$SMTPD_TLS_ECCERT_FILE" ]); then
		inform 0 "Activating incoming tls"
		postconf -e smtpd_use_tls=yes
	fi
}

regen_edh() {
	# Optionally generate non-default Postfix SMTP server EDH parameters for improved security
	# note, since 2015, 512 bit export ciphers are no longer used
	# this takes a long time. run this manually once the container is up by:
	# mtaconf regen_edh
	# smtpd_tls_dh1024_param_file
	local bits=${1-2048}
	if apk info openssl &>/dev/null; then
		inform 0 "Regenerating postfix edh $bits bit parameters"
		mkdir -p $postfix_smtpd_tls_dir
		openssl dhparam -out $postfix_smtpd_tls_dir/dh$bits.pem $bits
		postconf smtpd_tls_dh1024_param_file=$postfix_smtpd_tls_dir/dh$bits.pem
	else
		inform 1 "Cannot regenerate edh since openssl is not installed"
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
		lcase_var="$(echo $env_var | tr '[:upper:]' '[:lower:]')"
		if [ "$(postconf -H $lcase_var 2>/dev/null)" = "$lcase_var" ]; then
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

postconf_domains
postconf_relay
postconf_amavis
mtaconf_amavis_domain
mtaconf_amavis_dkim
postconf_mbox
postconf_ldap
postconf_opendkim
mtaconf_opendkim
#postconf_spf
mtaupdate_cert
postconf_tls
postconf_dovecot
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

