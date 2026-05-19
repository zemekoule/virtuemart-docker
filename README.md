# Packeta — Docker dev prostředí pro VirtueMart

Lokální vývojové prostředí v Dockeru pro modul **Packeta** (plugin `vmshipment/zasilkovna`)
do VirtueMart na Joomle. Stack: Joomla + Apache + PHP + Xdebug + MariaDB +
Adminer + Mailpit.

## Pro koho je tento README

- **Vývojář, který sem přichází poprvé** — projdi shora dolů sekce
  [Verze](#verze), [Předpoklady](#předpoklady), [Rychlý start](#rychlý-start).
  Skončíš s funkčním dev prostředím, na kterém můžeš začít pracovat na modulu.
- **Vývojář, který už projekt zná a hledá referenci** — přeskoč rovnou na
  [Skripty](#skripty), [Reset VM tabulek pro re-install](#reset-vm-tabulek-pro-re-install),
  nebo [PhpStorm setup](#phpstorm-setup).

## Verze

To, na čem je projekt **postavený a otestovaný** (default stack):

| Komponenta | Verze | Kde se konfiguruje |
|---|---|---|
| Joomla | 5 (latest minor z tagu `joomla:5-php8.3-apache`) | `.env` (`JOOMLA_TAG`) |
| PHP | 8.3 | `.env` (`PHP_VERSION`) |
| VirtueMart | 4.6.4.11226 (z `install/com_virtuemart.4.6.4.11226_package_or_extract.zip`) | manuální upload — viz [Rychlý start](#rychlý-start) krok 5 |
| MariaDB | 12 | `docker-compose.yml` |
| Xdebug | 3.5.x (latest z PECL při buildu) | `Dockerfile` |
| Apache | 2.4.x (z `joomla:5-php8.3-apache` base image) | base image |

Modul samotný cílí kompatibilitu **Joomla 4 + 5, VirtueMart 4, PHP 8.1 – 8.5**,
ale ostatní kombinace nejsou v tomto repo defaultně otestované. Postup
pro jejich vyzkoušení je v sekci [Změna verzí](#změna-verzí).

## Předpoklady

- Docker / Docker Desktop
- macOS nebo Linux (na macOS sjednocujeme UID/GID s hostitelem — typicky `501:20`)

## Rychlý start

Předpokládá Docker, git a ssh klíč nastavený pro GitHub. Sekvence od nuly:

### 1. Naklonovat tento repo

```bash
mkdir -p ~/dev && cd ~/dev
git clone git@github.com:zemekoule/virtuemart-docker.git
cd virtuemart-docker
```

(`~/dev` je doporučení, použij libovolný adresář — zbytek README předpokládá,
že jsi v rootu naklonovaného repa `virtuemart-docker/`.)

### 2. Naklonovat modul Packeta do `modules/packeta/`

Modul má vlastní upstream repo ([`Zasilkovna/virtuemart3`](https://github.com/Zasilkovna/virtuemart3))
a v tomto repu je gitignored (`/modules/` v `.gitignore`). Klonujeme ho samostatně:

```bash
git clone git@github.com:Zasilkovna/virtuemart3.git modules/packeta
```

Bez tohohle kroku nebude bind-mount do Joomly mít co mountovat a
`install-module.sh` nebude mít co zazipovat.

### 3. Vytvořit `.env` z příkladu a vyplnit UID/GID

```bash
cp .env.example .env
```

Edituj `.env` a nastav `ENV_UID` a `ENV_GID` podle hostitele:

- **Linux:** typicky `1000:1000` (zjisti přes `id -u` a `id -g`)
- **macOS:** typicky `501:20` (`id -u` / `id -g` pro jistotu)

Tím se UID/GID `www-data` v kontejneru sjednotí s tvým user, aby soubory
v `./src/` a `./modules/` měly správného vlastníka.

### 4. Build image a start stacku

```bash
./scripts/up.sh
```

První build trvá pár minut (build PHP + Xdebug + SOAP). Při dalších `up.sh`
už cache image použije.

Joomla auto-installer proběhne při prvním HTTP requestu — počkej ~30 sekund
a otevři **http://localhost:8080** nebo **http://localhost:8080/administrator**.

Co teď běží:

| Služba | URL / port | Login |
|---|---|---|
| Joomla frontend | http://localhost:8080 | — |
| Joomla admin | http://localhost:8080/administrator | `admin` / `adminadmin1234` |
| Adminer (DB UI) | http://localhost:8081 | server `dev_db`, user `root`, heslo `asdf` |
| Mailpit (mail catcher) | http://localhost:8025 | — |
| MariaDB (přímo z hosta) | `localhost:3308` | `root` / `asdf` |

### 5. Nainstalovat VirtueMart

> **Proč ručně, a ne skriptem jako modul (krok 10)?** VM má vlastní AIO
> instalátor s post-install UI workflow (welcome screen + šedý odkaz
> *Install Sample Data*), který by se přes Joomla CLI dal automatizovat,
> ale na první instalaci jednou za `reset-env.sh` se to nevyplatí —
> dál už si stav držíme přes [`db-snapshot.sh`](#scriptsdb-snapshotsh-name).
> Modul Packeta naopak instalujeme/reinstalujeme často během vývoje,
> proto má vlastní [`install-module.sh`](#scriptsinstall-modulesh).

V adminu klikni: **Sidebar System → System Dashboard → sekce Install → Extensions → tab Upload Package File**.
Do dropzóny přetáhni `install/com_virtuemart.4.6.4.11226_package_or_extract.zip`.

> **Nezavírej zatím** VM AIO welcome screen a **neklikej** na "Install Sample Data" —
> nejdřív další krok.

### 6. Spustit `configure-vm-after-install.sh`

```bash
./scripts/configure-vm-after-install.sh
```

Skript přes SQL/mkdir enabluje shipment plugin `weight_countries` (bez něj
sample importer padá v PHP 8+) a vytvoří + nastaví VM Safe Path (bez něj VM
hází warningy na každé admin stránce). Detaily v
[dokumentaci skriptu](#scriptsconfigure-vm-after-installsh).

### 7. Naimportovat VM sample data

Vrať se na záložku s VM AIO welcome screenem (Joomla admin → *Extensions: Install*)
a klikni na šedý inline odkaz **"Install Sample Data"** v sekci
*"Installing VirtueMart Plugins and Modules"*. Po importu přistaneš na stránce
*Updating & Data migration* s green hláškou `Sample data installed!!`.

### 8. Nastavit SMTP a debug mode

```bash
./scripts/configure-joomla-mail.sh    # mail přes Mailpit (:8025)
./scripts/configure-joomla-debug.sh   # $debug=true + error_reporting=maximum
```

Ověř, že mail pipeline funguje:

```bash
./scripts/send-test-mail.sh
```

Zpráva se objeví v Mailpitu na http://localhost:8025.

### 9. Udělat baseline DB snapshot

```bash
./scripts/db-snapshot.sh clean-joomla-vm
```

Dump skončí v `./db-snapshots/clean-joomla-vm.sql`. Z toho stavu se kdykoli
vrátíš přes `./scripts/db-restore.sh clean-joomla-vm` (bez nového VM install
workflow).

### 10. Nainstalovat modul Packeta

```bash
./scripts/install-module.sh
```

Modul je teď v Joomle jako plugin (`folder=vmshipment, element=zasilkovna`).
Defaultně `enabled=0` — povolit musíš v adminu: **Extensions → Plugins**,
filter `vmshipment`, klik na status u *Packeta*.

### Hotovo

Dev prostředí je připravené. Můžeš:

- Otevřít projekt v PhpStormu — viz [PhpStorm setup](#phpstorm-setup).
- Editovat soubory v `modules/packeta/` — díky live bind-mountu jsou změny
  PHP okamžitě live; jen při změně `zasilkovna.xml`, `install.sql` nebo
  jazykových souborů spusť `./scripts/reinstall-module.sh`.
- Kdykoli vrátit DB do baseline přes `./scripts/db-restore.sh clean-joomla-vm`.
- Plně resetovat prostředí přes `./scripts/reset-env.sh` (volitelně
  `--with-image` pro rebuild od Dockerfile).

## Změna verzí

Default stack (Joomla 5 + PHP 8.3 + VM 4.6.4) odpovídá tomu, co repo
[testuje](#verze). Pokud chceš odlišnou kombinaci:

- **Joomla / PHP** — uprav `JOOMLA_TAG` a `PHP_VERSION` v `.env`. Dostupné
  kombinace tagů: viz [`joomla` na Docker Hubu](https://hub.docker.com/_/joomla/tags)
  (např. `4-php8.1-apache`, `5-php8.2-apache`). Po změně `.env` spusť
  `./scripts/reset-env.sh --with-image` (smaže image i runtime state)
  a pak `./scripts/up.sh` (rebuild). PHP 8.4 a 8.5 zatím v oficiálních
  `joomla:` tagách nejsou, vyžadovaly by vlastní stack (`php:8.4-apache` +
  ruční Joomla install) — viz `PLAN_docker_environment.md` 3. kolo.
- **VirtueMart** — stáhni novější ZIP z [virtuemart.net/download](https://virtuemart.net/download),
  nahraď `install/com_virtuemart.*.zip` (v repu chceme jen jeden, aby
  nebylo nejasné, který použít) a commitni. Workflow čisté instalace
  zůstává stejný.
- **MariaDB / Adminer / Mailpit** — verze v `docker-compose.yml`. Změna
  vyžaduje `./scripts/up.sh` (re-create kontejnerů). Pozor na zpětnou
  kompatibilitu DB dat (`./db/`) při downgrade MariaDB.

## Skripty

Všechny skripty jsou ve složce `scripts/` a lze je spouštět z libovolného adresáře —
interně si přejdou do rootu projektu (`cd "$(dirname "$0")/.."`).

### `scripts/up.sh`

Build a start celého stacku (`docker compose up -d`). Pokud chybí `.env`, vytvoří ho
zkopírováním z `.env.example` a vypíše upozornění, ať si zkontroluješ `ENV_UID/GID`.
První build trvá pár minut, další startují z cache prakticky okamžitě.

```bash
./scripts/up.sh
```

### `scripts/down-all.sh`

Zastaví a odstraní všechny kontejnery (`docker compose down`). Data v `./db`, `./src`,
`./mailpit` jsou bind mounty na hostu, takže `down` je neodstraní — po dalším `up.sh`
prostředí pokračuje tam, kde skončilo.

```bash
./scripts/down-all.sh
```

### `scripts/reset-env.sh [--with-image]`

**Resetujeme prostředí do stavu „úplně prvního spuštění"**. Užitečné při testování
celého dev workflow od nuly nebo když se prostředí zaseklo v nějakém stavu.

```bash
./scripts/reset-env.sh                # smaže runtime state, image zachová
./scripts/reset-env.sh --with-image   # + smaže i custom image (force rebuild)
```

Smaže (po potvrzení):

- kontejnery (`docker compose down`)
- obsah `./src/` (Joomla install)
- obsah `./db/` (MariaDB data, **vč. VirtueMart sample dat a všech custom dat**)
- obsah `./mailpit/` (zachycené test maily)
- `./packeta.zip` (pokud existuje)

Zachová: `.env`, `db-snapshots/` (tvoje baseline dumpy), `modules/packeta/`
(zdrojový kód modulu).

Po dokončení spusť `./scripts/up.sh` pro čistou instalaci od nuly.

### `scripts/restart.sh [service]`

Restart služeb stacku (`docker compose restart`). Užitečné po změnách v `php.ini` /
`xdebug.ini` (oba jsou bind-mountnuté, takže stačí restart Apache uvnitř kontejneru,
což `restart` zařídí). Pokud chceš restartovat jen jednu službu:

```bash
./scripts/restart.sh                  # restart všech
./scripts/restart.sh joomla           # jen joomla
```

> Po změně `docker-compose.yml` (např. odkomentování bind-mountu) `restart` **nestačí** —
> kontejner se nerekreate-ne. Použij `./scripts/up.sh`, ten změny config detekuje
> a kontejnery podle nich znovu vytvoří.

### `scripts/build.sh [docker compose build args]`

Rebuild image podle `Dockerfile`. Užitečné po změnách v `Dockerfile`, `apt` balíčcích,
PECL extensions atd. Argumenty se propustí dál:

```bash
./scripts/build.sh                    # build s cache
./scripts/build.sh --no-cache         # úplný rebuild
./scripts/build.sh --pull             # stáhnout nejnovější base image
```

### `scripts/bash-www-data.sh` / `scripts/bash-root.sh`

Interaktivní bash uvnitř `joomla` kontejneru. `bash-www-data` jako uživatel `www-data`
(s UID/GID sjednoceným s hostem — soubory vytvořené v kontejneru budou na hostu mít
správného vlastníka). `bash-root` jako root (na `apt-get`, `pecl install` apod.).

```bash
./scripts/bash-www-data.sh
./scripts/bash-root.sh
```

### `scripts/php-www-data.sh <args>`

Spustí PHP CLI v kontejneru jako `www-data`. Argumenty se propustí. Joomla CLI má pracovní
adresář `/var/www/html`, takže `cli/joomla.php` cesta funguje rovnou.

```bash
./scripts/php-www-data.sh -v
./scripts/php-www-data.sh cli/joomla.php list extension
./scripts/php-www-data.sh cli/joomla.php extension:list --type=plugin
```

### `scripts/xdebug-php-www-data.sh <args>`

To samé, ale s aktivovaným Xdebug triggerem (`XDEBUG_TRIGGER=1` env). Xdebug je
v `xdebug.ini` nastavený jako `start_with_request=trigger`, takže bez triggeru se
nespustí. Pro debug breakpointu v IDE: nejprve v PhpStormu *Listen for PHP Debug
Connections* (poslouchá na portu 9003), pak spustit:

```bash
./scripts/xdebug-php-www-data.sh cli/joomla.php extension:list
```

### `scripts/pack-module.sh`

Zazipuje obsah `modules/packeta/` do `./packeta.zip` v rootu projektu. Manifest
`zasilkovna.xml` skončí v kořeni zipu (formát očekávaný Joomla installerem).
Vyloučené ze zipu: `.git/`, `.claude/`, `.gitignore`, `.gitattributes`, `.DS_Store`.

```bash
./scripts/pack-module.sh
```

Před spuštěním kontroluje, že `modules/packeta/zasilkovna.xml` existuje — bez manifestu
by Joomla zip stejně odmítla.

### `scripts/install-module.sh`

Zazipuje modul a nainstaluje ho do běžící Joomly přes Joomla CLI (`cli/joomla.php
extension:install`). Postup:

1. Zavolá `pack-module.sh` → vytvoří `packeta.zip`
2. Zkopíruje zip do kontejneru `joomla:/tmp/packeta.zip`
3. Spustí Joomla CLI install (`extension:install --path /tmp/packeta.zip`)
4. Smaže tmp soubor v kontejneru

```bash
./scripts/install-module.sh
```

Po úspěšné instalaci je plugin v `#__extensions` jako `folder=vmshipment,
element=zasilkovna`. Defaultně `enabled=0` — povolit musíš v adminu:
**Extensions → Plugins**, filter `vmshipment`, klik na status pluginu *Packeta*.

> Pokud máš v `docker-compose.yml` odkomentovaný druhý bind-mount
> (`./modules/packeta` → `/var/www/html/plugins/vmshipment/zasilkovna`), reinstall
> potřebuješ jen při změnách `zasilkovna.xml`, `install.sql` nebo lang souborů —
> změny PHP souborů jsou live.

### `scripts/configure-joomla-debug.sh`

Zapne v Joomle `$debug = true` a `$error_reporting = 'maximum'` — místo generického
*"An error has occurred"* uvidíš plný stack trace a všechny PHP deprecation
warningy. Patchuje `configuration.php` přes PHP one-shot v kontejneru (idempotentně,
stejný pattern jako `configure-joomla-mail.sh`).

```bash
./scripts/configure-joomla-debug.sh
```

> Defaultní hodnoty po Joomla auto-installu jsou `$debug = false` a
> `$error_reporting = 'default'`. Debug mode není v DB ale v `configuration.php`
> souboru, takže `db-restore.sh` ho nezasáhne — pokud script jednou spustíš,
> debug zůstane on.

### `scripts/configure-vm-after-install.sh`

Po nahrání VirtueMart zipu (krok 5 v [Rychlém startu](#rychlý-start))
spustit **před kliknutím na "Install Sample Data"** na VM welcome screen.
Skript udělá dvě věci, které VM defaultně nezařídí sám:

1. **Enable plugin `vmshipment - weight_countries`** (SQL UPDATE). Bez něj
   sample importer padne v PHP 8+ na *"Attempt to assign property name on
   null"* v `helpers/vdispatcher.php:240`.
2. **Setup Safe Path** — mkdir `<webroot>/administrator/components/com_virtuemart/safepath/`
   (+ podsložky `keys/`, `invoices/`) a zápis cesty do
   `joom_virtuemart_configs.config` (`forSale_path`). Bez toho VM hází nag
   warningy *"Safe Path is not configured yet"* a *"folder invoices does
   not exist..."* na každé admin stránce.

```bash
./scripts/configure-vm-after-install.sh
```

Idempotentní:

- Plugin update má `WHERE enabled = 0` — druhý běh nezasahuje.
- `mkdir -p` je no-op, pokud adresář existuje.
- `forSale_path` přepis používá `preg_replace` v PHP one-shotu; pokud je
  hodnota už cílová, zapíše se zpráva *"forSale_path už nastaveno...
  (skip)"* a žádný DB write se nedělá.

Pokud sem v budoucnu přibudou další "extra" nastavení po čisté instalaci
VM (která sample importer / běh storefrontu vyžaduje), patří do tohoto
skriptu.

### `scripts/configure-joomla-mail.sh`

Nastaví Joomla mail config tak, aby odesílal přes Mailpit (kontejner `mailpit`,
SMTP `:1025`). Patchuje `configuration.php` přes PHP one-shot v kontejneru —
nikoli ruční editací. **Idempotentní**, bezpečné opakované volání.

```bash
./scripts/configure-joomla-mail.sh
```

Změní (pokud ještě nejsou):

- `$mailer = 'smtp'`
- `$smtphost = 'mailpit'`
- `$smtpport = 1025`
- `$smtpauth = false` (Mailpit auth nevyžaduje)
- `$smtpsecure = 'none'` (lokálně bez TLS)
- `$mailfrom = 'admin@example.com'`, `$fromname = 'VirtueMart Dev'`

Po nastavení ověř end-to-end pipeline přes `./scripts/send-test-mail.sh` —
script naloaduje Joomla framework, zavolá `Factory::getMailer()->Send()`
a zachycená zpráva se objeví v Mailpitu na http://localhost:8025.
(Joomla 5 v admin UI samostatné "Send Test Mail" tlačítko nemá, takže test
provádíme z CLI.)

> **Pozor**: mail config je v `configuration.php` (soubor), ne v DB —
> `db-snapshot.sh` / `db-restore.sh` ho nezasáhne. Přepnutí mezi DB snapshoty
> tedy mail config zachová.
>
> `php.ini` má `disable_functions = mail`, takže Joomla nemůže silent fallback
> na PHP `mail()` — musí jít přes SMTP.

### `scripts/send-test-mail.sh`

Pošle testovací e-mail přes Joomla mailer (`Factory::getMailer()->Send()`).
Užitečné pro ověření, že `configure-joomla-mail.sh` + SMTP konfigurace fungují
end-to-end — pokud script vypíše *"Odesláno OK"* a zpráva se objeví v Mailpitu,
celá pipeline (configuration.php → Joomla mailer → mailpit:1025) je v pořádku.

```bash
./scripts/send-test-mail.sh
```

Script naloaduje Joomla framework stejným patternem jako `cli/joomla.php`
(bootstrap Console application, alias session.cli). Joomla 5 v admin UI vlastní
"Send Test Mail" tlačítko nemá, takže test provádíme z CLI.

### `scripts/reinstall-module.sh`

**Force clean reinstall** — smaže DB stopy modulu (extension row + plug-in tabulky)
a spustí čistý install. Použij, když chceš ověřit chování modulu od úplné nuly
(typicky po změně `install.sql` nebo `zasilkovna.xml`).

```bash
./scripts/reinstall-module.sh
```

Co dělá:

1. Před destruktivním krokem se ptá na potvrzení a vypíše, co všechno smaže.
2. `DELETE FROM #__extensions WHERE folder='vmshipment' AND element='zasilkovna'`
3. `DROP TABLE` na `#__virtuemart_shipment_plg_zasilkovna`, `#__virtuemart_zasilkovna_carriers`
   (a legacy `_branches` / `_backup`, pokud existují)
4. Spustí `install-module.sh` — Joomla teď nenajde extension row, takže to **není
   update path, ale install path** → `install.sql` se spustí znovu od nuly.

> **NEpoužívá Joomla `extension:remove` záměrně.** S aktivním druhým bind-mountem
> by Joomla při uninstallu mazala soubory v `/plugins/vmshipment/zasilkovna/`,
> což přes bind mount znamená smazat source files v `modules/packeta/` na hostu.
>
> Data v plug-in tabulkách (carrier configs, pickup points) přijdou pryč. Pokud je
> chceš zachovat, udělej napřed `./scripts/db-snapshot.sh <name>`.

### `scripts/db-snapshot.sh <name>`

Vytvoří dump celé databáze `joomla` do `./db-snapshots/<name>.sql`. Dump obsahuje
`CREATE DATABASE` + `USE joomla` (díky flagu `--databases`), `--single-transaction`,
`--routines --triggers --events`.

```bash
./scripts/db-snapshot.sh clean-joomla-vm     # vytvořit/přepsat snapshot
./scripts/db-snapshot.sh                     # bez argumentu vypíše existující
```

Před přepsáním existujícího snapshotu se ptá. Snapshoty jsou v `db-snapshots/`
(gitignored), tj. nesdílejí se přes git — slouží lokálnímu rychlému resetu prostředí.

### `scripts/db-restore.sh <name>`

Obnoví databázi `joomla` ze snapshotu. Drop staré DB → import dumpu (dump sám
zařídí `CREATE DATABASE` + `USE joomla`). Joomla kontejner se zastavovat nemusí,
connection se znovu naváže při dalším requestu.

```bash
./scripts/db-restore.sh clean-joomla-vm      # restore
./scripts/db-restore.sh                      # bez argumentu vypíše dostupné
```

Před destruktivním krokem se ptá. Po restoru ti admin odhlásí — sessions jsou
uložené v DB.

## Reset VM tabulek pro re-install

Pokud chceš VM zresetovat a importovat sample data znovu (např. po
experimentech s vlastními daty), je ve *VM Configuration* potřeba zapnout
volbu **Enable database Update tools**; pak se v *Tools & Migration* zobrazí
*Reset all Virtuemart tables and do a fresh install with sample data*. Pro
běžný clean install workflow ale stačí `db-restore.sh` s baseline
snapshotem (krok 9 z [Rychlého startu](#rychlý-start)).

## PhpStorm setup

Tato sekce předpokládá PhpStorm 2024+ a Xdebug 3. Stack už má Xdebug i `PHP_IDE_CONFIG`
hotové, takže v IDE stačí nastavit CLI interpreter, server pro web debug a path mappingy.

### 1. Otevřít projekt

Kořen projektu otevři jako PhpStorm projekt:

```
/Users/<ty>/.../virtuemart-docker
```

Modul Packeta je vidět v `modules/packeta/`. Joomla install v `src/` je generovaný
(gitignored) a slouží jen jako runtime — kód neupravuj přímo v `src/`.

### 2. CLI interpreter přes Docker Compose

**Settings → PHP → CLI Interpreter → `+` → From Docker, Vagrant, …** → vyber
**Docker Compose**:

- Server: Docker
- Configuration files: `./docker-compose.yml`
- Service: `joomla`
- Lifecycle: *Connect to existing container (`docker-compose exec`)*

PhpStorm si detekuje PHP 8.3, Xdebug 3.5+, Composer. Tento interpreter pak používej
pro **Settings → PHP → Composer** i pro Run/Debug konfigurace.

### 3. Server pro web debug

**Settings → PHP → Servers → `+`**:

- Name: **`virtuemart.local`** — **musí** souhlasit s `PHP_IDE_CONFIG: "serverName=virtuemart.local"`
  v `docker-compose.yml`, jinak Xdebug nepoužije správný mapping.
- Host: `localhost`, Port: `8080`, Debugger: Xdebug
- Use path mappings: **✓**

Path mappings:

| Lokální cesta (host) | Server cesta (kontejner) |
|---|---|
| `<repo>/src` | `/var/www/html` |
| `<repo>/modules/packeta` | `/var/www/html/plugins/vmshipment/zasilkovna` |
| `<repo>/modules/packeta` | `/var/www/packeta-dev` |

První mapping pokrývá celý Joomla runtime. Druhý mapping je důležitý pro breakpointy
v modulu během webových requestů (Joomla loaduje plugin z `/plugins/vmshipment/zasilkovna/`,
což je přes bind-mount náš `modules/packeta/`). Třetí mapping pokrývá build/lint/compose
operace v `/var/www/packeta-dev`.

### 4. Xdebug

V `xdebug.ini` máme `xdebug.mode=debug`, `xdebug.start_with_request=trigger`,
`xdebug.discover_client_host=1`. Tj. Xdebug se nespouští u každého requestu, jen na
trigger.

**PhpStorm**:

- **Settings → PHP → Debug**: Debug port `9003` (default Xdebug 3).
- Klikni na **telefonní ikonu** v toolbaru → *Start Listening for PHP Debug Connections*.

**Web debug**:

- Nainstaluj browser extension *Xdebug helper* (Chrome / Firefox) a klikni na ni
  → *Debug*. Tím se přidá cookie `XDEBUG_TRIGGER=1`. Pak request přes PhpStorm.

**CLI debug** modul / Joomla CLI:

```bash
./scripts/xdebug-php-www-data.sh cli/joomla.php extension:list
```

Script nastavuje `XDEBUG_TRIGGER=1` env, takže Xdebug se připojí na PhpStorm listener.

### 5. Joomla / VirtueMart sources jako "external library"

`src/` je gitignored runtime, ale často potřebuješ skočit do Joomla / VirtueMart kódu
přes Ctrl+klik. Označ `src/` jako external library / source root:

**Pravý klik na `src/` → Mark Directory as → Library Root** (nebo Sources Root).

Nebo přidej přes **Settings → Directories → Add Content Root** → `src/`, a označ
příslušné podadresáře (`administrator/`, `libraries/`, …) jako Sources.

Volba: pokud nechceš mít `src/` v indexu (zpomaluje fulltext search), použij Library Root.