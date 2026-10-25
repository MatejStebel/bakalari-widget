import json
import getpass
import urllib.parse
import urllib.request
import urllib.error
from datetime import date


BASE_URL = "https://marvdf.bakalari.cz:444"


username = input("Bakaláři username: ")
password = getpass.getpass("Bakaláři password: ")

login_data = urllib.parse.urlencode({
    "client_id": "ANDR",
    "grant_type": "password",
    "username": username,
    "password": password
}).encode()

login_request = urllib.request.Request(
    BASE_URL + "/api/login",
    data=login_data,
    headers={
        "Content-Type": "application/x-www-form-urlencoded"
    },
    method="POST"
)

try:
    with urllib.request.urlopen(login_request) as response:
        login_response = json.load(response)

except urllib.error.HTTPError as error:
    print("Login failed:")
    print(error.code, error.reason)
    print(error.read().decode())
    raise SystemExit(1)

access_token = login_response["access_token"]

print("Login successful!")

# Don't print the token.
print("Token received:", bool(access_token))


# -------------------------
# TIMETABLE
# -------------------------

today = date.today().isoformat()

timetable_request = urllib.request.Request(
    BASE_URL + "/api/3/timetable/actual?date=" + today,
    headers={
        "Authorization": "Bearer " + access_token
    }
)

try:
    with urllib.request.urlopen(timetable_request) as response:
        timetable = json.load(response)

except urllib.error.HTTPError as error:
    print("Timetable request failed:")
    print(error.code, error.reason)
    print(error.read().decode())
    raise SystemExit(1)


print("\nTimetable successfully received.\n")

with open("timetable.json", "w", encoding="utf-8") as file:
    json.dump(
        timetable,
        file,
        ensure_ascii=False,
        indent=4
    )

print("Saved to timetable.json")
