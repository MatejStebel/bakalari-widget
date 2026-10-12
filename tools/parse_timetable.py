import json
from pathlib import Path


INPUT_FILE = Path("timetable.json")
OUTPUT_FILE = Path("parsed_timetable.json")
JS_OUTPUT_FILE = Path("parsed_timetable.js")
CONFIG_FILE = Path("teacher_config.json")

MAX_HOUR_CAPTION = 9


TITLES_BEFORE = {
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
}

TITLES_AFTER = {
    "ph.d.",
    "th.d.",
    "csc.",
    "drsc.",
    "mba",
    "mba.",
    "dis.",
    "ll.m."
}


def normalize_word(word):
    return word.strip(" ,")


def get_surname(full_name):
    words = full_name.split()
    cleaned = []

    for word in words:
        normalized = normalize_word(word)
        lower = normalized.lower()

        if lower in TITLES_BEFORE:
            continue

        if lower in TITLES_AFTER:
            continue

        cleaned.append(normalized)

    if not cleaned:
        return full_name

    return cleaned[-1]


def generate_abbreviation(full_name):
    surname = get_surname(full_name)

    if len(surname) <= 5:
        return surname

    return surname[:4]


def lookup_by_id(items):
    return {
        str(item["Id"]): item
        for item in items
    }


# --------------------------------------------------
# Teacher configuration
# --------------------------------------------------

def load_teacher_config():
    if not CONFIG_FILE.exists():
        return {"teachers": {}}

    try:
        with CONFIG_FILE.open(
            "r",
            encoding="utf-8"
        ) as file:
            data = json.load(file)

    except (json.JSONDecodeError, OSError):
        return {"teachers": {}}

    if "teachers" not in data:
        data["teachers"] = {}

    return data


def update_teacher_config(teachers, config):
    configured = config["teachers"]

    for teacher_id, teacher in teachers.items():
        name = teacher.get("Name", "")
        automatic = generate_abbreviation(name)

        if teacher_id not in configured:
            configured[teacher_id] = {
                "name": name,
                "automaticAbbreviation": automatic,
                "abbreviation": ""
            }

        else:
            configured[teacher_id]["name"] = name

            configured[teacher_id][
                "automaticAbbreviation"
            ] = automatic

            configured[teacher_id].setdefault(
                "abbreviation",
                ""
            )

    with CONFIG_FILE.open(
        "w",
        encoding="utf-8"
    ) as file:
        json.dump(
            config,
            file,
            ensure_ascii=False,
            indent=4
        )


def teacher_abbreviation(teacher, config):
    teacher_id = str(teacher["Id"])

    entry = config["teachers"].get(
        teacher_id
    )

    if entry is None:
        return generate_abbreviation(
            teacher.get("Name", "")
        )

    custom = entry.get(
        "abbreviation",
        ""
    ).strip()

    if custom:
        return custom

    return entry.get(
        "automaticAbbreviation",
        ""
    )


# --------------------------------------------------
# Lookup helpers
# --------------------------------------------------

def get_subject(subject_id, subjects):
    if subject_id is None:
        return ""

    subject = subjects.get(
        str(subject_id)
    )

    if subject is None:
        return ""

    return subject.get(
        "Abbrev",
        subject.get("Name", "")
    )


def get_room(room_id, rooms):
    if room_id is None:
        return ""

    room = rooms.get(
        str(room_id)
    )

    if room is None:
        return ""

    # Rooms deliberately use Bakaláři's abbreviation.
    return room.get(
        "Abbrev",
        room.get("Name", "")
    )


def get_teacher(
    teacher_id,
    teachers,
    config
):
    if teacher_id is None:
        return ""

    teacher = teachers.get(
        str(teacher_id)
    )

    if teacher is None:
        return ""

    return teacher_abbreviation(
        teacher,
        config
    )


# --------------------------------------------------
# Timetable conversion
# --------------------------------------------------

def convert_hours(raw_hours):
    result = []

    for hour in raw_hours:
        caption = str(
            hour.get("Caption", "")
        ).strip()

        try:
            hour_number = int(caption)
        except ValueError:
            continue

        if hour_number > MAX_HOUR_CAPTION:
            continue

        result.append({
            "id": str(hour["Id"]),
            "number": caption,
            "start": hour.get(
                "BeginTime",
                ""
            ),
            "end": hour.get(
                "EndTime",
                ""
            )
        })

    return result

def convert_change(change):
    if not isinstance(change, dict):
        return None

    change_type = str(
        change.get("ChangeType", "")
    )

    lower_type = change_type.lower()

    if lower_type in CANCELLED_CHANGE_TYPES:
        status = "cancelled"
    else:
        status = "changed"

    return {
        "type": change_type,

        "status": status,

        "displayType": change.get(
            "ChangeDisplayType",
            ""
        ),

        "description": change.get(
            "Description",
            ""
        ),

        "atomType": change.get(
            "AtomType",
            ""
        )
    }


