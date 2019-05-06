-include    *.mk

BLD_ARG  ?= --build-arg DIST=alpine --build-arg REL=latest

IMG_REPO ?= mlan/postfix-amavis
IMG_VER  ?= latest
IMG_CMD  ?= /bin/sh

TST_PORT ?= 25
TST_DOM  ?= example.lan
TST_FROM ?= sender@$(TST_DOM)
TST_TO   ?= receiver@$(TST_DOM)
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

.PHONY: .FORCE build build-all build-smtp build-sasl build-milter build-auth build-full \
	run run-fg start stop create purge rm-container rm-image cmd diff logs \
	bayes install_debugtools exec-sa-learn download-spam \
	testall test1 test2 test3 test4 test5 test6 test7 test8 \
	test_wait_s test_wait_m test_wait_l test_mail_s test_mail_m \
	test_sendmail test_grepmail test_rmpem \
	test_down test_clt_logs test_srv_logs test_clt_cmd test_srv_cmd

build: Dockerfile
	docker build $(BLD_ARG) --target full -t $(IMG_REPO)\:$(IMG_VER) .

build-all: build-smtp build-sasl build-milter build-auth build-full

build-smtp: Dockerfile
	docker build $(BLD_ARG) --target smtp -t $(IMG_REPO)\:$(IMG_VER)-smtp .

build-sasl: Dockerfile
	docker build $(BLD_ARG) --target sasl -t $(IMG_REPO)\:$(IMG_VER)-sasl .

build-milter: Dockerfile
	docker build $(BLD_ARG) --target milter -t $(IMG_REPO)\:$(IMG_VER)-milter .

build-auth: Dockerfile
	docker build $(BLD_ARG) --target auth -t $(IMG_REPO)\:$(IMG_VER)-auth .

build-full: Dockerfile
	docker build $(BLD_ARG) --target full -t $(IMG_REPO)\:$(IMG_VER)-full \
		-t $(IMG_REPO)\:$(IMG_VER) .

variables:
	make -pn | grep -A1 "^# makefile"| grep -v "^#\|^--" | sort | uniq

push:
	docker push $(IMG_REPO)\:$(IMG_VER)

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

diff:
	docker container diff $(CNT_NAME)

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

testall: test4 test5 test6 test7

test_wait_s%:
	if [ $* -gt 6 ]; then sleep $(TST_W8M); else sleep $(TST_W8S); fi

test_wait_m%:
	if [ $* -gt 6 ]; then sleep $(TST_W8L); else sleep $(TST_W8M); fi

test_wait_l%:
	sleep $(TST_W8L)

test1:
	test/test-smtp.sh $(call CNT_IP,$(CNT_NAME)) $(TST_PORT) $(TST_FROM) $(TST_TO) \
	| grep '250 2.0.0 Ok:'

test2:
	test/test-smtp.sh localhost $(TST_PORT) $(TST_FROM) $(TST_TO) \
	| grep '250 2.0.0 Ok:'

test3:
	cat test/spam-email.txt | nc -C localhost 25

test_%: test_up% test_wait_m% test_mail_s% test_down%
	date

test_up4:
	# test4: basic smtp function
	docker network create $(TST_NET)
	docker run --rm -d --name $(TST_SRV) $(TST_ENV) --hostname srv.$(TST_DOM) \
		-e MAIL_BOXES="$(TST_FROM) $(TST_TO)" \
		$(IMG_REPO):$(IMG_VER)-smtp
	docker run --rm -d --name $(TST_CLT) $(TST_ENV) --hostname cli.$(TST_DOM) \
		-e RELAYHOST=[$(TST_SRV)] -e INET_INTERFACES=loopback-only \
		-e MYDESTINATION= \
		$(IMG_REPO):$(IMG_VER)-smtp

test_up5: test_genpem
	# test5: basic tls
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

