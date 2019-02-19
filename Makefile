-include    *.mk

BLD_ARG  ?= --build-arg DIST=alpine --build-arg REL=3.8

IMG_REPO ?= mlan/postfix-amavis
IMG_VER  ?= latest
IMG_CMD  ?= /bin/bash

TST_PORT ?= 25
CNT_NAME ?= postfix-amavis-default
CNT_PORT ?= -p $(TST_PORT):25
CNT_ENV  ?= --hostname mx1.example.com -e MAIL_BOXES="info@example.com abuse@example.com"
CNT_VOL  ?=
CNT_DRV  ?=
CNT_IP    = $(shell docker inspect -f \
	'{{range .NetworkSettings.Networks}}{{println .IPAddress}}{{end}}' \
	$(1) | head -n1)

TST_DK_S ?= default
TST_FROM ?= info@example.com
TST_TO   ?= abuse@example.com
TST_WAIT ?= 9

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
	docker create  --name $(CNT_NAME) $(CNT_PORT) $(CNT_VOL) $(CNT_DRV) $(CNT_ENV) $(IMG_REPO)\:$(IMG_VER)

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

testall: test1

testwait:
	sleep $(TST_WAIT)

test1:
	test/test-smtp.sh $(call CNT_IP,$(CNT_NAME)) $(TST_PORT) $(TST_FROM) $(TST_TO) \
	| grep '250 2.0.0 Ok:'

test2:
	test/test-smtp.sh localhost $(TST_PORT) $(TST_FROM) $(TST_TO) \
	| grep '250 2.0.0 Ok:'

test3:
	cat test/spam-email.txt | nc -C localhost 25
