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

- KDE Plasma 6.3 or newer for the no-compile backend
- Qt 6
- KDE Frameworks 6
- KWallet
- Bash and tar for installation

The default password backend now calls KWallet asynchronously through Plasma's
`org.kde.plasma.workspace.dbus` QML module. It sends no password through process
arguments, shell commands, or temporary files. Existing KWallet entries use the
same folder and account keys; no migration is needed. KWallet may ask to authorize
the application `cz.saruman.bakalari`.

### Installation (no compilation)

```bash
bash install.sh
```

Run the same command for updates, then reload Plasma or log out and back in.
This path targets Plasma 6.3 or newer with Plasma's D-Bus QML module and KWallet.
It needs no CMake, compiler, development packages, Python, or `secret-tool`.
`qtpaths6` is optional: the installer also searches standard Qt 6 QML locations,
including Debian multiarch directories, and `QML_IMPORT_PATH`. It checks the
Plasma version and module before copying files and does not restart your desktop.
Updates remove obsolete compiled plugin files while retaining KWallet passwords
and widget settings. `install-no-compile.sh` remains an alias for `install.sh`.

Debian 13 (Trixie) with its KDE desktop is supported by using the single-argument
D-Bus API and `finished` signal from Plasma 6.3, instead of the callback overload
introduced in Plasma 6.4. The module is supplied by Debian's
[`plasma-workspace` runtime package](https://packages.debian.org/trixie/amd64/plasma-workspace/filelist).
Run the installation command above as your normal desktop user, without `sudo`.
Debian 12's stock Plasma 5 is not supported; this remains a Plasma 6 widget.

Wallet failures are displayed separately from API status. Manual login can still
work without password storage; a failed deletion explicitly warns that the saved
password remains. The timetable parser, teacher overrides, and date/hour
highlighting are unchanged.

### Credential backend checks

Development tests use Python with PySide6 (not a widget runtime dependency):

```bash
python3 tools/test_wallet_qml.py
python3 tools/test_wallet_qml.py --live
python3 tools/test_login_lifecycle.py
python3 tools/test_no_compile_install.py
```

The live check creates a unique `prototype-test-…` entry, round-trips a dummy
password containing whitespace, Unicode and shell characters, and deletes it.
It also checks that queued deletion runs after an in-flight save. The lifecycle
tests exercise login, logout and account changes with deferred simulated replies.
These checks never read account passwords. A failed run prints its disposable key;
`--live --cleanup-abandoned` removes only UUID-shaped test entries before retesting.
KWallet may request unlock/authorization. Live API login and interactive wallet
cancellation still need desktop validation before considering this path stable.

To test the actual Debian 13 Plasma 6.3.6 D-Bus plugin with Debian's Qt libraries
and an isolated in-memory wallet service (no access to your real wallet):

```bash
podman run --rm --security-opt label=disable \
    --mount "type=bind,source=$PWD,target=/work,ro" \
    docker.io/library/debian:13-slim \
    bash /work/tools/test_debian_compat.sh --inside-container
```

This optional developer test downloads prebuilt runtime packages inside the
disposable container. The current test image/package command targets amd64.
The test verifies that the requested Debian plugin actually loaded, so a host
plugin cannot accidentally produce a passing compatibility result.

Validation: the Debian 13 container passed with the actual Plasma 6.3.6 plugin
and Qt 6.8.2, using the in-memory wallet fixture. Real KWallet round trips were
also tested on the Fedora host. A full Debian desktop/API login and interactive
wallet unlock/cancellation have not been tested.

## Tested environment

Development has primarily been tested on:

- Fedora Linux 44
- KDE Plasma Desktop Edition
- KDE Plasma 6

## First install
- For the first install you can just use
```bash
git clone https://github.com/MatejStebel/bakalari-widget.git
cd bakalari-widget
./install.sh
```

After installation, reload Plasma or log out and back in. The widget should then
appear in Plasma's **Add Widgets** dialog.

## Updating

```bash
git pull
bash update.sh
```

The update script uses the same no-compile installer. Reload Plasma afterward;
neither script automatically restarts your desktop.

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
├── install.sh
├── install-no-compile.sh
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
│           └── WalletDbus.qml
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

https://github.com/MatejStebel/bakalari-widget

## License

GPL-3.0
