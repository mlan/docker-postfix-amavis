-include    *.mk

BLD_ARG  ?= --build-arg DIST=alpine --build-arg REL=latest

IMG_REPO ?= mlan/postfix-amavis
IMG_VER  ?= latest
IMG_CMD  ?= /bin/sh

TST_PORT ?= 25
TST_DOM  ?= example.lan
TST_DOM2 ?= personal.lan
TST_DOM3 ?= global.lan
TST_FROM ?= sender@$(TST_DOM)
TST_TO   ?= receiver@$(TST_DOM)
TST_TO2  ?= receiver@$(TST_DOM2)
TST_HOST ?= mx.$(TST_DOM)
TST_NET  ?= mta-net
TST_CLT  ?= mta-client
TST_SRV  ?= mta-server
TST_ENV  ?= --network $(TST_NET) -e MYORIGIN=$(TST_DOM) -e SYSLOG_LEVEL=7
TST_MSG  ?= TeStMeSsAgE
TST_KEY  ?= local_priv_key.pem
TST_CRT  ?= local_ca_cert.pem
TST_PKEY ?= /etc/postfix/priv.pem
TST_PCRT ?= /etc/postfix/cert.pem
TST_USR1 ?= client1
TST_PWD1 ?= password1
TST_USR2 ?= client2
TST_PWD2 ?= password2

CNT_NAME ?= postfix-amavis-mta
CNT_PORT ?= -p 127.0.0.1:$(TST_PORT):25
CNT_ENV  ?= --hostname $(TST_HOST) -e MAIL_BOXES="$(TST_FROM) $(TST_TO)"
CNT_VOL  ?=
CNT_DRV  ?=
CNT_IP    = $(shell docker inspect -f \
	'{{range .NetworkSettings.Networks}}{{println .IPAddress}}{{end}}' \
	$(1) | head -n1)

TST_DK_S ?= default
TST_W8S  ?= 1
TST_W8M  ?= 20
TST_W8L  ?= 60

.PHONY: build build-all build-smtp build-sasl build-milter build-auth build-full \
    ps prune run run-fg start stop create purge rm-container rm-image cmd logs \
    bayes install_debugtools exec-sa-learn download-spam \
    test-all test-mail test-pem-rm test-down test-logs-clt test-logs-srv \
    test-cmd-clt test-cmd-srv test-diff-clt test-diff-srv

build: Dockerfile
	docker build $(BLD_ARG) --target full -t $(IMG_REPO)\:$(IMG_VER) .

build-all: build-smtp build-auth build-milter build-full

build-smtp: Dockerfile
	docker build $(BLD_ARG) --target smtp -t $(IMG_REPO)\:$(IMG_VER)-smtp .

build-auth: Dockerfile
	docker build $(BLD_ARG) --target auth -t $(IMG_REPO)\:$(IMG_VER)-auth .

build-milter: Dockerfile
	docker build $(BLD_ARG) --target milter -t $(IMG_REPO)\:$(IMG_VER)-milter .

build-full: Dockerfile
	docker build $(BLD_ARG) --target full -t $(IMG_REPO)\:$(IMG_VER)-full \
		-t $(IMG_REPO)\:$(IMG_VER) .

build-dkim: Dockerfile
	docker build $(BLD_ARG) --target dkim -t $(IMG_REPO)\:$(IMG_VER)-sasl .

variables:
	make -pn | grep -A1 "^# makefile"| grep -v "^#\|^--" | sort | uniq

ps:
	docker ps -a

prune:
	docker image prune
	docker container prune
	docker network prune

cmd:
	docker exec -it $(CNT_NAME) $(IMG_CMD)

run-fg:
	docker run --rm --name $(CNT_NAME) $(CNT_PORT) $(CNT_VOL) $(CNT_DRV) $(CNT_ENV) $(IMG_REPO)\:$(IMG_VER)

run:
	docker run --rm -d --name $(CNT_NAME) $(CNT_PORT) $(CNT_VOL) $(CNT_DRV) $(CNT_ENV) $(IMG_REPO)\:$(IMG_VER)

create:
	docker create --name $(CNT_NAME) $(CNT_PORT) $(CNT_VOL) $(CNT_DRV) $(CNT_ENV) $(IMG_REPO)\:$(IMG_VER)

