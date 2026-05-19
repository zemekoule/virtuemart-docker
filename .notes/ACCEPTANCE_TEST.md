# Akceptační test dev prostředí

End-to-end validace workflow z `PLAN_docker_environment.md` na **čistém prostředí**
po `./scripts/reset-env.sh --with-image`. Cíl: ověřit, že každý krok podle README
funguje od nuly a že dokumentace odpovídá realitě.

## Setup běhu

- **Datum:** 2026-05-19
- **Větev:** `e2e-acceptance-test`
- **Commit:** `8c775e5` (Enable PHP SOAP extension for Packeta module)
- **Reset:** `./scripts/reset-env.sh --with-image` proveden, image rebuild od nuly,
  src/db/mailpit smazány.

## Kroky

| # | Krok | Status | Findings |
|---|------|--------|----------|
| 1 | `./scripts/up.sh` → Joomla auto-install, admin :8080 odpovídá | ✅ | HTTP 200 na `/administrator` po cca 30 s; žádný redirect na `/installation/`. |
| 2 | Manual VM install přes admin UI (Upload Package File z `install/`) | ✅ | Druhý clean-install run (2026-05-19, větev `fix-vm-install-docs`, PR #2) zachytil přesné cesty: Sidebar *System* → System Dashboard → sekce *Install* → *Extensions* → tab *Upload Package File* → drop zóna. README sekce *VirtueMart — workflow čisté instalace* přepsána. |
| 3 | Enable plugin `vmshipment - Weight, Countries` | ✅ | V druhém clean-install runu sjednoceno se Step 2/4 — místo manuálního Extensions → Plugins enabluje plugin nový `scripts/configure-vm-after-install.sh` (SQL `UPDATE ... element='weight_countries'`, idempotentní). Reálný element je `weight_countries` (ne `weightcountries`), UI label *"VM Shipment - By weight, ZIP and countries"*. |
| 4 | VM Configuration → Enable update tools → reset s sample daty | ✅ | Druhý clean-install run odhalil: pro čistou instalaci je **reset zbytečný** — VM AIO post-install screen má šedý inline odkaz *"Install Sample Data"*, který naimportuje sample data napřímo. Reset workflow (s *Enable database Update tools*) demoted v README na "volitelné / pro re-install scénáře". |
| 5 | `configure-joomla-mail.sh` + test mail do Mailpitu (:8025) | ✅ | Script `configure-joomla-mail.sh` proběhl ("upraveno klíčů: 3" — zbytek měl už správné Joomla defaulty). `configuration.php` má všech 7 očekávaných klíčů správně. Test mail poslán přes Joomla mailer CLI bootstrap (cli/joomla.php pattern + `Factory::getMailer()->Send()` → SENT_OK), Mailpit potvrdil doručení. **Caveat:** v Joomle 5 (a/nebo s VirtueMartem) admin menu **System → Maintenance → Send Test Mail neexistuje** — README sekce `configure-joomla-mail.sh` na něj odkazuje, ale není kam kliknout. |
| 6 | `configure-joomla-debug.sh` → stack trace místo generic error | ✅ | Před: `$debug=false`, `$error_reporting='default'`. Script proběhl, "upraveno klíčů: 2". Po: `$debug=true`, `$error_reporting='maximum'`. Reálné rendrování stack trace neověřováno (potřeboval by se cíleně vyvolat error), ale to už je Joomla responsibility — pro účely tohoto kroku stačí, že config flagy sedí. |
| 7 | `db-snapshot.sh clean-joomla-vm` → baseline dump | ✅ | Dump 738 KB, 8805 řádků. Obsahuje 65 `joom_virtuemart_*` tabulek + `CREATE DATABASE joomla` + `USE joomla` directives (správné chování `--databases`). Override prompt funguje (`y` přes stdin přepsalo původní snapshot). |
| 8 | `install-module.sh` → Packeta plugin v `#__extensions` | ✅ | Plugin v `joom_extensions`: `extension_id=285`, `element=zasilkovna`, `folder=vmshipment`, `enabled=0`, `state=0`. Default `enabled=0` souhlasí s README. Verbose installer output (alter table notes pro `joom_virtuemart_shipment_plg_zasilkovna` — to je legit, install.sql obsahuje CREATE TABLE + následné ALTERy v rámci jednoho skriptu). |
| 9 | `reinstall-module.sh` → nový extension_id (install path) | ✅ | Před: `extension_id=285`. Po: `extension_id=286`. Jiné ID = extension row smazán a vytvořen nový → potvrzeno, že nejde o update path, ale o fresh install. |
| 10 | `db-restore.sh clean-joomla-vm` → Packeta zmizela z extensions | ✅ | Restore proběhl bez chyb (drop + import). Po: `SELECT COUNT(*) FROM joom_extensions WHERE element='zasilkovna'` = 0 → baseline obnoven, Packeta zmizela. |
| 11 | README/PLAN konzistentní s realitou — opravit diskrepance | ✅ | **Step 5 fix** (PR #1, větev `e2e-acceptance-test`): `send-test-mail.sh` + odstraněna fiktivní *System → Maintenance → Send Test Mail* zmínka. **Kroky 2–4 fix** (PR #2, větev `fix-vm-install-docs`): druhý clean-install run, README sekce *VirtueMart — workflow caveats* přepsána, nový `scripts/configure-vm-after-install.sh`, `reset-env.sh` tail aktualizován. |

**Legenda:** ✅ prošlo | ✗ selhalo | ⚠ částečně / s caveatem | ⏳ pending

## Diskrepance dokumentace ↔ realita

_Tady zapisujeme cokoli, co nesedí mezi README/PLAN a tím, co jsme reálně viděli.
Step 11 to pak zpracuje do oprav v dokumentech._

- **Kroky 2–4 (manual VM install)** — popisy menu cest a názvy položek v
  `README.md` ("VirtueMart — workflow caveats") i ve výpisu `reset-env.sh`
  na konci neodpovídají reálnému UI VirtueMartu, který user viděl při tomto runu.
  Bylo také nutné provést další nastavení nad rámec toho, co dokumentace popisuje.
  Konkrétní seznam vyžaduje další clean-install run, ve kterém si reálné kroky
  zapíšeme přesně (screenshot / přesné labely menu).
- **README, sekce `configure-joomla-mail.sh`** — slibuje cestu *System →
  Maintenance → Send Test Mail* pro ruční ověření. V Joomle 5 tato položka
  ale v admin menu neexistuje. Test mail se v tomto runu poslal PHP one-shotem
  přes `Factory::getMailer()->Send()` (proper CLI bootstrap modelovaný podle
  `cli/joomla.php`). Návrh: vyhodit zmínku o admin UI, místo toho dokumentovat
  CLI cestu (případně přidat `scripts/send-test-mail.sh` jako helper, aby si
  to nemusel každý psát ručně).

## Follow-upy z testu

_TODO, které vznikne během testu a které není critical fix pro tento run — typicky
"tohle by mohlo být ergonomičtější" / "tady by se hodil sanity check"._

- _(zatím nic)_
