"""Edit/generate an image with the OpenAI images API using reference images. The key is read from the project's
.env and never printed. usage: python openai_edit.py out.png "prompt" ref1.png [ref2.png ...]
Set OPENAI_SIZE (for example 1536x1024) for a non-square picture, and OPENAI_MASK (a png the size of the first
image; transparent where it may be changed) to limit the edit to part of the first image."""
import base64
import os
import sys
from pathlib import Path

import requests

env = {}
for line in (Path(__file__).parents[1] / ".env").read_text(encoding="utf-8").splitlines():
    if "=" in line and not line.startswith("#"):
        k, v = line.split("=", 1)
        env[k.strip()] = v.strip().strip('"').strip("'")
key = env["OPENAI_API_KEY"]
out, prompt, refs = sys.argv[1], sys.argv[2], sys.argv[3:]
files = [("image[]", (Path(r).name, open(r, "rb"), "image/png")) for r in refs]
if os.environ.get("OPENAI_MASK"):
    files.append(("mask", ("mask.png", open(os.environ["OPENAI_MASK"], "rb"), "image/png")))
r = requests.post("https://api.openai.com/v1/images/edits",
                  headers={"Authorization": f"Bearer {key}"},
                  data={"model": "gpt-image-2.5-sunburst", "prompt": prompt, "quality": "low",
                         "size": os.environ.get("OPENAI_SIZE", "1024x1024")},
                  files=files, timeout=300)
if r.status_code != 200:
    print("FAIL", r.status_code, r.text[:400].replace(key, "<key>"))
    sys.exit(1)
Path(out).write_bytes(base64.b64decode(r.json()["data"][0]["b64_json"]))
print("ok", out)