def convert_atom(
    atom,
    allowed_hour_ids,
    subjects,
    teachers,
    rooms,
    config
):
    hour_id = str(
        atom.get("HourId", "")
    )

    if hour_id not in allowed_hour_ids:
        return None

    change = convert_change(
        atom.get("Change")
    )

    subject = get_subject(
        atom.get("SubjectId"),
        subjects
    )

    teacher = get_teacher(
        atom.get("TeacherId"),
        teachers,
        config
    )

    room = get_room(
        atom.get("RoomId"),
        rooms
    )

    status = "normal"

    if change is not None:
        status = change["status"]

        if not subject:
            if status == "cancelled":
                subject = "Canceled"
            else:
                subject = "Changed"

    return {
        "hourId": hour_id,

        "start": atom.get(
            "Start",
            0
        ),

        "duration": atom.get(
            "Duration",
            1
        ),

        "subject": subject,
        "teacher": teacher,
        "room": room,

        "status": status,

        "groups": [
            str(group_id)
            for group_id
            in atom.get("GroupIds", [])
        ],

        "cycles": [
            str(cycle_id)
            for cycle_id
            in atom.get("CycleIds", [])
        ],

        "change": change
    }


def convert_day(
    day,
    allowed_hour_ids,
    subjects,
    teachers,
    rooms,
    config,
    full_day
):

    lessons = []

    if not full_day:
        for atom in day.get(
            "Atoms",
            []
        ):
            lesson = convert_atom(
                atom,
                allowed_hour_ids,
                subjects,
                teachers,
                rooms,
                config
            )

            if lesson is not None:
                lessons.append(lesson)

    return {
        "dayOfWeek": day.get(
            "DayOfWeek"
        ),

        "date": day.get(
            "Date",
            ""
        ),

        "description": day.get(
            "DayDescription",
            ""
        ),

        "type": day.get(
            "DayType",
            ""
        ),

        "allDayEvent": full_day,

        "eventText": (
            full_day_event_text(day)
            if full_day
            else ""
        ),

        "lessons": lessons
    }

def atom_has_content(atom):
    if (
        atom.get("SubjectId") is not None
        or atom.get("TeacherId") is not None
        or atom.get("RoomId") is not None
    ):
        return True

    change = atom.get("Change")

    if isinstance(change, dict) and change:
        if (
            change.get("Description")
            or change.get("ChangeType")
            or change.get("ChangeDisplayType")
            or change.get("AtomType")
        ):
            return True

    if atom.get("Notice"):
        return True

    if atom.get("Theme"):
        return True

    if atom.get("LessonRelease"):
        return True

    return False


def is_normal_lesson(atom):
    return (
        atom.get("SubjectId") is not None
        or atom.get("TeacherId") is not None
        or atom.get("RoomId") is not None
    )



def full_day_event_text(day):
    description = str(
        day.get("DayDescription", "")
    ).strip()

    if description:
        return description

    for atom in day.get("Atoms", []):
        change = atom.get("Change")

        if isinstance(change, dict):
            text = str(
                change.get(
                    "Description",
                    ""
                )
            ).strip()

            if text:
                return text

        notice = str(
            atom.get("Notice", "")
        ).strip()

        if notice:
            return notice

    return "Event"

CANCELLED_CHANGE_TYPES = {
    "canceled",
    "removed"
}


def get_change_type(atom):
    change = atom.get("Change")

    if not isinstance(change, dict):
        return ""

    return str(
        change.get("ChangeType", "")
    ).strip().lower()


def has_direct_lesson(atom):
    return (
        atom.get("SubjectId") is not None
        or atom.get("TeacherId") is not None
        or atom.get("RoomId") is not None
    )


def get_atom_hour_ids(
    atom,
    possible_hours
):
    positions = {
        hour["id"]: index
        for index, hour
        in enumerate(possible_hours)
    }

    hour_id = str(
        atom.get("HourId", "")
    )

    if hour_id not in positions:
        return set()

    start_index = positions[hour_id]

    duration = int(
        atom.get("Duration", 1)
        or 1
    )

    result = set()

    for offset in range(duration):
        index = start_index + offset

        if index >= len(possible_hours):
            break

        result.add(
            possible_hours[index]["id"]
        )

    return result


def get_day_hour_ids(
    day,
    possible_hours,
    direct_only=False
):
    result = set()

    for atom in day.get("Atoms", []):
        if not atom_has_content(atom):
            continue

        if (
            direct_only
            and not has_direct_lesson(atom)
        ):
            continue

        result.update(
            get_atom_hour_ids(
                atom,
                possible_hours
            )
        )

    return result