logs:
	docker container logs $(CNT_NAME)

start:
	docker start $(CNT_NAME)

stop:
	docker stop $(CNT_NAME)

purge: rm-container rm-image

rm-container:
	docker rm $(CNT_NAME)

rm-image:
	docker image rm $(IMG_REPO):$(IMG_VER)

install_debugtools:
	docker exec -it $(CNT_NAME) apk --no-cache --update add \
	nano less lsof htop openldap-clients bind-tools iputils

bayes:
	docker exec -it $(CNT_NAME) sh -c 'rm -f bayesian.database.gz && wget http://artinvoice.hu/spams/bayesian.database.gz && gunzip bayesian.database.gz && sa-learn --restore bayesian.database && chown -R amavis:amavis /var/amavis && rm -rf bayesian.database'

sa-learn:
	docker exec -it $(CNT_NAME) sa-learn.sh a

edh:
	docker exec -it $(CNT_NAME) mtaconf postconf_edh

dkim_import:
	docker cp seed/dkim/$(TST_DK_S).private $(CNT_NAME):/var/db/dkim
	docker cp seed/dkim/$(TST_DK_S).txt $(CNT_NAME):/var/db/dkim
	docker exec -it $(CNT_NAME) chown -R opendkim: /var/db/dkim
	docker exec -it $(CNT_NAME) find /var/db/dkim -type f -exec chmod 600 {} \;

dkim_test:
	docker exec -it $(CNT_NAME) opendkim-testkey -vvv

test-all: test_4 test_5 test_6 test_7 test_8
	

test-waits_%:
	if [ $* -ge 7 ]; then sleep $(TST_W8M); else sleep $(TST_W8S); fi

test-waitm_%:
	if [ $* -ge 7 ]; then sleep $(TST_W8L); else sleep $(TST_W8M); fi

test-1:
	test/test-smtp.sh $(call CNT_IP,$(CNT_NAME)) $(TST_PORT) $(TST_FROM) $(TST_TO) \
	| grep '250 2.0.0 Ok:'

test-2:
	test/test-smtp.sh localhost $(TST_PORT) $(TST_FROM) $(TST_TO) \
	| grep '250 2.0.0 Ok:'

test-3:
	cat test/spam-email.txt | nc -C localhost 25

test_%: test-up_% test-waitm_% test-mail_% test-down_%
	

test-up_4:
	# test (4) basic smtp function
	docker network create $(TST_NET)
	docker run --rm -d --name $(TST_SRV) $(TST_ENV) --hostname srv.$(TST_DOM) \
		-e MAIL_BOXES="$(TST_FROM) $(TST_TO)" \
		$(IMG_REPO):$(IMG_VER)-smtp
	docker run --rm -d --name $(TST_CLT) $(TST_ENV) --hostname cli.$(TST_DOM) \
		-e RELAYHOST=[$(TST_SRV)] -e INET_INTERFACES=loopback-only \
		-e MYDESTINATION= \
		$(IMG_REPO):$(IMG_VER)-smtp

test-up_5: test-pem-gen
	# test (5) basic tls
	docker network create $(TST_NET)
	docker run --rm -d --name $(TST_SRV) $(TST_ENV) --hostname srv.$(TST_DOM) \
		-e MAIL_BOXES="$(TST_FROM) $(TST_TO)" \
		-e SMTPD_TLS_KEY_FILE=$(TST_PKEY) -e SMTPD_TLS_CERT_FILE=$(TST_PCRT) \
		$(IMG_REPO):$(IMG_VER)-smtp
	docker cp $(TST_KEY) $(TST_SRV):$(TST_PKEY)
	docker cp $(TST_CRT) $(TST_SRV):$(TST_PCRT)
	docker run --rm -d --name $(TST_CLT) $(TST_ENV) --hostname cli.$(TST_DOM) \
		-e RELAYHOST=[$(TST_SRV)] -e INET_INTERFACES=loopback-only \
		-e MYDESTINATION= -e SMTP_TLS_SECURITY_LEVEL=encrypt \
		$(IMG_REPO):$(IMG_VER)-smtp

