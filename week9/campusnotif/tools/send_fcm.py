"""Kirim notifikasi uji FCM HTTP v1 untuk Campus Notify.

Dipakai untuk menguji tiga app state (foreground/background/terminated) dengan
payload yang persis sama, tanpa bergantung pada UI Firebase Console.

Prasyarat:
    .secrets/service-account.json  (Project settings -> Service accounts ->
                                    Generate new private key)

Pakai:
    python tools/send_fcm.py                 # kirim ke topik pengumuman-kampus
    python tools/send_fcm.py --id 7          # id pengumuman lain
    python tools/send_fcm.py --token <FCM>   # kirim ke satu perangkat
    python tools/send_fcm.py --data-only     # tanpa blok notification
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import requests
from google.auth.transport.requests import Request
from google.oauth2 import service_account

SCOPES = ["https://www.googleapis.com/auth/firebase.messaging"]
ROOT = Path(__file__).resolve().parent.parent
CREDENTIALS = ROOT / ".secrets" / "service-account.json"

TOPIC = "pengumuman-kampus"
CHANNEL_ID = "pengumuman"


def access_token() -> tuple[str, str]:
    """Kembalikan (token, project_id) dari service account."""
    if not CREDENTIALS.exists():
        sys.exit(
            f"Service account tidak ditemukan: {CREDENTIALS}\n"
            "Unduh dari Firebase Console -> Project settings -> "
            "Service accounts -> Generate new private key."
        )

    creds = service_account.Credentials.from_service_account_file(
        str(CREDENTIALS), scopes=SCOPES
    )
    creds.refresh(Request())
    token = creds.token
    project_id = creds.project_id
    if not token or not project_id:
        sys.exit("Gagal memperoleh access token dari service account.")
    return str(token), str(project_id)


def build_message(
    *,
    announcement_id: str,
    token: str | None,
    with_notification: bool,
) -> dict:
    data = {
        "route": f"/pengumuman/{announcement_id}",
        "id": announcement_id,
    }

    message: dict = {
        "data": data,
        "android": {
            "priority": "high",
            "notification": {"channel_id": CHANNEL_ID},
        },
    }

    if token:
        message["token"] = token
    else:
        message["topic"] = TOPIC

    if with_notification:
        message["notification"] = {
            "title": "Jadwal kuliah berubah",
            "body": f"Kelas Mobile pindah ke Ruang A2 jam 13.00 (id {announcement_id})",
        }

    return message


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--id", default="3", help="id pengumuman (default: 3)")
    parser.add_argument("--token", default=None, help="kirim ke satu token")
    parser.add_argument(
        "--data-only",
        action="store_true",
        help="kirim tanpa blok notification (menguji handler data)",
    )
    args = parser.parse_args()

    bearer, project_id = access_token()
    url = f"https://fcm.googleapis.com/v1/projects/{project_id}/messages:send"
    payload = {
        "message": build_message(
            announcement_id=args.id,
            token=args.token,
            with_notification=not args.data_only,
        )
    }

    target = args.token[:12] + "..." if args.token else f"topic {TOPIC}"
    print(f"project : {project_id}")
    print(f"target  : {target}")
    print(f"data    : {payload['message']['data']}")
    print(f"channel : {CHANNEL_ID}")

    response = requests.post(
        url,
        headers={
            "Authorization": f"Bearer {bearer}",
            "Content-Type": "application/json; UTF-8",
        },
        json=payload,
        timeout=30,
    )

    print(f"HTTP    : {response.status_code}")
    print(response.text)

    if response.status_code != 200:
        sys.exit(1)


if __name__ == "__main__":
    main()
