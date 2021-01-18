-include    *.mk .env .init.env

SRV_LIST ?= auth app db mta

AD_DOM   ?= $(call ad_sub_dot, $(AD_BASE))
AD_DC    ?= $(call ad_cut_dot, 1, 1, $(AD_DOM))

SSL_O     = $(MAIL_DOMAIN)
SSL_MAIL  = auto
SSL_PASS  = $(AD_USR_PW)
#SSL_TRST  = $(SSL_SMIME)

CURL_DBG ?= -v -s

variables:
	make -pn | grep -A1 "^# makefile"| grep -v "^#\|^--" | sort | uniq

test: all-test_quiet mta-test_smtp

init: up auth-init db-init app-down app-up mta-init app-init

ps:
	docker-compose ps

up:
	docker-compose up -d

down:
	docker-compose down

destroy: auth-gui-down all-destroy_smime
	docker-compose down -v

config:
	docker-compose config

logs:
	docker-compose logs --tail 10

images:
	docker-compose images

$(addsuffix -up,$(SRV_LIST)):
	docker-compose up -d $(patsubst %-up,%,$@)

$(addsuffix -down,$(SRV_LIST)):
	docker-compose rm -sf $(patsubst %-down,%,$@)

$(addsuffix -restart,$(SRV_LIST)):
	docker-compose restart $(patsubst %-restart,%,$@)

$(addsuffix -renew,$(SRV_LIST)):
	docker-compose rm -s $(patsubst %-renew,%,$@)
	docker-compose up -d $(patsubst %-renew,%,$@)

$(addsuffix -top,$(SRV_LIST)):
	docker-compose top $(patsubst %-top,%,$@)

$(addsuffix -logs,$(SRV_LIST)):
	docker-compose logs $(patsubst %-logs,%,$@)

$(addsuffix -pull,$(SRV_LIST)):
	docker-compose pull $(patsubst %-pull,%,$@)

$(addsuffix -sh,$(SRV_LIST)):
	docker-compose exec $(patsubst %-sh,%,$@) sh -c 'exec $$(getent passwd root | sed "s/.*://g")'

$(addsuffix -env,$(SRV_LIST)):
	docker-compose exec $(patsubst %-env,%,$@) env

$(addsuffix -sv,$(SRV_LIST)):
	docker-compose exec $(patsubst %-sv,%,$@) sh -c 'sv status $$SVDIR/*'

$(addsuffix -diff,$(SRV_LIST)):
	docker container diff $(COMPOSE_PROJECT_NAME)_$(patsubst %-diff,%,$@)_1

$(addsuffix -hostaddr,$(SRV_LIST)):
	$(eval myhost := $(call dkr_srv_ip,$(patsubst %-hostaddr,%,$@)))

wait_%:
	sleep $*

web:
	browse http://localhost:8008 &

auth-init: wait_3 auth-mod_conf auth-add_schema auth-add_data

export define LDIF_MOD_CONF
dn: olcDatabase={-1}frontend,cn=config
changetype: modify
add: olcPasswordHash
olcPasswordHash: {CRYPT}

dn: cn=config
changetype: modify
add: olcPasswordCryptSaltFormat
olcPasswordCryptSaltFormat: $$6$$%.16s

dn: olcDatabase={1}mdb,cn=config
changetype: modify
add: olcDbIndex
olcDbIndex: cn,ou,uid,mail eq
endef

export define LDIF_ADD_DATA
dn: $(AD_BASE)
objectClass: organization
objectClass: dcObject
dc: $(AD_DC)
o: $(AD_DOM)

dn: ou=$(AD_USR_OU),$(AD_BASE)
ou: $(AD_USR_OU)
objectClass: organizationalUnit

dn: ou=$(AD_GRP_OU),$(AD_BASE)
ou: $(AD_GRP_OU)
objectClass: organizationalUnit

dn: cn=$(AD_GRP_CN),ou=$(AD_GRP_OU),$(AD_BASE)
cn: $(AD_GRP_CN)
objectClass: groupOfNames
objectClass: kopano-group
member: uid=$(AD_ADM_CN),ou=$(AD_USR_OU),$(AD_BASE)
member: uid=$(AD_USR_CN),ou=$(AD_USR_OU),$(AD_BASE)
mail: $(AD_GRP_CN)@$(MAIL_DOMAIN)

dn: uid=$(AD_ADM_CN),ou=$(AD_USR_OU),$(AD_BASE)
changetype: add
cn: $(AD_ADM_CN)
objectClass: inetOrgPerson
objectClass: kopano-user
sn: $(AD_ADM_CN)
uid: $(AD_ADM_CN)
mail: $(AD_ADM_CN)@$(MAIL_DOMAIN)
userPassword: $(AD_ADM_PW)
telephoneNumber: $(AD_ADM_TEL)
title: $(AD_ADM_TIT)
kopanoAccount: 1
kopanoAdmin: 1
kopanoEnabledFeatures: imap
kopanoEnabledFeatures: pop3

