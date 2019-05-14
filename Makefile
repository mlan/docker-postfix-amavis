-include    *.mk

BLD_ARG  ?= --build-arg DIST=alpine --build-arg REL=latest

IMG_REPO ?= mlan/postfix-amavis
IMG_VER  ?= latest
IMG_CMD  ?= /bin/sh

TST_PORT ?= 25
TST_DOM  ?= example.lan
TST_DOM2 ?= personal.lan
TST_DOM3 ?= global.lan
TST_SADR ?= sender
TST_RADR ?= receiver
TST_BOX  ?= $(TST_RADR)@$(TST_DOM) $(TST_SADR)@$(TST_DOM)
TST_BOX2 ?= $(TST_RADR)@$(TST_DOM) $(TST_RADR)@$(TST_DOM2)
TST_HOST ?= mx.$(TST_DOM)
TST_NET  ?= test-net
TST_CLT  ?= test-client
TST_SRV  ?= test-server
TST_AUTH ?= test-auth
TST_VCLT ?= $(TST_CLT)-var:/var
TST_VSRV ?= $(TST_SRV)-var:/var
TST_SLOG ?= 4
TST_ALOG ?= 5
TST_TZ   ?= UTC
TST_ENV  ?= -e MYORIGIN=$(TST_DOM) -e SYSLOG_LEVEL=$(TST_SLOG) -e TZ=$(TST_TZ) \
		-e SA_TAG_LEVEL_DEFLT=-999 -e SA_DEBUG=1 -e LOG_LEVEL=$(TST_ALOG)
TST_MSG  ?= ---test-message---
TST_KEY  ?= local_priv_key.pem
TST_CRT  ?= local_ca_cert.pem
TST_PKEY ?= /etc/postfix/priv.pem
TST_PCRT ?= /etc/postfix/cert.pem
TST_USR1 ?= client1
TST_PWD1 ?= password1
TST_USR2 ?= client2
TST_PWD2 ?= password2
TST_DK_S ?= default
LDAP_BAS ?= dc=example,dc=com
LDAP_UOU ?= users
LDAP_UOB ?= posixAccount
LDAP_GOU ?= groups
LDAP_MTH ?= "(&(objectclass=$(LDAP_UOB))(mail=%s))"

CNT_NAME ?= postfix-amavis-mta
CNT_PORT ?= -p 127.0.0.1:$(TST_PORT):25
CNT_ENV  ?= --hostname $(TST_HOST) -e MAIL_BOXES="$(TST_BOX)"
CNT_VOL  ?= -
CNT_DRV  ?=
CNT_IP    = $(shell docker inspect -f \
	'{{range .NetworkSettings.Networks}}{{println .IPAddress}}{{end}}' \
	$(1) | head -n1)

TST_W8S1 ?= 1
TST_W8S2 ?= 30
TST_W8L1 ?= 20
TST_W8L2 ?= 120

.PHONY: build build-all build-mta build-mda build-milter build-full ps \
    prune test-debugtools-srv test-learn-bayes test-learn-spam test-regen-edh-srv \
    test-all test-mail test-cert-rm test-down test-logs-clt test-logs-srv \
    test-cmd-clt test-cmd-srv test-diff-clt test-diff-srv

build: Dockerfile
	docker build $(BLD_ARG) --target full -t $(IMG_REPO):$(IMG_VER) .

build-all: build-mta build-mda build-milter build-full

build-mta: Dockerfile
	docker build $(BLD_ARG) --target mta -t $(IMG_REPO):$(IMG_VER)-mta .

build-mda: Dockerfile
	docker build $(BLD_ARG) --target mda -t $(IMG_REPO):$(IMG_VER)-mda .

build-milter: Dockerfile
	docker build $(BLD_ARG) --target milter -t $(IMG_REPO):$(IMG_VER)-milter .

build-full: Dockerfile
	docker build $(BLD_ARG) --target full -t $(IMG_REPO):$(IMG_VER)-full \
		-t $(IMG_REPO)\:$(IMG_VER) .

build-dkim: Dockerfile
	docker build $(BLD_ARG) --target dkim -t $(IMG_REPO):$(IMG_VER)-sasl .

variables:
	make -pn | grep -A1 "^# makefile"| grep -v "^#\|^--" | sort | uniq

