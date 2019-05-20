# 1.2.2
- Simplify registering with razor so that spam signatures can be checked and shared
- Fixed razor installation
- Moved hooks for integrating Let’s Encrypt TLS certs to target mda 

# 1.2.1
- Fixed new bug where the ACME TLS hook was not run in persistent setups

# 1.2.0
- Supports SMTP client SASL authentication using Dovecot
- Support multiple domains
- Services' configuration and run files now consolidated under /srv
- Now use AMaViS implementation of dkim, so dropping opendkim
- Now use SpamAssassin implementation of SPF, so dropping postfix-policyd-spf-perl
- AMaViS configuration is now possible using environment variables
- AMaViS configuration file moved to /etc/amavis/amavisd.conf
- Now all ClamAV logs are redirected as intended
- Using alpine:latest since bug [9987](https://bugs.alpinelinux.org/issues/9987) was resolved
- Configured tests run on Travis CI.
- Now install tzdata in target full to allow time zone configuration

# 1.1.1
- Make sure the .env settings are honored also for MYSQL

# 1.1.0
- Demo based on `docker-compose.yml` and `Makefile` files

# 1.0.0
- Using alpine:3.8 due to bug [9987](https://bugs.alpinelinux.org/issues/9987)
