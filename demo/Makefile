-include    *.mk .env .init.env

srv_list ?= auth app db mta
curl_dbg ?= -v
_ip       = $(shell docker inspect -f \
	'{{range .NetworkSettings.Networks}}{{println .IPAddress}}{{end}}' \
	$(1) | head -n1)

.PHONY:

variables:
	make -pn | grep -A1 "^# makefile"| grep -v "^#\|^--" | sort | uniq

test: mta-test_quiet mta-test_smtp

init: auth-init db-up mta-up app-up

auth-init: auth-up wait_11 auth-mod_hash auth-mod_index auth-add_user

ps:
	docker-compose ps

up:
	docker-compose up -d

down:
	docker-compose down

destroy:
	docker-compose down -v

config:
	docker-compose config

logs:
	docker-compose logs --tail 10

images:
	docker-compose images

$(addsuffix -up,$(srv_list)):
	docker-compose up -d $(patsubst %-up,%,$@)

$(addsuffix -down,$(srv_list)):
	docker-compose rm -s $(patsubst %-down,%,$@)

$(addsuffix -restart,$(srv_list)):
	docker-compose restart $(patsubst %-restart,%,$@)

$(addsuffix -renew,$(srv_list)):
	docker-compose rm -s $(patsubst %-renew,%,$@)
	docker-compose up -d $(patsubst %-renew,%,$@)

$(addsuffix -top,$(srv_list)):
	docker-compose top $(patsubst %-top,%,$@)

$(addsuffix -logs,$(srv_list)):
	docker-compose logs $(patsubst %-logs,%,$@)

$(addsuffix -sh,$(srv_list)):
	docker-compose exec $(patsubst %-sh,%,$@) sh

$(addsuffix -env,$(srv_list)):
	docker-compose exec $(patsubst %-env,%,$@) env

$(addsuffix -sv,$(srv_list)):
	docker-compose exec $(patsubst %-sv,%,$@) sh -c 'sv status $$SVDIR/*'

$(addsuffix -diff,$(srv_list)):
	docker container diff $(COMPOSE_PROJECT_NAME)_$(patsubst %-diff,%,$@)_1

wait_%:
	sleep $*

web:
	firefox localhost:8008 &

auth-show_conf:
	docker-compose exec auth ldap search -b cn=config "(cn=config)"
	docker-compose exec auth ldap search -b cn=config olcDatabase={-1}frontend
	docker-compose exec auth ldap search -b cn=config olcDatabase={1}mdb

auth-show_user:
	docker-compose exec auth ldap search -b "$(LDAP_BASE)"

auth-show_cat0:
	docker-compose exec auth slapcat -n0

auth-show_cat1:
	docker-compose exec auth slapcat -n1

auth-add_user:
	printf "dn: ou=$(LDAP_USEROU),$(LDAP_BASE)\nchangetype: add\nobjectClass: organizationalUnit\nobjectClass: top\nou: $(LDAP_USEROU)\n\ndn: ou=$(LDAP_GROUPOU),$(LDAP_BASE)\nchangetype: add\nobjectClass: organizationalUnit\nobjectClass: top\nou: $(LDAP_GROUPOU)\n\ndn: uid=$(LDAP_TEST_USER),ou=$(LDAP_USEROU),$(LDAP_BASE)\nchangetype: add\nobjectClass: top\nobjectClass: inetOrgPerson\nobjectClass: $(LDAP_USEROBJ)\ncn: $(LDAP_TEST_USER)\nsn: $(LDAP_TEST_USER)\nuid: $(LDAP_TEST_USER)\nmail: $(LDAP_TEST_USER)@$(MAIL_DOMAIN)\nuidNumber: 1234\ngidNumber: 1234\nhomeDirectory: /home/$(LDAP_TEST_USER)\nuserPassword: $(LDAP_TEST_PASSWD)\n" \
	| docker-compose exec -T auth ldap modify

auth-mod_index:
	printf "dn: olcDatabase={1}mdb,cn=config\nchangetype: modify\nadd: olcDbIndex\nolcDbIndex: cn,ou,uid,mail eq\n" \
	| docker-compose exec -T auth ldap modify

auth-mod_hash:
	printf "dn: olcDatabase={-1}frontend,cn=config\nchangetype: modify\nadd: olcPasswordHash\nolcPasswordHash: {CRYPT}\n\ndn: cn=config\nchangetype: modify\nadd: olcPasswordCryptSaltFormat\nolcPasswordCryptSaltFormat: \$$6\$$%%.16s\n" \
	| docker-compose exec -T auth ldap modify

mta-bayes:
	docker-compose exec mta sh -c 'rm -f bayesian.database.gz && wget http://artinvoice.hu/spams/bayesian.database.gz && gunzip bayesian.database.gz && sa-learn --restore bayesian.database && chown -R amavis: /var/amavis/.spamassassin && rm -rf bayesian.database'

mta-test_quiet:
	$(eval curl_dbg := )