ps:
	docker ps -a

prune:
	docker image prune
	docker container prune
	docker volume prune
	docker network prune

test-all: test_1 test_2 test_3 test_4 test_5 test_6 test_7 test_8
	

test_%: test-up_% test-waitl_% test-logs_% test-mail_% test-down_%
	

test-up_1: test-up-net
	#
	# test (1) basic mta function and virtual lookup
	#
	docker run --rm -d --name $(TST_SRV) --hostname srv.$(TST_DOM) \
		--network $(TST_NET) $(TST_ENV) \
		-e MAIL_BOXES="$(TST_BOX)" \
		$(IMG_REPO):$(IMG_VER)-mta
	docker run --rm -d --name $(TST_CLT) --hostname clt.$(TST_DOM) \
		--network $(TST_NET) $(TST_ENV) \
		-e RELAYHOST=[$(TST_SRV)] -e INET_INTERFACES=loopback-only \
		-e MYDESTINATION= \
		$(IMG_REPO):$(IMG_VER)-mta

test-up_2: test-up-net test-up-auth
	#
	# test (2) basic mta function and ldap lookup
	#
	docker run --rm -d --name $(TST_SRV) --hostname srv.$(TST_DOM) \
		--network $(TST_NET) $(TST_ENV) \
		-e LDAP_HOST=$(TST_AUTH) -e LDAP_USER_BASE=ou=$(LDAP_UOU),$(LDAP_BAS) \
		-e LDAP_QUERY_FILTER_USER=$(LDAP_MTH) \
		$(IMG_REPO):$(IMG_VER)-mta
	docker run --rm -d --name $(TST_CLT) --hostname clt.$(TST_DOM) \
		--network $(TST_NET) $(TST_ENV) \
		-e RELAYHOST=[$(TST_SRV)] -e INET_INTERFACES=loopback-only \
		-e MYDESTINATION= \
		$(IMG_REPO):$(IMG_VER)-mta

test-up_3: test-up-net test-cert-gen
	#
	# test (3) basic tls
	#
	docker run --rm -d --name $(TST_SRV) --hostname srv.$(TST_DOM) \
		--network $(TST_NET) $(TST_ENV) \
		-e MAIL_BOXES="$(TST_BOX)" \
		-e SMTPD_TLS_KEY_FILE=$(TST_PKEY) -e SMTPD_TLS_CERT_FILE=$(TST_PCRT) \
		$(IMG_REPO):$(IMG_VER)-mta
	docker cp $(TST_KEY) $(TST_SRV):$(TST_PKEY)
	docker cp $(TST_CRT) $(TST_SRV):$(TST_PCRT)
	docker run --rm -d --name $(TST_CLT) --hostname clt.$(TST_DOM) \
		--network $(TST_NET) $(TST_ENV) \
		-e RELAYHOST=[$(TST_SRV)] -e INET_INTERFACES=loopback-only \
		-e MYDESTINATION= -e SMTP_TLS_SECURITY_LEVEL=encrypt \
		$(IMG_REPO):$(IMG_VER)-mta

test-up_4: test-up-net test-cert-gen
	#
	# test (4) basic sasl
	#
	docker run --rm -d --name $(TST_SRV) --hostname srv.$(TST_DOM) \
		--network $(TST_NET) $(TST_ENV) \
		-e MAIL_BOXES="$(TST_BOX)" \
		-e SMTPD_TLS_KEY_FILE=$(TST_PKEY) -e SMTPD_TLS_CERT_FILE=$(TST_PCRT) \
		-e SMTPD_SASL_CLIENTAUTH="$(TST_USR1):{plain}$(TST_PWD1) $(TST_USR2):{plain}$(TST_PWD2)" \
		$(IMG_REPO):$(IMG_VER)-mda
	docker cp $(TST_KEY) $(TST_SRV):$(TST_PKEY)
	docker cp $(TST_CRT) $(TST_SRV):$(TST_PCRT)
	docker run --rm -d --name $(TST_CLT) --hostname clt.$(TST_DOM) \
		--network $(TST_NET) $(TST_ENV) \
		-e SMTP_RELAY_HOSTAUTH="[$(TST_SRV)]:587 $(TST_USR2):$(TST_PWD2)" \
		-e INET_INTERFACES=loopback-only \
		-e MYDESTINATION= -e SMTP_TLS_SECURITY_LEVEL=encrypt \
		$(IMG_REPO):$(IMG_VER)-mta

