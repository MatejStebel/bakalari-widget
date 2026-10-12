function lookupById(items) {
    var result = {}

    if (!items) {
        return result
    }

    for (var i = 0; i < items.length; i++) {
        result[String(items[i].Id)] = items[i]
    }

    return result
}


function getSurname(fullName) {
    var titlesBefore = [
        "bc.",
        "mgr.",
        "ing.",
        "rndr.",
        "mudr.",
        "judr.",
        "phdr.",
        "paeddr.",
        "mvdr.",
        "doc.",
        "prof."
    ]

    var titlesAfter = [
        "ph.d.",
        "th.d.",
        "csc.",
        "drsc.",
        "mba",
        "mba.",
        "dis.",
        "ll.m."
    ]

    var words = String(fullName || "").split(/\s+/)
    var cleaned = []

    for (var i = 0; i < words.length; i++) {
        var word = words[i]
            .replace(/^[,\s]+|[,\s]+$/g, "")

        var lower = word.toLowerCase()

        if (titlesBefore.indexOf(lower) !== -1) {
            continue
        }

        if (titlesAfter.indexOf(lower) !== -1) {
            continue
        }

        if (word !== "") {
            cleaned.push(word)
        }
    }

    if (cleaned.length === 0) {
        return fullName || ""
    }

    return cleaned[cleaned.length - 1]
}


function automaticTeacherAbbreviation(teacher) {
    if (!teacher) {
        return ""
    }

    var surname = getSurname(
        teacher.Name || ""
    )

    if (surname.length <= 5) {
        return surname
    }

    return surname.substring(0, 4)
}


function teacherAbbreviation(
    teacher,
    overrides
) {
    if (!teacher) {
        return ""
    }

    var teacherId =
        String(teacher.Id)

    if (
        overrides
        && overrides[teacherId] !== undefined
        && overrides[teacherId] !== null
    ) {
        var custom =
            String(
                overrides[teacherId]
            ).trim()

        if (custom !== "") {
            return custom
        }
    }

    return automaticTeacherAbbreviation(
        teacher
    )
}


function buildTeacherList(rawTeachers) {
    var result = []

    if (!rawTeachers) {
        return result
    }

    for (
        var i = 0;
        i < rawTeachers.length;
        i++
    ) {
        var teacher =
            rawTeachers[i]

        result.push({
            id: String(teacher.Id),

            name:
                teacher.Name || "",

            automaticAbbreviation:
                automaticTeacherAbbreviation(
                    teacher
                )
        })
    }

    result.sort(function(a, b) {
        return a.name.localeCompare(
            b.name
        )
    })

    return result
}


function atomHasContent(atom) {
    if (!atom) {
        return false
    }

    if (
        atom.SubjectId !== null
        && atom.SubjectId !== undefined
    ) {
        return true
    }

    if (
        atom.TeacherId !== null
        && atom.TeacherId !== undefined
    ) {
        return true
    }

    if (
        atom.RoomId !== null
        && atom.RoomId !== undefined
    ) {
        return true
    }

    var change = atom.Change

    if (change) {
        if (
            change.Description
            || change.ChangeType
            || change.ChangeDisplayType
            || change.AtomType
        ) {
            return true
        }
    }

    return !!(
        atom.Notice
        || atom.Theme
        || atom.LessonRelease
    )
}


function hasDirectLesson(atom) {
    return (
        atom.SubjectId !== null
        && atom.SubjectId !== undefined
    ) || (
        atom.TeacherId !== null
        && atom.TeacherId !== undefined
    ) || (
        atom.RoomId !== null
        && atom.RoomId !== undefined
    )
}


function convertHours(rawHours) {
    var result = []

    if (!rawHours) {
        return result
    }

    for (var i = 0; i < rawHours.length; i++) {
        var hour = rawHours[i]
        var caption = String(
            hour.Caption || ""
        ).trim()

        var number = parseInt(caption)

        if (isNaN(number)) {
            continue
        }

        // We currently support school hours through 9.
        if (number > 9) {
            continue
        }

        result.push({
            id: String(hour.Id),
            number: caption,
            start: hour.BeginTime || "",
            end: hour.EndTime || ""
        })
    }

    return result
}


