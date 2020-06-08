#!/bin/sh
#
# docker-postfix.inc
#
# Define variables and functions used during container initialization here
# and source this file in entry.d and exit.d files.
#

#
# Depends
#
#. docker-common.sh

#
# config
#
DOCKER_RUNSV_DIR=${DOCKER_RUNSV_DIR-/etc/service}
DOCKER_PERSIST_DIR=${DOCKER_PERSIST_DIR-/srv}
docker_config_lock=${docker_config_lock-/etc/postfix/docker-config-lock}
docker_default_domain=${docker_default_domain-example.com}
postfix_sasl_passwd=${postfix_sasl_passwd-/etc/postfix/sasl-passwords}
postfix_virt_mailbox=${postfix_virt_mailbox-/etc/postfix/virt-users}
postfix_virt_domain=${postfix_virt_domain-/etc/postfix/virt-domains}
postfix_aliases=${postfix_aliases-/etc/postfix/aliases}
mail_dir=${mail_dir-/var/mail}
postfix_cf=${postfix_cf-/etc/postfix/main.cf}
postfix_runas=${postfix_runas-postfix}
postfix_ldap_users_cf=${postfix_ldap_users_cf-/etc/postfix/ldap-users.cf}
postfix_ldap_alias_cf=${postfix_ldap_alias_cf-/etc/postfix/ldap-aliases.cf}
postfix_ldap_groups_cf=${postfix_ldap_groups_cf-/etc/postfix/ldap-groups.cf}
postfix_ldap_expand_cf=${postfix_ldap_expand_cf-/etc/postfix/ldap-groups-expand.cf}
postfix_smtpd_tls_dir=${postfix_smtpd_tls_dir-/etc/ssl/postfix}
postfix_home=${postfix_home-/var/spool/postfix}
amavis_runas=${amavis_runas-amavis}
amavis_home=${amavis_home-/var/amavis}
amavis_cf=${amavis_cf-/etc/amavis/amavisd.conf}
dkim_dir=${dkim_dir-/var/db/dkim}
dovecot_users=${dovecot_users-/etc/dovecot/virt-passwd}
dovecot_cf=${dovecot_cf-/etc/dovecot/dovecot.conf}
razor_url=${razor_url-discovery.razor.cloudmark.com}
razor_home=${razor_home-/var/amavis/.razor}
razor_identity=${razor_identity-$razor_home/identity}
razor_runas=${razor_runas-amavis}
acme_dump_tls_dir=${acme_dump_tls_dir-/etc/ssl/acme}
acme_dump_json_link=${acme_dump_json_link-$acme_dump_tls_dir/acme.json}
acme_dump_sv_dir=${acme_dump_sv_dir-$DOCKER_RUNSV_DIR/acme}
ACME_FILE=${ACME_FILE-/acme/acme.json}
DOCKER_SPAMD_DIR=${DOCKER_SPAMD_DIR-/var/lib/kopano/spamd}
DOCKER_SPAMD_SV_DIR=${DOCKER_SPAMD_SV_DIR-$DOCKER_RUNSV_DIR/spamd}

#
# define environment variables
#

amavis_var="FINAL_VIRUS_DESTINY FINAL_BANNED_DESTINY FINAL_SPAM_DESTINY FINAL_BAD_HEADER_DESTINY SA_TAG_LEVEL_DEFLT SA_TAG2_LEVEL_DEFLT SA_KILL_LEVEL_DEFLT SA_DEBUG LOG_LEVEL"

#
# package install functions
#

imgcfg_dovecot_passwdfile() {
	# run during build time
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
		        user  = $postfix_runas
		        group = $postfix_runas
		    }
		}
	!cat
	[ -e ${1-$dovecot_cf} ] && cp $dovecot_cf $dovecot_cf.bld
}

imgcfg_runit_acme_dump() {
	if _is_installed jq; then
		dc_log 5 "Setting up acme-update service"
		mkdir -p $acme_dump_sv_dir
		cat <<-!cat > $acme_dump_sv_dir/run
			#!/bin/sh -e
			# define helpers
			exec 2>&1
			# run dumpcerts.sh when $acme_dump_json_link changes
			exec $(which inotifyd) $(which dumpcerts.sh) $acme_dump_json_link:c
		!cat
		chmod +x $acme_dump_sv_dir/run
		# make sure that there is a file that inotifyd can monitor
		# we will replace this file if we detect a proper one
		touch $acme_dump_json_link
	fi
}