dn: uid=$(AD_USR_CN),ou=$(AD_USR_OU),$(AD_BASE)
changetype: add
cn: $(AD_USR_CN)
objectClass: inetOrgPerson
objectClass: kopano-user
sn: $(AD_USR_CN)
uid: $(AD_USR_CN)
mail: $(AD_USR_CN)@$(MAIL_DOMAIN)
userPassword: $(AD_USR_PW)
telephoneNumber: $(AD_USR_TEL)
title: $(AD_USR_TIT)
kopanoAccount: 1
kopanoAliases: $(AD_USR_AS)@$(MAIL_DOMAIN)
kopanoEnabledFeatures: imap
kopanoEnabledFeatures: pop3

dn: uid=$(AD_SHR_CN),ou=$(AD_USR_OU),$(AD_BASE)
cn: $(AD_SHR_CN)
objectClass: inetOrgPerson
objectClass: kopano-user
sn: $(AD_SHR_CN)
uid: $(AD_SHR_CN)
mail: $(AD_SHR_CN)@$(MAIL_DOMAIN)
kopanoAccount: 1
kopanoSharedStoreOnly: 1

dn: uid=$(AD_PUB_CN),ou=$(AD_USR_OU),$(AD_BASE)
cn: $(AD_PUB_CN)
objectClass: inetOrgPerson
objectClass: kopano-user
sn: $(AD_PUB_CN)
uid: $(AD_PUB_CN)
mail: $(AD_PUB_CN)@$(MAIL_DOMAIN)
kopanoAccount: 1
kopanoHidden: 1
kopanoSharedStoreOnly: 1
kopanoResourceType: publicFolder:Public Stores/public
endef

auth-mod_conf:
	echo "$$LDIF_MOD_CONF" | docker-compose exec -T auth ldapmodify -Q

auth-add_data:
	echo "$$LDIF_ADD_DATA" | docker-compose exec -T auth ldapadd -Q

auth-add_schema:
	docker-compose exec app zcat /usr/share/doc/kopano/kopano.ldif.gz \
	| docker-compose exec -T auth ldapadd -Q

auth-show_conf:
	docker-compose exec auth ldapsearch -QLLLb cn=config "(cn=config)"
	docker-compose exec auth ldapsearch -QLLLb cn=config olcDatabase={-1}frontend
	docker-compose exec auth ldapsearch -QLLLb cn=config olcDatabase={1}mdb

auth-show_data:
	docker-compose exec auth ldapsearch -QLLL

auth-show_cat0:
	docker-compose exec auth slapcat -n0

auth-show_cat1:
	docker-compose exec auth slapcat -n1

auth-gui-up:
	docker run -d --name auth-gui --network demo_backend \
	-p 127.0.0.1:8001:80 -e PHPLDAPADMIN_LDAP_HOSTS=auth \
	-e PHPLDAPADMIN_HTTPS=false osixia/phpldapadmin || true
	sleep 2
	firefox localhost:8001 &

auth-gui-down:
	docker rm -f auth-gui || true

mta-init:

mta-bayes:
	docker-compose exec mta sh -c 'rm -f bayesian.database.gz && wget http://artinvoice.hu/spams/bayesian.database.gz && gunzip bayesian.database.gz && sa-learn --restore bayesian.database && chown -R amavis: /var/amavis/.spamassassin && rm -rf bayesian.database'

mta-test_smtp:
	printf "From: A tester <test@example.biz>\nTo: <$(AD_USR_CN)@$(MAIL_DOMAIN)>\nDate: $$(date)\nSubject: A SMTP test message\n\nGreat news! You can receive email.\n" \
	| curl smtp://localhost -T - --mail-from test@example.biz \
	--mail-rcpt $(AD_USR_CN)@$(MAIL_DOMAIN) $(CURL_DBG)

mta-test_smtps:
	printf "From: A tester <test@example.biz>\nTo: <$(AD_USR_CN)@$(MAIL_DOMAIN)>\nDate: $$(date)\nSubject: A SMTPS test message\n\nGreat news! You can receive secure email.\n" \
	| curl smtps://localhost -T - --mail-from test@example.biz -k \
	-u $(AD_USR_CN):$(AD_USR_PW) \
	--mail-rcpt $(AD_USR_CN)@$(MAIL_DOMAIN) $(CURL_DBG)

mta-test_smtp2:
	printf "From: A info tester <test-info@example.biz>\nTo: <$(AD_USR_CN)-info@$(MAIL_DOMAIN)>\nDate: $$(date)\nSubject: A SMTP test message \n\nGreat news! $(AD_USR_CN)-info@$(MAIL_DOMAIN) can also receive email.\n" \
	| curl smtp://localhost -T - --mail-from test@example.biz \
	--mail-rcpt $(AD_USR_CN)@$(MAIL_DOMAIN) $(CURL_DBG)

