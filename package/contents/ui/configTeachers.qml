import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: page

    property string teacherJson:
        plasmoid.configuration.teacherList || "[]"

    ListModel {
        id: teacherModel
    }


    function readOverrides() {
        try {
            var result = JSON.parse(
                plasmoid.configuration.teacherOverrides
                || "{}"
            )

            if (
                result === null
                || Array.isArray(result)
                || typeof result !== "object"
            ) {
                return {}
            }

            return result

        } catch (error) {
            return {}
        }
    }


    function saveOverride(
        teacherId,
        value
    ) {
        var overrides =
            readOverrides()

        var cleaned =
            String(value).trim()

        if (cleaned === "") {
            delete overrides[teacherId]
        } else {
            overrides[teacherId] =
                cleaned
        }

        plasmoid.configuration.teacherOverrides =
            JSON.stringify(overrides)
    }


    function resetOverride(
        teacherId
    ) {
        var overrides =
            readOverrides()

        delete overrides[teacherId]

        plasmoid.configuration.teacherOverrides =
            JSON.stringify(overrides)

        rebuildTeachers()
    }


    function rebuildTeachers() {
        teacherModel.clear()

        var teachers = []

        try {
            teachers = JSON.parse(
                teacherJson || "[]"
            )
        } catch (error) {
            teachers = []
        }

        var overrides =
            readOverrides()

        for (
            var i = 0;
            i < teachers.length;
            i++
        ) {
            var teacher =
                teachers[i]

            var teacherId =
                String(teacher.id)

            var automatic =
                String(
                    teacher.automaticAbbreviation
                    || ""
                )

            var custom = ""

            if (
                overrides[teacherId]
                !== undefined
            ) {
                custom =
                    String(
                        overrides[teacherId]
                    )
            }

            teacherModel.append({
                teacherId:
                    teacherId,

                teacherName:
                    String(
                        teacher.name || ""
                    ),

                automatic:
                    automatic,

                custom:
                    custom
            })
        }
    }


    onTeacherJsonChanged:
        rebuildTeachers()

    Component.onCompleted:
        rebuildTeachers()


    Kirigami.FormLayout {
        width: parent.width


        QQC2.Label {
            visible:
                teacherModel.count === 0

            text:
                i18n(
                    "Log in and load the timetable once to discover teachers."
                )

            wrapMode:
                Text.WordWrap

            Layout.fillWidth: true
        }


        Repeater {
            model: teacherModel

            delegate: RowLayout {
                required property string teacherId
                required property string teacherName
                required property string automatic
                required property string custom

                Kirigami.FormData.label:
                    teacherName

                Layout.fillWidth: true


                QQC2.TextField {
                    id: abbreviationField

                    Layout.preferredWidth: 120
                    Layout.minimumWidth: 100

                    text:
                        custom !== ""
                        ? custom
                        : automatic

                    placeholderText:
                        automatic

                    onEditingFinished: {
                        var value =
                            text.trim()

                        // If the user sets it back
                        // to the automatic value,
                        // remove the override.
                        if (
                            value === automatic
                        ) {
                            page.resetOverride(
                                teacherId
                            )
                        } else {
                            page.saveOverride(
                                teacherId,
                                value
                            )
                        }
                    }
                }


                QQC2.Button {
                    text:
                        i18n("Reset")

                    enabled:
                        custom !== ""

                    onClicked: {
                        page.resetOverride(
                            teacherId
                        )
                    }
                }
            }
        }
    }
}