function getAtomHourIds(
    atom,
    possibleHours
) {
    var positions = {}

    for (
        var i = 0;
        i < possibleHours.length;
        i++
    ) {
        positions[possibleHours[i].id] = i
    }

    var hourId = String(
        atom.HourId !== undefined
        ? atom.HourId
        : ""
    )

    if (positions[hourId] === undefined) {
        return []
    }

    var startIndex = positions[hourId]

    var duration = parseInt(
        atom.Duration || 1
    )

    if (isNaN(duration) || duration < 1) {
        duration = 1
    }

    var result = []

    for (
        var offset = 0;
        offset < duration;
        offset++
    ) {
        var index =
            startIndex + offset

        if (index >= possibleHours.length) {
            break
        }

        result.push(
            possibleHours[index].id
        )
    }

    return result
}


function getLongestNormalDay(
    days,
    possibleHours
) {
    var valid = {}

    for (
        var i = 0;
        i < possibleHours.length;
        i++
    ) {
        valid[possibleHours[i].id] = true
    }

    var longest = 0

    for (
        var dayIndex = 0;
        dayIndex < days.length;
        dayIndex++
    ) {
        var used = {}
        var atoms = days[dayIndex].Atoms || []

        for (
            var atomIndex = 0;
            atomIndex < atoms.length;
            atomIndex++
        ) {
            var atom = atoms[atomIndex]

            if (!hasDirectLesson(atom)) {
                continue
            }

            var hourId = String(
                atom.HourId
            )

            if (valid[hourId]) {
                used[hourId] = true
            }
        }

        var count =
            Object.keys(used).length

        if (count > longest) {
            longest = count
        }
    }

    return longest
}


function isFullDayEvent(
    day,
    possibleHours,
    longestNormalDay
) {
    var atoms = day.Atoms || []
    var relevantAtoms = []

    for (
        var i = 0;
        i < atoms.length;
        i++
    ) {
        if (atomHasContent(atoms[i])) {
            relevantAtoms.push(atoms[i])
        }
    }

    var dayType =
        String(day.DayType || "")

    var description =
        String(
            day.DayDescription || ""
        ).trim()

    var specialDay =
        dayType === "Holiday"
        || dayType === "Celebration"
        || dayType === "DirectorDay"

    if (specialDay) {
        var direct = false

        for (
            var d = 0;
            d < relevantAtoms.length;
            d++
        ) {
            if (
                hasDirectLesson(
                    relevantAtoms[d]
                )
            ) {
                direct = true
                break
            }
        }

        if (!direct) {
            return true
        }
    }

    if (relevantAtoms.length === 0) {
        return description !== ""
    }

    for (
        var j = 0;
        j < relevantAtoms.length;
        j++
    ) {
        if (
            hasDirectLesson(
                relevantAtoms[j]
            )
        ) {
            return false
        }
    }

    var covered = {}

    for (
        var k = 0;
        k < relevantAtoms.length;
        k++
    ) {
        var ids = getAtomHourIds(
            relevantAtoms[k],
            possibleHours
        )

        for (
            var n = 0;
            n < ids.length;
            n++
        ) {
            covered[ids[n]] = true
        }
    }

    return (
        longestNormalDay > 0
        && Object.keys(covered).length
            >= longestNormalDay
    )
}


function findUsedHourIds(
    days,
    possibleHours,
    fullDayFlags
) {
    var valid = {}
    var used = {}

    for (
        var i = 0;
        i < possibleHours.length;
        i++
    ) {
        valid[possibleHours[i].id] = true
    }

    for (
        var dayIndex = 0;
        dayIndex < days.length;
        dayIndex++
    ) {
        if (fullDayFlags[dayIndex]) {
            continue
        }

        var atoms =
            days[dayIndex].Atoms || []

        for (
            var atomIndex = 0;
            atomIndex < atoms.length;
            atomIndex++
        ) {
            var atom = atoms[atomIndex]

            if (!atomHasContent(atom)) {
                continue
            }

            // Important:
            // duration does NOT create more columns.
            var hourId = String(
                atom.HourId
            )

            if (valid[hourId]) {
                used[hourId] = true
            }
        }
    }

    return used
}


function convertChange(change) {
    if (!change) {
        return null
    }

    var type =
        String(
            change.ChangeType || ""
        )

    var lower =
        type.toLowerCase()

    var status =
        (
            lower === "canceled"
            || lower === "removed"
        )
        ? "cancelled"
        : "changed"

    return {
        type: type,
        status: status,
        displayType:
            change.ChangeDisplayType || "",
        description:
            change.Description || "",
        atomType:
            change.AtomType || ""
    }
}


function fullDayEventText(day) {
    var description =
        String(
            day.DayDescription || ""
        ).trim()

    if (description !== "") {
        return description
    }

    var atoms = day.Atoms || []

    for (
        var i = 0;
        i < atoms.length;
        i++
    ) {
        var change = atoms[i].Change

        if (
            change
            && change.Description
        ) {
            return change.Description
        }

        if (atoms[i].Notice) {
            return atoms[i].Notice
        }
    }

    return "Event"
}