mta-test_shared: all-test_quiet
	printf "From: A tester <test@example.biz>\nTo: <$(AD_SHR_CN)@$(MAIL_DOMAIN)>\nDate: $$(date)\nSubject: A SMTP test message\n\nGreat news! A shared store can receive email.\n" \
	| curl smtp://localhost -T - --mail-from test@example.biz \
	--mail-rcpt $(AD_SHR_CN)@$(MAIL_DOMAIN) $(CURL_DBG)

mta-test_public: all-test_quiet
	printf "From: A tester <test@example.biz>\nTo: <$(AD_PUB_CN)@$(MAIL_DOMAIN)>\nDate: $$(date)\nSubject: A SMTP test message\n\nGreat news! A public store can receive email.\n" \
	| curl smtp://localhost -T - --mail-from test@example.biz \
	--mail-rcpt $(AD_PUB_CN)@$(MAIL_DOMAIN) $(CURL_DBG)

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

mta-test_auth:
	docker-compose exec mta doveadm auth test $(AD_USR_CN) $(AD_USR_PW)

mta-test_imap: mta-hostaddr
	curl imaps://$(myhost)/inbox -s --ssl --anyauth -k -X "fetch 1 all" \
	-u $(AD_USR_CN):$(AD_USR_PW)

db-init:

db-test:
	docker-compose exec db mysqlshow -u $(MYSQL_USER) $(MYSQL_DATABASE) -p$(MYSQL_PASSWORD)

db-gui-up:
	docker run -d --name db-gui --network demo_backend \
	-p 127.0.0.1:8002:80 -e PMA_HOST=db \
	phpmyadmin/phpmyadmin || true
	sleep 2
	firefox localhost:8002 &

db-gui-down:
	docker rm -f db-gui || true

app-init: app-public_store app-create_smime

app-debugtools:
	docker-compose exec app apt-get update
	docker-compose exec app apt-get install --yes \
	less nano ldap-utils htop net-tools lsof iputils-ping dnsutils strace

app-htop: app-debugtools
	docker-compose exec app htop

app-test_smtp: mta-test_smtp

app-test_lmtp: app-hostaddr
	printf "LHLO mx\nMAIL FROM: <test@example.biz>\nRCPT TO: <$(AD_USR_CN)@$(MAIL_DOMAIN)>\nDATA\nFrom: A tester <test@example.biz>\nTo: <$(AD_USR_CN)@$(MAIL_DOMAIN)>\nDate: $$(date)\nSubject: A LMTP test message from me to you\n\nDelete me, please \n.\nQUIT\n" | nc -C $(myhost) 2003

app-test_all: all-test_muted app-test_imap app-test_pop3 app-test_ical app-test_imaps app-test_pop3s app-test_icals

app-test_imap: app-hostaddr
	curl imap://$(myhost) -u $(AD_USR_CN):$(AD_USR_PW) $(CURL_DBG)

app-test_imaps: app-hostaddr
	curl imaps://$(myhost) -k -u $(AD_USR_CN):$(AD_USR_PW) $(CURL_DBG)

app-test_pop3: app-hostaddr
	curl pop3://$(myhost) -u $(AD_USR_CN):$(AD_USR_PW) $(CURL_DBG)

app-test_pop3s: app-hostaddr
	curl pop3s://$(myhost) -k -u $(AD_USR_CN):$(AD_USR_PW) $(CURL_DBG)

app-test_ical: app-hostaddr
	curl http://$(myhost):8080 -u $(AD_USR_CN):$(AD_USR_PW) $(CURL_DBG)

app-test_icals: app-hostaddr
	curl https://$(myhost):8443 -k -u $(AD_USR_CN):$(AD_USR_PW) $(CURL_DBG)

app-test_tls: app-hostaddr
	docker run --rm -it --network demo_backend drwetter/testssl.sh app:993 || true

app-test_oof1:
	docker-compose exec app kopano-oof -u $(AD_USR_CN) -m 1 -t "Dunno when I return"

app-test_oof0:
	docker-compose exec app kopano-oof -u $(AD_USR_CN) -m 0

app-show_user1:
	docker-compose exec app kopano-admin --details $(AD_USR_CN)

app-show_user2: app-debugtools
	docker-compose exec app ldapsearch -H ldap://auth:389 -xLLL -b $(AD_BASE) '*'

app-show_sync:
	docker-compose exec app z-push-top

app-create_store:
	docker-compose exec app kopano-admin --create-store $(AD_USR_CN)

app-public_store:
	docker-compose exec app kopano-storeadm -P

$(addprefix app-parms_,archiver dagent gateway ical ldap search server spamd spooler):
	docker-compose exec app run list_parms $(patsubst app-parms_%,%,$@)

app-create_smime: all-create_smime
	docker cp ssl/ca.crt $$(docker-compose ps -q app):/usr/local/share/ca-certificates/$(MAIL_DOMAIN)_CA.crt
	docker-compose exec app update-ca-certificates

all-test_quiet:
	$(eval CURL_DBG := -s -S )

all-test_muted:
	$(eval CURL_DBG := -s -S >/dev/null || true)

all-create_smime: ssl/$(AD_USR_CN).p12

all-destroy_smime: ssl-destroy
