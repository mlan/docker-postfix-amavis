# 1.2.0
- Supports SMTP client SASL authentication using Dovecot
- AMaViS configuration is now possible using environment variables
- Now all ClamAV logs are redirected as intended
- Using alpine:latest since bug 9987 was resolved
- Configured tests run on Travis CI.

# 1.1.1
- Make sure the .env settings are honored also for MYSQL

# 1.1.0
- Demo based on `docker-compose.yml` and `Makefile` files

# 1.0.0
- Using alpine:3.8 due to bug [9987](https://bugs.alpinelinux.org/issues/9987)
