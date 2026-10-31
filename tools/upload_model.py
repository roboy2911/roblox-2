"""Uploads a model file (FBX) to Roblox as a Model asset using Open Cloud.

Needs these environment variables:
    ROBLOX_API_KEY   Open Cloud key with asset read + write
    ROBLOX_USER_ID   the user that will own the asset

Usage:
    python tools/upload_model.py path/to/Model.fbx "Display Name" ["description"]

Prints the new asset ID when Roblox finishes processing.
"""

import json
import mimetypes
import os
import sys
import time
import urllib.error
import urllib.request
import uuid

API = "https://apis.roblox.com/assets/v1"


def request(method, url, body=None, headers=None):
    req = urllib.request.Request(url, data=body, method=method, headers=headers or {})
    req.add_header("x-api-key", os.environ["ROBLOX_API_KEY"])
    try:
        with urllib.request.urlopen(req) as resp:
            return json.load(resp)
    except urllib.error.HTTPError as err:
        sys.exit(f"{method} {url} failed: {err.code} {err.read().decode(errors='replace')}")


def upload(path, name, description):
    meta = {
        "assetType": "Model",
        "displayName": name,
        "description": description,
        "creationContext": {"creator": {"userId": str(os.environ["ROBLOX_USER_ID"])}},
    }
    content_type = "model/fbx" if path.lower().endswith(".fbx") else mimetypes.guess_type(path)[0]
    boundary = uuid.uuid4().hex
    with open(path, "rb") as f:
        data = f.read()
    body = b"".join([
        f"--{boundary}\r\n".encode(),
        b'Content-Disposition: form-data; name="request"\r\nContent-Type: application/json\r\n\r\n',
        json.dumps(meta).encode(),
        f"\r\n--{boundary}\r\n".encode(),
        f'Content-Disposition: form-data; name="fileContent"; filename="{os.path.basename(path)}"\r\n'.encode(),
        f"Content-Type: {content_type}\r\n\r\n".encode(),
        data,
        f"\r\n--{boundary}--\r\n".encode(),
    ])
    op = request("POST", f"{API}/assets", body, {"Content-Type": f"multipart/form-data; boundary={boundary}"})

    for _ in range(60):
        if op.get("done"):
            break
        time.sleep(2)
        op = request("GET", f"{API}/{op['path']}")
    if not op.get("done"):
        sys.exit(f"Timed out waiting for Roblox to process the upload: {op}")
    if "error" in op:
        sys.exit(f"Upload failed: {op['error']}")
    return op["response"]["assetId"]


if __name__ == "__main__":
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    asset_id = upload(sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else "")
    print(asset_id)