function convertAtom(
    atom,
    allowedHours,
    subjects,
    teachers,
    rooms,
    teacherOverrides
) {
    var hourId =
        String(atom.HourId)

    if (!allowedHours[hourId]) {
        return null
    }

    var change =
        convertChange(atom.Change)

    var subject = ""

    if (
        atom.SubjectId !== null
        && atom.SubjectId !== undefined
    ) {
        var subjectObject =
            subjects[
                String(atom.SubjectId)
            ]

        if (subjectObject) {
            subject =
                subjectObject.Abbrev
                || subjectObject.Name
                || ""
        }
    }

    var teacher = ""

    if (
        atom.TeacherId !== null
        && atom.TeacherId !== undefined
    ) {
        teacher =
            teacherAbbreviation(
                teachers[
                    String(atom.TeacherId)
                ],
                teacherOverrides
            )
    }

    var room = ""

    if (
        atom.RoomId !== null
        && atom.RoomId !== undefined
    ) {
        var roomObject =
            rooms[
                String(atom.RoomId)
            ]

        if (roomObject) {
            room =
                roomObject.Abbrev
                || roomObject.Name
                || ""
        }
    }

    var status = "normal"

    if (change) {
        status = change.status

        if (subject === "") {
            subject =
                status === "cancelled"
                ? "Canceled"
                : "Changed"
        }
    }

    return {
        hourId: hourId,
        start: atom.Start || 0,
        duration: atom.Duration || 1,

        subject: subject,
        teacher: teacher,
        room: room,

        status: status,
        change: change,

        groups: atom.GroupIds || [],
        cycles: atom.CycleIds || []
    }
}


function parseTimetable(
    data,
    teacherOverrides
) {
    teacherOverrides =
        teacherOverrides || {}

    var possibleHours =
        convertHours(
            data.Hours || []
        )

    var rawDays =
        data.Days || []

    var subjects =
        lookupById(
            data.Subjects || []
        )

    var teachers =
        lookupById(
            data.Teachers || []
        )

    var rooms =
        lookupById(
            data.Rooms || []
        )

    var longestNormalDay =
        getLongestNormalDay(
            rawDays,
            possibleHours
        )

    var fullDayFlags = []

    for (
        var i = 0;
        i < rawDays.length;
        i++
    ) {
        fullDayFlags.push(
            isFullDayEvent(
                rawDays[i],
                possibleHours,
                longestNormalDay
            )
        )
    }

    var usedHourIds =
        findUsedHourIds(
            rawDays,
            possibleHours,
            fullDayFlags
        )

    var hours = []
    var allowedHours = {}

    for (
        var h = 0;
        h < possibleHours.length;
        h++
    ) {
        var hour =
            possibleHours[h]

        if (usedHourIds[hour.id]) {
            hours.push(hour)
            allowedHours[hour.id] = true
        }
    }

    var days = []

    for (
        var dayIndex = 0;
        dayIndex < rawDays.length;
        dayIndex++
    ) {
        var rawDay =
            rawDays[dayIndex]

        var fullDay =
            fullDayFlags[dayIndex]

        var lessons = []

        if (!fullDay) {
            var atoms =
                rawDay.Atoms || []

            for (
                var atomIndex = 0;
                atomIndex < atoms.length;
                atomIndex++
            ) {
                var lesson =
                    convertAtom(
                        atoms[atomIndex],
                        allowedHours,
                        subjects,
                        teachers,
                        rooms,
                        teacherOverrides
                    )

                if (lesson !== null) {
                    lessons.push(lesson)
                }
            }
        }

        var description =
            rawDay.DayDescription || ""

        if (
            lessons.length === 0
            && !fullDay
            && String(description).trim()
                === ""
        ) {
            continue
        }

        days.push({
            dayOfWeek:
                rawDay.DayOfWeek,

            date:
                rawDay.Date || "",

            description:
                description,

            type:
                rawDay.DayType || "",

            allDayEvent:
                fullDay,

            eventText:
                fullDay
                ? fullDayEventText(
                    rawDay
                )
                : "",

            lessons:
                lessons
        })
    }

    var cycle = ""

    if (
        data.Cycles
        && data.Cycles.length > 0
    ) {
        cycle =
            data.Cycles[0].Abbrev
            || ""
    }

    return {
        cycle: cycle,
        hours: hours,
        days: days
    }
}
