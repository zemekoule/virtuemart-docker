# Follow-ups z nasazení dev prostředí

Drobnosti, které se vynořily během stavby Docker dev prostředí
(`PLAN_docker_environment.md`), ale nejsou součástí samotného prostředí — týkají se
modulu nebo ekosystému kolem. Sem si je odkládáme, ať nezapadnou.

---

## 1. PHP 8.1+ deprecation v `modules/packeta/install.zasilkovna.php:632`

Při CLI instalaci modulu (`./install-module.sh`) Joomla vypsala:

```
PHP Deprecated:  Automatic conversion of false to array is deprecated
in install.zasilkovna.php on line 632
```

### Kontext

```php
// modules/packeta/install.zasilkovna.php:626-636
private function createCronToken() {
    /** @var \VirtueMartModelZasilkovna $model */
    $model = VmModel::getModel('zasilkovna');
    $config = $model->loadConfig();       // při fresh installu vrací false (ne [])

    if (!isset($config['cron_token'])) {
        $config['cron_token'] = substr(sha1(rand()), 0, 16);  // ← :632, $config je false
    }

    $model->updateConfig($config);
}
```

Při čistém installu (žádný `cron_token` v DB) vrací `loadConfig()` `false`.
Větev `if (!isset(...))` projde, a PHP musí na `false` udělat implicitní konverzi
na pole pro indexové přiřazení — v PHP 8.1 deprecation, v PHP 9 fatal.

### Proč to řešit

Projekt cílí kompatibilitu **PHP 8.1 – 8.5** (CLAUDE.md). V PHP 9 to bude fatal,
takže by se to mělo opravit dřív, než PHP 9 přijde do běžných hostingových stacků.

### Možné cesty fixu

1. **Normalizovat `$config` lokálně** — minimální zásah:
   ```php
   $config = $model->loadConfig();
   if (!is_array($config)) {
       $config = [];
   }
   ```
2. **Opravit `loadConfig()` v modelu** — ať vždy vrací pole (i prázdné).
   Cleaner, ale je potřeba zkontrolovat všechna volání `loadConfig()`,
   jestli někde nespoléhají na `false` jako signál „neexistuje".

### Status

Není opraveno, jen poznamenané. Plánovat samostatný PR proti modulu.

---

## 2. ~~Zapnout automatické mazání feature větví po mergi (GitHub)~~ ✅ HOTOVO

**Vyřešeno 2026-05-19** — *Settings → General → Pull Requests → "Automatically
delete head branches"* zapnuto user-em. Origin větve se po mergi mažou samy,
cleanup workflow stačí lokální `git branch -d` + `git fetch --prune`. Záznam
jako project memory (`project_github_auto_delete_branches.md`).

---

## 3. Hardcoded DB credentials ve scriptech + diskuse o přímém DB zápisu

Konfigurace skriptů, které sahají do DB, je dnes ve dvou ohledech fragile.

### Kde to je

`grep` napříč repem (2026-05-19):

| Soubor | Co |
|---|---|
| `scripts/reinstall-module.sh:43` | `mariadb -uroot -pasdf joomla <<SQL` |
| `scripts/db-snapshot.sh:38` | `-uroot -pasdf` (mysqldump) |
| `scripts/db-restore.sh:40,43` | `mariadb -uroot -pasdf` (drop + import) |
| `scripts/configure-vm-after-install.sh:36` | `mariadb -uroot -pasdf joomla` (bash SQL) |
| `scripts/configure-vm-after-install.sh:69-70` | `new PDO('...', 'root', 'asdf', ...)` (PHP) |
| `docker-compose.yml:22` | `JOOMLA_DB_PASSWORD: asdf` |
| `docker-compose.yml:59` | `MARIADB_ROOT_PASSWORD: asdf` |

V `.env.example` **žádné DB-related proměnné** nejsou — heslo `asdf` je
doslovný literál rozházený napříč repem.

### Vrstva 1 (architektonická) — přímý DB zápis vs. VM API

