#!/bin/sh
#
# amavis-common.sh
#
# Define variables and functions used during build. Source in Dockerfile.
#

#
# Configure milter. More information can be found at links below.
# https://amavis.org/README.postfix.html#basics_transport
# https://amavis.org/README.postfix.html#d0e1110
#
ac_amavis_setup_postfix() {
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