test-up_5: test-up-net
	#
	# test (5) basic milter function
	#
	docker run --rm -d --name $(TST_SRV) --hostname srv.$(TST_DOM) \
		--network $(TST_NET) $(TST_ENV) \
		-e MAIL_BOXES="$(TST_BOX)" \
		$(IMG_REPO):$(IMG_VER)-milter
	docker run --rm -d --name $(TST_CLT) --hostname clt.$(TST_DOM) \
		--network $(TST_NET) $(TST_ENV) \
		-e RELAYHOST=[$(TST_SRV)] -e INET_INTERFACES=loopback-only \
		-e MYDESTINATION= -e LOG_LEVEL=$(TST_ALOG) \
		$(IMG_REPO):$(IMG_VER)-milter

test-up_6: test-up-net
	#
	# test (6) dkim and multiple domains
	#
	docker run --rm -d --name $(TST_SRV) --hostname srv.$(TST_DOM) \
		--network $(TST_NET) $(TST_ENV) \
		-e MAIL_BOXES="$(TST_BOX2)" -e MAIL_DOMAIN="$(TST_DOM) $(TST_DOM2)" \
		-v $(TST_SRV)-srv:/srv \
		$(IMG_REPO):$(IMG_VER)-full
	docker run --rm -d --name $(TST_CLT) --hostname clt.$(TST_DOM) \
		--network $(TST_NET) $(TST_ENV) \
		-e RELAYHOST=[$(TST_SRV)] -e INET_INTERFACES=loopback-only \
		-e MYDESTINATION= -e MAIL_DOMAIN="$(TST_DOM)" \
		-v $(TST_CLT)-srv:/srv \
		$(IMG_REPO):$(IMG_VER)-full

test-up_7: test-up-net test_6
	#
	# test (7) persistent /srv no env given
	#
	docker run --rm -d --name $(TST_SRV) --hostname srv.$(TST_DOM) \
		--network $(TST_NET) \
		-v $(TST_SRV)-srv:/srv \
		$(IMG_REPO):$(IMG_VER)-full
	docker run --rm -d --name $(TST_CLT) --hostname clt.$(TST_DOM) \
		--network $(TST_NET) \
		-v $(TST_SRV)-srv:/srv \
		$(IMG_REPO):$(IMG_VER)-full

test-up_8: test-up-net test_7
	#
	# test (8) persistent /srv
	#
	docker run --rm -d --name $(TST_SRV) --hostname srv.$(TST_DOM) \
		--network $(TST_NET) $(TST_ENV) \
		-e MAIL_BOXES="$(TST_BOX2)" -e MAIL_DOMAIN="$(TST_DOM) $(TST_DOM2)" \
		-v $(TST_SRV)-srv:/srv \
		$(IMG_REPO):$(IMG_VER)-full
	docker run --rm -d --name $(TST_CLT) --hostname clt.$(TST_DOM) \
		--network $(TST_NET) $(TST_ENV) \
		-e RELAYHOST=[$(TST_SRV)] -e INET_INTERFACES=loopback-only \
		-e MYDESTINATION= -e MAIL_DOMAIN="$(TST_DOM)" \
		-v $(TST_CLT)-srv:/srv \
		$(IMG_REPO):$(IMG_VER)-full

test-mail: test-mail_0

test-mail_%: test-mail-send_% test-waits_% test-mail-read_%
	#
	# test ($*) successful
	#

test-logs_%:
	docker container logs $(TST_SRV) | grep '(entrypoint.sh)' || true

test-waits_%:
	if [ $* -ge 5 ]; then sleep $(TST_W8S2); else sleep $(TST_W8S1); fi

test-waitl_%:
	if [ $* -ge 5 ]; then sleep $(TST_W8L2); else sleep $(TST_W8L1); fi

test-up-net:
	docker network create $(TST_NET) 2>/dev/null || true

test-down-net:
	docker network rm $(TST_NET) || true

test-down: test-down_0
	docker network rm $(TST_NET) 2>/dev/null || true
	docker volume rm $(TST_SRV)-srv $(TST_CLT)-srv 2>/dev/null || true

