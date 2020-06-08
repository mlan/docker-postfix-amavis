# Road map

## Entrypoint.d

Split up entrypoint.sh script in sever "run-parts" files to be put in entrypoint.d.

### The `docker-include_?.sh`files.

The `docker-include_?.sh` files defines shell functions and variables that are used during the build, init and run phases of the image/container.

| File name          | Usage                                                        |
| ------------------ | ------------------------------------------------------------ |
| docker-logger.inc  | General, logging and test                                    |
| docker-modfile.inc | General, image build phase in Dockerfile                     |
| docker-common.inc  | General, functions                                  |
| build-postfix.inc  | Service specific                                  |
| entry-postfix.inc  | Service specific                                  |
| docker-acme.inc   | Feature specific, image build phase in Dockerfile            |
| docker-entry.inc   | Service specific, container initialization phase in run-parts files |


#### `docker-logger.inc`
```sh
#!/bin/sh -e

d_log()
d_log_tag()
d_log_level()
d_log_stamp()
d_is_installed()
```

#### `docker-chfile.inc`

Used in Dockerfile.
```dockerfile
RUN	. docker-chfile.inc \
	dm_modify /etc/amavis/amavisd.conf '\$pid_file' = '"/run/amavis/amavisd.pid";'
```

File overview:
```sh
#!/bin/sh -e
. docker-logger.inc

d_modify()
d_replace()
d_addafter()
d_comment()
d_uncommentsection()
d_removeline()
d_uniquelines()

d_chowncond()
d_condappend()
d_common_persist_dirs

```
#### `docker-build.inc`

Used in Dockerfile.
```dockerfile
RUN	. docker-build.inc \
	db_mvfile dist /etc/postfix/aliases
```

File overview:
```sh
#!/bin/sh -e
. docker-modfile.inc

db_dovecot_passwdfile()
db_amavis_postfix()
db_dirpersist()
db_cpfile()
db_mvfile()
```
- imgcfg_runit_acme_dump()

#### `docker-startup.inc`

Used in run-parts files.

```sh
#!/bin/sh
#
# 30_configure-postfix-amavis

. docker-startup.inc
ds_postfix_smtp_auth_pwfile
```

File overview:
```sh
#!/bin/sh -e
. docker-modfile.inc

lock_config()
_need_config()
cntrun_cfgall()
cntcfg_postfix_smtp_auth_pwfile()
cntcfg_dovecot_smtpd_auth_pwfile()
cntcfg_default_domains()
cntcfg_postfix_domains()
cntcfg_amavis_domains()
cntcfg_amavis_dkim()
_cntgen_postfix_ldapmap()
cntcfg_postfix_mailbox_auth_ldap()
cntcfg_postfix_mailbox_auth_hash()
cntcfg_postfix_alias_map()
cntcfg_acme_postfix_tls_cert()
cntcfg_postfix_generate_tls_cert()
cntcfg_postfix_activate_tls_cert()
cntcfg_postfix_apply_envvars()
cntcfg_amavis_apply_envvars()
cntcfg_razor_register()
```

#### src/docker/entrypoint.d/20_configure

#### src/docker/entrypoint.d/50_chown_home
cntrun_chown_home()

#### src/docker/entrypoint.d/50_prune_pidfiles
cntrun_prune_pidfiles()

#### src/amavis/entrypoint.d/50_runit-spamd
cntrun_runit_spamd()

### Used during runtime

#### src/docker/entrypoint.d/50_update-loglevel
cntrun_loglevel_update()

#### src/amavis/entrypoint.d/50_update-spamassassin
cntrun_spamassassin_update()

#### `postfix-include_3.sh`
doveadm_pw()
update_postfix_dhparam()
cntrun_cli_and_exit()

## Docker config lock

Revisit the config lock. Now we depend on a single file. Feels unsafe.

Compute SHA1 for config folder (`DOCKER_LOCKDIR=/etc/postfix`) at build stage (`DOCKER_LOCKFILE=.lock.sha1`).
At start-up
1) There is no DOCKER_LOCKFILE; "empty" volume mounted, so run configuration.
2) The DOCKER_LOCKFILE has the same SHA; virgin dir, so run configuration.
3) The DOCKER_LOCKFILE has different SHA; already configured, so don't touch it.

```sh
find $DOCKER_LOCKDIR/ f ! -name $DOCKER_LOCKFILE -print0 | sort -z | xargs -0 sha1sum | sha1sum
```
#### Things to consider:

There are more the one config directory;
- /etc/amavis/
- /etc/clamav/
- /etc/dovecot/
- /etc/postfix/
- /etc/ssl/

The config directories of the image are not empty.
During both build and startup, config files backed up, with suffix .dist and .bld,
which could be used to determine config state?

Perhaps we just keep the config lock the way it is?

## amavisd-ls

Perhaps, implement something more interactive using dialog?

## Dovecot IMAP and POP3

Accommodate IMAP and POP3 configuration via environment variables in build target `base`

## OpenDMARC

Consider installing opendmarc once it is available in alpine/main (now in testing).
Include in build target `full` in Dockerfile.
Add configuration function in entrypoint.sh

## Pyzor

Consider installing pyzor once it is available in alpine/main (now in testing).
Include in build target `full` in Dockerfile.
Add configuration function in entrypoint.sh

## Amavisd optimization

Lets see if we can optimize the amavisd parameters so that we can improve
its throughput using ideas in [amavisd-new, advanced configuration and management](https://www.ijs.si/software/amavisd/amavisd-new-magdeburg-20050519.pdf)

## Amavisd MySQL Quarantine

#### References

[Set-up-SQL-quarantine-with-Amavisd-new-and-ISPConfig](https://uname.pingveno.net/blog/index.php/post/2015/12/05/Set-up-SQL-quarantine-with-Amavisd-new-and-ISPConfig)

[Explanation of Amavisd SQL database](https://docs.iredmail.org/amavisd.sql.db.html)

#### MySQL Database

Create an user and a database for quarantine storage :

```bash
# mysql -u root -p
mysql> CREATE DATABASE amavis_storage;
mysql> CREATE USER 'amavis_storage'@'localhost' IDENTIFIED BY 'xxxx';
mysql> GRANT ALL PRIVILEGES ON amavis_storage.* TO 'amavis_storage'@'localhost';
mysql> FLUSH PRIVILEGES;
```
Load the initial schema from Amavis docs (usually located in /usr/share/doc/amavisd-new/ ).

Delete unnecessary tables, as we will be using this database only for mail storage and not for lookups :
```bash
# mysql -u amavis_storage -p amavis_storage
mysql> DROP TABLE users;
mysql> DROP TABLE mailaddr;
mysql> DROP TABLE policy;
mysql> DROP TABLE wblist;
```

#### amavisd.conf

```bash
@storage_sql_dsn = ( ['DBI:mysql:database=amavis_storage;host=127.0.0.1;port=3306', 'amavis_storage', 'xxxx'] );  # none, same, or separate database

# Quarantine SPAM into SQL server.
$spam_quarantine_method = 'sql:';

# Quarantine VIRUS into SQL server.
$virus_quarantine_method = 'sql:';

# Quarantine BANNED message into SQL server.
$banned_files_quarantine_method = 'sql:';

# Quarantine Bad Header message into SQL server.
$bad_header_quarantine_method = 'sql:';

# Do not store non-quarantined messages info
# You can set it to 1 (the default) to test if Amavis is filling correctly the tables maddr, msgs, and msgcrpt
$sql_store_info_for_all_msgs = 0;
```