imgcfg_amavis_postfix() {
	# https://amavis.org/README.postfix.html#basics_transport
	# https://amavis.org/README.postfix.html#d0e1110
	dc_log 5 "Configuring postfix-amavis"
	postconf -e content_filter=smtp-amavis:[localhost]:10024
	postconf -M "smtp-amavis/unix=smtp-amavis unix - - n - 2 smtp"
	postconf -P "smtp-amavis/unix/syslog_name=postfix/amavis"
	postconf -P "smtp-amavis/unix/smtp_data_done_timeout=1200"
	postconf -P "smtp-amavis/unix/smtp_send_xforward_command=yes"
	postconf -P "smtp-amavis/unix/disable_dns_lookups=yes"
	postconf -P "smtp-amavis/unix/smtp_tls_security_level=none"
	postconf -P "smtp-amavis/unix/smtp_tls_wrappermode=no"
	postconf -P "smtp-amavis/unix/max_use=20"
	postconf -M "localhost:10025/inet=localhost:10025 inet n - n - - smtpd"
	postconf -P "localhost:10025/inet/syslog_name=postfix/amavis"
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
	postconf -P "localhost:10025/inet/local_header_rewrite_clients="
	postconf -P "localhost:10025/inet/receive_override_options=no_header_body_checks,no_unknown_recipient_checks,no_milters"
	postconf -M "pre-cleanup/unix=pre-cleanup unix n - n - 0 cleanup"
	postconf -P "pre-cleanup/unix/syslog_name=postfix/pre"
	postconf -P "pre-cleanup/unix/virtual_alias_maps="
	postconf -P "cleanup/unix/mime_header_checks="
	postconf -P "cleanup/unix/nested_header_checks="
	postconf -P "cleanup/unix/body_checks="
	postconf -P "cleanup/unix/header_checks="
	postconf -P "smtp/inet/cleanup_service_name=pre-cleanup"
	postconf -P "pickup/unix/cleanup_service_name=pre-cleanup"
#	postconf -P "pickup/unix/content_filter="
#	postconf -P "pickup/unix/receive_override_options=no_header_body_checks"
}

imgdir_persist() {
	# mv dir to persist location and leave a link to it
	local srcdirs="$@"
	if [ -n "$DOCKER_PERSIST_DIR" ]; then
		for srcdir in $srcdirs; do
			if [ -e "$srcdir" ]; then
				local dstdir="${DOCKER_PERSIST_DIR}${srcdir}"
				local dsthome="$(dirname $dstdir)"
				if [ ! -d "$dstdir" ]; then
					dc_log 5 "Moving $srcdir to $dstdir"
					mkdir -p "$dsthome"
					mv "$srcdir" "$dsthome"
					ln -sf "$dstdir" "$srcdir"
				else
					dc_log 4 "$srcdir already moved to $dstdir"
				fi
			else
				dc_log 4 "Cannot find $srcdir"
			fi
		done
	fi
}

imgcfg_cpfile() {
	local suffix=$1
	shift
	local cfs=$@
	for cf in $cfs; do
		cp "$cf" "$cf.$suffix"
	done
}

imgcfg_mvfile() {
	local suffix=$1
	shift
	local cfs=$@
	for cf in $cfs; do
		mv "$cf" "$cf.$suffix"
	done
}

#
# package config procedure
#

_need_config() { [ ! -f "$docker_config_lock" ] || [ -n "$FORCE_CONFIG" ] ;}
	# true if there is no lock file or FORCE_CONFIG is not empty

_is_installed() { apk -e info $1 &>/dev/null ;} # true if pkg is installed

_cond_append() {
	# append entry if it is not already there
	# if mode is -i then append before last line
	local mode filename lineraw lineesc
	case $1 in
		-i) mode=i; shift;;
		-a) mode=a; shift;;
		 *) mode=a;;
	esac
	filename=$1
	shift
	lineraw=$@
	lineesc="$(echo $lineraw | sed 's/[\";/*]/\\&/g')"
	if [ -e "$filename" ]; then
		if [ -z "$(sed -n '/'"$lineesc"'/p' $filename)" ]; then
			dc_log 7 "_cond_append append: $mode $filename $lineraw"
			case $mode in
				a) echo "$lineraw" >> $filename;;
				i) sed -i "$ i\\$lineesc" $filename;;
			esac
		else
			dc_log 4 "Avoiding duplication: $filename $lineraw"
		fi
	else
		dc_log 7 "_cond_append create: $mode $filename $lineraw"
		echo "$lineraw" >> $filename
	fi
}

