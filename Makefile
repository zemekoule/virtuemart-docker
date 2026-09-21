# Single-verze dev stack pro modul Packeta (Joomla + VirtueMart).
# Makefile je jen tenký obal nad scripts/*.sh — logika zůstává ve skriptech.
# Verzi (Joomla/PHP) přepínáš v .env (JOOMLA_TAG / PHP_VERSION) + `make build` + `make up`.

.PHONY: up down build restart shell shell-root php xdebug mysql logs \
        pack install-module reinstall-module db-snapshot db-restore \
        configure-debug configure-mail configure-vm send-mail reset-env help

help: ## Vypíše dostupné cíle
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*?## "}{printf "  %-18s %s\n", $$1, $$2}'

# --- lifecycle ---------------------------------------------------------------
up: ## Nahodí stack (vytvoří .env z příkladu, pak docker compose up -d)
	./scripts/up.sh

down: ## Zastaví a odstraní kontejnery (data v ./db ./src ./mailpit zůstávají)
	./scripts/down-all.sh

build: ## Rebuild image z Dockerfile; ARGS="--no-cache"
	./scripts/build.sh $(ARGS)

restart: ## Restart služeb; ARGS="joomla" jen jednu
	./scripts/restart.sh $(ARGS)

reset-env: ## Smaže veškerý runtime state; ARGS="--with-image" i image
	./scripts/reset-env.sh $(ARGS)

# --- shell / php -------------------------------------------------------------
shell: ## Interaktivní bash v kontejneru joomla (www-data)
	./scripts/bash-www-data.sh

shell-root: ## Interaktivní bash v kontejneru joomla (root)
	./scripts/bash-root.sh

php: ## PHP CLI v kontejneru; ARGS="cli/joomla.php extension:list"
	./scripts/php-www-data.sh $(ARGS)

xdebug: ## PHP CLI s Xdebug triggerem; ARGS="cli/joomla.php …"
	./scripts/xdebug-php-www-data.sh $(ARGS)

mysql: ## MariaDB shell (heslo asdf hardcoded i ve skriptech — viz FOLLOWUPS #3)
	docker exec -it dev_db mariadb -u root -pasdf joomla

logs: ## Sleduje logy kontejneru joomla
	docker logs -f --tail=100 joomla

# --- modul -------------------------------------------------------------------
pack: ## Zazipuje modules/packeta/ → ./packeta.zip
	./scripts/pack-module.sh

install-module: ## Nainstaluje modul přes Joomla CLI (fresh install)
	./scripts/install-module.sh

reinstall-module: ## Odinstaluje + nainstaluje modul znovu (po změně manifestu / install.sql)
	./scripts/reinstall-module.sh

# --- DB snapshot/restore -----------------------------------------------------
db-snapshot: ## Dump DB → ./db-snapshots/<NAME>.sql; NAME=clean-joomla-vm
	./scripts/db-snapshot.sh $(NAME)

db-restore: ## Obnoví DB ze ./db-snapshots/<NAME>.sql; NAME=clean-joomla-vm
	./scripts/db-restore.sh $(NAME)

# --- post-install konfigurace ------------------------------------------------
configure-debug: ## Zapne Joomla debug + maximum error reporting
	./scripts/configure-joomla-debug.sh

configure-mail: ## Nastaví Joomla mailer na SMTP do Mailpitu
	./scripts/configure-joomla-mail.sh

configure-vm: ## Post-install nastavení VirtueMartu (enable shipment plugin, …)
	./scripts/configure-vm-after-install.sh

send-mail: ## Pošle testovací e-mail do Mailpitu (:8025)
	./scripts/send-test-mail.sh
