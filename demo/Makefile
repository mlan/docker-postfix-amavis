-include    *.mk .env .init.env

_ip       = $(shell docker inspect -f \
	'{{range .NetworkSettings.Networks}}{{println .IPAddress}}{{end}}' \
	$(1) | head -n1)

.PHONY:

variables:
	make -pn | grep -A1 "^# makefile"| grep -v "^#\|^--" | sort | uniq

ps:
	docker-compose ps

init: auth-up wait_11 auth-mod_index auth-add_user mail-db-up mail-mta-up wait_12 mail-app-up wait_23 mail-app-create_store

up:
	docker-compose up -d

down:
	docker-compose down

destroy:
	docker-compose down -v

config:
	docker-compose config

wait_%:
	sleep $*

web:
	firefox localhost:8080 &

test: mail-mta-test

auth-up:
	docker-compose up -d auth

auth-down:
	docker-compose rm -s auth

auth-cmd:
	docker-compose exec auth /bin/sh

auth-logs:
	docker container logs $(COMPOSE_PROJECT_NAME)_auth_1

auth-show_conf:
	docker-compose exec auth ldap search -b cn=config olcDatabase={1}mdb

auth-show_user:
	docker-compose exec auth ldap search -b "$(LDAP_BASE)"

auth-add_user:
	printf "dn: ou=$(LDAP_USEROU),$(LDAP_BASE)\nchangetype: add\nobjectClass: organizationalUnit\nobjectClass: top\nou: $(LDAP_USEROU)\n\ndn: ou=$(LDAP_GROUPOU),$(LDAP_BASE)\nchangetype: add\nobjectClass: organizationalUnit\nobjectClass: top\nou: $(LDAP_GROUPOU)\n\ndn: uid=$(LDAP_TEST_USER),ou=$(LDAP_USEROU),$(LDAP_BASE)\nchangetype: add\nobjectClass: top\nobjectClass: inetOrgPerson\nobjectClass: $(LDAP_USEROBJ)\ncn: $(LDAP_TEST_USER)\nsn: $(LDAP_TEST_USER)\nuid: $(LDAP_TEST_USER)\nmail: $(LDAP_TEST_USER)@$(MAIL_DOMAIN)\nuidNumber: 1234\ngidNumber: 1234\nhomeDirectory: /home/$(LDAP_TEST_USER)\nuserPassword: $(LDAP_TEST_PASSWD)\n" \
	| docker-compose exec -T auth ldap modify

auth-mod_index:
	printf "dn: olcDatabase={1}mdb,cn=config\nchangetype: modify\nadd: olcDbIndex\nolcDbIndex: cn,ou,uid,mail eq\n" \
	| docker-compose exec -T auth ldap modify

mail-mta-up:
	docker-compose up -d mail-mta

mail-mta-down:
	docker-compose rm -s mail-mta

mail-mta-cmd:
	docker-compose exec mail-mta /bin/sh

mail-mta-logs:
	docker container logs $(COMPOSE_PROJECT_NAME)_mail-mta_1

mail-mta-diff:
	docker container diff $(COMPOSE_PROJECT_NAME)_mail-mta_1

mail-mta-bayes:
	docker-compose exec mail-mta sh -c 'rm -f bayesian.database.gz && wget http://artinvoice.hu/spams/bayesian.database.gz && gunzip bayesian.database.gz && sa-learn --restore bayesian.database && chown -R amavis: /var/amavis/.spamassassin && rm -rf bayesian.database'

mail-mta-test:
	printf "EHLO mx\nMAIL FROM: <test@example.biz>\nRCPT TO: <$(LDAP_TEST_USER)@$(MAIL_DOMAIN)>\nDATA\nFrom: A tester <test@example.biz>\nTo: <$(LDAP_TEST_USER)@$(MAIL_DOMAIN)>\nDate: $$(date)\nSubject: A SMTP test message\n\nGreat news! You can receive email.\n.\nQUIT\n" \
	| nc -C localhost 25

mail-mta-razor:
	docker-compose exec mail-mta conf cntcfg_razor_register

mail-mta-apk_list:
	docker-compose exec mail-mta /bin/sh -c 'for pkg in $$(apk info 2>/dev/null); do printf "%9s  %s\n" $$(apk info -s $$pkg 2>/dev/null | sed -n "2{p;q}") $$pkg; done | sort'

mail-mta-quarantine_list:
	docker-compose exec mail-mta amavisd-ls

mail-mta-debugtools:
	docker-compose exec mail-mta apk --no-cache --update add \
	nano less lsof htop openldap-clients bind-tools iputils strace

mail-db-up:
	docker-compose up -d mail-db

mail-db-down:
	docker-compose rm -s mail-db

mail-db-cmd:
	docker-compose exec mail-db /bin/bash

mail-db-logs:
	docker container logs $(COMPOSE_PROJECT_NAME)_mail-db_1

mail-db-diff:
	docker container diff $(COMPOSE_PROJECT_NAME)_mail-db_1

mail-db-test:
	docker-compose exec mail-db mysqlshow -u $(MYSQL_USER) $(MYSQL_DATABASE) -p$(MYSQL_PASSWORD)

mail-app-up:
	docker-compose up -d mail-app

mail-app-down:
	docker-compose rm -s mail-app

mail-app-cmd:
	docker-compose exec mail-app /bin/bash

mail-app-logs:
	docker container logs $(COMPOSE_PROJECT_NAME)_mail-app_1

mail-app-diff:
	docker container diff $(COMPOSE_PROJECT_NAME)_mail-app_1

mail-app-debugtools:
	docker-compose exec mail-app apt-get update
	docker-compose exec mail-app apt-get install --yes \
	less nano ldap-utils htop net-tools lsof iputils-ping strace

mail-app-htop: mail-app-debugtools
	docker-compose exec mail-app htop

mail-app-man_server:
	docker-compose exec mail-app man kopano-server.cfg

mail-app-man_ldap:
	docker-compose exec mail-app man kopano-ldap.cfg

mail-app-test_smtp: mail-mta-test

mail-app-test_lmtp:
	printf "LHLO mx\nMAIL FROM: <test@example.biz>\nRCPT TO: <$(LDAP_TEST_USER)@$(MAIL_DOMAIN)>\nDATA\nFrom: A tester <test@example.biz>\nTo: <$(LDAP_TEST_USER)@$(MAIL_DOMAIN)>\nDate: $$(date)\nSubject: A LMTP test message from me to you\n\nDelete me, please \n.\nQUIT\n" | nc -C $(call _ip,$(COMPOSE_PROJECT_NAME)_mail-app_1) 2003

mail-app-show_user1: 
	docker-compose exec mail-app kopano-admin -l

mail-app-show_user2: mail-app-debugtools
	docker-compose exec mail-app ldapsearch -H ldap://auth:389 -xLLL -b $(LDAP_BASE) '*'

mail-app-create_store:
	docker-compose exec mail-app kopano-admin --create-store $(LDAP_TEST_USER)
