# `.notes/` — verzované týmové poznámky k dev prostředí

Tato složka je **commitnutá v repu** a obsahuje:

- **`PLAN_docker_environment.md`** — vývojový plán s odsouhlasenými
  rozhodnutími, otevřenými otázkami a TODO ke třem kolům prací
  na dev prostředí.
- **`FOLLOWUPS.md`** — známé technické dluhy a follow-upy, které jsme
  záměrně odložili (s odůvodněním a plánem řešení).
- **`ACCEPTANCE_TEST.md`** — pracovní log akceptačního testu
  (11 kroků end-to-end, sloupec *Findings*, diskrepance dokumentace
  ↔ reality, follow-upy z testu).

Cíl: nový developer otevře tuhle složku a hned vidí, **co se dělalo,
proč, co je hotovo a co zbývá**. Hlavní `README.md` v rootu je referenční,
sem patří kontext a rozhodnutí.

## Co sem nepatří

- **Osobní poznámky** (zápisky, scratchpad, věci na úkor mě osobně) —
  patří do `private-notes.md` v rootu (gitignored).
- **Runtime config** (`.env`, `php.ini`, `xdebug.ini`, …) — ty mají
  vlastní místo v rootu.
- **Skripty** — `scripts/`.
- **Code** — `modules/packeta/` pro modul, `src/` pro Joomla runtime.

## Historie

Až do `warn-against-changing-db-creds` PR byla tahle složka v `.gitignore`
(jen `README.md` byl tracked) — sloužila jako developer scratchpad. Po
realizaci, že obsah má dlouhodobou hodnotu a hrozí ztráta, jsme ji
graduovali na committed. Osobní item (Bear KB plán) přesunut do
gitignored `private-notes.md`.