lock_config() {
	local lock_str=$(cat <<-!cat
		$(date) $(basename $0):

		%s configuration completed.

		Don't remove this file, it prevents the configuration from
		being overwritten on container restart!
		!cat
		)
	if [ -z "$FORCE_CONFIG" ]; then
		printf "$lock_str" "Virgin" > "$docker_config_lock"
	else
		printf "$lock_str" "Forced" > "$docker_config_lock"
	fi
}

cntrun_cfgall() {
	if _need_config; then
		cntcfg_default_domains
		cntcfg_acme_postfix_tls_cert
		cntcfg_amavis_domains
		cntcfg_amavis_dkim
		cntcfg_amavis_apply_envvars
		cntcfg_dovecot_smtpd_auth_pwfile
		cntcfg_postfix_domains
		cntcfg_postfix_smtp_auth_pwfile
		cntcfg_postfix_mailbox_auth_hash
		cntcfg_postfix_mailbox_auth_ldap
		cntcfg_postfix_alias_map
		cntcfg_postfix_generate_tls_cert
		cntcfg_postfix_activate_tls_cert
		cntcfg_postfix_apply_envvars
		cntcfg_razor_register
		lock_config
	else
		dc_log 5 "Found config lock file, so not touching configuration"
	fi
}

#
# package config units
#

