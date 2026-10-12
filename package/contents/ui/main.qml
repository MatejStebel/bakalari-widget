import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import "../code/timetableParser.js" as TimetableParser
import "BakalariWallet" as BakalariWallet


PlasmoidItem {
    id: root

    preferredRepresentation: fullRepresentation

    property string cycle: ""
    property var lessonTimes: []
    property var days: []

    property string loadError: ""

    property string sessionPassword: ""
    property string accessToken: ""
    property string apiStatus: ""
    property bool apiBusy: false
    property var lastApiData: null
    property string teacherOverridesJson:
        plasmoid.configuration.teacherOverrides || "{}"
    property bool logoutRequested:
        plasmoid.configuration.logoutRequested

    onLogoutRequestedChanged: {
        if (!root.logoutRequested) {
            return
        }

        root.forgetPasswordAndLogout()

        // Reset the one-shot request.
        plasmoid.configuration.logoutRequested = false
    }

    onTeacherOverridesJsonChanged: {
        if (root.lastApiData !== null) {
            root.applyTimetableData(
                root.lastApiData
            )
        }
    }
    BakalariWallet.WalletBackend {
        id: walletBackend
    }
    Component.onCompleted: {
        Qt.callLater(function() {
            root.tryAutomaticLogin()
        })
    }
    function normalizedServerUrl() {
        var url = plasmoid.configuration.serverUrl.trim()

        while (url.endsWith("/")) {
            url = url.slice(0, -1)
        }

        return url
    }
    function walletKey() {
        var server =
            root.normalizedServerUrl()

        var username =
            plasmoid.configuration.username.trim()

        if (
            server === ""
            || username === ""
        ) {
            return ""
        }

        return server + "|" + username
    }


    function savePasswordToWallet(password) {
        var key = root.walletKey()

        if (
            key === ""
            || password === ""
        ) {
            return
        }

        var success =
            walletBackend.savePassword(
                key,
                password
            )

        if (!success) {
            console.error(
                "Could not save password to KWallet"
            )
        }
    }
    function forgetPasswordAndLogout() {
        var key =
            root.walletKey()

        if (key !== "") {
            var removed =
                walletBackend.deletePassword(
                    key
                )

            if (!removed) {
                console.error(
                    "Could not remove password from KWallet"
                )
            }
        }

        refreshTimer.stop()

        root.accessToken = ""
        root.sessionPassword = ""
        root.lastApiData = null

        root.cycle = ""
        root.lessonTimes = []
        root.days = []

        root.apiBusy = false
        root.apiStatus = "Logged out"
    }

    function tryAutomaticLogin() {
        var key = root.walletKey()

        if (key === "") {
            return
        }

        var password =
            walletBackend.loadPassword(key)

        if (
            password === undefined
            || password === null
            || password === ""
        ) {
            return
        }

        root.sessionPassword =
            password

        root.loginToBakalari()
    }
    function loadTeacherOverrides() {
        try {
            var overrides = JSON.parse(
                plasmoid.configuration.teacherOverrides
                || "{}"
            )

            if (
                overrides === null
                || Array.isArray(overrides)
                || typeof overrides !== "object"
            ) {
                return {}
            }

            return overrides

        } catch (error) {
            console.error(
                "Invalid teacher overrides:",
                error
            )

            return {}
        }
    }
    Timer {
        id: refreshTimer

        interval:
            Math.max(
                1,
                plasmoid.configuration.refreshInterval
            )
            * 60
            * 1000

        repeat: true
        running:
            root.accessToken !== ""

        onTriggered: {
            root.fetchTimetable()
        }
    }
    Connections {
        target:
            plasmoid.configuration

        function onRefreshIntervalChanged() {
            refreshTimer.restart()
        }
    }


    function applyTimetableData(data) {
        root.lastApiData = data

        // Save a lightweight teacher list
        // for the settings page.
        var teachers =
            TimetableParser.buildTeacherList(
                data.Teachers || []
            )

        var teacherJson =
            JSON.stringify(teachers)

        if (
            plasmoid.configuration.teacherList
            !== teacherJson
        ) {
            plasmoid.configuration.teacherList =
                teacherJson
        }

        var parsed =
            TimetableParser.parseTimetable(
                data,
                root.loadTeacherOverrides()
            )

        root.cycle =
            parsed.cycle

        root.lessonTimes =
            parsed.hours

        root.days =
            parsed.days
    }

    property date currentTime: new Date()

    Timer {
        interval: 30000
        repeat: true
        running: true

        onTriggered: {
            root.currentTime = new Date()
        }
    }
    function isCurrentHour(hour) {
        if (!hour || !hour.start || !hour.end) {
            return false
        }

        var now = root.currentTime

        var startParts =
            hour.start.split(":")

        var endParts =
            hour.end.split(":")

        if (
            startParts.length < 2
            || endParts.length < 2
        ) {
            return false
        }

        var nowMinutes =
            now.getHours() * 60
            + now.getMinutes()

        var startMinutes =
            parseInt(startParts[0]) * 60
            + parseInt(startParts[1])

        var endMinutes =
            parseInt(endParts[0]) * 60
            + parseInt(endParts[1])

        return (
            nowMinutes >= startMinutes
            && nowMinutes < endMinutes
        )
    }

    function isToday(day) {
        if (!day) {
            return false
        }

        var now = root.currentTime

        var year =
            now.getFullYear()

        var month =
            String(now.getMonth() + 1)
            .padStart(2, "0")

        var date =
            String(now.getDate())
            .padStart(2, "0")

        var today =
            year
            + "-"
            + month
            + "-"
            + date

        var dayDate =
            String(day.date || "")

        // Works for both:
        // 2026-10-05
        // 2026-10-05T00:00:00+02:00
        if (
            dayDate.substring(0, 10)
            === today
        ) {
            return true
        }

        return false
    }
    
    function loginToBakalari() {
        var server = normalizedServerUrl()
        var username = plasmoid.configuration.username.trim()

        if (server === "") {
            apiStatus = "Server URL is missing"
            return
        }

        if (username === "") {
            apiStatus = "Username is missing"
            return
        }

        if (sessionPassword === "") {
            apiStatus = "Password is missing"
            return
        }

        apiBusy = true
        apiStatus = "Logging in..."

        var request = new XMLHttpRequest()

        request.open(
            "POST",
            server + "/api/login"
        )

        request.setRequestHeader(
            "Content-Type",
            "application/x-www-form-urlencoded"
        )

        request.onreadystatechange = function() {
            if (
                request.readyState
                !== XMLHttpRequest.DONE
            ) {
                return
            }

            root.apiBusy = false

            if (request.status !== 200) {
                root.apiStatus =
                    "Login failed (HTTP "
                    + request.status
                    + ")"

                console.error(
                    "Bakaláři login failed:",
                    request.responseText
                )

                return
            }

            var response

            try {
                response = JSON.parse(
                    request.responseText
                )
            } catch (error) {
                root.apiStatus =
                    "Invalid login response"

                console.error(
                    "Could not parse login response:",
                    error
                )

                return
            }

            if (
                !response.access_token
                || response.access_token === ""
            ) {
                root.apiStatus =
                    "Login response has no access token"

                return
            }

            root.accessToken =
            response.access_token

            root.apiStatus =
                "Logged in"

            // Save it BEFORE clearing sessionPassword.
            root.savePasswordToWallet(
                root.sessionPassword
            )

            refreshTimer.restart()

            root.sessionPassword = ""

            root.fetchTimetable()
        }
        var body =
            "client_id=ANDR"
            + "&grant_type=password"
            + "&username="
            + encodeURIComponent(username)
            + "&password="
            + encodeURIComponent(sessionPassword)

        request.send(body)
    }
    function todayForApi() {
        var date = new Date()

        var year = date.getFullYear()

        var month =
            String(date.getMonth() + 1)
            .padStart(2, "0")

        var day =
            String(date.getDate())
            .padStart(2, "0")

        return year + "-" + month + "-" + day
    }


    function fetchTimetable() {
        console.log("fetchTimetable called")
        if (root.accessToken === "") {
            root.apiStatus = "Not logged in"
            return
        }

        root.apiBusy = true
        root.apiStatus = "Loading timetable..."

        var request = new XMLHttpRequest()

        var url =
            root.normalizedServerUrl()
            + "/api/3/timetable/actual?date="
            + root.todayForApi()

        request.open(
            "GET",
            url
        )

        request.setRequestHeader(
            "Authorization",
            "Bearer " + root.accessToken
        )

        request.onreadystatechange = function() {
            if (
                request.readyState
                !== XMLHttpRequest.DONE
            ) {
                return
            }

            root.apiBusy = false

            if (request.status !== 200) {
                root.apiStatus =
                    "Timetable failed (HTTP "
                    + request.status
                    + ")"

                console.error(
                    "Timetable request failed:",
                    request.responseText
                )

                return
            }

            try {
                var data = JSON.parse(
                    request.responseText
                )

                root.applyTimetableData(data)

            } catch (error) {
                root.apiStatus =
                    "Could not process timetable"

                console.error(
                    "Timetable processing error:",
                    error
                )

                return
            }

            root.apiStatus =
                "Timetable updated at "
                + Qt.formatTime(
                    new Date(),
                    "HH:mm"
                )
        }

        request.send()
    }

    function lessonForHour(day, hourId) {
        if (!day || !day.lessons) {
            return null
        }

        for (
            var i = 0;
            i < day.lessons.length;
            i++
        ) {
            var lesson = day.lessons[i]

            if (
                String(lesson.hourId)
                === String(hourId)
            ) {
                return lesson
            }
        }

        return null
    }


    function dayName(dayNumber) {
        switch (Number(dayNumber)) {
        case 1:
            return "Monday"

        case 2:
            return "Tuesday"

        case 3:
            return "Wednesday"

        case 4:
            return "Thursday"

        case 5:
            return "Friday"

        case 6:
            return "Saturday"

        case 7:
            return "Sunday"

        default:
            return ""
        }
    }


    fullRepresentation: Item {
        id: representation

        implicitWidth: 900
        implicitHeight: 500

        Layout.minimumWidth: 360

        property int dayWidth: 90
        property int lessonWidth: 110
        property int headerHeight: 55
        property int lessonHeight: 90
        property int cellSpacing: 5


        Flickable {
            id: timetableScroll

            anchors.fill: parent

            contentWidth: timetable.width
            contentHeight: timetable.height

            clip: true

            flickableDirection:
                Flickable.HorizontalAndVerticalFlick

            boundsBehavior:
                Flickable.StopAtBounds


            ScrollBar.horizontal:
                PlasmaComponents.ScrollBar {
                    policy: ScrollBar.AsNeeded
                }


            ScrollBar.vertical:
                PlasmaComponents.ScrollBar {
                    policy: ScrollBar.AsNeeded
                }


            Item {
                id: timetable

                width: Math.max(
                    timetableScroll.width,

                    representation.dayWidth
                    + root.lessonTimes.length
                    * representation.lessonWidth
                    + root.lessonTimes.length
                    * representation.cellSpacing
                )

                height: Math.max(
                    timetableScroll.height,
                    timetableColumn.implicitHeight
                )

                ColumnLayout {
                    id: timetableColumn
                    anchors.fill: parent

                    spacing:
                        representation.cellSpacing


                    PlasmaComponents.Label {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40

                        text:
                            plasmoid.configuration.username !== ""
                            ? "Weekly schedule — "
                                + plasmoid.configuration.username
                            : "Weekly schedule — not configured"

                        horizontalAlignment:
                            Text.AlignHCenter

                        verticalAlignment:
                            Text.AlignVCenter

                        font.pixelSize: 20
                        font.bold: true
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.minimumWidth: 320

                        visible:
                            root.accessToken === ""

                        spacing: 8

                        TextField {
                            id: passwordField

                            Layout.fillWidth: true
                            Layout.minimumWidth: 220

                            text:
                                root.sessionPassword

                            placeholderText:
                                i18n("Bakaláři password")

                            echoMode:
                                TextInput.Password

                            enabled:
                                !root.apiBusy

                            onTextEdited:
                                root.sessionPassword = text

                            onAccepted:
                                root.loginToBakalari()
                        }

                        Button {
                            text:
                                root.apiBusy
                                ? i18n("Loading...")
                                : i18n("Login")

                            enabled:
                                !root.apiBusy

                            onClicked:
                                root.loginToBakalari()
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true

                        visible:
                            root.accessToken !== ""

                        Item {
                            Layout.fillWidth: true
                        }

                        Button {
                            text:
                                root.apiBusy
                                ? i18n("Loading...")
                                : i18n("Refresh")

                            enabled:
                                !root.apiBusy

                            onClicked:
                                root.fetchTimetable()
                        }
                    }
                    PlasmaComponents.Label {
                        Layout.fillWidth: true

                        visible:
                            root.apiStatus !== ""

                        text:
                            root.apiStatus

                        horizontalAlignment:
                            Text.AlignHCenter

                        opacity: 0.8
                    }

                    PlasmaComponents.Label {
                        Layout.fillWidth: true

                        visible:
                            root.days.length === 0
                            && root.accessToken === ""

                        text:
                            i18n("Enter your password to load the timetable")

                        horizontalAlignment:
                            Text.AlignHCenter

                        opacity: 0.8
                    }
                    // -------------------------
                    // Hour header
                    // -------------------------

                    RowLayout {
                        Layout.fillWidth: true

                        Layout.preferredHeight:
                            representation.headerHeight

                        spacing:
                            representation.cellSpacing


                        // Top-left corner
                        PlasmaComponents.Label {
                            Layout.minimumWidth:
                                representation.dayWidth

                            Layout.preferredWidth:
                                representation.dayWidth

                            Layout.fillHeight: true

                            text:
                                root.cycle

                            horizontalAlignment:
                                Text.AlignHCenter

                            verticalAlignment:
                                Text.AlignVCenter

                            font.bold: true
                            font.pixelSize: 18
                        }


                        Repeater {
                            model:
                                root.lessonTimes

                            delegate: Rectangle {
                                required property var modelData

                                Layout.fillWidth: true

                                Layout.minimumWidth:
                                    representation.lessonWidth

                                Layout.preferredWidth:
                                    representation.lessonWidth

                                Layout.fillHeight: true

                                radius: 6

                                color:
                                    root.isCurrentHour(modelData)
                                    ? Qt.rgba(
                                        0.7,
                                        0.7,
                                        0.7,
                                        0.25
                                    )
                                    : "transparent"

                                ColumnLayout {
                                    anchors.fill: parent

                                    anchors.margins: 2

                                    spacing: 0


                                    PlasmaComponents.Label {
                                        Layout.fillWidth: true

                                        text:
                                            modelData.number

                                        horizontalAlignment:
                                            Text.AlignHCenter

                                        verticalAlignment:
                                            Text.AlignVCenter

                                        font.bold: true
                                        font.pixelSize: 16
                                    }


                                    PlasmaComponents.Label {
                                        Layout.fillWidth: true

                                        text:
                                            modelData.start
                                            + "–"
                                            + modelData.end

                                        horizontalAlignment:
                                            Text.AlignHCenter

                                        verticalAlignment:
                                            Text.AlignVCenter

                                        font.pixelSize: 11
                                        opacity: 0.7
                                    }
                                }
                            }
                        }
                    }

                    // -------------------------
                    // Days
                    // -------------------------

                    Repeater {
                        model: root.days

                        delegate: RowLayout {
                            id: dayRow

                            required property var modelData

                            property var dayData:
                                modelData

                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            Layout.minimumHeight:
                                representation.lessonHeight

                            Layout.preferredHeight:
                                representation.lessonHeight

                            spacing:
                                representation.cellSpacing


                            Rectangle {
                                Layout.minimumWidth:
                                    representation.dayWidth

                                Layout.preferredWidth:
                                    representation.dayWidth

                                Layout.fillHeight: true

                                radius: 6

                                color:
                                    root.isToday(dayRow.dayData)
                                    ? Qt.rgba(
                                        0.7,
                                        0.7,
                                        0.7,
                                        0.25
                                    )
                                    : "transparent"

                                PlasmaComponents.Label {
                                    anchors.fill: parent

                                    text:
                                        root.dayName(
                                            dayRow.dayData.dayOfWeek
                                        )

                                    horizontalAlignment:
                                        Text.AlignHCenter

                                    verticalAlignment:
                                        Text.AlignVCenter

                                    font.bold: true
                                }
                            }

                            Rectangle {
                                visible:
                                dayRow.dayData.allDayEvent === true

                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                Layout.minimumHeight:
                                representation.lessonHeight

                                radius: 6

                                color: Qt.rgba(
                                    0.5,
                                    0.5,
                                    0.5,
                                    0.15
                                )

                                border.width: 1

                                border.color: Qt.rgba(
                                    0.5,
                                    0.5,
                                    0.5,
                                    0.3
                                )

                                PlasmaComponents.Label {
                                    anchors.fill: parent
                                    anchors.margins: 8

                                    text:
                                    dayRow.dayData.eventText || ""

                                    horizontalAlignment:
                                    Text.AlignHCenter

                                    verticalAlignment:
                                    Text.AlignVCenter

                                    wrapMode:
                                    Text.WordWrap

                                    font.bold: true
                                }
                            }

                            // One cell for every displayed
                            // school hour.
                            Repeater {
                                model:
                                dayRow.dayData.allDayEvent
                                ? []
                                : root.lessonTimes

                                delegate: Rectangle {
                                    required property var modelData

                                    property var lesson:
                                        root.lessonForHour(
                                            dayRow.dayData,
                                            modelData.id
                                        )

                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    Layout.minimumWidth:
                                        representation.lessonWidth

                                    Layout.preferredWidth:
                                        representation.lessonWidth

                                    Layout.minimumHeight:
                                        representation.lessonHeight

                                    radius: 6

                                    color: {
                                        if (!lesson) {
                                            return "transparent"
                                        }

                                        if (lesson.status === "cancelled") {
                                            return Qt.rgba(
                                                0.2,
                                                0.8,
                                                0.2,
                                                0.25
                                            )
                                        }

                                        if (lesson.status === "changed") {
                                            return Qt.rgba(
                                                1.0,
                                                0.65,
                                                0.0,
                                                0.25
                                            )
                                        }

                                        return Qt.rgba(
                                            0.5,
                                            0.5,
                                            0.5,
                                            0.15
                                        )
                                    }

                                    border.width:
                                        lesson ? 1 : 0

                                    border.color:
                                        Qt.rgba(
                                            0.5,
                                            0.5,
                                            0.5,
                                            0.3
                                        )


                                    ColumnLayout {
                                        anchors.centerIn:
                                            parent

                                        width:
                                            parent.width - 10

                                        spacing: 2


                                        PlasmaComponents.Label {
                                            Layout.fillWidth: true

                                            visible:
                                                lesson !== null

                                            text:
                                                lesson
                                                ? lesson.subject
                                                : ""

                                            horizontalAlignment:
                                                Text.AlignHCenter

                                            font.bold: true
                                            font.pixelSize: 15
                                        }


                                        PlasmaComponents.Label {
                                            Layout.fillWidth: true

                                            visible:
                                                lesson !== null

                                            text:
                                                lesson
                                                ? lesson.teacher
                                                : ""

                                            horizontalAlignment:
                                                Text.AlignHCenter

                                            font.pixelSize: 12
                                        }


                                        PlasmaComponents.Label {
                                            Layout.fillWidth: true

                                            visible:
                                                lesson !== null

                                            text:
                                                lesson
                                                ? lesson.room
                                                : ""

                                            horizontalAlignment:
                                                Text.AlignHCenter

                                            font.pixelSize: 11
                                            opacity: 0.7
                                        }
                                        PlasmaComponents.Label {
                                            Layout.fillWidth: true

                                            visible:
                                                lesson !== null
                                                && lesson.change !== null
                                                && lesson.change.description !== undefined
                                                && lesson.change.description !== ""

                                            text:
                                                visible
                                                ? lesson.change.description
                                                : ""

                                            horizontalAlignment:
                                                Text.AlignHCenter

                                            wrapMode:
                                                Text.WordWrap

                                            maximumLineCount: 2
                                            elide: Text.ElideRight

                                            font.pixelSize: 10
                                            opacity: 0.8
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}