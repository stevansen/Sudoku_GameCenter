"""Winziger Client für die App-Store-Connect-API.

Das Token hält 15 Minuten; `refresh()` erneuert es. Der private Schlüssel liegt
in ~/.appstoreconnect/private_keys und wird nur an das Swift-Skript gereicht.

    import asc
    asc.refresh()
    code, payload = asc.call('GET', '/v1/apps?limit=10')
"""
import json
import pathlib
import socket
import subprocess
import urllib.error
import urllib.request

BASE = 'https://api.appstoreconnect.apple.com'
ROOT = pathlib.Path(__file__).resolve().parent.parent
KEY_ID = 'D5BM7BM3H5'
ISSUER = '69a6de6f-1f1c-47e3-e053-5b8c7c11a4d1'
KEY = pathlib.Path.home() / f'.appstoreconnect/private_keys/AuthKey_{KEY_ID}.p8'
TOKEN = pathlib.Path('/tmp/asc.token')

socket.setdefaulttimeout(60)


def refresh():
    out = subprocess.run(
        ['swift', str(ROOT / 'Scripts/asc-token.swift'), str(KEY), KEY_ID, ISSUER],
        capture_output=True, text=True, check=True).stdout.strip().splitlines()[-1]
    TOKEN.write_text(out)
    return out


def token():
    if not TOKEN.exists():
        return refresh()
    return TOKEN.read_text().strip()


def call(method, path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    request = urllib.request.Request(BASE + path, data=data, method=method)
    request.add_header('Authorization', 'Bearer ' + token())
    if data:
        request.add_header('Content-Type', 'application/json')
    try:
        with urllib.request.urlopen(request) as response:
            raw = response.read()
            return response.status, (json.loads(raw) if raw else {})
    except urllib.error.HTTPError as error:
        raw = error.read()
        try:
            return error.code, json.loads(raw)
        except Exception:
            return error.code, {'raw': raw.decode(errors='replace')}


def problems(payload):
    return [f"{e.get('title')}: {e.get('detail')}" for e in payload.get('errors', [])]