cntcfg_postfix_smtp_auth_pwfile() {
	local hostauth=${1-$SMTP_RELAY_HOSTAUTH}
	local host=${hostauth% *}
	local auth=${hostauth#* }
	if [ -n "$host" ]; then
		dc_log 5 "Configuring postfix SMTP relay: $host"
		postconf -e relayhost=$host
		if [ -n "$auth" ]; then
			postconf -e smtp_sasl_auth_enable=yes
			postconf -e smtp_sasl_password_maps=hash:$postfix_sasl_passwd
			postconf -e smtp_sasl_security_options=noanonymous
			echo "$hostauth" > $postfix_sasl_passwd
			postmap hash:$postfix_sasl_passwd
		fi
	else
		dc_log 7 "No SMTP relay defined"
	fi
}

cntcfg_dovecot_smtpd_auth_pwfile() {
	local clientauth=${1-$SMTPD_SASL_CLIENTAUTH}
	# dovecot need to be installed
	if (_is_installed dovecot && [ -n "$clientauth" ]); then
		dc_log 5 "Enabling postfix-dovecot client SASL via submission"
		# create client passwd file used for autentication
		for entry in $clientauth; do
			_cond_append $dovecot_users $entry
		done
		# enable sasl auth on the submission port
		postconf -M "submission/inet=submission inet n - n - - smtpd"
		postconf -P "submission/inet/syslog_name=postfix/submission"
		postconf -P "submission/inet/smtpd_sasl_auth_enable=yes"
		postconf -P "submission/inet/smtpd_sasl_type=dovecot"
		postconf -P "submission/inet/smtpd_sasl_path=private/auth"
		postconf -P "submission/inet/smtpd_sasl_security_options=noanonymous"
		postconf -P "submission/inet/smtpd_tls_security_level=encrypt"
		postconf -P "submission/inet/smtpd_tls_auth_only=yes"
		postconf -P "submission/inet/smtpd_client_restrictions=permit_sasl_authenticated,reject"
		postconf -P "submission/inet/smtpd_recipient_restrictions=permit_auth_destination,reject"
#		postconf -P "submission/inet/smtpd_recipient_restrictions=reject_non_fqdn_recipient,reject_unknown_recipient_domain,permit_sasl_authenticated,reject"
		postconf -M "smtps/inet=smtps inet n - n - - smtpd"
		postconf -P "smtps/inet/syslog_name=postfix/smtps"
		postconf -P "smtps/inet/smtpd_sasl_auth_enable=yes"
		postconf -P "smtps/inet/smtpd_sasl_type=dovecot"
		postconf -P "smtps/inet/smtpd_sasl_path=private/auth"
		postconf -P "smtps/inet/smtpd_sasl_security_options=noanonymous"
		postconf -P "smtps/inet/smtpd_tls_security_level=encrypt"
		postconf -P "smtps/inet/smtpd_tls_auth_only=yes"
		postconf -P "smtps/inet/smtpd_tls_wrappermode=yes"
		postconf -P "smtps/inet/smtpd_client_restrictions=permit_sasl_authenticated,reject"
		postconf -P "smtps/inet/smtpd_recipient_restrictions=permit_auth_destination,reject"
#  postconf -P "smtps/inet/smtpd_reject_unlisted_recipient=yes"
		if _is_installed amavisd-new; then
			postconf -P "submission/inet/cleanup_service_name=pre-cleanup"
			postconf -P "smtps/inet/cleanup_service_name=pre-cleanup"
		fi
	fi
}

cntcfg_default_domains() {
	# run first to make sure MAIL_DOMAIN is not empty
	local domains=${MAIL_DOMAIN-$(hostname -d)}
	if [ -z "$domains" ]; then
		export MAIL_DOMAIN=$docker_default_domain
		dc_log 4 "No MAIL_DOMAIN, non FQDC HOSTNAME, so using $MAIL_DOMAIN"
	fi
}

cntcfg_postfix_domains() {
	# configure domains if we have recipients
	local domains=${MAIL_DOMAIN-$(hostname -d)}
	if [ -n "$domains" ] && ([ -n "$LDAP_HOST" ] || [ -n "$MAIL_BOXES" ]); then
		dc_log 5 "Configuring postfix for domains $domains"
		if [ $(echo $domains | wc -w) -gt 1 ]; then
			for domain in $domains; do
				_cond_append $postfix_virt_domain "$domain #domain"
			done
			postconf virtual_mailbox_domains=hash:$postfix_virt_domain
			postmap  hash:$postfix_virt_domain
		else
			postconf mydomain=$domains
			postconf virtual_mailbox_domains='$mydomain'
		fi
	fi
}

cntcfg_amavis_domains() {
	# NOTE: the contanare only starts if either MAIL_DOMAIN or hostname is fqdn
	local domains=${MAIL_DOMAIN-$(hostname -d)}
	local domain_main=$(echo $domains | sed 's/\s.*//')
	local domain_extra=$(echo $domains | sed 's/[^ ]* *//' | sed 's/[^ ][^ ]*/"&"/g' | sed 's/ /, /g')
	if (_is_installed amavisd-new && [ -n "$domain_main" ]); then
		dc_log 5 "Configuring amavis for domains $domains"
		modify $amavis_cf '\$mydomain' = "'"$domain_main"';"
		if [ $(echo $domains | wc -w) -gt 1 ]; then
			modify $amavis_cf '@local_domains_maps' = '( [".$mydomain", '$domain_extra'] );'
		fi
	fi
}

cntcfg_amavis_dkim() {
	# generate and activate dkim domainkey.
	# incase of multi domain generate key for first domain only, but accept it
	# to be used for all domains specified.
	local domains=${MAIL_DOMAIN-$(hostname -d)}
	local domain_main=$(echo $domains | sed 's/\s.*//')
	local user=$amavis_runas
	local bits=${DKIM_KEYBITS-2048}
	local selector=${DKIM_SELECTOR}
	local keyfile=$dkim_dir/$domain_main.$selector.privkey.pem
	local txtfile=$dkim_dir/$domain_main.$selector._domainkey.txt
	local keystring="$DKIM_PRIVATEKEY"
	if (_is_installed amavisd-new && [ -n "$selector" ] && [ -n "$domain_main" ]); then
		dc_log 5 "Setting dkim selector and domain to $selector and $domain_main"
		# insert config statements just before last line
		_cond_append -i $amavis_cf '@dkim_signature_options_bysender_maps = ( { "." => { ttl => 21*24*3600, c => "relaxed/simple" } } );'
		_cond_append -i $amavis_cf 'dkim_key("'$domain_main'", "'$selector'", "'$keyfile'");'
		if [ -n "$keystring" ]; then
			if [ -e $keyfile ]; then
				dc_log 4 "Overwriting private dkim key here $keyfile"
			else
				dc_log 5 "Writing private dkim key here $keyfile"
			fi
			if echo "$keystring" | grep "PRIVATE KEY" - > /dev/null; then
				echo "$keystring" fold -w 64 > $keyfile
			else
				echo "-----BEGIN RSA PRIVATE KEY-----" > $keyfile
				echo "$keystring" | fold -w 64 >> $keyfile
				echo "-----END RSA PRIVATE KEY-----" >> $keyfile
			fi
		fi
		if [ ! -e $keyfile ]; then
			local message="$(amavisd genrsa $keyfile $bits 2>&1)"
			dc_log 4 "$message"
			amavisd showkeys $domain_main > $txtfile
			#amavisd testkeys $domain_main
		fi
		_chowncond $user $dkim_dir
	fi
}

_cntgen_postfix_ldapmap() {
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

cntcfg_postfix_mailbox_auth_ldap() {
	if ([ -n "$LDAP_HOST" ] && [ -n "$LDAP_USER_BASE" ] && [ -n "$LDAP_QUERY_FILTER_USER" ]); then
		dc_log 5 "Configuring postfix-ldap with ldap-host $LDAP_HOST"
		postconf virtual_mailbox_maps=ldap:$postfix_ldap_users_cf
		_cntgen_postfix_ldapmap "$LDAP_USER_BASE" mail "$LDAP_QUERY_FILTER_USER" > $postfix_ldap_users_cf
		if [ -n "$LDAP_QUERY_FILTER_ALIAS" ]; then
			_cntgen_postfix_ldapmap "$LDAP_USER_BASE" mail "$LDAP_QUERY_FILTER_ALIAS" > $postfix_ldap_alias_cf
			if [ -n "$LDAP_GROUP_BASE" -a -n "$LDAP_QUERY_FILTER_GROUP" -a -n "$LDAP_QUERY_FILTER_EXPAND" ]; then
				postconf virtual_alias_maps="ldap:$postfix_ldap_alias_cf, ldap:$postfix_ldap_groups_cf, ldap:$postfix_ldap_expand_cf"
				_cntgen_postfix_ldapmap "$LDAP_GROUP_BASE" memberUid "$LDAP_QUERY_FILTER_GROUP" > $postfix_ldap_groups_cf
				_cntgen_postfix_ldapmap "$LDAP_GROUP_BASE" mail "$LDAP_QUERY_FILTER_EXPAND" > $postfix_ldap_expand_cf
			else
				postconf virtual_alias_maps=ldap:$postfix_ldap_alias_cf
			fi
		fi
		if [ -z "$VIRTUAL_TRANSPORT" ]; then # need local mail boxes
			mkdir -p $mail_dir
			_chowncond $postfix_runas $mail_dir
			postconf virtual_mailbox_base=$mail_dir
			postconf virtual_uid_maps=static:$(id -u $postfix_runas)
			postconf virtual_gid_maps=static:$(id -g $postfix_runas)
		fi
	fi
}

cntcfg_postfix_mailbox_auth_hash() {
	local emails="${1-$MAIL_BOXES}"
	if [ -n "$emails" ]; then
		dc_log 5 "Configuring postfix-virt-mailboxes"
		for email in $emails; do
			_cond_append $postfix_virt_mailbox $email $email
		done
#		postconf alias_maps=
#		postconf alias_database=
		postconf virtual_mailbox_maps=hash:$postfix_virt_mailbox
		postmap hash:$postfix_virt_mailbox
		if [ -z "$VIRTUAL_TRANSPORT" ]; then # need local mail boxex
			mkdir -p $mail_dir
			_chowncond $postfix_runas $mail_dir
			postconf virtual_mailbox_base=$mail_dir
			postconf virtual_uid_maps=static:$(id -u $postfix_runas)
			postconf virtual_gid_maps=static:$(id -g $postfix_runas)
		fi
	fi
}

cntcfg_postfix_alias_map() {
	# MAIL_ALIASES="alias1:target1a,target1b alias2:target2"
	local aliasmaps="${1-$MAIL_ALIASES}"
	if [ -n "$aliasmaps" ]; then
		dc_log 5 "Config. postfix aliases"
		for aliasmap in $aliasmaps; do
			_cond_append $postfix_aliases $(echo "$aliasmap" | sed 's/[:,]/& /g')
		done
		postconf alias_maps=hash:$postfix_aliases
		postconf alias_database=hash:$postfix_aliases
		postalias $postfix_aliases
		newaliases
	else
		dc_log 7 "No postfix aliases defined"
		postconf alias_maps=
		postconf alias_database=
	fi
}

cntcfg_acme_postfix_tls_cert() {
	# we are potentially updating $SMTPD_TLS_CERT_FILE and $SMTPD_TLS_KEY_FILE,
	# so we need to run this func before cntcfg_postfix_activate_tls_cert and
	# cntcfg_postfix_apply_envvars
	if (_is_installed jq && [ -f $ACME_FILE ]); then
		HOSTNAME=${HOSTNAME-$(hostname)}
		dc_log 5 "Configuring acme-tls for host $HOSTNAME"
		ln -sf $ACME_FILE $acme_dump_json_link
		ACME_TLS_CERT_FILE=$acme_dump_tls_dir/certs/${HOSTNAME}.crt
		ACME_TLS_KEY_FILE=$acme_dump_tls_dir/private/${HOSTNAME}.key
		export SMTPD_TLS_CERT_FILE=${SMTPD_TLS_CERT_FILE-$ACME_TLS_CERT_FILE}
		export SMTPD_TLS_KEY_FILE=${SMTPD_TLS_KEY_FILE-$ACME_TLS_KEY_FILE}
		# run dumpcerts.sh on cnt creation (and every time the json file changes)
		dumpcerts.sh $acme_dump_json_link $acme_dump_tls_dir
	fi
}

cntcfg_postfix_generate_tls_cert() {
	# generate self signed certificate if SMTPD_USE_TLS=yes but no certificates
	# are given
	# run after cntcfg_acme_postfix_tls_cert and before cntcfg_postfix_activate_tls_cert
	if ([ -z "$SMTPD_TLS_CERT_FILE" ] && [ -z "$SMTPD_TLS_ECCERT_FILE" ] && \
		[ -z "$SMTPD_TLS_DCERT_FILE" ] && [ -z "$SMTPD_TLS_CHAIN_FILES" ] && \
		[ "$SMTPD_USE_TLS" = "yes" ] && _is_installed openssl); then
		dc_log 4 "SMTPD_USE_TLS=yes but no certs given, so generating self-signed cert for host $HOSTNAME"
		HOSTNAME=${HOSTNAME-$(hostname)}
		export SMTPD_TLS_KEY_FILE=${SMTPD_TLS_KEY_FILE-$postfix_smtpd_tls_dir/rsakey.pem}
		export SMTPD_TLS_CERT_FILE=${SMTPD_TLS_CERT_FILE-$postfix_smtpd_tls_dir/rsacert.pem}
		openssl genrsa -out $SMTPD_TLS_KEY_FILE
		openssl req -x509 -utf8 -new -batch -subj "/CN=$HOSTNAME" \
			-key $SMTPD_TLS_KEY_FILE -out $SMTPD_TLS_CERT_FILE
	fi
}

cntcfg_postfix_activate_tls_cert() {
	if ([ -n "$SMTPD_TLS_CERT_FILE" ] || [ -n "$SMTPD_TLS_ECCERT_FILE" ] || \
		[ -n "$SMTPD_TLS_DCERT_FILE" ] || [ -n "$SMTPD_TLS_CHAIN_FILES" ]); then
		dc_log 5 "Activating incoming tls"
		postconf -e smtpd_use_tls=yes
		postconf -e smtpd_tls_security_level=may
		postconf -e smtpd_tls_auth_only=yes
	fi
}

cntcfg_postfix_apply_envvars() {
	# some postfix parameters start with a digit and may contain dash "-"
	# and so are not legal variable names
	local env_vars="$(export -p | sed -r 's/export ([^=]+).*/\1/g')"
	local lcase_var env_val
	for env_var in $env_vars; do
		lcase_var="$(echo $env_var | tr '[:upper:]' '[:lower:]')"
		if [ "$(postconf -H $lcase_var 2>/dev/null)" = "$lcase_var" ]; then
			env_val="$(eval echo \$$env_var)"
			dc_log 5 "Setting postfix parameter $lcase_var = $env_val"
			postconf $lcase_var="$env_val"
		fi
	done
}

cntcfg_amavis_apply_envvars() {
	local env_vars="$(export -p | sed -r 's/export ([^=]+).*/\1/g')"
	local lcase_var env_val
	if _is_installed amavisd-new; then
		for env_var in $env_vars; do
			lcase_var="$(echo $env_var | tr '[:upper:]' '[:lower:]')"
			if [ -z "${amavis_var##*$env_var*}" ]; then
				env_val="$(eval echo \$$env_var)"
				dc_log 5 "Setting amavis parameter $lcase_var = $env_val"
				modify $amavis_cf '\$'$lcase_var = "$env_val;"
			fi
		done
	fi
}

cntcfg_razor_register() {
	local auth="${1-$RAZOR_REGISTRATION}"
	auth=${auth//:/ }
	set -- $auth
	local user=$1
	local pass=$2
	# create a razor conf file and discover razor servers
	if _is_installed razor; then
		dc_log 5 "Discovering razor servers"
		razor-admin -home=$razor_home -create
		if ([ -n "$auth" ] && [ ! -e $razor_identity ]); then
			# register an identity if RAZOR_REGISTRATION is not empty
			[ -n "$user" ] && user="-user=$user"
			[ -n "$pass" ] && pass="-pass=$pass"
			if ping -c1 $razor_url >/dev/null 2>&1; then
				local message="$(razor-admin -home=$razor_home $user $pass -register)"
				dc_log 5 "$message"
			else
				dc_log 4 "Not registering razor, cannot ping $razor_url"
			fi
		fi
		_chowncond $razor_runas $razor_home
	fi
}

#
# run time utility commands
#

cntrun_chown_home() {
	# do we need to check  /var/amavis/.spamassassin/bayes_journal?
	_chowncond $postfix_runas $postfix_home
	_chowncond $postfix_runas $mail_dir
	_chowncond $amavis_runas  $amavis_home
}

cntrun_prune_pidfiles() {
	for dir in /run /var/spool/postfix/pid; do
		if [ -n "$(find -H $dir -type f -name "*.pid" -exec rm {} \; 2>/dev/null)" ]; then
			dc_log 5 "Removed orphan pid files in $dir"
		fi
	done
}

cntrun_loglevel_update() {
	local loglevel=${1-$SYSLOG_LEVEL}
	if [ -n "$loglevel" ]; then
		dc_log 5 "Setting syslogd level = $loglevel"
		setup-runit.sh "syslogd -nO- -l$loglevel $SYSLOG_OPTIONS"
	fi
	if [ "$calledformcli" = true ]; then
		sv restart syslogd
	fi
}

cntrun_spamassassin_update() {
	# Download rules for spamassassin at start up.
	# There is also an daily cron job that updates these.
	if _is_installed spamassassin; then
		dc_log 5 "Updating spamassassin rules"
		( sa-update ) &
	fi
}

cntrun_runit_spamd() {
	if [ -d $DOCKER_SPAMD_DIR ]; then
		local runitdir
		local subdir
		for watchdir in $DOCKER_SPAMD_DIR/*; do
			if [ -d $watchdir ]; then
				subdir=$(basename $watchdir)
				dc_log 5 "Setting up spamd-$subdir service"
				runitdir=$DOCKER_SPAMD_SV_DIR-$subdir
				mkdir -p $runitdir
				cat <<-!cat > $runitdir/run
					#!/bin/sh -e
					# define helpers
					exec 2>&1
					# run sa-learn.sh when a file is reated in $watchdir
					exec $(which inotifyd) $(which sa-learn.sh) $watchdir:n
				!cat
				chmod +x $runitdir/run
			fi
		done
	fi
}

doveadm_pw() { doveadm pw -p $1 ;}

update_postfix_dhparam() {
	# Optionally generate non-default Postfix SMTP server EDH parameters for improved security
	# note, since 2015, 512 bit export ciphers are no longer used
	# this takes a long time. run this manually once the container is up by:
	# conf update_postfix_dhparam
	# smtpd_tls_dh1024_param_file
	local bits=${1-2048}
	if _is_installed openssl; then
		dc_log 5 "Regenerating postfix edh $bits bit parameters"
		mkdir -p $postfix_smtpd_tls_dir
		openssl dhparam -out $postfix_smtpd_tls_dir/dh$bits.pem $bits
		postconf smtpd_tls_dh1024_param_file=$postfix_smtpd_tls_dir/dh$bits.pem
	else
		dc_log 4 "Cannot regenerate edh since openssl is not installed"
	fi
}

#
# allow functions to be accessed on cli
#

cntrun_cli_and_exit() {
	if [ "$(basename $0)" = conf ]; then
		calledformcli=true
		local cmd=$1
		if [ -n "$cmd" ]; then
			shift
			dc_log 7 "CMD:$cmd ARG:$@"
			$cmd "$@"
		else
			usage
		fi
		exit 0
	fi
}
