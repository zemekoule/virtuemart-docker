# Packeta — Docker dev prostředí pro VirtueMart

Lokální vývojové prostředí v Dockeru pro modul **Packeta** (plugin `vmshipment/zasilkovna`)
do VirtueMart na Joomle. Stack: Joomla 5 + Apache + PHP 8.3 + Xdebug + MariaDB 12 +
Adminer + Mailpit.

## Předpoklady

- Docker / Docker Desktop
- macOS nebo Linux (na macOS sjednocujeme UID/GID s hostitelem — typicky `501:20`)

## Rychlý start

```bash
git clone git@github.com:Zasilkovna/virtuemart3.git modules/packeta
cp .env.example .env       # vyplnit ENV_UID/GID podle `id -u` / `id -g`
./scripts/up.sh            # build a start celého stacku
```

`modules/packeta/` je v `.gitignore` — modul má vlastní upstream repo
([Zasilkovna/virtuemart3](https://github.com/Zasilkovna/virtuemart3)) a tady ho
jen mountujeme do Joomly. Bez klonu nebude `install-module.sh` mít co
zazipovat.

Po startu jsou dostupné:

| Služba | URL / port | Login |
|---|---|---|
| Joomla frontend | http://localhost:8080 | — |
| Joomla admin | http://localhost:8080/administrator | `admin` / `adminadmin1234` |
| Adminer (DB UI) | http://localhost:8081 | server `dev_db`, user `root`, pass `asdf` |
| Mailpit (mail catcher) | http://localhost:8025 | — |
| MariaDB (přímo z hosta) | `localhost:3308` | `root` / `asdf` |

Detailní workflow prvního spuštění je v sekci [VirtueMart — workflow čisté instalace](#virtuemart--workflow-čisté-instalace)
níže a v dokumentaci jednotlivých skriptů.

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

Po nahrání VirtueMart zipu (sekce
[VirtueMart — workflow čisté instalace](#virtuemart--workflow-čisté-instalace))
spustit **před kliknutím na "Install Sample Data"** na VM welcome screen.
Skript přes SQL enabluje plugin `vmshipment - weight_countries`, který je
po čisté instalaci VM `enabled=0`. Bez toho sample importer padne v PHP 8+
na *"Attempt to assign property name on null"* v
`helpers/vdispatcher.php:240`.

```bash
./scripts/configure-vm-after-install.sh
```

Idempotentní — `UPDATE ... WHERE enabled=0` zařídí, že druhý běh nedělá nic.
Pokud sem v budoucnu přibudou další "extra" nastavení po čisté instalaci VM
(která sample importer / běh storefrontu vyžaduje), patří do tohoto skriptu.

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

## VirtueMart — workflow čisté instalace

Při čisté instalaci VM (po `reset-env.sh` + `up.sh`) jsou tři ne-intuitivní věci:

**Cesta k uploadu zipu.** V Joomle 5 *System → Install → Extensions* není
souvislý menu chain — *Install* je sekce **na stránce System Dashboard**,
ne submenu položka. Reálná cesta:

1. Sidebar **System** (otevře *System Dashboard*).
2. Na System Dashboard sekce **Install** → klik na **Extensions**.
3. Stránka *Extensions: Install*, tab **Upload Package File** (default).
4. Drag/drop `install/com_virtuemart.<verze>_package_or_extract.zip` do dropzóny.

**Sample data importer padá v PHP 8+ bez `vmshipment - weight_countries`.**
Po úspěšném uploadu zipu zůstaneš na *Extensions: Install* obrazovce s VM
welcome screen ("Installation was SUCCESSFUL"). V sekci *Installing VirtueMart
Plugins and Modules* je šedý inline odkaz **"Install Sample Data"** — ten ale
teď neklikat. Nejdřív spustit:

```bash
./scripts/configure-vm-after-install.sh
```

Skript přes SQL enabluje plugin `vmshipment - weight_countries` (defaultně
`enabled=0`). Bez toho sample importer padne na *"Attempt to assign property
name on null"* v `helpers/vdispatcher.php:240`. Teprve po skriptu klik
na **Install Sample Data** — landing page *Updating & Data migration*
ohlásí *"Sample data installed!!"*.

**Baseline DB dump.** Po úspěšném importu jsi v cílovém stavu pro další práci
na modulu. Udělej `./scripts/db-snapshot.sh clean-joomla-vm` — z toho se
kdykoli vrátíš přes `db-restore.sh`.

### Reset VM tabulek (volitelné, pro re-install scénáře)

Pokud chceš VM zresetovat a importovat sample data znovu (např. po
experimentech s vlastními daty), je ve *VM Configuration* potřeba zapnout
volbu **Enable database Update tools**; pak se v *Tools & Migration* zobrazí
*Reset all Virtuemart tables and do a fresh install with sample data*. Pro
běžný clean install workflow ale stačí `db-restore.sh` s baseline snapshotem.

**VirtueMart installer v `install/`** — `install/com_virtuemart.<verze>_package_or_extract.zip`
je commitnutý (cca 6 MB), aby každý klonující měl rovnou čím VM nainstalovat přes
**System → Install → Extensions → Upload Package File**. Není to ale latest verze
napořád — když [virtuemart.net/download](https://virtuemart.net/download) vydá novou,
stáhni ji, nahraď zip v `install/` a starý smaž (v repu chceme jen jeden, aby
nebylo nejasné, který použít).

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