test_up6: test_genpem
	# test6: basic sasl
	docker network create $(TST_NET)
	docker run --rm -d --name $(TST_SRV) $(TST_ENV) --hostname srv.$(TST_DOM) \
		-e MAIL_BOXES="$(TST_FROM) $(TST_TO)" \
		-e SMTPD_TLS_KEY_FILE=$(TST_PKEY) -e SMTPD_TLS_CERT_FILE=$(TST_PCRT) \
		-e SMTPD_SASL_CLIENTAUTH="$(TST_USR1):{plain}$(TST_PWD1) $(TST_USR2):{plain}$(TST_PWD2)" \
		$(IMG_REPO):$(IMG_VER)-sasl
	docker cp $(TST_KEY) $(TST_SRV):$(TST_PKEY)
	docker cp $(TST_CRT) $(TST_SRV):$(TST_PCRT)
	docker run --rm -d --name $(TST_CLT) $(TST_ENV) --hostname cli.$(TST_DOM) \
		-e SMTP_RELAY_HOSTAUTH="[$(TST_SRV)]:587 $(TST_USR2):$(TST_PWD2)" \
		-e INET_INTERFACES=loopback-only \
		-e MYDESTINATION= -e SMTP_TLS_SECURITY_LEVEL=encrypt \
		$(IMG_REPO):$(IMG_VER)-smtp

test_up7:
	# test7: basic milter function
	docker network create $(TST_NET)
	docker run --rm -d --name $(TST_SRV) $(TST_ENV) --hostname srv.$(TST_DOM) \
		-e MAIL_BOXES="$(TST_FROM) $(TST_TO)" \
		$(IMG_REPO):$(IMG_VER)-milter
	docker run --rm -d --name $(TST_CLT) $(TST_ENV) --hostname cli.$(TST_DOM) \
		-e RELAYHOST=[$(TST_SRV)] -e INET_INTERFACES=loopback-only \
		-e MYDESTINATION= \
		$(IMG_REPO):$(IMG_VER)-milter

test_up8:
	# test8: dkim
	docker network create $(TST_NET)
	docker run --rm -d --name $(TST_SRV) $(TST_ENV) --hostname srv.$(TST_DOM) \
		-e MAIL_BOXES="$(TST_FROM) $(TST_TO)" \
		$(IMG_REPO):$(IMG_VER)-milter
	docker run --rm -d --name $(TST_CLT) $(TST_ENV) --hostname cli.$(TST_DOM) \
		-e RELAYHOST=[$(TST_SRV)] -e INET_INTERFACES=loopback-only \
		-e MYDESTINATION= \
		$(IMG_REPO):$(IMG_VER)-milter

test_mail_s: test_mail_s0

test_mail_s%: test_sendmail% test_wait_s% test_grepmail%
	date

test_mail_m%: test_sendmail% test_wait_m% test_grepmail%
	date

test_dovecot_auth:
	docker exec -it $(TST_SRV) doveadm auth lookup $(TST_USR2)

test_sendmail%:
	printf "subject:Test\nfrom:$(TST_FROM)\n$(TST_MSG)\n" \
	| docker exec -i $(TST_CLT) sendmail $(TST_TO)

test_grepmail%:
ifeq ($*,8)
	$(eval tst_str := DKIM-Signature:)
else
	$(eval tst_str := ^$(TST_MSG))
endif
	docker exec -it $(TST_SRV) cat /var/mail/$(TST_DOM)/receiver | grep $(tst_str)

test_genpem: $(TST_CRT)

$(TST_CRT): $(TST_KEY)
	openssl req -x509 -utf8 -new -batch \
		-subj "/CN=$(TST_SRV)" -key $(TST_KEY) -out $(TST_CRT)

$(TST_KEY):
	openssl genrsa -out $(TST_KEY)

test_rmpem:
	rm $(TST_KEY) $(TST_CRT)

test_down: test_down0

test_down%:
	docker stop $(TST_CLT) $(TST_SRV) || true
	docker network rm $(TST_NET)

test_clt_logs:
	docker container logs $(TST_CLT)

test_srv_logs:
	docker container logs $(TST_SRV)

test_clt_cmd:
	docker exec -it $(TST_CLT) /bin/sh

test_srv_cmd:
	docker exec -it $(TST_SRV) /bin/sh