mta-test_smtp:
	printf "From: A tester <test@example.biz>\nTo: <$(LDAP_TEST_USER)@$(MAIL_DOMAIN)>\nDate: $$(date)\nSubject: A SMTP test message\n\nGreat news! You can receive email.\n" \
	| curl smtp://localhost -s -T - $(curl_dbg) \
	--mail-from test@example.biz --mail-rcpt $(LDAP_TEST_USER)@$(MAIL_DOMAIN)

mta-test_smtp2:
	printf "From: A info tester <test-info@example.biz>\nTo: <$(LDAP_TEST_USER)-info@$(MAIL_DOMAIN)>\nDate: $$(date)\nSubject: A SMTP test message \n\nGreat news! $(LDAP_TEST_USER)-info@$(MAIL_DOMAIN) can also receive email.\n" \
	| curl smtp://localhost -s -T - $(curl_dbg) \
	--mail-from test@example.biz --mail-rcpt $(LDAP_TEST_USER)@$(MAIL_DOMAIN)

mta-razor:
	docker-compose exec mta run amavis_register_razor

mta-apk_list:
	docker-compose exec mta /bin/sh -c 'for pkg in $$(apk info 2>/dev/null); do printf "%9s  %s\n" $$(apk info -s $$pkg 2>/dev/null | sed -n "2{p;q}") $$pkg; done | sort'

mta-quarantine_list:
	docker-compose exec mta amavis-ls

mta-freshclam_nodns:
	docker-compose exec mta freshclam --no-dns

mta-clamdtop:
	docker-compose exec mta clamdtop

mta-debugtools:
	docker-compose exec mta apk --no-cache --update add \
	nano less lsof htop openldap-clients bind-tools iputils strace

mta-htop: mta-debugtools
	docker-compose exec mta htop

mta-encrypt:
	$(eval secret := $(shell whiptail --backtitle "doveadm pw" --title "encrypt password" --inputbox "password" 8 78 secret 3>&1 1>&2 2>&3))
	docker-compose exec mta doveadm pw -p $(secret)

mta-show_doveconf:
	docker-compose exec mta doveconf -n

mta-show_postconf:
	docker-compose exec mta postconf -n

mta-show_mailq:
	docker-compose exec mta mailq

mta-flush_mailq:
	docker-compose exec mta postqueue -f

mta-hostaddr:
	$(eval myhost := $(call _ip,$(COMPOSE_PROJECT_NAME)_mta_1))

mta-test_auth:
	docker-compose exec mta doveadm auth test $(LDAP_TEST_USER) $(LDAP_TEST_PASSWD)

mta-test_imap: mta-hostaddr
	curl imap://$(myhost) -X CAPABILITY
	curl imap://$(myhost) -u $(LDAP_TEST_USER):$(LDAP_TEST_PASSWD)

mta-test_rimap:
	docker-compose exec mta curl imap://app -X CAPABILITY
	docker-compose exec mta curl imap://app -u $(LDAP_TEST_USER):$(LDAP_TEST_PASSWD)

mta-test_ldap: mta-debugtools
	docker-compose exec mta ldapsearch -H ldap://auth:389 -xLLL -s base namingContexts

db-test:
	docker-compose exec db mysqlshow -u $(MYSQL_USER) $(MYSQL_DATABASE) -p$(MYSQL_PASSWORD)

app-debugtools:
	docker-compose exec app apt-get update
	docker-compose exec app apt-get install --yes \
	less nano ldap-utils htop net-tools lsof iputils-ping strace

app-htop: app-debugtools
	docker-compose exec app htop

app-man_server:
	docker-compose exec app man kopano-server.cfg

app-man_ldap:
	docker-compose exec app man kopano-ldap.cfg

app-hostaddr:
	$(eval myhost := $(call _ip,$(COMPOSE_PROJECT_NAME)_app_1))

app-test_smtp: mta-test_smtp

app-test_lmtp: app-hostaddr
	printf "LHLO mx\nMAIL FROM: <test@example.biz>\nRCPT TO: <$(LDAP_TEST_USER)@$(MAIL_DOMAIN)>\nDATA\nFrom: A tester <test@example.biz>\nTo: <$(LDAP_TEST_USER)@$(MAIL_DOMAIN)>\nDate: $$(date)\nSubject: A LMTP test message from me to you\n\nDelete me, please \n.\nQUIT\n" | nc -C $(myhost) 2003

app-test_imap: app-hostaddr
	curl imap://$(myhost) -X CAPABILITY
	curl imap://$(myhost) -u $(LDAP_TEST_USER):$(LDAP_TEST_PASSWD)

app-test_pop3: app-hostaddr
	curl pop3://$(myhost) -u $(LDAP_TEST_USER):$(LDAP_TEST_PASSWD)

app-test_ical: app-hostaddr
	curl http://$(myhost):8080 -u $(LDAP_TEST_USER):$(LDAP_TEST_PASSWD)

app-show_user1:
	docker-compose exec app kopano-admin -l

app-show_user2: app-debugtools
	docker-compose exec app ldapsearch -H ldap://auth:389 -xLLL -b $(LDAP_BASE) '*'

app-show_sync:
	docker-compose exec app z-push-top

app-create_store:
	docker-compose exec app kopano-admin --create-store $(LDAP_TEST_USER)
