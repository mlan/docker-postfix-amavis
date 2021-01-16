# 1.5.0

- [docker](Dockerfile) Now use alpine:3.13 (postfix:3.5.8) _BREAKING!_ Incompatible hash|btree, use FORCE_CONFIG to migrate to lmdb.
- [test](test) Update to use `mlan/openldap:2`.
- [demo](demo) Update to use `mlan/openldap:2`.

# 1.4.3

- [dovecot](src/dovecot) Added SASL authentication methods LDAP and IMAP (RIMAP).
- [dovecot](src/dovecot) SASL LDAP now use `auth_bind = yes`.
- [demo](demo) Enable IMAP POP3 and CalDAV/iCAL in demo.
- [docker](README.md) Update docker-compose example.
- [docker](README.md) Update SMPTS SASL authentication sections.
- [test](Makefile) Added LDAP SASL SMTPS and MSA test, using curl.
- [postfix](src/postfix) Check all required LDAP parameters in `postfix_setup_domains()`.
- [postfix](src/postfix) Use `smtpd_reject_unlisted_recipient=no` in `postfix_setup_domains()`.
- [dovecot](src/dovecot) Remove `smtps/inet/smtpd_recipient_restrictions` and rely on `smtpd_relay_restrictions` instead in `dovecot_setup_smtpd_sasl()`.
- [postfix](src/postfix) Allow recipient email address to be rewritten using regexp in `REGEX_ALIAS`.
- [docker](src/docker/bin/docker-common.sh) Print package versions function `dc_pkg_versions()` now supports both apk and apt.
- [docker](src/docker/bin/docker-config.sh) Better log message when `FORCE_CONFIG` active.

# 1.4.2

- [docker](Dockerfile) Now use alpine:3.12.1 (postfix:3.5.7).
- [docker](src/docker/bin/docker-common.sh) Print package versions using `dc_apk_versions()`.

# 1.4.1

- [acme](src/acme) BREAKING change! When migrating from 1.3.7 or older you need to run `postconf -e smtpd_tls_cert_file=/etc/ssl/postfix/cert.pem` and `postconf -e smtpd_tls_key_file=/etc/ssl/postfix/priv_key.pem` from within the container.
- [acme](src/acme) Introduce `ACME_POSTHOOK="postfix reload"` and run that after we have updated the certificates.
- [docker](src/docker) Don't move `DOCKER_APPL_SSL_DIR=$DOCKER_SSL_DIR/postfix` to persistent storage. Data there is updated at container startup anyway. Moreover there is no need to remove old data when it is updated.

# 1.4.0

- [repo](src) Cut up monolithic configuration script (docker-entrypoint.sh) into, easily reusable, modules.
- [repo](.travis.yml) Revisited `.travis.yml`.
- [repo](src) Revisited `src/module/bin` script names.
- [docker](src/docker/bin/docker-entrypoint.sh) Now use entry.d and exit.d.
- [docker](src) Harmonize script names.
- [docker](src/docker) Use the native envvar `SVDIR` instead of `DOCKER_RUNSV_DIR`.
- [docker](src/docker) Now use 80-docker-lock-config.
- [docker](src/docker) Reintroduce dynamic updates of the loglevel.
- [docker](src/docker) Renamed utility script `run` previously called `conf`.
- [amavis](src/amavis) Reintroduce `amavis_register_razor()`.
- [amavis](src/amavis) make spamassassin use razor.
- [docker](Dockerfile) Reintroduce `dc_persist_dirs()`.
- [docker](Dockerfile) Revert back to `DOCKER_DKIM_LIB=/var/db/dkim`.
- [docker](Dockerfile) Now use an unlock file, instead of a lock file, since it unlikely to accidentally *create* a file.
- [docker](Dockerfile) Improved configurability of Dockerfile.
- [docker](Dockerfile) Now use alpine:3.12 (postfix:3.5.2).
- [docker](src/docker) Moved function dc_is_installed() into docker-common.sh.
- [docker](src/docker/bin/docker-common.sh) Fixed minor issue in logging functionality.
- [acme](src/acme) Added module providing Let's encrypt TLS certificates using ACME.
- [acme](src/acme/bin/acme-extract.sh) Support both v1 and v2 formats of the acme.json file.
- [acme](src/acme/entry.d/50-acme-monitor-tlscert) Support both host and domain wildcard TLS certificates.
- [amavis](src/amavis) Added module providing amavis configuration.
- [dovecot](src/dovecot) Added module providing dovecot configuration.
- [postfix](src/postfix) Reintroduce `doveadm_pw()` and `postfix_update_dhparam()`.
- [postfix](src/postfix) Added module providing postfix configuration.
- [demo](demo) Made service names shorter.
- [demo](demo/Makefile) Add app-show_sync.
- [test](test) Cleaned up test directory and files.

# 1.3.7

- [docker](src/docker/bin/docker-entrypoint.sh) Added spamd-spam/ham service uses sa-learn for spam or ham.
- [docker](src/docker/bin/docker-common.sh) Consolidated logging functionality.
- [repo](src) separate source code in by which service it belongs to.
- [demo](demo) Activated kopano-spamd integration.

# 1.3.6

- [demo](demo) Use host timezone by mounting /etc/localtime.
- [docker](src/docker/bin/docker-entrypoint.sh) Always run `sa-update` at container start, otherwise amavisd refuses to start with new versions.
- [docker](Dockerfile) Don't install tzdata, instead mount host's /etc/localtime.
- [docker](ROADMAP.md) Config lock studied.

# 1.3.5

- Now use alpine:3.11.

# 1.3.4

- Use refactored docker-service.sh.
- Fixed acme-extract.sh leaking to stdout. Have it write to logger instead.
- Fixed amavis-ls script that was broken.
- Added section "Managing the quarantine" in README.md.
- Health-check now tests all services.
- In demo/Makefile added config, web, -diff, mta-apk_list, mta-quarantine_list, mta-debugtools, app-test_lmtp.

# 1.3.3

- Now generate selfsigned certificate when needed; SMTPD_USE_TLS=yes but no certificates given.
- Hardening submission (port 587 using STARTTLS) by only accepting permit_auth_destination.
- Now also enable smtps (port 465 using implicit TLS).

# 1.3.2

- Now support configuring aliases database using environment variable MAIL_ALIASES.
- New utility script amavis-ls which lists contents of quarantine.
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
