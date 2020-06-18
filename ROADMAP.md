# Road map

## Entrypoint.d

Make these CLI functions available:
- doveadm_pw()
- update_postfix_dhparam()

## Docker config lock

Revisit the config lock. Now we depend on a single file. Feels unsafe.

### SHA1

Compute SHA1 for config folder (`DOCKER_LOCKDIR=/etc/postfix`) at build stage (`DOCKER_LOCKFILE=.lock.sha1`).
At start-up
1) The DOCKER_LOCKFILE has the same SHA; virgin dir, so run configuration.
2) The DOCKER_LOCKFILE has different SHA; already configured, so don't touch it. There should always be a DOCKER_LOCKFILE if not, something is wrong so print error and do noting.

```sh
find $DOCKER_LOCKDIR/ f ! -name $DOCKER_LOCKFILE -print0 | sort -z | xargs -0 sha1sum | sha1sum
```
### DOCKER_UNLOCKFILE

At build stage touch `DOCKER_UNLOCKFILE=/srv/etc/.unlock`. at startup: 1) there is a DOCKER_UNLOCKFILE or DOCKER_FORCE, run configuration and delete DOCKER_UNLOCKFILE. 2) no DOCKER_UNLOCKFILE, assume already configured, so don't touch it.

This should be safer since it is difficult to accidentally _create_ a file.

## amavis-ls

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
