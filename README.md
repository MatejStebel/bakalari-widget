# Bakaláři widget

Jednoduchý widget pro **KDE Plasma 6**, který zobrazuje rozvrh ze systému
Bakaláři přímo na ploše.

## Instalace
Nejjednodušší instalace přímo z GitHubu:

```bash
curl -fsSL https://raw.githubusercontent.com/kralicekgamer/bakalari-widget/main/install.sh | bash
```

Nebo z naklonovaného repozitáře:

```bash
git clone https://github.com/kralicekgamer/bakalari-widget.git
cd bakalari-widget
./install.sh
```

Instalátor widget zkopíruje do uživatelského Plasma adresáře a restartuje
Plasma Shell. Není potřeba `sudo`.

## Odinstalace

Z klonovaného repozitáře spusť:

```bash
./uninstall.sh
```

Odinstalace odstraní pouze widget. Heslo v KWallet a Plasma nastavení zůstanou
zachované.

## Motivy
- Motivy jsou kompatibilní s aplikací lepší rozvrh
- Lze je najít např na webu https://themes.kralyk.dev

## Vývoj a testy

Vývojové nástroje jsou v adresáři `tools/` a nejsou potřeba pro běžné použití.

```bash
python3 -m unittest discover -s tools -p 'test_*.py' -v
```

Ruční kontrolu Bakaláři API lze spustit pomocí:

```bash
python3 tools/api_smoke.py
```