def get_longest_normal_day(
    days,
    possible_hours
):
    valid_hour_ids = {
        hour["id"]
        for hour in possible_hours
    }

    longest = 0

    for day in days:
        used = set()

        for atom in day.get("Atoms", []):
            if not has_direct_lesson(atom):
                continue

            hour_id = str(
                atom.get("HourId", "")
            )

            if hour_id in valid_hour_ids:
                used.add(hour_id)

        longest = max(
            longest,
            len(used)
        )

    return longest


def is_full_day_event(
    day,
    possible_hours,
    longest_normal_day
):
    atoms = [
        atom
        for atom in day.get("Atoms", [])
        if atom_has_content(atom)
    ]

    day_type = str(
        day.get("DayType", "")
    )

    description = str(
        day.get("DayDescription", "")
    ).strip()

    # Holidays / director days etc.
    if (
        day_type in {
            "Holiday",
            "Celebration",
            "DirectorDay"
        }
        and not any(
            has_direct_lesson(atom)
            for atom in atoms
        )
    ):
        return True

    if not atoms:
        return bool(description)

    # A normal lesson means this should still be
    # rendered as a timetable day.
    if any(
        has_direct_lesson(atom)
        for atom in atoms
    ):
        return False

    covered_hours = get_day_hour_ids(
        day,
        possible_hours
    )

    # Change-only entry covering at least as many
    # hours as the longest real school day:
    # treat it as an all-day event.
    if (
        longest_normal_day > 0
        and len(covered_hours)
        >= longest_normal_day
    ):
        return True

    return False


def find_used_hour_ids(
    days,
    possible_hours,
    full_day_flags
):
    used = set()

    valid_hour_ids = {
        hour["id"]
        for hour in possible_hours
    }

    for index, day in enumerate(days):

        # Whole-day events have absolutely no
        # influence on visible timetable columns.
        if full_day_flags[index]:
            continue

        for atom in day.get("Atoms", []):
            if not atom_has_content(atom):
                continue

            hour_id = str(
                atom.get("HourId", "")
            )

            if hour_id in valid_hour_ids:
                used.add(hour_id)

    return used

def main():
    with INPUT_FILE.open(
        "r",
        encoding="utf-8"
    ) as file:
        data = json.load(file)

    teachers = lookup_by_id(
        data.get("Teachers", [])
    )

    subjects = lookup_by_id(
        data.get("Subjects", [])
    )

    rooms = lookup_by_id(
        data.get("Rooms", [])
    )

    config = load_teacher_config()

    update_teacher_config(
        teachers,
        config
    )

        # --------------------------
    # Possible hours
    # --------------------------

    possible_hours = convert_hours(
        data.get("Hours", [])
    )

    raw_days = data.get(
        "Days",
        []
    )

    # Find the longest REAL school day first.
    longest_normal_day = \
        get_longest_normal_day(
            raw_days,
            possible_hours
        )

    # Only after that determine which days
    # are all-day events.
    full_day_flags = [
        is_full_day_event(
            day,
            possible_hours,
            longest_normal_day
        )
        for day in raw_days
    ]

    used_hour_ids = find_used_hour_ids(
        raw_days,
        possible_hours,
        full_day_flags
    )

    hours = [
        hour
        for hour in possible_hours
        if hour["id"] in used_hour_ids
    ]

    allowed_hour_ids = {
        hour["id"]
        for hour in hours
    }

    # --------------------------
    # Cycle
    # --------------------------

    cycles = data.get(
        "Cycles",
        []
    )

    cycle = ""

    if cycles:
        cycle = cycles[0].get(
            "Abbrev",
            ""
        )

    # --------------------------
    # Days
    # --------------------------

        days = []

    for index, raw_day in enumerate(
        raw_days
    ):
        day = convert_day(
            raw_day,
            allowed_hour_ids,
            subjects,
            teachers,
            rooms,
            config,
            full_day_flags[index]
        )

        if (
            not day["lessons"]
            and not day["allDayEvent"]
            and not str(
                day["description"]
            ).strip()
        ):
            continue

        days.append(day)
    # --------------------------
    # Final widget data
    # --------------------------

    output = {
        "cycle": cycle,
        "hours": hours,
        "days": days
    }

    with OUTPUT_FILE.open(
        "w",
        encoding="utf-8"
    ) as file:
        json.dump(
            output,
            file,
            ensure_ascii=False,
            indent=4
        )
    with JS_OUTPUT_FILE.open(
        "w",
        encoding="utf-8"
    ) as file:
        file.write("var timetable = ")

        json.dump(
            output,
            file,
            ensure_ascii=False,
            indent=4
        )

        file.write(";\n")

    print(
        f"Created {OUTPUT_FILE}"
    )

    print(
        f"Hours: {len(hours)}"
    )

    print(
        f"Days: {len(days)}"
    )

    print(
        "Lessons:",
        sum(
            len(day["lessons"])
            for day in days
        )
    )


if __name__ == "__main__":
    main()
