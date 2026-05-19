# Plán: lokální Docker prostředí pro vývoj modulu Packeta (Joomla + VirtueMart)

## Cíl

Vývojové prostředí v Dockeru pro modul **Packeta** pro VirtueMart.
Inspirováno [`zemekoule/ps8-docker`](https://github.com/zemekoule/ps8-docker) (PrestaShop varianta).

## Modul

- Lokace v repu: `modules/packeta/` (klon z GitHubu)
- Typ: Joomla plugin, group `vmshipment`, název `zasilkovna`
- Manifest: `zasilkovna.xml` (`<extension type="plugin" group="vmshipment">`)
- Distribuce: ZIP root celé složky `modules/packeta/` → instalace přes Joomla admin
  (Extensions → Install → Upload)
- Cílová cesta v Joomle: `/plugins/vmshipment/zasilkovna/`

## Kompatibilita (CLAUDE.md)

- Joomla 4 a 5
- VirtueMart 4
- PHP 8.1 – 8.5

## Co přebíráme z ps8-docker 1:1

| Komponenta | Detail |
|---|---|
| Adminer | DB UI na `:8081` |
| Mailpit | mail catcher na `:8025`, SMTP `:1025`; `disable_functions=mail` v `php.ini` |
| MariaDB 12 | databáze na `:3308`, data v `./db/` |
| Xdebug | mode=debug, trigger-based, `discover_client_host=1` |
| UID/GID mapping | přes `ARG_UID/GID` v Dockerfile, hodnota z `ENV_UID/GID` v `.env` |
| Pomocné skripty | `up.sh`, `down-all.sh`, `restart.sh`, `bash-*.sh`, `php-*.sh`, `xdebug-*.sh`, `menu.sh` |
| Vzor `.gitignore` | `/src/`, `/db/`, `/mailpit/`, `/.env` + navíc `modules/packeta/.git/` |

## Klíčové rozdíly oproti ps8-docker

1. **Base image** — `joomla:${JOOMLA_TAG}-php${PHP_VERSION}-apache` (oficiální Joomla image).
   - VirtueMart **není** součástí image — instaluje se ručně jednou přes admin UI.
   - PHP 8.1–8.3 jsou v oficiálních tagech k dispozici; PHP 8.4/8.5 řešíme později.
2. **Parametrizace verzí** — `JOOMLA_TAG` a `PHP_VERSION` v `.env`, build args do Dockerfile.
   Přepnutí verze = úprava `.env` + `build.sh` + `up.sh`. Vždy jen jedna kombinace najednou.
3. **Bind-mount modulu — dva směry:**
   - `./modules/packeta` → `/var/www/packeta-dev` (build zip, composer, lint)
     — aktivní od začátku, neovlivňuje Joomla.
   - `./modules/packeta` → `/var/www/html/plugins/vmshipment/zasilkovna`
     — **zapnout až po prvním instalu** Packety (přes zip),
     pak je každá změna PHP souboru v modulu okamžitě live.
     Reinstall je třeba jen při změně `zasilkovna.xml`, `install.sql` nebo jazykových souborů.
4. **DB snapshot/restore** — nový pár skriptů `db-snapshot.sh` / `db-restore.sh`
   pro rychlý reset prostředí (např. zpět na „čistá Joomla + VirtueMart, bez modulu").

## Struktura repa

```
virtuemart-docker/
├── CLAUDE.md
├── PLAN_docker_environment.md       # tento soubor
├── README.md                        # ve druhém kole (návod ke spuštění + PhpStorm)
├── docker-compose.yml
├── Dockerfile
├── .env.example
├── .gitignore
├── apache2.conf, ports.conf, virtualhost.conf   # ve třetím kole, pokud bude třeba SSL/vhost
├── php.ini
├── xdebug.ini
├── scripts/                                     # všechny shell scripty pohromadě
│   ├── up.sh, down-all.sh, restart.sh, build.sh
│   ├── reset-env.sh                             # reset prostředí do stavu prvního spuštění
│   ├── bash-www-data.sh, bash-root.sh
│   ├── php-www-data.sh, xdebug-php-www-data.sh
│   ├── pack-module.sh                           # zazipuje modules/packeta/ → packeta.zip
│   ├── install-module.sh                        # pack + instalace přes Joomla CLI
│   ├── reinstall-module.sh                      # force clean install (DB cleanup + install)
│   ├── configure-joomla-mail.sh                 # SMTP přes Mailpit (patch configuration.php)
│   ├── configure-joomla-debug.sh                # $debug=true + error_reporting=maximum
│   ├── db-snapshot.sh                           # mysqldump → db-snapshots/<name>.sql
│   └── db-restore.sh                            # drop+import z db-snapshots/<name>.sql
├── menu.sh                                      # rozcestník v rootu (ve třetím kole)
├── modules/packeta/                             # naklonovaný modul (gitignored .git)
├── src/                                         # Joomla instalace (gitignored)
├── db/                                          # MariaDB data (gitignored)
├── db-snapshots/                                # uložené dumpy (gitignored)
└── mailpit/                                     # mailpit data (gitignored)
```

## Workflow prvního spuštění

1. `cp .env.example .env` → vyplnit `ENV_UID/GID` (macOS typicky `501:20`)
2. `./scripts/up.sh` (první build potrvá pár minut)
3. Otevřít `http://localhost:8080` — Joomla naběhne automaticky díky env proměnným
4. `http://localhost:8080/administrator` → login `admin` / `adminadmin1234`
   (Joomla image vyžaduje heslo delší než 12 znaků, jinak auto-install spadne.)
5. **Doinstalovat VirtueMart** ručně přes System → Install → Extensions (z [virtuemart.net](https://virtuemart.net/download))
   - Před spuštěním sample data importu zapnout plugin **VM - Shipment - Weight, Countries**
     (Extensions → Plugins, filter `vmshipment`). VM sample importer ho volá, ale defaultně
     je unpublished a v PHP 8 to padá na *"Attempt to assign property name on null"*
     v `helpers/vdispatcher.php:240`.
   - Volba *Reset all Virtuemart tables and do a fresh install with sample data*
     nejdříve je potřeba zapnout ve VM Configuration zapnuto **Enable database Update tools**, jinak nelze volbu provést, VM na to upozorní hláškou.
     (viz poznámka u README v "Druhém kole").
6. `./scripts/db-snapshot.sh clean-joomla-vm` ⇒ baseline dump pro budoucí reset
7. `./scripts/install-module.sh` ⇒ zazipuje `modules/packeta/` a doinstaluje plugin
8. **Po prvním instalu Packety:** odkomentovat v `docker-compose.yml` druhý bind-mount
   (`./modules/packeta` → `plugins/vmshipment/zasilkovna`), `./scripts/restart.sh`
9. PhpStorm path mappings:
   - `./src` → `/var/www/html`
   - `./modules/packeta` → `/var/www/html/plugins/vmshipment/zasilkovna`
   - `./modules/packeta` → `/var/www/packeta-dev`

## Odsouhlasená rozhodnutí

- ✅ VM instalace ručně jednou + baseline dump (ne automatizace teď)
- ✅ Default `JOOMLA_TAG=5`, `PHP_VERSION=8.3`
- ✅ Postup: MVP nejdřív (Dockerfile + compose + .env + up.sh), zbytek druhé kolo

## Odloženo

- PHP 8.4/8.5 (čekáme na oficiální `joomla:` tagy nebo vlastní stack `php:8.4-apache` + ruční Joomla)
- HTTPS / SSL (zatím HTTP na `:8080`)
- Pre-baked SQL dump s VM v Dockerfile
- Automatizace VM instalace přes Joomla CLI

## Otevřené otázky pro pozdější fáze

- ~~Funguje `joomla:5-php8.3-apache` auto-install z env proměnných out-of-the-box,
  nebo si vyžádá setup wizard?~~
  **Funguje** — ale image vyžaduje `JOOMLA_ADMIN_PASSWORD` *delší* než 12 znaků,
  jinak install spadne na error a server servíruje `/installation/index.php`.
- Joomla SMTP konfigurace na `mailpit:1025` — uložit do baseline dumpu
  nebo nastavit ručně v admin UI?
- Joomla 4 + PHP 8.1 kombinace pro backward kompatibilní testy —
  potřebujeme samostatný `db/`-snapshot na každou kombinaci?

## Plán prací

### MVP (toto kolo)

- [x] `PLAN_docker_environment.md`
- [x] `Dockerfile`
- [x] `docker-compose.yml`
- [x] `.env.example`
- [x] `xdebug.ini`
- [x] `php.ini`
- [x] `up.sh`
- [x] `.gitignore`

### Druhé kolo (po ověření, že Joomla naběhne)

- [x] `README.md` — návod ke skriptům, PhpStorm setup, VM workflow caveats
      (vč. precondition *Enable database Update tools* pro reset VM tabulek).
- [x] Helper skripty: `down-all.sh`, `restart.sh`, `build.sh`, `bash-*.sh`, `php-*.sh`, `xdebug-*.sh`
- [x] `reset-env.sh` — reset prostředí do stavu „úplně prvního spuštění"
      (`docker compose down` + smaž runtime state v `src/`, `db/`, `mailpit/`, `packeta.zip`;
      zachová `.env`, `db-snapshots/`, `modules/packeta/`; flag `--with-image` pro rebuild od Dockerfile).
- [x] `pack-module.sh`, `install-module.sh`, `reinstall-module.sh`
- [x] `db-snapshot.sh`, `db-restore.sh`
- [x] Odkomentovat `plugins/vmshipment/zasilkovna` bind-mount v `docker-compose.yml`
- [x] Konfigurace Joomla SMTP na `mailpit:1025` přes `scripts/configure-joomla-mail.sh`
      (patch `configuration.php` přes PHP heredoc v kontejneru, idempotentní).
      Mail config je v souboru, ne v DB — db-snapshot/restore na něj nesahá,
      přepnutí mezi snapshoty configuration.php zachová.
- [x] Joomla debug mode + maximum error reporting — vyřešeno přes
      `scripts/configure-joomla-debug.sh` (PHP heredoc patch `configuration.php`
      v kontejneru, idempotentní, stejný pattern jako `configure-joomla-mail.sh`).
      Defaultní hodnoty po Joomla auto-installu jsou `$debug = false`,
      `$error_reporting = 'default'` — script je flipne na `true` / `'maximum'`.

### Úklid při dokončení projektu

- [ ] **Smazat složku `screens/` a odstranit ji ze `.gitignore`.** Slouží
      jen jako pracovní docasné úložiště pro screenshoty z manual UI
      walkthroughů — když se občas drag&drop nebo cmd+V screenshotu přímo
      do konverzace nedaří, user ho nahraje do `screens/` a Claude ho čte
      odsud. Po dokončení dev prostředí (až nebudou další UI walkthroughy)
      složka pozbývá smyslu, smažeme ji a uklidíme i řádek `/screens/`
      z `.gitignore`.

### Návazné úklidy po vyřešení modulových issues

- [ ] **Po vyřešení FOLLOWUPS #5 (refactor `recurse_copy` v modulu) —
      odstranit live-bind workaround z `docker-compose.yml`.** Až modul
      přepíše instalátor na moderní Joomla manifest deklarace
      (`<files>` / `<media>` / `<languages>` v `zasilkovna.xml`), soubory
      se při instalaci dostanou na správná místa nativně a workaround už
      nebude potřeba. Konkrétně:

      1. V `docker-compose.yml` smazat 2 bind mounty pro `views/zasilkovna`
         a `models/zasilkovna_src` (přidané v PR #6 `live-bind-admin-files`).
      2. Z `README.md` zjednodušit *Hotovo* bullet v Rychlém startu —
         "live je vše v `modules/packeta/`" bez výjimek pro admin paths.
      3. Aktualizovat poznámky u `### scripts/install-module.sh` a
         `### scripts/reinstall-module.sh` — stejně zjednodušit.
      4. Smazat odkaz na tento bod v `FOLLOWUPS.md #5`.

      Spouštěč: nová verze modulu (push do `master` branch
      `Zasilkovna/virtuemart3`) bez `recurse_copy` v `install.zasilkovna.php`.
      Ověřit reinstall workflow v devu, pak commit + PR.

### Drobnosti k opravě

- [x] Duplicitní načítání Xdebug — `docker-php-ext-enable xdebug` (build)
      i `xdebug.ini` (mount) oba registrují extension, takže každé volání
      PHP CLI hlásí `Cannot load Xdebug - it was already loaded`.
      **Vyřešeno** (2026-05-19, větev `fix-xdebug-duplicate-load`): odstraněno
      `zend_extension=xdebug.so` z `xdebug.ini`, registraci dělá výhradně
      `docker-php-ext-xdebug.ini` z `docker-php-ext-enable xdebug` v Dockerfile.
- [x] **Manual VM install workflow (kroky 2–4 akceptačního testu) — popisy
      menu cest v dokumentaci nesedí realitě.** **Vyřešeno** clean-install
      runem (2026-05-19, větev `fix-vm-install-docs`, PR #2): zachyceny
      přesné menu cesty (System → System Dashboard → Install:Extensions
      → Upload Package File), `configure-vm-after-install.sh` přidán
      pro `weight_countries` enable + (později v PR #3) Safe Path setup,
      README sekce *VirtueMart — workflow čisté instalace* přepsána,
      `reset-env.sh` tail aktualizován. Kroky 2–4 v
      `.notes/ACCEPTANCE_TEST.md` flipnuty na ✅.

### Vyřešeno v repu virtuemart-docker

- [x] `install/com_virtuemart.*.zip` (~6 MB VM installer) — **commitnout**.
      Důvod: nový dev má hned čím VM nainstalovat, bez extra manual downloadu.
      V README pokyn aktualizovat zip při novém VM release z virtuemart.net
      (v repu jen jeden zip najednou, ať není nejasnost, který použít).
- [x] `modules/packeta/` — **gitignorovat** (`/modules/` v `.gitignore`).
      Důvod: modul má vlastní upstream repo (Zasilkovna/virtuemart3), submodule
      přidává friction (detached HEAD, .gitmodules údržba). README má v Rychlém
      startu `git clone git@github.com:Zasilkovna/virtuemart3.git modules/packeta`.

### Akceptační test dev prostředí

- [x] **End-to-end validace** — projít celý workflow na čisté mašině / přes
      `./scripts/reset-env.sh --with-image` a zkontrolovat, že:
      1. `./scripts/up.sh` → Joomla naběhne na `:8080`, admin login funguje
      2. Manual VM install přes admin UI dle README
      3. Enable `vmshipment - Weight, Countries` plugin
      4. VM Configuration → *Enable database Update tools* → reset s sample daty
      5. `./scripts/configure-joomla-mail.sh` → test mail z admina dorazí do Mailpitu
      6. `./scripts/configure-joomla-debug.sh` → admin vypisuje stack trace místo generické chyby
      7. `./scripts/db-snapshot.sh clean-joomla-vm` → baseline dump existuje
      8. `./scripts/install-module.sh` → plugin Packeta v `#__extensions`
      9. `./scripts/reinstall-module.sh` → fresh install path, nový `extension_id`
      10. `./scripts/db-restore.sh clean-joomla-vm` → vrácení do baseline funguje
      11. README/PLAN konzistentní s realitou — opravit diskrepance.

      **Vyřešeno** (2026-05-19, větev `e2e-acceptance-test`): všech 11
      kroků projeto, diskrepance Step 5 (mail) opraveny v PR #1, diskrepance
      kroků 2–4 v PR #2 a #3 (viz výše). Detailní log v `.notes/ACCEPTANCE_TEST.md`.

- [ ] **Xdebug + PhpStorm — ověřit, že breakpoints reálně fungují.** README
      sekce *PhpStorm setup* setup popisuje (CLI interpreter přes Docker
      Compose, Server `virtuemart.local` s path mappingy, `start_with_request=trigger`,
      port 9003, browser extension *Xdebug helper*). End-to-end ale nikdy
      neověřeno. Test plán:
      1. **CLI debug** — `./scripts/xdebug-php-www-data.sh cli/joomla.php
         extension:list` s breakpoint nastaveným někde v Joomla CLI route
         (např. `cli/joomla.php`). Očekáváme, že PhpStorm zastaví běh.
      2. **Web debug** — v prohlížeči nainstalovat *Xdebug helper*, zapnout
         *Debug* (přidá cookie `XDEBUG_TRIGGER=1`), v PhpStorm *Start
         Listening for PHP Debug Connections*, breakpoint v `modules/packeta/zasilkovna.php`,
         vyvolat request, který plugin loaduje (např. stránka shippingu v
         eshopu). Očekáváme zastavení s validním path mappingem.
      3. **Path mappingy ověřit** — proměnné v debug okně by měly ukazovat
         na soubory v `modules/packeta/` (host strana mountu), ne na
         `/var/www/html/plugins/vmshipment/zasilkovna/` (kontejner strana).

- [ ] **Verzovaná šablona pro manuální akceptační test + částečná
      automatizace.** Doteď žije akceptační test jako one-off plánovací
      bod tady plus pracovní záznam v `.notes/ACCEPTANCE_TEST.md`
      (gitignored). Po každé změně ve stacku — bump `JOOMLA_TAG`,
      `PHP_VERSION`, nová verze VM zipu v `install/`, větší změna
      Dockerfile — bude potřeba projít test znovu, abychom věděli, že
      kombinace funguje. Plán:

      1. **Šablona** v repu (např. `docs/acceptance-test-template.md`
         nebo `tests/acceptance/README.md`). Strukturou kopíruje současný
         `.notes/ACCEPTANCE_TEST.md` (tabulka 11 kroků, sloupec
         *Findings*, sekce *Diskrepance* a *Follow-upy*), ale je
         verzovaná, takže ji každý dev má v repu a kopíruje si ji do
         pracovního stavu pro daný run (např.
         `docs/acceptance-runs/2026-05-19_j5-php83-vm4.6.4.md`,
         gitignored nebo commitnuté podle týmové dohody — viz otevřená
         otázka).
      2. **Auto-runner** `scripts/acceptance-test.sh` — udělá za
         uživatele, co lze automaticky:
         - reset prostředí (`reset-env.sh`)
         - up + heartbeat (`up.sh` + curl loop na `:8080`)
         - configure-joomla-mail/debug + send-test-mail + verify v
           Mailpitu (HTTP GET na `:8025/api/v1/messages`)
         - install-module + verify DB (extension row)
         - reinstall-module + verify nový extension_id
         - db-snapshot + db-restore round-trip + verify Packeta zmizela
         Manual kroky zůstávají v šabloně, auto-runner u nich jen
         pauzne a počká na potvrzení usera ("hotovo, pokračuj").
      3. **Co zůstává manuální** (a tedy proč šablona pořád existuje):
         - VM zip upload přes admin UI (technicky možné přes Joomla CLI,
           ale řeší [[bootstrap-script]])
         - klik *Install Sample Data* na VM AIO welcome screenu
         - Xdebug + PhpStorm breakpoint test (vyžaduje IDE)
         - vizuální kontrola, že VM admin UI funguje bez Safe Path
           warningů

      Otevřená otázka: archivace pracovních záznamů z runů — committed
      do `docs/acceptance-runs/` (audit trail, růst repa), nebo
      gitignored a žijí jen v lokálním `.notes/` (čisté repo, žádný
      audit)? Spíš první, ale rozhodneme až k tomu dojde.

### Třetí kolo (volitelné)

- [ ] `menu.sh` v rootu — rozcestník / interaktivní menu, deleguje na `scripts/*.sh`.
      Slouží jako jediný entry point z rootu, ať uživatel nemusí pamatovat
      cesty `./scripts/up.sh`, `./scripts/db-snapshot.sh foo` atd.
- [ ] **`scripts/bootstrap.sh` — jednokomandový onboarding (kroky 4–10
      Rychlého startu v README).** Po manuálních krocích 1–3 (klonování
      reposů + `.env` s UID/GID, které vyžadují user rozhodnutí) by tenhle
      skript za jediný příkaz provedl celý zbytek:

      1. `./scripts/up.sh` (build + start)
      2. heartbeat na Joomla `:8080` (čekání, až dojede auto-install)
      3. **VM zip install** — pravděpodobně přes `cli/joomla.php extension:install
         --path install/com_virtuemart*.zip`. Ověřit, že CLI volání má stejný
         efekt jako admin UI upload (vč. registrace AIO `com_virtuemart_aio`).
      4. `./scripts/configure-vm-after-install.sh` (plugin enable + Safe Path)
      5. **Sample data import programaticky** — netriviální, vyžaduje
         najít a zavolat VM importer (typicky v
         `administrator/components/com_virtuemart/install/` nebo přes
         `VirtueMartModelMigrator`). Pokud čistá CLI cesta nepůjde,
         fallback: HTTP request s admin session. Pokud ani to ne,
         tenhle krok zůstává manuální click a bootstrap končí na něm
         (= "udělej step 7 ručně a pusť `bootstrap.sh --resume`").
      6. `./scripts/configure-joomla-mail.sh`
      7. `./scripts/configure-joomla-debug.sh`
      8. `./scripts/send-test-mail.sh` (sanity check)
      9. `./scripts/db-snapshot.sh clean-joomla-vm` (baseline)
      10. `./scripts/install-module.sh`

      Každý sub-krok loguje banner `[X/10] Co se teď děje + očekávaný čas`;
      při chybě stop + návrh, co zkontrolovat. Existující stand-alone
      skripty zůstávají — bootstrap je jen orchestrátor, takže nový dev
      má volbu spustit vše naráz, nebo individuálně (debugging onboardingu).

      Hlavní výzkumný úkol před implementací: ověřit cestu pro sample
      data import. To je single point of friction; zbytek je glue.
- [ ] Profily/kombinace pro J4 + PHP 8.1 testovací běh
- [ ] PHP 8.4/8.5 vrstva
- [ ] SSL/HTTPS pokud bude třeba