Skripty `configure-vm-after-install.sh` (forSale_path) a v menší míře
`reinstall-module.sh` (DELETE FROM #__extensions + DROP TABLE) sahají
přímo do DB. Otázka pro diskusi: existuje **čistší cesta**, jak takové
změny prosadit přes VM/Joomla API místo SQL? Možnosti k prozkoumání:

- **Joomla CLI** — `cli/joomla.php` má `extension:install`, `extension:remove`
  a další; možná existuje něco jako `config:set` nebo přidatelné přes plugin.
- **VM-specific CLI** — VirtueMart může mít vlastní CLI příkazy
  (kontrola: `cli/joomla.php list` filtruje vmshipment/component apod.).
- **VM PHP API** — `VirtueMartModelConfig::storeConfig()` nebo podobné
  (zachoval by VM-side validace, hooks, cache invalidaci).
- **Joomla Factory + Component params API** — pro joom_extensions.params
  fields.

Přínos: scripts by přežily upgrade VM, který změní DB schema nebo escape
formát config sloupce. Náklad: bootstrap VM frameworku v každém scriptu
(podobně jako `send-test-mail.sh`).

### Vrstva 2 (config) — credentials z `.env`

Bez ohledu na to, jestli vyřešíme vrstvu 1, hardcoded `root`/`asdf` má jít
pryč. Plán:

1. Přidat do `.env.example` defaulty: `DB_ROOT_USER=root`,
   `DB_ROOT_PASSWORD=asdf`, `DB_NAME=joomla`, `DB_HOST=dev_db`.
2. V `docker-compose.yml` přepsat literály na `${VAR:-default}`.
3. Scripts: dvě možnosti:
   - **a)** sourcovat `.env` na začátku (`set -a; source .env; set +a`)
     a používat `"$DB_ROOT_PASSWORD"` atd. Jednoduché, ale duplikuje env
     parsing ve všech scriptech.
   - **b)** číst přes `docker compose exec mysql sh -c 'echo $MARIADB_ROOT_PASSWORD'`
     — single source of truth (compose já hodnoty má). Lehce ošklivé.
   - **c)** pro PHP PDO uvnitř kontejneru: číst přímo z Joomla
     `configuration.php` (`$user`, `$password`, `$db`, `$host`) přes
     parsing nebo `include`. Joomla má ty hodnoty kanonicky.

Pro PHP PDO mě láká **c)** — žádná duplikace, žádné env propagation, prostě
to read what Joomla itself uses. Pro bash scripts spíš **a)** nebo **b)**.

### Status

Není urgentní (heslo `asdf` neopouští localhost), ale je to dluh. Otevřená
diskuse, řešení v samostatném PR — nejlépe po stabilizaci celého dev
prostředí, aby refactor scripts byl izolovaný od dalších feature změn.

---

## 4. Refactor `install.zasilkovna.php` — vyhodit `recurse_copy`

Při auditu souboru (2026-05-19, větev `live-bind-admin-files`) zjištěno, že
`postflight()` a `update()` oba volají legacy `recurse_copy` funkci
definovanou na začátku souboru. Ta kopíruje **50 PHP souborů** z
`media/admin/com_virtuemart/` do VM admin tree
(`<webroot>/administrator/components/com_virtuemart/...`) plus **3 lang
ini soubory** do `administrator/language/<locale>/`. Pro dev prostředí to
znamená, že většina admin-side kódu modulu **není live** přes bind mount
— edit zdroje vyžaduje reinstall.

### Krátkodobé řešení (už hotové v `virtuemart-docker`)

PR #6 (`live-bind-admin-files`): přidány 2 bind mounty do `docker-compose.yml`
pro exkluzivní podadresáře (`views/zasilkovna/`, `models/zasilkovna_src/`),
které pokrývají ~18 z 50 souborů. Zbytek (controllers, jednotlivé models,
fields, lang ini, frontend media assets) pořád vyžaduje
`reinstall-module.sh` — bind mount jednotlivých souborů nefunguje na
macOS Docker Desktop (virtiofs neumí vytvořit file mountpoint, když
cílový soubor ještě neexistuje).

### Správné řešení (modul, samostatný PR)

