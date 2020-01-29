# 1.3.6

- [demo](demo) Use host timezone by mounting /etc/localtime.
- [docker](src/docker/bin/entrypoint.sh) Always run `sa-update` at container start, otherwise amavisd refuses to start with new versions.
- [docker](Dockerfile) Don't install tzdata, instead mount host's /etc/localtime.

# 1.3.5

- Now use alpine:3.11.

# 1.3.4

- Use refactored setup-runit.sh.
- Fixed dumpcert.sh leaking to stdout. Have it write to logger instead.
- Fixed amavisd-ls script that was broken.
- Added section "Managing the quarantine" in README.md.
- Health-check now tests all services.
- In demo/Makefile added config, web, -diff, mail-mta-apk_list, mail-mta-quarantine_list, mail-mta-debugtools, mail-app-test_lmtp.


# 1.3.3

- Now generate selfsigned certificate when needed; SMTPD_USE_TLS=yes but no certificates given.
- Hardening submission (port 587 using STARTTLS) by only accepting permit_auth_destination.
- Now also enable smtps (port 465 using implicit TLS).

# 1.3.2

- Now support configuring aliases database using environment variable MAIL_ALIASES.
- New utility script amavisd-ls which lists contents of quarantine.
- Make sure duplicate entries are NOT created with FORCE_CONFIG.
- Use default value if MAIL_DOMAIN is empty and HOSTNAME is not FQDC.
- New behavior; DKIM_SELECTOR must be non empty for DKIM to be configured.
- Now use [Multiple cleanup service architecture](https://amavis.org/README.postfix.html#d0e1038).
- Added smoke test.
- Changed test-mail in Makefile so that it connects to postfix smtp service (and not pickup).

# 1.3.1

- Fixed the ACME TLS hook.
- Fixed some minor bugs in demo/Makefile.

# 1.3.0

- Simplify registering with razor so that spam signatures can be checked and shared.
- Consolidated build targets into `mini`, `base` and `full`.
- Fixed razor installation.
- Moved hooks for integrating Let’s Encrypt ACME TLS certs to target `base`.
- Fixed the ACME TLS hook.

# 1.2.1

- Fixed new bug where the ACME TLS hook was not run in persistent setups.

# 1.2.0

- Supports SMTP client SASL authentication using Dovecot.
- Support multiple domains.
- Services' configuration and run files now consolidated under /srv.
- Now use AMaViS implementation of dkim, so dropping opendkim.
- Now use SpamAssassin implementation of SPF, so dropping postfix-policyd-spf-perl.
- AMaViS configuration is now possible using environment variables.
- AMaViS configuration file moved to /etc/amavis/amavisd.conf.
- Now all ClamAV logs are redirected as intended.
- Using alpine:latest since bug [9987](https://bugs.alpinelinux.org/issues/9987) was resolved.
- Configured tests run on Travis CI.
- Now install tzdata in target full to allow time zone configuration.

# 1.1.1

- Make sure the .env settings are honored also for MYSQL.

# 1.1.0

- Demo based on `docker-compose.yml` and `Makefile` files.

# 1.0.0

- Using alpine:3.8 due to bug [9987](https://bugs.alpinelinux.org/issues/9987).
