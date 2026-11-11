"""Check the notification inbox on the isolated Windows CI runner."""

import os
from pathlib import Path
import sqlite3
import sys
import xml.etree.ElementTree as ET


def main():
    tag, expected_text = sys.argv[1:]
    database = (
        Path(os.environ["LOCALAPPDATA"])
        / "Microsoft/Windows/Notifications/wpndatabase.db"
    )
    try:
        with sqlite3.connect(database.as_uri() + "?mode=ro", uri=True, timeout=0.2) as db:
            rows = db.execute(
                """
                SELECT n.Payload, n.ArrivalTime
                FROM Notification n
                JOIN NotificationHandler h ON h.RecordId = n.HandlerId
                WHERE h.PrimaryId = ? AND n.Tag = ? AND n.Type = 'toast'
                """,
                ("Apeh.MapRotation", tag),
            ).fetchall()
    except sqlite3.Error:
        return
    for payload, arrival in rows:
        if not payload or not arrival:
            continue
        try:
            texts = ET.fromstring(payload).itertext()
        except ET.ParseError:
            continue
        if expected_text in texts:
            print("Windows notification inbox")
            return


if __name__ == "__main__":
    main()
