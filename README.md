# The `mlan/postfix-amavis` repository

![travis-ci test](https://img.shields.io/travis/mlan/docker-postfix-amavis.svg?label=build&style=popout-square&logo=travis)
![image size](https://img.shields.io/microbadger/image-size/mlan/postfix-amavis.svg?label=size&style=popout-square&logo=docker)
![docker stars](https://img.shields.io/docker/stars/mlan/postfix-amavis.svg?label=stars&style=popout-square&logo=docker)
![docker pulls](https://img.shields.io/docker/pulls/mlan/postfix-amavis.svg?label=pulls&style=popout-square&logo=docker)

This (non official) repository provides dockerized (MTA) [Mail Transfer Agent](https://en.wikipedia.org/wiki/Message_transfer_agent) (SMTP) service using [Postfix](http://www.postfix.org/) and [Dovecot](https://www.dovecot.org/) with [anti-spam](https://en.wikipedia.org/wiki/Anti-spam_techniques) and anti-virus filter using [amavisd-new](https://www.amavis.org/), [SpamAssassin](https://spamassassin.apache.org/) and [ClamAV](https://www.clamav.net/), which also provides sender authentication using [SPF](https://en.wikipedia.org/wiki/Sender_Policy_Framework) and [DKIM](https://en.wikipedia.org/wiki/DomainKeys_Identified_Mail).

## Features

Feature list follows below

- MTA (SMTP) server and client [Postfix](http://www.postfix.org/)
- Anti-spam filter [amavisd-new](https://www.amavis.org/), [SpamAssassin](https://spamassassin.apache.org/) and [Razor](http://razor.sourceforge.net/)
- Anti-virus [ClamAV](https://www.clamav.net/)
- Sender authentication using [SPF](https://en.wikipedia.org/wiki/Sender_Policy_Framework) and [DKIM](https://en.wikipedia.org/wiki/DomainKeys_Identified_Mail)
- SMTP client authentication on the SMTPS (port 465) and submission (port 587) using [Dovecot](https://www.dovecot.org/)
- Hooks for integrating [Let’s Encrypt](https://letsencrypt.org/) LTS certificates using the reverse proxy [Traefik](https://docs.traefik.io/)
- Consolidated configuration and run data under `/srv` to facilitate persistent storage
- Simplified configuration of mailbox table lookup using environment variables
- Simplified configuration of [LDAP](https://en.wikipedia.org/wiki/Lightweight_Directory_Access_Protocol) mailbox and alias lookup using environment variables
- Simplified configuration of [SMTP](https://en.wikipedia.org/wiki/Simple_Mail_Transfer_Protocol) relay using environment variables
- Simplified configuration of [DKIM](https://en.wikipedia.org/wiki/DomainKeys_Identified_Mail) keys using environment variables
- Simplified configuration of SMTP [TLS](https://en.wikipedia.org/wiki/Transport_Layer_Security) using environment variables
- Simplified generation of Diffie-Hellman parameters needed for [EDH](https://en.wikipedia.org/wiki/Diffie–Hellman_key_exchange) using utility script
- Multi-staged build providing the images `mini`, `base` and `full`
- Configuration using environment variables
- Log directed to docker daemon with configurable level
- Built in utility script `amavisd-ls` which lists the contents of quarantine
- Built in utility script `conf` helping configuring Postfix, AMaViS, SpamAssassin, Razor, ClamAV and Dovecot
- Makefile which can build images and do some management and testing
- Health check
- Small image size based on [Alpine Linux](https://alpinelinux.org/)
- Demo based on `docker-compose.yml` and `Makefile` files

## Tags

The breaking.feature.fix [semantic versioning](https://semver.org/)
used. In addition to the three number version number you can use two or
one number versions numbers, which refers to the latest version of the 
sub series. The tag `latest` references the build based on the latest commit to the repository.

The `mlan/postfix-amavis` repository contains a multi staged built. You select which build using the appropriate tag from `mini`, `base` and `full`. The image `mini` only contain Postfix. The image built with the tag `base` extend `mini` to include [Dovecot](https://www.dovecot.org/), which provides mail delivery via IMAP and POP3 and SMTP client authentication as well as integration of [Let’s Encrypt](https://letsencrypt.org/) TLS certificates using [Traefik](https://docs.traefik.io/). The image with the tag `full`, which is the default, extend `base` with anti-spam and ant-virus [milters](https://en.wikipedia.org/wiki/Milter), and sender authentication via [SPF](https://en.wikipedia.org/wiki/Sender_Policy_Framework) and [DKIM](https://en.wikipedia.org/wiki/DomainKeys_Identified_Mail).

To exemplify the usage of the tags, lets assume that the latest version is `1.0.0`. In this case `latest`, `1.0.0`, `1.0`, `1`, `full`, `full-1.0.0`, `full-1.0` and `full-1` all identify the same image.

# Usage

Often you want to configure Postfix and its components. There are different methods available to achieve this. You can use the environment variables described below set in the shell before creating the container. These environment variables can also be explicitly given on the command line when creating the container. They can also be given in an `docker-compose.yml` file, see below. Moreover docker volumes or host directories with desired configuration files can be mounted in the container. And finally you can `docker exec` into a running container and modify configuration files directly.

If you want to test the image you can start it using the destination domain `example.com` and table mail boxes for info@example.com and abuse@example.com using the shell command below.

```bash
docker run -d --name mail-mta --hostname mx1.example.com -e MAIL_BOXES="info@example.com abuse@example.com" -p 127.0.0.1:25:25 mlan/postfix-amavis
```

## Docker compose example

An example of how to configure an web mail server using docker compose is given below. It defines 4 services, `mail-app`, `mail-mta`, `mail-db` and `auth`, which are the web mail server, the mail transfer agent, the SQL database and LDAP authentication respectively.

```yaml
version: '3.7'

services:
  mail-app:
    image: mlan/kopano
    networks:
      - backend
    ports:
      - "127.0.0.1:8080:80"
    depends_on:
      - auth
      - mail-db
      - mail-mta
    environment:
      - USER_PLUGIN=ldap
      - LDAP_HOST=auth
      - MYSQL_HOST=mail-db
      - SMTP_SERVER=mail-mta
      - LDAP_SEARCH_BASE=${LDAP_BASE-dc=example,dc=com}
      - LDAP_USER_TYPE_ATTRIBUTE_VALUE=${LDAP_USEROBJ-posixAccount}
      - LDAP_GROUP_TYPE_ATTRIBUTE_VALUE=${LDAP_GROUPOBJ-posixGroup}
      - MYSQL_DATABASE=${MYSQL_DATABASE-kopano}
      - MYSQL_USER=${MYSQL_USER-kopano}
      - MYSQL_PASSWORD=${MYSQL_PASSWORD-secret}
      - SYSLOG_LEVEL=3
    volumes:
      - mail-conf:/etc/kopano
      - mail-atch:/var/lib/kopano/attachments
      - mail-sync:/var/lib/z-push

  mail-mta:
    image: mlan/postfix-amavis
    hostname: ${MAIL_SRV-mx}.${MAIL_DOMAIN-example.com}
    networks:
      - backend
    ports:
      - "127.0.0.1:25:25"
    depends_on:
      - auth
    environment:
      - LDAP_HOST=auth
      - VIRTUAL_TRANSPORT=lmtp:mail-app:2003
      - LDAP_USER_BASE=ou=${LDAP_USEROU-users},${LDAP_BASE-dc=example,dc=com}
      - LDAP_QUERY_FILTER_USER=(&(objectclass=${LDAP_USEROBJ-posixAccount})(mail=%s))
    volumes:
      - mail-mta:/srv

  mail-db:
    image: mariadb
    command: ['--log_warnings=1']
    networks:
      - backend
    environment:
      - LANG=C.UTF-8
      - MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD-secret}
      - MYSQL_DATABASE=${MYSQL_DATABASE-kopano}
      - MYSQL_USER=${MYSQL_USER-kopano}
      - MYSQL_PASSWORD=${MYSQL_PASSWORD-secret}
    volumes:
      - mail-db:/var/lib/mysql

  auth:
    image: mlan/openldap
    networks:
      - backend
    environment:
      - LDAP_LOGLEVEL=parse
    volumes:
      - auth-db:/srv

networks:
  backend:

volumes:
  auth-db:
  mail-conf:
  mail-atch:
  mail-db:
  mail-mta:
  mail-sync:
```

This repository contains a `demo` directory which hold the `docker-compose.yml` file as well as a `Makefile` which might come handy. From within the `demo` directory you can start the container simply by typing:

```bash
make init
```

Once you have given the container some time to start up you can assess WebApp on the URL [`http://localhost:8080`](http://localhost:8080) and log in with the user name `demo` and password `demo` . You can send a test email by typing:

```bash
make test
```

## Environment variables

When you create the `mlan/postfix-amavis` container, you can configure the services by passing one or more environment variables or arguments on the docker run command line. Once the services has been configured a lock file is created, to avoid repeating the configuration procedure when the container is restated. In the rare event that want to modify the configuration of an existing container you can override the default behavior by setting `FORCE_CONFIG` to a no-empty string.

To see all available postfix configuration variables you can run `postconf` within the container, for example like this:

```bash
docker exec -it mail-mta postconf
```

If you do, you will notice that configuration variable names are all lower case, but they will be matched with all uppercase environment variables by the container `entrypoint.sh` script.

## Persistent storage

By default, docker will store the configuration and run data within the container. This has the drawback that the configurations and queued and quarantined mail are lost together with the container should it be deleted. It can therefore be a good idea to use docker volumes and mount the run directories and/or the configuration directories there so that the data will survive a container deletion.

To facilitate such approach, to achieve persistent storage, the configuration and run directories of the services has been consolidated to `/srv/etc` and `/srv/var` respectively. So if you to have chosen to use both persistent configuration and run data you can run the container like this:

```
docker run -d --name mail-mta -v mail-mta:/srv -p 127.0.0.1:25:25 mlan/postfix-amavis
```

## Outgoing SMTP relay

Sometimes you want outgoing email to be sent to a SMTP relay and _not_ directly to its destination. This could for instance be when your ISP is blocking port 25 or perhaps if you have a dynamic IP and are afraid of that mail servers will drop your outgoing emails because of that.

#### `SMTP_RELAY_HOSTAUTH`
This environment variable simplify a SMTP relay configuration. The SMTP relay host might require SASL authentication in which case user name and password can also be given in variable. The format is `"host:port user:passwd"`. Example: `SMTP_RELAY_HOSTAUTH="[example.relay.com]:587 e863ac2bc1e90d2b05a47b2e5c69895d:b35266f99c75d79d302b3adb42f3c75f"`

#### `SMTP_TLS_SECURITY_LEVEL`

You can enforce the use of TLS, so that the Postfix SMTP server announces STARTTLS and accepts no
mail without TLS encryption, by setting `SMTP_TLS_SECURITY_LEVEL=encrypt`. Default: `SMTP_TLS_SECURITY_LEVEL=none`.

#### `SMTP_TLS_WRAPPERMODE`

To configure the Postfix SMTP client connecting using the legacy SMTPS protocol instead of using the STARTTLS command, set `SMTP_TLS_WRAPPERMODE=yes`. This mode requires `SMTP_TLS_SECURITY_LEVEL=encrypt` or stronger. Default: `SMTP_TLS_WRAPPERMODE=no`

## Incoming SMTPS and submission client authentication

Postfix achieves client authentication using Dovecot. Client authentication is the mechanism that is used on SMTP relay using SASL authentication, see the `SMTP_RELAY_HOSTAUTH`. Here the client authentication is arranged on the [smtps](https://en.wikipedia.org/wiki/SMTPS) port: 465 and [submission](https://en.wikipedia.org/wiki/Message_submission_agent) port: 587. To avoid the risk of being an open relay the SMTPS and submission services are only activated when `SMTPD_SASL_CLIENTAUTH` is set. Additionally clients are required to authenticate using TLS to avoid password being sent in the clear. The configuration of the services are the similar with the exception that the SMTPS service uses the legacy SMTPS protocol; `SMTPD_TLS_WRAPPERMODE=yes`, whereas the submission service uses the STARTTLS protocol.

#### `SMTPD_SASL_CLIENTAUTH`

You can list clients and their passwords in a space separated string using the format: `"username:{scheme}passwd"`. Example: `SMTPD_SASL_CLIENTAUTH="client1:{plain}passwd1 client2:{plain}passwd2"`. For security you might want to use encrypted passwords. One way to encrypt a password (`{plain}secret`) is by running

```bash
docker exec -it mail-mta doveadm pw -p secret

{CRYPT}$2y$05$Osj5ebALV/bXo18H4BKLa.J8Izn23ilI8TNA/lIHz92TuQFbZ/egK
```

for use in `SMTPD_SASL_CLIENTAUTH`.

## Incoming destination domain

Postfix is configured to be
the final destination of the virtual/hosted domains defined by the environment variable `MAIL_DOMAIN`. If the domains are not properly configured Postfix will be rejecting the emails. When multiple domains are used the first domain in the list is considered to be the primary one.

#### `MAIL_DOMAIN`

The default value of `MAIL_DOMAIN=$(hostname -d)` is to
use the host name of the container minus the first component. So you can either use the environment variable `MAIL_DOMAIN` or the argument `--hostname`. So for example, `--hostname mx1.example.com` or `-e MAIL_DOMAIN="example.com secondary.com" `.

## Incoming TLS support

Transport Layer Security (TLS, formerly called SSL) provides certificate-based authentication and encrypted sessions. An encrypted session protects the information that is transmitted with SMTP mail or with SASL authentication. 

Here TLS is activated for inbound messages when either `SMTPD_TLS_CHAIN_FILES` or `SMTPD_TLS_CERT_FILE` (or its [DSA](https://en.wikipedia.org/wiki/Digital_Signature_Algorithm) and [ECDSA](https://en.wikipedia.org/wiki/Elliptic_Curve_Digital_Signature_Algorithm) counterparts) is not empty or `SMTPD_USE_TLS=yes`. The Postfix SMTP server generally needs a certificate and a private key to provide TLS. Both must be in [PEM](https://en.wikipedia.org/wiki/Privacy-Enhanced_Mail) format. The private key must not be encrypted, meaning: the key must be accessible without a password. The [RSA](https://en.wikipedia.org/wiki/RSA_(cryptosystem)) certificate and a private key files are identified by `SMTPD_TLS_CERT_FILE` and `SMTPD_TLS_KEY_FILE`.

#### `SMTPD_USE_TLS=yes`

If `SMTPD_USE_TLS=yes` is explicitly defined but there are no certificate files defined, a self-signed certificate will be generated when the container is created.

#### `SMTPD_TLS_CERT_FILE`

Specifies the [RSA](https://en.wikipedia.org/wiki/RSA_(cryptosystem)) [PEM](https://en.wikipedia.org/wiki/Privacy-Enhanced_Mail) certificate file within the container to be used with incoming TLS connections. The certificate file need to be made available in the container by some means. Example `SMTPD_TLS_CERT_FILE=cert.pem`. Additionally there are the [DSA](https://en.wikipedia.org/wiki/Digital_Signature_Algorithm), [ECDSA](https://en.wikipedia.org/wiki/Elliptic_Curve_Digital_Signature_Algorithm) or chain counterparts; `SMTPD_TLS_DCERT_FILE`, `SMTPD_TLS_ECCERT_FILE` and `SMTPD_TLS_CHAIN_FILES`.

#### `SMTPD_TLS_KEY_FILE`

Specifies the RSA PEM private key file within the container to be used with incoming TLS connections. The private key file need to be made available in the container by some means. Example `SMTPD_TLS_KEY_FILE=key.pem`. Additionally there are the DSA, ECDSA or chain counterparts; `SMTPD_TLS_DKEY_FILE`, `SMTPD_TLS_ECKEY_FILE` and `SMTPD_TLS_CHAIN_FILES`.

### TLS forward secrecy

The term "Forward Secrecy" (or sometimes "Perfect Forward Secrecy") is used to describe security protocols in which the confidentiality of past traffic is not compromised when long-term keys used by either or both sides are later disclosed.

Forward secrecy is accomplished by negotiating session keys using per-session cryptographically-strong random numbers that are not saved, and signing the exchange with long-term authentication keys. Later disclosure of the long-term keys allows impersonation of the key holder from that point on, but not recovery of prior traffic, since with forward secrecy, the discarded random key agreement inputs are not available to the attacker.

The built in utility script `conf` can be used to generate the Diffie-Hellman parameters needed for forward secrecy.

```bash
docker exec -it mail-mta conf update_postfix_dhparam
```

### Let’s Encrypt LTS certificates using Traefik

Let’s Encrypt provide free, automated, authorized certificates when you can demonstrate control over your domain. Automatic Certificate Management Environment (ACME) is the protocol used for such demonstration. There are many agents and applications that supports ACME, e.g., [certbot](https://certbot.eff.org/). The reverse proxy [Traefik](https://docs.traefik.io/) also supports ACME.

#### `ACME_FILE`

The `mlan/postfix-amavis` image looks for a file `ACME_FILE=/acme/acme.json`. at container startup and every time this file changes certificates within this file are exported and if the host name of one of those certificates matches `HOSTNAME=$(hostname)` is will be used for TLS support.

So reusing certificates from Traefik will work out of the box if the `/acme` directory in the Traefik container is also mounted in the mlan/postfix-amavis container.

```bash
docker run -d -name mail-mta -v proxy-acme:/acme:ro mlan/postfix-amavis
```

Do not set `SMTPD_TLS_CERT_FILE` and/or `SMTPD_TLS_KEY_FILE` when using `ACME_FILE`.

## Incoming anti-spam and anti-virus

[amavisd-new](https://www.amavis.org/) is a high-performance interface between mailer (MTA) and content checkers: virus scanners, and/or [SpamAssassin](https://spamassassin.apache.org/). Apache SpamAssassin is the #1 open source anti-spam platform giving system administrators a filter to classify email and block spam (unsolicited bulk email). It uses a robust scoring framework and plug-ins to integrate a wide range of advanced heuristic and statistical analysis tests on email headers and body text including text analysis, Bayesian filtering, DNS block-lists, and collaborative filtering databases. Clam AntiVirus is an anti-virus toolkit, designed especially for e-mail scanning on mail gateways.

[Vipul's Razor](http://razor.sourceforge.net/) is a distributed, collaborative, spam detection and filtering network. It uses a fuzzy [checksum](http://en.wikipedia.org/wiki/Checksum) technique to identify
message bodies based on signatures submitted by users, or inferred by 
other techniques such as high-confidence Bayesian or DNSBL entries. 

AMaViS will only insert mail headers in incoming messages with domain mentioned in `MAIL_DOMAIN`. So proper configuration is needed for anti-spam and anti-virus to work.

#### `FINAL_VIRUS_DESTINY`, `FINAL_BANNED_DESTINY`, `FINAL_SPAM_DESTINY`, `FINAL_BAD_HEADER_DESTINY`

When an undesirable email is found, the action according to the `FINAL_*_DESTINY` variables will be taken. Possible settings for the `FINAL_*_DESTINY` variables are: `D_PASS`, `D_BOUNCE`,`D_REJECT` and `D_DISCARD`.

`D_PASS`: Mail will pass to recipients, regardless of bad contents. `D_BOUNCE`: Mail will not be delivered to its recipients, instead, a non-delivery notification (bounce) will be created and sent to the sender. `D_REJECT`: Mail will not be delivered to its recipients, instead, a reject response will be sent to the upstream MTA and that MTA may create a reject notice (bounce) and return it to the sender. `D_DISCARD`: Mail will not be delivered to its recipients and the sender normally will NOT be notified.

Default settings are: `FINAL_VIRUS_DESTINY=D_DISCARD`, `FINAL_BANNED_DESTINY=D_DISCARD`, `FINAL_SPAM_DESTINY=D_PASS`, `FINAL_BAD_HEADER_DESTINY=D_PASS`.

#### `SA_TAG_LEVEL_DEFLT`, `SA_TAG2_LEVEL_DEFLT`, `SA_KILL_LEVEL_DEFLT`

`SA_TAG_LEVEL_DEFLT=2.0` controls at which level (or above) spam info headers are added to mail. `SA_TAG2_LEVEL_DEFLT=6.2` controls at which level the 'spam detected' headers are added. `SA_KILL_LEVEL_DEFLT=6.9` set the trigger level when spam evasive actions are taken (e.g. blocking mail).

#### `RAZOR_REGISTRATION`

Razor, called by SpamAssassin, will check if the signature of the received email is registered in the Razor servers and adjust the spam score accordingly. Razor can also report detected spam to its servers, but then it needs to use a registered identity.

To register an identity with the Razor server, use `RAZOR_REGISTRATION`. You can request to be know as a certain user name, `RAZOR_REGISTRATION=username:passwd`. If you omit both user name and password, e.g., `RAZOR_REGISTRATION=:`, they will both be assigned to you by the Razor server. Likewise if password is omitted a password will be assigned by the Razor server. Razor users are encouraged
to use their email addresses as their user name. Example: `RAZOR_REGISTRATION=postmaster@example.com:secret`

### Managing the quarantine

A message is quarantined by being saved in the directory `/var/amavis/quarantine/` allowing manual inspection to determine weather or not to release it. The utility `amavisd-ls` allow some simple inspection of what is in the quarantine. To do so type:

```bash
docker-compose exec mail-mta amavisd-ls
```

A quarantined message receives one additional header field: an
X-Envelope-To-Blocked. An X-Envelope-To still holds a complete list
of envelope recipients, but the X-Envelope-To-Blocked only lists its
subset (in the same order), where only those recipients are listed
which did not receive a message (e.g. being blocked by virus/spam/
banning... rules). This facilitates a release of a multi-recipient
message from a quarantine in case where some recipients had a message
delivered (e.g. spam lovers) and some had it blocked.

To release a quarantined message type:

```bash
docker-compose exec mail-mta amavisd-release <file>
```

## Incoming SPF sender authentication

Sender Policy Framework (SPF) is an [email authentication](https://en.wikipedia.org/wiki/Email_authentication) method designed to detect forged sender addresses in emails. SPF allows the receiver to check that an email claiming to come from a specific domain comes from an IP address authorized by that domain's administrators. The list of authorized sending hosts and IP addresses for a domain is published in the [DNS](https://en.wikipedia.org/wiki/Domain_Name_System_Security_Extensions) records for that domain.

## DKIM sender authentication

Domain-Keys Identified Mail (DKIM) is an [email authentication](https://en.wikipedia.org/wiki/Email_authentication) method designed to detect forged sender addresses in emails. DKIM allows the receiver to check that an email claimed to have come from a specific [domain](https://en.wikipedia.org/wiki/Domain_name) was indeed authorized by the owner of that domain. It achieves this by affixing a [digital signature](https://en.wikipedia.org/wiki/Digital_signature), linked to a domain name, `MAIL_DOMAIN`, to each outgoing email message, which the receiver can verify by using the DKIM key published in the [DNS](https://en.wikipedia.org/wiki/Domain_Name_System_Security_Extensions) records for that domain.

amavisd-new is configured to check the digital signature of incoming email as well as add digital signatures to outgoing email.

#### `DKIM_KEYBITS`

The bit length used when creating new keys. Default: `DKIM_KEYBITS=2048`

#### `DKIM_SELECTOR`
The public key DNS record should appear as a TXT resource record at: `DKIM_SELECTOR._domainkey.MAIL_DOMAIN`. The TXT record to be used with the private key generated at container creation is written here: `/var/db/dkim/MAIL_DOMAIN.DKIM_SELECTOR._domainkey.txt`.
Default: `DKIM_SELECTOR=default`
#### `DKIM_PRIVATEKEY`
DKIM uses a private and public key pair used for signing and verifying email. A private key is created when the container is created. If you already have a private key you can pass it to the container by using the environment variable `DKIM_PRIVATEKEY`. For convenience the strings `-----BEGIN RSA PRIVATE KEY-----` and `-----END RSA PRIVATE KEY-----` can be omitted form the key string. For example `DKIM_PRIVATEKEY="MIIEpAIBAAKCAQEA04up8hoqzS...1+APIB0RhjXyObwHQnOzhAk"`

The private key is stored here `/var/db/dkim/MAIL_DOMAIN.DKIM_SELECTOR.privkey.pem`, so alternatively you can copy the private key into the container:

```bash
docker cp $MAIL_DOMAIN.$DKIM_SELECTOR.privkey.pem <container_name>:var/db/dkim
```

If you wish to create a new private key you can run:

```bash
docker exec -it <container_name> amavisd genrsa /var/db/dkim/$MAIL_DOMAIN.$DKIM_SELECTOR.privkey.pem $DKIM_KEYBITS
```

## Table mailbox lookup

Postfix can use a table as a source for any of its lookups including virtual mailbox and aliases. The `mlan/postfix-amavis` image provides a simple way to generate virtual mailbox lookup using the `MAIL_BOXES` environment variable.

#### `MAIL_BOXES`

Using the `MAIL_BOXES` environment variable you simply provide a space separated list with all email addresses that Postfix should accept incoming mail to. For example: `MAIL_BOXES="info@example.com abuse@example.com"`. The default value is empty.

#### `MAIL_ALIASES`

Using the `MAIL_ALIASES` environment variable you simply provide a space separated list with email alias addresses that Postfix should accept incoming mail to, using the following syntax: `MAIL_ALIASES="alias1:target1a,target1b alias2:target2"`. For example: `MAIL_ALIASES="root:info,info@example.com postmaster:root"`. The default value is empty.

## LDAP mailbox lookup

Postfix can use an LDAP directory as a source for any of its lookups including virtual mailbox and aliases.

For LDAP mailbox lookup to work `LDAP_HOST`, `LDAP_USER_BASE` and `LDAP_QUERY_FILTER_USER` need to be configured. LDAP can also be used for alias lookup, in which case use `LDAP_QUERY_FILTER_ALIAS`. In addition LDAP can be used to lookup mail groups using `LDAP_QUERY_FILTER_GROUP` and `LDAP_QUERY_FILTER_EXPAND`. For detailed explanation see [ldap_table](http://www.postfix.org/ldap_table.5.html).

If the LDAP server is not configured to allow anonymous queries, you use `LDAP_BIND_DN` and `LDAP_BIND_PW` to proved LDAP user and password to be used for the queries.

#### `LDAP_HOST`

Use `LDAP_HOST` to configure the connection to the LDAP server. When the default port (389) is used just providing the server name is often sufficient. You can also use full URL or part thereof, for example: `LDAP_HOST=auth`, `LDAP_HOST=auth:389`, `LDAP_HOST=ldap://ldap.example.com:1444`.

#### `LDAP_USER_BASE`, `LDAP_GROUP_BASE`

The `LDAP_USER_BASE`, `LDAP_GROUP_BASE` are the base DNs at which to conduct the searches for users and groups respectively. Examples: `LDAP_USER_BASE=ou=people,dc=example,dc=com` and `LDAP_GROUP_BASE=ou=groups,dc=example,dc=com`.

#### `LDAP_QUERY_FILTER_USER`, `LDAP_QUERY_FILTER_ALIAS`

These are the filters used to search the directory, where `%s` is a
substitute for the address Postfix is trying to resolve. 

Example, only consider the email address of users who also have `kopanoAccount=1`: `LDAP_QUERY_FILTER_USER=(&(kopanoAccount=1)(mail=%s))`.

Example, only consider email aliases of users who also have `kopanoAccount=1`: `LDAP_QUERY_FILTER_ALIAS=(&(kopanoAccount=1)(kopanoAliases=%s))`.

#### `LDAP_QUERY_FILTER_GROUP`, `LDAP_QUERY_FILTER_EXPAND`

To deliver mails to a member of a group the email addresses of the individual must be resolved. For resolving group members use `LDAP_QUERY_FILTER_GROUP` and to expand group members’ mail into `uid` use `LDAP_QUERY_FILTER_EXPAND`.

Example, only consider group mail from group who is of `objectclass=kopano-group`: `LDAP_QUERY_FILTER_GROUP=(&(objectclass=kopano-group)(mail=%s))` and then only consider user with matching `uid` how is of `objectclass=kopano-user`: `LDAP_QUERY_FILTER_EXPAND=(&(objectclass=kopano-user)(uid=%s))`.

#### `LDAP_BIND_DN`, `LDAP_BIND_PW`

The defaults for these environment variables are empty. If you do have to bind, do it with this distinguished name and password. Example: `LDAP_BIND_DN=uid=admin,dc=example,dc=com`, `LDAP_BIND_PW=secret`.


## Delivery transport
The `mlan/postfix-amavis` image is designed primarily to work with a companion software which holds the mail boxes. That is, Postfix is not intended to be used for final delivery.

#### `VIRTUAL_TRANSPORT`

Postfix delivers the messages to the companion software, like [Kolab](https://hub.docker.com/r/kvaps/kolab), [Kopano](https://cloud.docker.com/u/mlan/repository/docker/mlan/kopano) or [Zimbra](https://hub.docker.com/r/jorgedlcruz/zimbra/), using a transport mechanism you specify using the environment variable `VIRTUAL_TRANSPORT`. [LMTP](https://en.wikipedia.org/wiki/Local_Mail_Transfer_Protocol) is one such transport mechanism. One example of final delivery transport to Kopano is: `VIRTUAL_TRANSPORT=lmtp:app:2003`

Local mail boxes will be created if there is no `VIRTUAL_TRANSPORT` defined. The local mail boxes will be created in the directory `/var/mail`. For example `/var/mail/info@example.com`.

## Message size limit `MESSAGE_SIZE_LIMIT`

The maximal size in bytes of a message, including envelope information. Default: `MESSAGE_SIZE_LIMIT=10240000` ~10MB. Many mail servers are configured with maximal size of 10MB, 20MB or 25MB.

## SMTP Client Authentication

Sometimes want to authenticate SMTP client connecting to the submission port 578.

`SMTPD_SASL_CLIENTAUTH="client1:{plain}password1 client2:{plain}password2"`

## Logging `SYSLOG_LEVEL`, `LOG_LEVEL`, `SA_DEBUG`

The level of output for logging is in the range from 0 to 8. 1 means emergency logging only, 2 for alert messages, 3 for critical messages only, 4 for error or worse, 5 for warning or worse, 6 for notice or worse, 7 for info or worse, 8 debug. Default: `SYSLOG_LEVEL=4`

Separately, `LOG_LEVEL` and `SA_DEBUG` control the logging level of amavisd-new and spamassasin respectively.
`LOG_LEVEL` takes valued from 0 to 5 and `SA_DEBUG` is either 1 (activated) or 0 (deactivated). Note that these messages will only appear in the log if `SYSLOG_LEVEL` is 7 or greater.


## DNS records

The [Domain Name System](https://en.wikipedia.org/wiki/Domain_Name_System) (DNS) is a [hierarchical](https://en.wikipedia.org/wiki/Hierarchical) and [decentralized](https://en.wikipedia.org/wiki/Decentralised_system) naming system for computers, services, or other resources connected to the [Internet](https://en.wikipedia.org/wiki/Internet) or a private network.

### MX record

A mail exchanger record (MX record) specifies the [mail server](https://en.wikipedia.org/wiki/Mail_server) responsible for accepting [email](https://en.wikipedia.org/wiki/Email) messages on behalf of a domain name. It is a [resource record](https://en.wikipedia.org/wiki/Resource_record) in the DNS. The MX record should correspond to the host name of the image.

### SPF record

An [SPF record](https://en.wikipedia.org/wiki/Sender_Policy_Framework) is a [TXT](https://en.wikipedia.org/wiki/TXT_Record) record that is part of a domain's DNS zone file.
The TXT record specifies a list of authorized host names/IP addresses that mail can originate from for a given domain name. An example of such TXT record is give below

```
"v=spf1 ip4:192.0.2.0/24 mx include:example.com a -all"
```

### DKIM record

The public key DNS record should appear as a [TXT](https://en.wikipedia.org/wiki/TXT_Record) resource record at: `DKIM_SELECTOR._domainkey.DOMAIN`

The data returned from the query of this record is also a list of tag-value pairs. It includes the domain's [public key](https://en.wikipedia.org/wiki/Public_key), along with other key usage tokens and flags as in this example:

```
"k=rsa; t=s; p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDDmzRmJRQxLEuyYiyMg4suA2Sy
MwR5MGHpP9diNT1hRiwUd/mZp1ro7kIDTKS8ttkI6z6eTRW9e9dDOxzSxNuXmume60Cjbu08gOyhPG3
GfWdg7QkdN6kR4V75MFlw624VY35DaXBvnlTJTgRg/EW72O1DiYVThkyCgpSYS8nmEQIDAQAB"
```

The receiver can use the public key (value of the p tag) to then decrypt the hash value in the header field, and at the same time recalculate the hash value for the mail message (headers and body) that was received.
