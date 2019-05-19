-include    *.mk .env .init.env

.PHONY: variables ps init up down destroy wait test \
	auth-up auth-down auth-cmd auth-logs auth-show_conf auth-show_user auth-add_user \
	mail-mta-up mail-mta-down mail-mta-cmd mail-mta-logs mail-mta-bayes mail-mta-test \
	mail-db-up mail-db-down mail-db-cmd mail-db-logs mail-db-test \
	mail-app-up mail-app-down mail-app-cmd mail-app-logs mail-app-debugtools \
	mail-app-man_server mail-app-man_ldap \
	mail-app-test mail-app-show_user1 mail-app-show_user2

variables:
	make -pn | grep -A1 "^# makefile"| grep -v "^#\|^--" | sort | uniq

ps:
	docker-compose ps

init: auth-up wait auth-add_user wait mail-db-up wait mail-mta-up wait mail-app-up

up:
	docker-compose up -d

down:
	docker-compose down

destroy:
	docker-compose down -v

wait:
	sleep 10

test: mail-mta-test

auth-up:
	docker-compose up -d auth

auth-down:
	docker-compose down auth

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

mail-mta-up:
	docker-compose up -d mail-mta

mail-mta-down:
	docker-compose down mail-mta

mail-mta-cmd:
	docker-compose exec mail-mta /bin/bash

mail-mta-logs:
	docker container logs $(COMPOSE_PROJECT_NAME)_mail-mta_1

mail-mta-bayes:
	docker-compose exec mail-mta sh -c 'rm -f bayesian.database.gz && wget http://artinvoice.hu/spams/bayesian.database.gz && gunzip bayesian.database.gz && sa-learn --restore bayesian.database && chown -R amavis: /var/amavis/.spamassassin && rm -rf bayesian.database'

mail-mta-test:
	printf "EHLO mx\nMAIL FROM: <test@example.biz>\nRCPT TO: <$(LDAP_TEST_USER)@$(MAIL_DOMAIN)>\nDATA\nFrom: A tester <test@example.biz>\nTo: <$(LDAP_TEST_USER)@$(MAIL_DOMAIN)>\nDate: $$(date)\nSubject: A test message\n\nGreat news! You can receive email.\n.\nQUIT\n" \
	| nc -C localhost 25

mail-mta-razor:
	docker-compose exec mail-mta conf cntcfg_razor_register

mail-db-up:
	docker-compose up -d mail-db

mail-db-down:
	docker-compose down mail-db

mail-db-cmd:
	docker-compose exec mail-db /bin/bash

mail-db-logs:
	docker container logs $(COMPOSE_PROJECT_NAME)_mail-db_1

mail-db-test:
	docker-compose exec mail-db mysqlshow -u $(MYSQL_USER) $(MYSQL_DATABASE) -p$(MYSQL_PASSWORD)

mail-app-up:
	docker-compose up -d mail-app

mail-app-down:
	docker-compose down mail-app

mail-app-cmd:
	docker-compose exec mail-app /bin/bash

mail-app-logs:
	docker container logs $(COMPOSE_PROJECT_NAME)_mail-app_1

mail-app-debugtools:
	docker-compose exec mail-app apt-get update 
	docker-compose exec mail-app apt-get install --yes \
	less nano ldap-utils htop net-tools lsof iputils-ping

mail-app-man_server:
	docker-compose exec mail-app man kopano-server.cfg

mail-app-man_ldap:
	docker-compose exec mail-app man kopano-ldap.cfg

mail-app-test: mail-mta-test

mail-app-show_user1: 
	docker-compose exec mail-app kopano-admin -l

mail-app-show_user2: mail-app-debugtools
	docker-compose exec mail-app ldapsearch -H ldap://auth:389 -xLLL -b $(LDAP_BASE) '*'
