# Akceptační test PhpStorm + Xdebug

Sub-test akceptačního testu dev prostředí podle `PLAN_docker_environment.md`
sekce *Akceptační test dev prostředí*. Cíl: ověřit, že breakpointy reálně
fungují pro CLI i web debug a že path mappingy směřují na host zdroje
(ne na container kopie).

## Setup běhu

- **Datum:** 2026-05-20
- **PhpStorm verze:** 2026.1 (z UI)
- **Větev:** `main` (commit `14c8020` — head)
- **Xdebug helper:** Chrome extension (default settings)
- **Stack:** `joomla` + `mysql` + `mailpit` + `adminer` běžící, modul Packeta
  nainstalovaný + sample data v DB

## Setup PhpStormu (5 sub-kroků z README)

| Krok | Stav | Findings |
|---|---|---|
| 1. Otevřít projekt | ✅ | Bez problémů. |
| 2. CLI interpreter přes Docker Compose | ⚠ | **Diskrepance #1:** Docker binary na macOS Apple Silicon Docker Desktopu žije v `~/.docker/bin/docker`, ale PhpStorm hledá `/usr/local/bin/docker`. Bez symlinku selhává parsing docker-compose.yml: *"Cannot run program /usr/local/bin/docker"*. Fix: `sudo ln -s ~/.docker/bin/docker /usr/local/bin/docker` (+ stejně pro `docker-compose` legacy binary). Po symlinku detekce PHP 8.3.31 + Xdebug 3.5.1 + Composer OK. |
| 3. Server pro web debug | ⚠ | **Diskrepance #2:** README slibuje 3 path mappingy, ale 3. (`modules/packeta` → `/var/www/packeta-dev`) je redundantní — PhpStorm Server config neumožňuje stejnou lokální cestu mapovat dvakrát, a přes `/var/www/packeta-dev` nikdy nedebuguje žádný PHP runtime. 2 mappingy stačí. Také jsme při setupu udělali překlep "port 80" místo "8080" — pozor v README, aby byl 8080 jasně zvýrazněn. |
| 4. Xdebug listener | ⚠ | **Diskrepance #3:** README říká "klikni na telefonní ikonu v toolbaru". V PhpStormu 2024+ telefonní ikona v default toolbaru chybí. Aktivace přes **Run menu → Start Listening for PHP Debug Connections** nebo Find Action (`Cmd+Shift+A` → "Start Listening"). |
| 5. Joomla / VirtueMart sources jako external library | — | Nepotřebovali jsme pro test breakpointů, neověřeno. Volitelný UX setup. |

## Testy z PLANu (3 sub-testy + bonus admin)

| Test | Stav | Findings |
|---|---|---|
| **CLI debug** — breakpoint v `cli/joomla.php` po bootstrap, spuštěno `./scripts/xdebug-php-www-data.sh cli/joomla.php extension:list` | ✅ | Zastavilo se na `$container = \Joomla\CMS\Factory::getContainer();`. Stack, variables, console v debug okně OK. |
| **Web debug** — breakpoint na konstruktoru v `modules/packeta/zasilkovna.php`, frontend `http://localhost:8080/` s aktivním Xdebug helperem | ✅ | Hitl konstruktor hned po pageload (Joomla loaduje vmshipment pluginy při dispatch frontend události). Stack ukázal volání z Joomla event mechanismu. |
| **Path mappingy ověřit** — debug okno ukazuje host cesty, ne container | ✅ | V obou testech editor/Frames panel ukazoval `…/modules/packeta/zasilkovna.php` a `…/src/cli/joomla.php` (host strana), ne container `/var/www/...` |
| **Bonus — admin debug** (mimo původní PLAN, surfovalo se během testu) | ⚠ | Breakpoint v `modules/packeta/zasilkovna.php` (plugin třída) v admin module config stránce **nezafrkl** — důvod 1: config page renderuje jen XML manifest, neinstantizuje plugin třídu (Joomla architektura). Důvod 2: custom field types deklarované v manifestu (`vmzasilkovnacarriers`, `vmzasilkovnashowvendors`, `vmzasilkovnashowcarriers`, `vmzasilkovnacountries`) **jsou** instantizovány, ale jejich soubory nejsou bind-mountnuté přes PR #6 (jen `views/zasilkovna/` a `models/zasilkovna_src/`). Workaround: nastavit breakpoint na kopii v `src/administrator/components/com_virtuemart/fields/vmzasilkovna*.php`. Edit pro reálné změny ale dál vyžaduje úpravu zdroje + `reinstall-module.sh`. |

**Legenda:** ✅ prošlo | ✗ selhalo | ⚠ částečně / s caveatem | — netestováno

## Diskrepance dokumentace ↔ realita

Tři README fixy potřeba (sekce *PhpStorm setup* v README):

1. **Step 2 (CLI interpreter)** — chybí troubleshooting poznámka pro macOS Apple
   Silicon: pokud `which docker` vrací `~/.docker/bin/docker`, vytvořit symlink
   `sudo ln -s ~/.docker/bin/docker /usr/local/bin/docker` (+ docker-compose).
2. **Step 3 (Server pro web debug)** — odstranit třetí mapping
   (`modules/packeta` → `/var/www/packeta-dev`). Přidat větu "stejnou
   lokální cestu nelze mapovat dvakrát; pro debug stačí dva mappingy".
   Zvýraznit port 8080 (ne 80 — Apache uvnitř kontejneru poslouchá na 80,
   ale ven přes docker-compose mapuje na 8080).
3. **Step 4 (Xdebug listener)** — přepsat "klikni na telefonní ikonu" na
   "**Run → Start Listening for PHP Debug Connections**" (nebo Find
   Action `Cmd+Shift+A` → "Start Listening"). Telefonní ikona z default
   toolbaru v PhpStormu 2024+ zmizela.

## Follow-upy z testu

1. **Admin debug nesedí s edit workflow** (bonus zjištění). Pro debugging
   custom fields a controllers (= soubory rozkopírované přes `recurse_copy`,
   nepokryté PR #6 bind mounty) je třeba nastavit breakpoint na kopii
   v `src/administrator/components/com_virtuemart/...` a edit dělat na
   zdroji v `modules/packeta/media/admin/com_virtuemart/...` + reinstall.
   To je nepřirozené.
   **Fix:** FOLLOWUPS #4 (refactor `recurse_copy` v modulu na moderní
   Joomla manifest deklarace). Po něm files půjdou rovnou na finální
   cesty a docker-compose může bind-mountovat zdroj přímo tam → debug
   i edit na jednom souboru. To je hlavní motivace pro FOLLOWUPS #4
   z dev experience pohledu.
2. **Step 5 setupu (external library)** netestovaný — nepotřebovali jsme.
   Až někdo bude reálně chtít Ctrl+klik do Joomla / VM core přes editor,
   pak ověří, jestli setup funguje.

## Status

✅ PhpStorm + Xdebug funguje pro CLI debug + web debug (= primary use cases).
⚠ Admin debug má workflow rough edge (debug-on-copy, edit-on-source) blokovaný
FOLLOWUPS #4. Tři README diskrepance připravené k fixu (samostatný PR
nebo součást FOLLOWUPS #4 PR).
