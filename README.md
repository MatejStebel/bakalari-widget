# Bakaláři Schedule for KDE Plasma 6

A KDE Plasma 6 widget that displays a weekly timetable from the Czech **Bakaláři** school system directly on your desktop.

The widget connects to the Bakaláři API, downloads the current timetable, and displays it in a compact weekly view.

## Features

- Weekly Bakaláři timetable directly on the Plasma desktop
- Direct login through the Bakaláři API
- Password stored securely in **KWallet**
- Automatic timetable refresh
- Manual refresh button
- Configurable refresh interval
- Multiple independent widget instances
- Automatic teacher abbreviations
- Custom teacher abbreviation overrides
- Classroom abbreviations from Bakaláři
- Dynamically hides unused lesson columns
- Dynamically hides unused days
- Whole-day events such as holidays
- Changed lessons highlighted
- Cancelled/removed lessons highlighted
- Change descriptions displayed when available
- Current school hour highlighted
- Current day highlighted
- Scrollable layout for small widget sizes

## Requirements

- KDE Plasma 6
- Qt 6
- KDE Frameworks 6
- KWallet
- C++ compiler
- CMake

The widget contains a small compiled QML plugin used for secure KWallet access, so it must currently be built before installation.

## Tested environment

Development has primarily been tested on:

- Fedora Linux 44
- KDE Plasma Desktop Edition
- KDE Plasma 6

## First install
- For the first install you can just use
```bash
git clone https://github.com/MatejStebel/plasma-widgets.git
cd plasma-widgets/bakalari-widget
./install.sh
```

## Building on Fedora Linux

Install the required development packages:

```bash
sudo dnf install \
    cmake \
    gcc-c++ \
    kf6-kwallet-devel \
    qt6-qtdeclarative-devel
```

Clone the repository:

```bash
git clone https://github.com/MatejStebel/plasma-widgets.git
cd plasma-widgets/bakalari-widget
```

Configure the project:

```bash
cmake \
    -S . \
    -B build \
    -DCMAKE_BUILD_TYPE=Release
```

Build:

```bash
cmake --build build
```

Install into the current user's Plasma installation:

```bash
cmake --install build \
    --prefix "$HOME/.local"
```

Restart Plasma:

```bash
systemctl --user restart plasma-plasmashell.service
```

The widget should then appear in Plasma's **Add Widgets** dialog.

## Updating

Pull the newest source:

```bash
git pull
```

Then rebuild and reinstall:

```bash
cmake \
    -S . \
    -B build \
    -DCMAKE_BUILD_TYPE=Release

cmake --build build

cmake --install build \
    --prefix "$HOME/.local"

systemctl --user restart plasma-plasmashell.service
```

For development, the repository also contains:

```bash
./update.sh
```

which performs the build, installation, and Plasma restart automatically.

## Configuration

Right-click the widget and open its settings.

### General

Configure:

- **Bakaláři server URL**
- **Username**
- **Refresh interval**

Example server URL:

```text
https://school.bakalari.cz
```

Do not include `/api/login` or another API path.

### Password

The password is entered directly through the widget.

After a successful login, it is stored securely in **KWallet**.

The password is not stored in:

- Plasma configuration
- the repository
- timetable files
- JavaScript files

After Plasma restarts, the widget can retrieve the password from KWallet and log in automatically.

The General settings page also provides:

**Forget password and log out**

This removes the saved password from KWallet and clears the current login session.

## Teacher abbreviations

The widget automatically creates short teacher names based on the teacher's surname.

Default behavior:

- surname with 5 characters or fewer → full surname
- longer surname → first 4 characters

Examples:

```text
Novák   → Novák
Smith   → Smith
Novotný → Novo
Dvořák  → Dvoř
```

Titles such as:

```text
Mgr.
Ing.
RNDr.
Ph.D.
MBA
```

are ignored when detecting the surname.

Teacher abbreviations can be changed in:

**Widget Settings → Teachers**

Teacher IDs are used internally, but the settings page displays full teacher names so users do not need to know those IDs.

Overrides are stored separately for each widget instance.

## Timetable behavior

### Hours

The internal Bakaláři hour ID is used to connect timetable entries.

Unused lesson columns are automatically hidden.

### Days

Days keep their real `DayOfWeek` value.

If a day contains nothing that needs to be displayed, it can be removed without shifting the labels of later days.

### Whole-day events

Whole-day events such as holidays are displayed as one event spanning the timetable.

They do not increase the number of visible lesson columns.

The width is based on the longest actual school day during that week.

### Changed lessons

Changed lessons are visually distinguished from normal lessons.

Examples include:

- substitution
- changed classroom
- added lesson

### Cancelled lessons

Cancelled and removed lessons are displayed separately rather than disappearing from the timetable.

### Current time

The widget highlights:

- the current school-hour header
- today's day-name cell

Only the header/day label is highlighted; the entire timetable row or column is not.

## Multiple accounts

Multiple instances of the widget can be added to Plasma.

Each instance has its own configuration, which makes it possible to use different Bakaláři accounts, for example for multiple students in one household.

## Project structure

```text
bakalari-widget/
├── CMakeLists.txt
├── package/
│   ├── metadata.json
│   └── contents/
│       ├── code/
│       │   └── timetableParser.js
│       ├── config/
│       │   ├── config.qml
│       │   └── main.xml
│       └── ui/
│           ├── main.qml
│           ├── configGeneral.qml
│           ├── configTeachers.qml
│           └── BakalariWallet/
│               └── qmldir
├── wallet/
│   ├── qmldir
│   ├── walletbackend.cpp
│   ├── walletbackend.h
│   └── walletplugin.cpp
├── tools/
│   ├── parse_timetable.py
│   └── test_api.py
└── update.sh
```

The Python tools are primarily development/debugging utilities. The installed widget fetches and parses the timetable itself.

## Privacy

The widget communicates directly with the configured Bakaláři server.

Sensitive or user-specific files should never be committed to Git, including:

```text
timetable.json
parsed_timetable.json
parsed_timetable.js
teacher_config.json
credentials.json
*.token
```

The Bakaláři password is stored using KWallet.

## Development

After editing QML, JavaScript, or C++ code:

```bash
./update.sh
```

The development script rebuilds the KWallet plugin, installs the widget into the user's Plasma directory, and restarts Plasma Shell.

Useful Plasma logs can be viewed with:

```bash
journalctl --user -f | grep plasmashell
```

or:

```bash
journalctl --user -b \
    | grep -iE 'bakalari|main.qml|qml'
```

## Uninstall

Remove the installed plasmoid:

```bash
rm -rf \
    ~/.local/share/plasma/plasmoids/cz.saruman.bakalari
```

Then restart Plasma:

```bash
systemctl --user restart plasma-plasmashell.service
```

The saved KWallet password should be removed using **Forget password and log out** before uninstalling if you no longer want the credential stored.

## Status

The project is currently under active development.

Initial target release:

```text
v0.1.0
```

## Repository

https://github.com/MatejStebel/plasma-widgets

## License

GPL-3.0