test-up_6: test-pem-gen
	# test (6) basic sasl
	docker network create $(TST_NET)
	docker run --rm -d --name $(TST_SRV) $(TST_ENV) --hostname srv.$(TST_DOM) \
		-e MAIL_BOXES="$(TST_FROM) $(TST_TO)" \
		-e SMTPD_TLS_KEY_FILE=$(TST_PKEY) -e SMTPD_TLS_CERT_FILE=$(TST_PCRT) \
		-e SMTPD_SASL_CLIENTAUTH="$(TST_USR1):{plain}$(TST_PWD1) $(TST_USR2):{plain}$(TST_PWD2)" \
		$(IMG_REPO):$(IMG_VER)-auth
	docker cp $(TST_KEY) $(TST_SRV):$(TST_PKEY)
	docker cp $(TST_CRT) $(TST_SRV):$(TST_PCRT)
	docker run --rm -d --name $(TST_CLT) $(TST_ENV) --hostname cli.$(TST_DOM) \
		-e SMTP_RELAY_HOSTAUTH="[$(TST_SRV)]:587 $(TST_USR2):$(TST_PWD2)" \
		-e INET_INTERFACES=loopback-only \
		-e MYDESTINATION= -e SMTP_TLS_SECURITY_LEVEL=encrypt \
		$(IMG_REPO):$(IMG_VER)-smtp

test-up_7:
	# test (7) basic milter function
	docker network create $(TST_NET)
	docker run --rm -d --name $(TST_SRV) $(TST_ENV) --hostname srv.$(TST_DOM) \
		-e MAIL_BOXES="$(TST_FROM) $(TST_TO)" \
		$(IMG_REPO):$(IMG_VER)-milter
	docker run --rm -d --name $(TST_CLT) $(TST_ENV) --hostname cli.$(TST_DOM) \
		-e RELAYHOST=[$(TST_SRV)] -e INET_INTERFACES=loopback-only \
		-e MYDESTINATION= \
		$(IMG_REPO):$(IMG_VER)-milter

test-up_8:
	# test (8) dkim and multiple domains
	docker network create $(TST_NET)
	docker run --rm -d --name $(TST_SRV) $(TST_ENV) --hostname srv.$(TST_DOM) \
		-e MAIL_BOXES="$(TST_TO) $(TST_TO2)" -e MAIL_DOMAIN="$(TST_DOM) $(TST_DOM2)" \
		$(IMG_REPO):$(IMG_VER)-milter
	docker run --rm -d --name $(TST_CLT) $(TST_ENV) --hostname cli.$(TST_DOM) \
		-e RELAYHOST=[$(TST_SRV)] -e INET_INTERFACES=loopback-only \
		-e MYDESTINATION= -e MAIL_DOMAIN="$(TST_DOM)" \
		$(IMG_REPO):$(IMG_VER)-milter

test-mail: test-mail_0

test-mail_%: test-mail-send_% test-waits_% test-mail-grep_%
	

test-dovecot_auth:
	docker exec -it $(TST_SRV) doveadm auth lookup $(TST_USR2)

test-mail-send_%:
	$(eval tst_dom := $(shell if [ $* -ge 8 ]; then echo $(TST_DOM2); else echo $(TST_DOM); fi ))
	printf "subject:Test\nfrom:$(TST_FROM)\n$(TST_MSG)$*\n" \
	| docker exec -i $(TST_CLT) sendmail receiver@$(tst_dom)

test-mail-grep_%:
	$(eval tst_str := $(shell if [ $* -ge 8 ]; then echo DKIM-Signature; else echo ^$(TST_MSG)$*; fi ))
	$(eval tst_dom := $(shell if [ $* -ge 8 ]; then echo $(TST_DOM2); else echo $(TST_DOM); fi ))
	docker exec -it $(TST_SRV) cat /var/mail/$(tst_dom)/receiver | grep $(tst_str)

test-pem-gen: $(TST_CRT)

$(TST_CRT): $(TST_KEY)
	openssl req -x509 -utf8 -new -batch \
		-subj "/CN=$(TST_SRV)" -key $(TST_KEY) -out $(TST_CRT)

$(TST_KEY):
	openssl genrsa -out $(TST_KEY)

test-pem-rm:
	rm $(TST_KEY) $(TST_CRT)

test-down: test-down_0

test-down_%:
	docker stop $(TST_CLT) $(TST_SRV) || true
	docker network rm $(TST_NET)

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

