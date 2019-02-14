# The `mlan/postfix-amavis` repository

This (non official) repository provides dockerized (MTA) [Mail Transfer Agent](https://en.wikipedia.org/wiki/Message_transfer_agent) (SMTP) service using [Postfix](http://www.postfix.org/) with [anti-spam](https://en.wikipedia.org/wiki/Anti-spam_techniques) and anti-virus filter using [amavisd-new](https://www.amavis.org/), [SpamAssassin](https://spamassassin.apache.org/) and [ClamAV](https://www.clamav.net/), as well as sender authentication using [SPF](https://en.wikipedia.org/wiki/Sender_Policy_Framework) and [OpenDKim](http://opendkim.org/).

## Features

Brief feature list follows below

- MTA (SMTP) server and client [Postfix](http://www.postfix.org/)
- Anti-spam filter [amavisd-new](https://www.amavis.org/), [SpamAssassin](https://spamassassin.apache.org/)
- Anti-virus [ClamAV](https://www.clamav.net/)
- Sender authentication using [SPF](https://en.wikipedia.org/wiki/Sender_Policy_Framework) and [OpenDKIM](http://opendkim.org/)
- Hooks for integrating [Let’s Encrypt](https://letsencrypt.org/) LTS certificates using the reverse proxy [Traefik](https://docs.traefik.io/)
- Simplified configuration of mailbox table lookup using environment variables
- Simplified configuration of [LDAP](https://en.wikipedia.org/wiki/Lightweight_Directory_Access_Protocol) mailbox and alias lookup using environment variables
- Simplified configuration of [SMTP](https://en.wikipedia.org/wiki/Simple_Mail_Transfer_Protocol) relay using environment variables
- Simplified configuration of [DKIM](https://en.wikipedia.org/wiki/DomainKeys_Identified_Mail) keys using environment variables
- Simplified configuration of SMTP [TLS](https://en.wikipedia.org/wiki/Transport_Layer_Security) using environment variables
- Simplified generation of Diffie-Hellman parameters needed for [EDH](https://en.wikipedia.org/wiki/Diffie–Hellman_key_exchange) using utility script
- Multi-staged build providing the images `full `, `auth` , `milter` and `smtp`
- Configuration using environment variables
- Log directed to docker daemon with configurable level
- Built in utility script `mtaconf` helping configuring Postfix, AMaViS, SpamAssassin, ClamAV and OpenDKIM
- Makefile which can build images and do some management and testing
- Health check
- Small image size based on [Alpine Linux](https://alpinelinux.org/)

## Tags

The `mlan/postfix-amavis` repository contains a multi staged built. You select which build using the appropriate tag. The version part of the tag is `latest` or the revision number, e.g., `1.0.0`.

The build part of the tag is one of `full `, `auth` , `milter` and `smtp`. The image with the default tag `full` contain Postfix with anti-spam and ant-virus [milters](https://en.wikipedia.org/wiki/Milter), sender authentication and integration of [Let’s Encrypt](https://letsencrypt.org/) LTS certificates using [Traefik](https://docs.traefik.io/). The image with the tag `auth` does _not_ integrate the [Let’s Encrypt](https://letsencrypt.org/) LTS certificates using [Traefik](https://docs.traefik.io/). The image built with the tag `milter` include Postfix and the anti-spam and ant-virus [milters](https://en.wikipedia.org/wiki/Milter). Finally the image `smtp` only contain Postfix.

To exemplify the usage of the tags, lets assume that the latest version is `1.0.0`. In this case `latest`, `1.0.0`, `full`, `full-latest` and `full-1.0.0` all identify the same image.

## Usage

Often you want to configure Postfix and its components. There are different methods available to achieve this. You can use the environment variables described below set in the shell before creating the container. These environment variables can also be explicitly given on the command line when creating the container. They can also be given in an `docker-compose.yml` file, see below. Moreover docker volumes or host directories with desired configuration files can be mounted in the container. And finally you can `exec` into a running container and modify configuration files directly.

If you want to test the image you can start it using the destination domain `example.com` and mail boxes for info@example.com and abuse@example.com using the shell command below.

```bash
docker run -d --name mail-mta --hostname mx1.example.com -e MAIL_BOXES="info@example.com abuse@example.com" -p 25:25 mlan/postfix-amavis
```

### Docker compose example

An example of how to configure an mail server using docker compose is given below. It defines two services, `mail-mta`, and `auth`, which are the mail transfer agent and the LDAP mailbox lookup database respectively. In this example messages are delivered to a web mail application, which is not defined here. 

```yaml
version: '3.7'

services:
  mail-mta:
    image: mlan/postfix-amavis:1
    restart: unless-stopped
    hostname: ${MAIL_SRV-mx}.${MAIL_DOMAIN-docker.localhost}
    networks:
      - backend
    ports:
      - "25:25"
    depends_on:
      - auth
    environment:
      - MESSAGE_SIZE_LIMIT=${MESSAGE_SIZE_LIMIT-25600000}
      - LDAP_HOST=auth
      - VIRTUAL_TRANSPORT=lmtp:mail-app:2003
      - SMTP_RELAY_HOSTAUTH=${SMTP_RELAY_HOSTAUTH}
      - SMTP_TLS_SECURITY_LEVEL=${SMTP_TLS_SECURITY_LEVEL-}
      - SMTP_TLS_WRAPPERMODE=${SMTP_TLS_WRAPPERMODE-no}
      - LDAP_USER_BASE=${LDAP_USEROU},${LDAP_BASE}
      - LDAP_QUERY_FILTER_USER=(&(kopanoAccount=1)(mail=%s))
      - LDAP_QUERY_FILTER_ALIAS=(&(kopanoAccount=1)(kopanoAliases=%s))
      - DKIM_SELECTOR=${DKIM_SELECTOR-default}
      - SYSLOG_LEVEL=4
    env_file:
      - .init.env
    volumes:
      - mail-mta:/var

  auth:
    image: mlan/openldap:1
    restart: unless-stopped
    networks:
      - backend
    environment:
      - LDAP_LOGLEVEL=parse
    volumes:
      - auth-conf:/srv/conf
      - auth-data:/srv/data

networks:
  backend:

volumes:
  mail-mta:
  auth-conf:
  auth-data:

```

### Environment variables

When you create the `mlan/postfix-amavis` container, you can configure the services by passing one or more environment variables or arguments on the docker run command line. Note that any pre-existing configuration files within the container will be updated.

To see all available configuration variables you can run `postconf` within the container, for example like this:

```bash
docker exec -it mail-mta postconf
```

If you do, you will notice that configuration variable names are all lower case, but they will be matched with all uppercase environment variables by the container entrypoint script.

### Outgoing SMTP relay

Sometimes you want outgoing email to be sent to a SMTP relay and _not_ directly to its destination. This could for instance be when your ISP is blocking port 25 or perhaps if you have a dynamic IP and are afraid of that mail servers will drop your outgoing emails because of that.

#### `SMTP_RELAY_HOSTAUTH`
This environment variable simplify a SMTP relay configuration. The SMTP relay host might require SASL authentication in which case user name and password can also be given in variable. The format is `"host:port user:passwd"`. Example: `SMTP_RELAY_HOSTAUTH="[example.relay.com]:587 e863ac2bc1e90d2b05a47b2e5c69895d:b35266f99c75d79d302b3adb42f3c75f"`

#### `SMTP_TLS_SECURITY_LEVEL`

You can enforce the use of TLS, so that the Postfix SMTP server announces STARTTLS and accepts no
mail without TLS encryption, by setting `SMTP_TLS_SECURITY_LEVEL=encrypt`. Default: `SMTP_TLS_SECURITY_LEVEL=none`.

#### `SMTP_TLS_WRAPPERMODE`

To configure the Postfix SMTP client connecting using the legacy SMTPS protocol instead of using the STARTTLS command, set `SMTP_TLS_WRAPPERMODE=yes`. This mode requires `SMTP_TLS_SECURITY_LEVEL=encrypt` or stronger. Default: `SMTP_TLS_WRAPPERMODE=no`

### Incoming destination domain

Postfix is configured to be
the final destination of the virtual/hosted domains defined by the environment variable `MAIL_DOMAIN`. If the domains are not properly configured Postfix will be rejecting the emails. At present there is _no_ support for multiple domains.

#### `MAIL_DOMAIN`

The default value of `MAIL_DOMAIN=$(hostname -d)` is to
use the host name of the container minus the first component. So you can either use the environment variable `MAIL_DOMAIN` or the argument `--hostname`. So for example, `--hostname mx1.example.com` or `-e MAIL_DOMAIN=example.com`.

### Incoming TLS support

Transport Layer Security (TLS, formerly called SSL) provides certificate-based authentication and encrypted sessions. An encrypted session protects the information that is transmitted with SMTP mail or with SASL authentication. 

Here TLS is activated for inbound messages when `SMTPD_TLS_CERT_FILE` is not empty. The Postfix SMTP server generally needs a certificate and a private key. Both must be in "PEM" format. The private key must not be encrypted, meaning: the key must be accessible without a password. The certificate and a private key files are identified by `SMTPD_TLS_CERT_FILE` and `SMTPD_TLS_KEY_FILE`.

#### `SMTPD_TLS_CERT_FILE`

Specifies the RSA certificate file within the container to be used with incoming TLS connections. Example `SMTPD_TLS_CERT_FILE=cert.pem`

#### `SMTPD_TLS_KEY_FILE`

Specifies the RSA private key file within the container to be used with incoming TLS connections. Example `SMTPD_TLS_KEY_FILE=key.pem`

### TLS forward secrecy

The term "Forward Secrecy" (or sometimes "Perfect Forward Secrecy") is used to describe security protocols in which the confidentiality of past traffic is not compromised when long-term keys used by either or both sides are later disclosed.

Forward secrecy is accomplished by negotiating session keys using per-session cryptographically-strong random numbers that are not saved, and signing the exchange with long-term authentication keys. Later disclosure of the long-term keys allows impersonation of the key holder from that point on, but not recovery of prior traffic, since with forward secrecy, the discarded random key agreement inputs are not available to the attacker.

The built in utility script `mtaconf` can be used to generate the Diffie-Hellman parameters needed for forward secrecy.

```bash
docker exec -it mail-mta mtaconf postconf_edh
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

### Incoming anti-spam and anti-virus

Amavisd-new is a high-performance interface between mailer (MTA) and content checkers: virus scanners, and/or SpamAssassin. Apache SpamAssassin is the #1 open source anti-spam platform giving system administrators a filter to classify email and block spam (unsolicited bulk email). It uses a robust scoring framework and plug-ins to integrate a wide range of advanced heuristic and statistical analysis tests on email headers and body text including text analysis, Bayesian filtering, DNS blocklists, and collaborative filtering databases. Clam AntiVirus is an anti-virus toolkit, designed especially for e-mail scanning on mail gateways.

AMaViS will only insert mail headers in incoming messages with domain mentioned in `MAIL_DOMAIN`. So proper configuration is needed for anti-spam and anti-virus to work. 

### Incoming SPF sender authentication

Sender Policy Framework (SPF) is an [email authentication](https://en.wikipedia.org/wiki/Email_authentication) method designed to detect forged sender addresses in emails. SPF allows the receiver to check that an email claiming to come from a specific domain comes from an IP address authorized by that domain's administrators. The list of authorized sending hosts and IP addresses for a domain is published in the [DNS](https://en.wikipedia.org/wiki/Domain_Name_System_Security_Extensions) records for that domain.

### DKIM sender authentication

Domain-Keys Identified Mail (DKIM) is an [email authentication](https://en.wikipedia.org/wiki/Email_authentication) method designed to detect forged sender addresses in emails. DKIM allows the receiver to check that an email claimed to have come from a specific [domain](https://en.wikipedia.org/wiki/Domain_name) was indeed authorized by the owner of that domain. It achieves this by affixing a [digital signature](https://en.wikipedia.org/wiki/Digital_signature), linked to a domain name, `MAIL_DOMAIN`, to each outgoing email message, which the receiver can verify by using the DKIM key published in the [DNS](https://en.wikipedia.org/wiki/Domain_Name_System_Security_Extensions) records for that domain.

OpenDKIM is configured to check the digital signature of incoming email as well as add digital signatures to outgoing email.

#### `DKIM_KEYBITS`

The bit length used when creating new keys. Default: `DKIM_KEYBITS=2048`

#### `DKIM_SELECTOR`
This will set the `Selector` property in the `/etx/opendkim/opendkim.conf` file.
The public key DNS record should appear as a TXT resource record at: `DKIM_SELECTOR._domainkey.DOMAIN`

Example `DKIM_SELECTOR=default`
#### `DKIM_PRIVATEKEY`
Opendkim uses a private and public key pair used for signing and verifying your mail.
The private key is stored here: `/var/db/dkim/$DKIM_SELECTOR.private`.

Run the script "opendkim-genkey -s $DKIM_SELECTOR". The opendkim-genkey man
page has full details of options. This will generate a private key
in PEM format and output a TXT record containing the matching public
key appropriate for insertion into your DNS zone file. Insert it in
your zone file, increment the serial number, and reload your DNS system
so the data is published.
You can copy your key into the container `docker cp default.private container_name:var/db/dkim`.

Alternatively you can pass the private key using the `DKIMPRIVATE_KEY` variable.
If you do, you can exclude the strings `-----BEGIN RSA PRIVATE KEY-----` and `-----END RSA PRIVATE KEY-----`
Example `DKIM_PRIVATEKEY="MIIEpAIBAAKCAQEA04up8hoqzS...1+APIB0RhjXyObwHQnOzhAk"`

### Table mailbox lookup

Postfix can use a table as a source for any of its lookups including virtual mailbox and aliases. The `mlan/postfix-amavis` image provides a simple way to generate virtual mailbox lookup using the `MAIL_BOXES` environment variable.

#### `MAIL_BOXES`

Using the `MAIL_BOXES` environment variable you simply provide a space separated list with all email addressees that Postfix should accept incoming mail to. For example: `MAIL_BOXES="info@example.com abuse@example.com"`. The default value is empty.

### LDAP mailbox lookup

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


### Delivery transport
The `mlan/postfix-amavis` image is designed primarily to work with a companion software which holds the mail boxes. That is, Postfix is not intended to be used for final delivery.

#### `VIRTUAL_TRANSPORT`

Postfix delivers the messages to the companion software, like [Kolab](https://hub.docker.com/r/kvaps/kolab), [Kopano](https://cloud.docker.com/u/mlan/repository/docker/mlan/kopano) or [Zimbra](https://hub.docker.com/r/jorgedlcruz/zimbra/), using a transport mechanism you specify using the environment variable `VIRTUAL_TRANSPORT`. LMTP is one such transport mechanism. One example of final delivery transport to Kopano is: `VIRTUAL_TRANSPORT=lmtp:app:2003`

### Message size limit `MESSAGE_SIZE_LIMIT`

The maximal size in bytes of a message, including envelope information. Default: `MESSAGE_SIZE_LIMIT=10240000` ~10MB. Many mail servers are configured with maximal size of 10MB, 20MB or 25MB.

### Logging `SYSLOG_LEVEL`

The level of output for logging is in the range from 0 to 8. 0 means emergency logging only, 1 for alert messages, 2 for critical messages only, 3 for error or worse, 4 for warning or worse, 5 for notice or worse, 6 for info or worse, 7 debug. Default: `SYSLOG_LEVEL=4`

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
