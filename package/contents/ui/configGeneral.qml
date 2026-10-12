import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    id: page

    property alias cfg_serverUrl: serverUrl.text
    property alias cfg_username: username.text
    property alias cfg_refreshInterval: refreshInterval.value

    QQC2.TextField {
        id: serverUrl

        Kirigami.FormData.label:
            i18n("Bakaláři server:")

        placeholderText:
            "https://school.bakalari.cz"

        Layout.fillWidth: true
    }

    QQC2.TextField {
        id: username

        Kirigami.FormData.label:
            i18n("Username:")

        Layout.fillWidth: true
    }

    QQC2.Button {
        Kirigami.FormData.label:
            i18n("Account:")

        text:
            i18n("Forget password and log out")

        icon.name:
            "system-log-out"

        enabled:
            plasmoid.configuration.username !== ""
            && plasmoid.configuration.serverUrl !== ""

        onClicked: {
            plasmoid.configuration.logoutRequested =
                true
        }
    }
    
    QQC2.SpinBox {
        id: refreshInterval

        Kirigami.FormData.label:
            i18n("Refresh interval:")

        from: 1
        to: 1440
        editable: true

        textFromValue: function(value) {
            return value + " min"
        }

        valueFromText: function(text) {
            var result = parseInt(text)

            if (isNaN(result)) {
                return 15
            }

            return result
        }
    }
}