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

.PHONY: build build-all build-smtp build-milter build-auth build-full \
	run run-fg start stop create purge rm-container rm-image cmd diff logs \
	bayes install_debugtools exec-sa-learn download-spam \
	push testwait testall testall test1

build: Dockerfile
	docker build $(BLD_ARG) --target full -t $(IMG_REPO)\:$(IMG_VER) .

build-all: build-smtp build-milter build-auth build-full

build-smtp: Dockerfile
	docker build $(BLD_ARG) --target smtp -t $(IMG_REPO)\:$(IMG_VER)-smtp .

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

testall: test4 test5

test_wait_s:
	sleep $(TST_W8S)

test_wait_m:
	sleep $(TST_W8M)

test_wait_l:
	sleep $(TST_W8L)

test1:
	test/test-smtp.sh $(call CNT_IP,$(CNT_NAME)) $(TST_PORT) $(TST_FROM) $(TST_TO) \
	| grep '250 2.0.0 Ok:'

test2:
	test/test-smtp.sh localhost $(TST_PORT) $(TST_FROM) $(TST_TO) \
	| grep '250 2.0.0 Ok:'

test3:
	cat test/spam-email.txt | nc -C localhost 25

test4: test4_up test_wait_m test_mail_s test_down

test5: test5_up test_wait_l test_mail_m test_down

test4_up:
	docker network create $(TST_NET)
	docker run --rm -d --name $(TST_SRV) $(TST_ENV) --hostname srv.$(TST_DOM) \
		-e MAIL_BOXES="$(TST_FROM) $(TST_TO)" \
		$(IMG_REPO):$(IMG_VER)-smtp
	docker run --rm -d --name $(TST_CLT) $(TST_ENV) --hostname cli.$(TST_DOM) \
		-e RELAYHOST=[$(TST_SRV)] -e INET_INTERFACES=loopback-only \
		-e MYDESTINATION= \
		$(IMG_REPO):$(IMG_VER)-smtp

test5_up:
	docker network create $(TST_NET)
	docker run --rm -d --name $(TST_SRV) $(TST_ENV) --hostname srv.$(TST_DOM) \
		-e MAIL_BOXES="$(TST_FROM) $(TST_TO)" \
		$(IMG_REPO):$(IMG_VER)-milter
	docker run --rm -d --name $(TST_CLT) $(TST_ENV) --hostname cli.$(TST_DOM) \
		-e RELAYHOST=[$(TST_SRV)] -e INET_INTERFACES=loopback-only \
		-e MYDESTINATION= \
		$(IMG_REPO):$(IMG_VER)-milter

test_mail_s: test_sendmail test_wait_s test_grepmail

test_mail_m: test_sendmail test_wait_m test_grepmail

test_sendmail:
	printf "subject:Test\nfrom:$(TST_FROM)\n$(TST_MSG)\n" \
	| docker exec -i $(TST_CLT) sendmail $(TST_TO)

test_grepmail:
	docker exec -it $(TST_SRV) cat /var/mail/$(TST_DOM)/receiver \
	| grep ^$(TST_MSG)

test_down:
	docker stop $(TST_CLT) $(TST_SRV)
	docker network rm $(TST_NET)

test_cli_logs:
	docker container logs $(TST_CLT)

test_srv_logs:
	docker container logs $(TST_SRV)

test_cli_cmd:
	docker exec -it $(TST_CLI) /bin/sh

test_srv_cmd:
	docker exec -it $(TST_SRV) /bin/sh

