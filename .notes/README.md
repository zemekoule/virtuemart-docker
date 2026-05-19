# `.notes/` — lokální poznámky vývojáře

Tato složka je určená pro **lokální, neverzované poznámky** vývojářů pracujících
na tomto dev prostředí. Typicky:

- vlastní plán prací (např. `PLAN_docker_environment.md`)
- seznam follow-upů a TODO, které ses rozhodl(a) odložit (`FOLLOWUPS.md`)
- ad-hoc poznámky, dump terminalu, výpisy z debugu, návrhy, scratchpad

Obsah `.notes/` je v `.gitignore` (kromě tohoto `README.md`), takže každý vývojář
si tu může držet to své, aniž by to vstupovalo do PR.

## Co sem nepatří

- věci, které by měl vidět i kolega — ty patří do `README.md` v rootu
- konfigurace, kterou potřebuje runtime (`.env`, `php.ini`, `xdebug.ini`, …)
- skripty (`scripts/`)