Přepsat instalátor na moderní Joomla install konvence — místo
`recurse_copy` deklarovat soubory přes elementy `<files>`, `<media>`,
`<languages>` v `zasilkovna.xml` manifestu (případně `<scriptfile>` pro
custom post-install logiku, pokud něco zbude). Joomla sám rozkopíruje na
správná místa. Tím odpadne:

- potřeba `recurse_copy` funkce v `install.zasilkovna.php`
- bind mount workaround v `docker-compose.yml` (po refactoru se může
  zredukovat zpět na jeden plugin mount)
- problém s tím, že frontend media assets v `media/media/**` nejsou live
- problém s tím, že individuální admin soubory (controllers, fields, …)
  nejsou live

Samostatný PR proti modulovému repu ([Zasilkovna/virtuemart3](https://github.com/Zasilkovna/virtuemart3)),
scope mimo `virtuemart-docker`. Vyžaduje regresní test, protože manifest
deklarace má jiné defaulty než `recurse_copy` (např. co se děje při
uninstallu, jak Joomla mažou stará verze při update).

### Status

Není opraveno. Krátkodobý workaround hotový, dlouhodobý fix čeká na
samostatný PR proti modulovému repu.

### Před začátkem next session (rozhodovací body)

Než začnu kódovat na tomhle refactoru, rozhodnout s userem:

1. **Push přístup do upstream repa.** `Zasilkovna/virtuemart3` — mám
   tam push přístup, nebo musíme forknout pod `zemekoule/virtuemart3`?
   Zjistit: `cd modules/packeta && git remote -v` (vidíme URL) +
   `gh repo view Zasilkovna/virtuemart3 --json viewerPermission` (vidíme
   user role). Pokud `WRITE`/`ADMIN`, jdeme přímo. Pokud `READ`/null,
   forkujeme.
2. **Scope refactoru** — tři možnosti:
   - **Minimální:** jen `recurse_copy` → `<files>` / `<media>` /
     `<languages>` deklarace. Malý diff, nízké riziko, brzy mergovatelné.
   - **Střední:** + FOLLOWUPS #1 (PHP 8.1 deprecation v `createCronToken`,
     `false → array` cast). Stejný soubor, dva související bugy.
   - **Velký:** kompletní cleanup `install.zasilkovna.php` (moderní Joomla
     API, vyhodit deprecated calls, refactor migračních funkcí).
     Větší scope, složitější review.

   Doporučení: **střední** — `recurse_copy` refactor stejně zasahuje do
   `postflight()` a `update()`, kde mu rovnou opravit i `createCronToken`
   bude levné.

3. **Branch + workflow.** Pracujeme v `modules/packeta/` (nested git repo,
   ne `virtuemart-docker`). Feature větev odvodit od `master` modulu, ne
   od main našeho dev prostředí. PR proti `Zasilkovna/virtuemart3` master.

### Po dokončení refactoru — návazné kroky v `virtuemart-docker`

Až bude refactor v modulu mergnut, vrátit se sem a:

1. Update `modules/packeta` k nové verzi (git pull v nested repu).
2. Provést úklid z PLAN sekce *Návazné úklidy po vyřešení modulových issues*
   (odstranit bind mount workaround z `docker-compose.yml`, zjednodušit
   README, smazat odkazy).
3. Projet znovu oba akceptační testy (`.notes/ACCEPTANCE_TEST.md` +
   `.notes/ACCEPTANCE_TEST_PHPSTORM.md`), aktualizovat logy.
4. Odstranit odkaz na #4 v `PLAN_docker_environment.md`.

---

## 5. Vygenerovat technickou dokumentaci modulu a odkázat na ni z `CLAUDE.md`

Při draftování ticketů (např. PES-3149 – consign password) musí Claude
pokaždé objevovat strukturu modulu znovu od nuly: kde leží šablony, jak se
volá `order_extended_detail.php` (hook `plgVmOnShowOrderBEShipment`), kde
je DB schéma (`install.sql` + `install.zasilkovna.php::upgradeSchema()`),
jak vypadá storno (`cancelOrderSubmitToZasilkovna()`), jaké SOAP volání
se dnes používají atd. Každé sezení = stejné `git grep` / `git show`.

### Co s tím

Připravit jednorázově **technickou dokumentaci modulu** uloženou v repu
(např. `modules/packeta/docs/architecture.md` nebo přímo
`.notes/MODULE_ARCHITECTURE.md` v tomto repu) a odkázat na ni z
`CLAUDE.md`, aby ji Claude měl vždy v kontextu.

### Co by tam mělo být (minimum)

1. **Mapa souborů** — kde leží:
   - `zasilkovna.php` (kořenový plugin, hooky `plgVmOn…`)
   - `install.sql`, `install.zasilkovna.php` (instalace, migrace, schema)
   - `media/admin/com_virtuemart/controllers/zasilkovna.php` (controller)
   - `media/admin/com_virtuemart/models/zasilkovna.php`,
     `zasilkovna_orders.php` (modely, SOAP volání)
   - `media/admin/com_virtuemart/models/zasilkovna_src/VirtueMartModelZasilkovna/…`
     (PSR-4 source — `Order\Detail`, `Order\Repository`, `Box\Renderer`, `Label\Format`, …)
   - `media/admin/com_virtuemart/views/zasilkovna/tmpl/` (šablony — `default.php`,
     `default_config.php`, `default_export.php`, `order_extended_detail.php`,
     `order_detail_form.php`, …)
   - `language/*` a `media/admin/*.ini` (překlady cs-CZ / en-GB / sk-SK)
2. **DB schema** — tabulky `#__virtuemart_shipment_plg_zasilkovna`
   a `#__virtuemart_zasilkovna_carriers`, popis sloupců, kdo je plní.
3. **Hooky do VirtueMart** — které `plgVmOn…` metody plugin implementuje
   a co každá z nich dělá (`plgVmOnShowOrderBEShipment`,
   `plgVmDisplayListFE…` atd.).
4. **Tok dat** — od checkoutu (výběr výdejního místa) přes uložení do
   `#__virtuemart_shipment_plg_zasilkovna`, hromadné/jednotlivé podání
   přes SOAP `createPacket()`, tisk štítku, storno.
5. **SOAP API volání** — která se dnes používají (`createPacket`,
   `packetsLabelsPdf`, `packetCourierNumberV2`, `packetsCourierLabelsPdf`),
   kde jsou v kódu, jaký WSDL endpoint.
6. **Konfigurace modulu** — boxy v `default_config.php` (Settings,
   COD, Autosubmission, …) a jak se hodnoty čtou (`$model->getConfig(...)`).
7. **Branch model** — `master` (stable), `v1.5.0` (next release),
   konvence pojmenování feature větví, GitHub auto-delete branches
   (viz [[project-github-auto-delete-branches]]).

Stačí stručně, formou checklist / odkazů na konkrétní soubory a třídy.
Cíl: aby Claude na začátku sezení o modulu věděl, kde co je, bez
opětovného grep/show kola.

### Otázky k vyřešení před začátkem

1. **Kam dokumentaci umístit:**
   - `modules/packeta/docs/architecture.md` (v nested repu modulu, půjde
     i do upstreamu Zasilkovna/virtuemart3 — užitečné pro každého
     vývojáře pluginu, ne jen pro Claude)
   - `.notes/MODULE_ARCHITECTURE.md` (jen tento dev-env repo, snazší
     iterace bez PR do upstreamu)
   - obojí (master copy v modulu, lokální zkrácený link v `.notes/`)
2. **Kdo dokumentaci napíše:** může ji rozjet Claude (projde modul,
   vypíše strukturu), uživatel pak udělá CR / doplní byznysový kontext.
3. **Jak často aktualizovat:** ideálně lehký update při každém větším PR
   (přidání hooku, nové tabulky, nového SOAP volání). Případně občasný
   "audit" dokumentace v samostatném ticketu.

### Acceptance pro tento followup

- Dokumentace existuje na jednom dohodnutém místě.
- `CLAUDE.md` (projekt) ji odkazuje, ideálně v nové sekci "Architektura
  modulu" / "Kde co je" – aby Claude měl odkaz hned na začátku každého
  sezení.
- Pokrývá body 1–7 z výčtu výše (klidně stručně).