test-down_%:
	docker stop $(TST_CLT) $(TST_SRV) $(TST_AUTH) 2>/dev/null || true
	if [ $* -ge 0 ]; then sleep $(TST_W8S1); fi

test-up-auth:
	docker run --rm -d --name $(TST_AUTH) --network $(TST_NET) mlan/openldap
	sleep $(TST_W8L1)
	printf "dn: ou=$(LDAP_UOU),$(LDAP_BAS)\nchangetype: add\nobjectClass: organizationalUnit\nobjectClass: top\nou: $(LDAP_UOU)\n\ndn: ou=$(LDAP_GOU),$(LDAP_BAS)\nchangetype: add\nobjectClass: organizationalUnit\nobjectClass: top\nou: $(LDAP_GOU)\n\ndn: uid=$(TST_RADR),ou=$(LDAP_UOU),$(LDAP_BAS)\nchangetype: add\nobjectClass: top\nobjectClass: inetOrgPerson\nobjectClass: $(LDAP_UOB)\ncn: $(TST_RADR)\nsn: $(TST_RADR)\nuid: $(TST_RADR)\nmail: $(TST_RADR)@$(TST_DOM)\nuidNumber: 1234\ngidNumber: 1234\nhomeDirectory: /home/$(TST_RADR)\nuserPassword: $(TST_PWD1)\n" \
	| docker exec -i $(TST_AUTH) ldap modify

test-auth-srv:
	docker exec -it $(TST_SRV) doveadm auth lookup $(TST_USR2)

test-mail-send_%:
	$(eval tst_dom := $(shell if [ $* -ge 6 ]; then echo $(TST_DOM2); else echo $(TST_DOM); fi ))
	printf "subject:Test\nfrom:$(TST_SADR)@$(TST_DOM)\n$(TST_MSG)$*\n" \
	| docker exec -i $(TST_CLT) sendmail $(TST_RADR)@$(tst_dom)

test-mail-read_%:
	$(eval tst_str := $(shell if [ $* -ge 9 ]; then echo DKIM-Signature; else echo ^$(TST_MSG)$*; fi ))
	$(eval tst_dom := $(shell if [ $* -ge 6 ]; then echo $(TST_DOM2); else echo $(TST_DOM); fi ))
	docker exec -it $(TST_SRV) cat /var/mail/$(TST_RADR)@$(tst_dom) | grep $(tst_str)

$(TST_CRT): $(TST_KEY)
	openssl req -x509 -utf8 -new -batch \
		-subj "/CN=$(TST_SRV)" -key $(TST_KEY) -out $(TST_CRT)

$(TST_KEY):
	openssl genrsa -out $(TST_KEY)

test-cert-rm:
	rm $(TST_KEY) $(TST_CRT)

test-logs-clt:
	docker container logs $(TST_CLT)

test-logs-srv:
	docker container logs $(TST_SRV)

test-cmd-clt:
	docker exec -it $(TST_CLT) /bin/sh

test-cmd-srv:
	docker exec -it $(TST_SRV) /bin/sh

test-diff-clt:
	docker container diff $(TST_CLT)

test-diff-srv:
	docker container diff $(TST_SRV)

test-regen-edh-srv:
	docker exec -it $(TST_SRV) conf update_postfix_dhparam

test-dkim-key:
	docker exec -it $(TST_SRV) amavisd testkeys

test-cert-gen: $(TST_CRT)

test-debugtools-srv:
	docker exec -it $(TST_SRV) apk --no-cache --update add \
	nano less lsof htop openldap-clients bind-tools iputils

test-learn-bayes:
	docker exec -it $(TST_SRV) sh -c 'rm -f bayesian.database.gz && wget http://artinvoice.hu/spams/bayesian.database.gz && gunzip bayesian.database.gz && sa-learn --restore bayesian.database && chown -R amavis:amavis /var/amavis && rm -rf bayesian.database'

test-learn-spam:
	docker exec -it $(TST_SRV) sa-learn.sh a

test-timezone-srv:
	docker cp /usr/share/zoneinfo/$(TST_TZ) $(TST_SRV):/etc/localtime
	docker exec -it $(TST_SRV) sh -c 'echo $(TST_TZ) > /etc/timezone'
