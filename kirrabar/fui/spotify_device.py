#!/usr/bin/env python3
import json
import os
import shutil
import sqlite3
import sys
import tempfile
import urllib.error
import urllib.request
from hashlib import pbkdf2_hmac
from pathlib import Path

HOSTS = (".spotify.com", "open.spotify.com", "accounts.spotify.com")
NAMES = ("sp_dc", "sp_key")
UA = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/146.0.0.0 Safari/537.36"


def cookie_paths():
    home = Path.home()
    roots = [
        home / ".cache/spotify/Default",
        home / ".cache/spotify/Default/Network",
        home / ".cache/spotify/Browser/Default",
        home / ".cache/spotify/Browser/Default/Network",
        home / ".config/spotify",
    ]
    out = []
    for root in roots:
        for name in ("Cookies", "cookies.sqlite"):
            p = root / name
            if p.is_file():
                out.append(p)
    return out


def unpad(buf: bytes) -> bytes:
    if not buf:
        return buf
    n = buf[-1]
    if 1 <= n <= 16:
        return buf[:-n]
    return buf


def decrypt_value(raw: bytes) -> str:
    if not raw:
        return ""
    if raw.startswith(b"v10") or raw.startswith(b"v11"):
        payload = raw[3:]
        try:
            from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
        except Exception:
            return ""
        key = pbkdf2_hmac("sha1", b"peanuts", b"saltysalt", 1, dklen=16)
        dec = Cipher(algorithms.AES(key), modes.CBC(b" " * 16)).decryptor()
        try:
            plain = unpad(dec.update(payload) + dec.finalize())
            return plain.decode("utf-8", "ignore")
        except Exception:
            return ""
    try:
        return raw.decode("utf-8", "ignore")
    except Exception:
        return ""


def load_cookies():
    found = {}
    for path in cookie_paths():
        tmp = None
        try:
            fd, tmp = tempfile.mkstemp(prefix="spcook-")
            os.close(fd)
            shutil.copy2(path, tmp)
            con = sqlite3.connect(tmp)
            cur = con.cursor()
            cur.execute(
                "SELECT host_key, name, value, encrypted_value FROM cookies "
                "WHERE name IN (?, ?)",
                NAMES,
            )
            for host, name, value, enc in cur.fetchall():
                host = host or ""
                if not any(h in host for h in HOSTS):
                    continue
                val = (value or "").strip() or decrypt_value(enc or b"")
                if val and name not in found:
                    found[name] = val
            con.close()
        except Exception:
            pass
        finally:
            if tmp:
                try:
                    os.unlink(tmp)
                except Exception:
                    pass
        if "sp_dc" in found:
            break
    return found


def get_json(url, headers):
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req, timeout=8) as resp:
        return json.loads(resp.read().decode("utf-8", "ignore") or "{}")


def access_token(cookies):
    dc = cookies.get("sp_dc")
    if not dc:
        return ""
    cookie = "sp_dc=" + dc
    if cookies.get("sp_key"):
        cookie += "; sp_key=" + cookies["sp_key"]
    headers = {
        "User-Agent": UA,
        "Accept": "application/json",
        "Cookie": cookie,
        "App-Platform": "WebPlayer",
        "Referer": "https://open.spotify.com/",
    }
    try:
        data = get_json(
            "https://open.spotify.com/get_access_token?reason=transport&productType=web_player",
            headers,
        )
    except Exception:
        return ""
    tok = data.get("accessToken") or data.get("access_token") or ""
    return tok if isinstance(tok, str) else ""


def player_device(token):
    headers = {
        "User-Agent": UA,
        "Accept": "application/json",
        "Authorization": "Bearer " + token,
    }
    try:
        data = get_json("https://api.spotify.com/v1/me/player", headers)
    except urllib.error.HTTPError:
        return "", ""
    except Exception:
        return "", ""
    if not isinstance(data, dict):
        return "", ""
    dev = data.get("device") or {}
    if not isinstance(dev, dict):
        return "", ""
    name = str(dev.get("name") or "").strip()
    kind = str(dev.get("type") or "").strip()
    return name, kind


def main():
    cookies = load_cookies()
    token = access_token(cookies)
    if not token:
        return
    name, kind = player_device(token)
    if not name:
        return
    sys.stdout.write(name + "\t" + kind + "\n")
    sys.stdout.flush()


if __name__ == "__main__":
    main()
