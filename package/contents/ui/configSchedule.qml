import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import "../code/themeParser.js" as ThemeParser

KCM.SimpleKCM {
    id: page

    property alias cfg_serverUrl: serverUrl.text
    property alias cfg_username: username.text
    property alias cfg_displayName: displayName.text
    property alias cfg_refreshInterval: refreshInterval.value
    property alias cfg_themeJson: themeInput.text
    property bool cfg_logoutRequested: false
    property bool cfg_loginRequested: false
    property string cfg_teacherList: "[]"
    property string cfg_teacherOverrides: "{}"
    property string themeError: ""
    property string walletMessage: ""

    function walletKey() {
        var server = serverUrl.text.trim().replace(/\/+$/, "")
        var user = username.text.trim()
        return server === "" || user === "" ? "" : server + "|" + user
    }

    function savePassword() {
        var key = walletKey()
        if (key === "" || passwordInput.text === "") {
            walletMessage = i18n("Enter the server, username, and password first.")
            return
        }
        if (!walletLoader.item) {
            walletMessage = i18n("KWallet is unavailable.")
            return
        }
        walletLoader.item.savePassword(key, passwordInput.text, function(error) {
            walletMessage = error
                ? i18n("Password could not be saved to KWallet.")
                : i18n("Password saved. The timetable will log in automatically.")
            if (!error) {
                passwordInput.clear()
                plasmoid.configuration.loginRequested = true
            }
        })
    }

    function validateTheme() {
        var parsed = ThemeParser.parseTheme(themeInput.text)
        themeError = parsed.valid
            ? i18n("Theme JSON is valid.")
            : i18n("Theme JSON is invalid.")
    }

    Component.onCompleted: {
        if (themeInput.text.trim() === "") {
            themeInput.text = ThemeParser.defaultThemeJson()
        }
        validateTheme()
    }

    Loader {
        id: walletLoader
        source: "WalletDbus.qml"
    }

    Kirigami.FormLayout {
        width: parent.width

        QQC2.Label {
            Kirigami.FormData.label: i18n("Account")
            text: i18n("Credentials are stored securely in KWallet.")
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        QQC2.TextField {
            id: serverUrl
            Kirigami.FormData.label: i18n("Bakaláři server")
            placeholderText: "https://school.bakalari.cz"
            Layout.fillWidth: true
        }

        QQC2.TextField {
            id: username
            Kirigami.FormData.label: i18n("Username")
            Layout.fillWidth: true
        }

        QQC2.TextField {
            id: passwordInput
            Kirigami.FormData.label: i18n("Password")
            echoMode: TextInput.Password
            onAccepted: page.savePassword()
            Layout.fillWidth: true
        }

        QQC2.Button {
            Kirigami.FormData.label: i18n("Account")
            text: i18n("Save password")
            icon.name: "document-save"
            onClicked: page.savePassword()
        }

        QQC2.Button {
            Kirigami.FormData.label: i18n("Account")
            text: i18n("Forget password and log out")
            icon.name: "system-log-out"
            enabled: serverUrl.text.trim() !== "" && username.text.trim() !== ""
            onClicked: {
                plasmoid.configuration.logoutRequested = true
                walletMessage = i18n("Logged out.")
            }
        }

        QQC2.Label {
            visible: walletMessage !== ""
            Kirigami.FormData.label: i18n("Account")
            text: walletMessage
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        QQC2.TextField {
            id: displayName
            Kirigami.FormData.label: i18n("Display name")
            placeholderText: i18n("Optional name shown above the timetable")
            Layout.fillWidth: true
        }

        QQC2.SpinBox {
            id: refreshInterval
            Kirigami.FormData.label: i18n("Refresh interval")
            from: 1
            to: 1440
            editable: true
            textFromValue: function(value) { return value + " min" }
            valueFromText: function(text) {
                var result = parseInt(text)
                return isNaN(result) ? 15 : result
            }
        }

        QQC2.Label {
            Kirigami.FormData.label: i18n("Theme JSON")
            text: i18n("Paste a theme JSON from lepsi-rozvrh-themes.")
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        QQC2.ScrollView {
            id: themeScroll
            Layout.fillWidth: true
            Layout.minimumHeight: 220
            Layout.preferredHeight: 260
            Layout.maximumHeight: 260
            implicitHeight: 260
            height: 260
            clip: true
            QQC2.ScrollBar.vertical.policy: QQC2.ScrollBar.AsNeeded

            QQC2.TextArea {
                id: themeInput
                width: themeScroll.width
                height: Math.max(themeScroll.height, contentHeight)
                wrapMode: TextEdit.NoWrap
                font.family: "monospace"
                onTextChanged: validateTheme()
            }
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Theme")
            Layout.fillWidth: true

            QQC2.Button {
                text: i18n("Use default theme")
                onClicked: themeInput.text = ThemeParser.defaultThemeJson()
            }
            QQC2.Label {
                text: page.themeError
                color: page.themeError === i18n("Theme JSON is valid.")
                    ? Kirigami.Theme.positiveTextColor
                    : Kirigami.Theme.negativeTextColor
            }
        }
    }
}
