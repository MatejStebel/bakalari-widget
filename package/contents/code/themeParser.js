var DEFAULT_THEME = {
    cyaneaTheme: {
        primary: "1F6F5C",
        accent: "7FD1B9",
        background: "101513"
    },
    cABg: "18201D",
    cAPrimaryText: "E3EAE6",
    cARoomText: "9FB0A8",
    cASecondaryText: "9FB0A8",
    cChngBg: "7A5A18",
    cChngPrimaryText: "FFFFFF",
    cChngRoomText: "FFFFFF",
    cChngSecondaryText: "FFF4D6",
    cHBg: "1F6F5C",
    cHPrimaryText: "FFFFFF",
    cHRoomText: "D3EBE3",
    cHSecondaryText: "BDEBDD",
    cEmptyBg: "121916",
    cError: "B3261E",
    cHeaderBg: "101513",
    cHeaderPrimaryText: "7FD1B9",
    cHeaderSecondaryText: "9FB0A8",
    cDivider: "2E3A35",
    cHighlight: "7FD1B9",
    cHomework: "7FD1B9",
    cInfolineBg: "18201D",
    cInfolineText: "E3EAE6",
    dpDividerWidth: 1,
    dpHighlightWidth: 2,
    dpHomework: 5,
    dpPaddingBottom: 3,
    dpPaddingLeft: 3,
    dpPaddingRight: 3,
    dpPaddingTop: 3,
    dpTextPadding: 2,
    spInfolineTextSize: 12,
    spPrimaryText: 18,
    spSecondaryText: 12
}

function isColor(value) {
    return typeof value === "string"
        && /^[0-9a-fA-F]{6}$/.test(value)
}

function copyTheme(source) {
    var result = JSON.parse(JSON.stringify(DEFAULT_THEME))

    if (!source || typeof source !== "object" || Array.isArray(source)) {
        return result
    }

    for (var key in DEFAULT_THEME) {
        if (key === "cyaneaTheme") {
            continue
        }

        if (typeof DEFAULT_THEME[key] === "number") {
            var numeric = Number(source[key])
            if (isFinite(numeric) && numeric >= 0) {
                result[key] = numeric
            }
        } else if (isColor(source[key])) {
            result[key] = source[key].toUpperCase()
        }
    }

    if (source.cyaneaTheme
            && typeof source.cyaneaTheme === "object") {
        ["primary", "accent", "background"].forEach(function(key) {
            if (isColor(source.cyaneaTheme[key])) {
                result.cyaneaTheme[key] =
                    source.cyaneaTheme[key].toUpperCase()
            }
        })
    }

    return result
}

function parseTheme(json) {
    try {
        return {
            valid: true,
            theme: copyTheme(JSON.parse(String(json || ""))),
            error: ""
        }
    } catch (error) {
        return {
            valid: false,
            theme: copyTheme(null),
            error: "Invalid theme JSON"
        }
    }
}

function defaultThemeJson() {
    return JSON.stringify(DEFAULT_THEME, null, 2)
}
