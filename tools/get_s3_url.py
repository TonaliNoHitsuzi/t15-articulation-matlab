# 过 Anubis 后提取 S3 预签名直链, 供 aria2 多线程下载
import hashlib, json, re, sys, time
import requests

UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36")

def solve(random_data, difficulty):
    nzb = difficulty // 2
    odd = difficulty % 2 != 0
    nonce = 0
    while True:
        h = hashlib.sha256((random_data + str(nonce)).encode()).digest()
        if h[:nzb] == b"\x00" * nzb and (not odd or h[nzb] >> 4 == 0):
            return h.hex(), nonce
        nonce += 1

def get_s3_url(file_id):
    s = requests.Session()
    s.headers.update({"User-Agent": UA, "Referer": "https://datadryad.org/"})
    target = f"https://datadryad.org/downloads/file_stream/{file_id}"
    r = s.get(target, timeout=60, allow_redirects=False)
    if r.status_code in (301, 302) and "Location" in r.headers:
        return r.headers["Location"]
    m = re.search(r'<script id="anubis_challenge" type="application/json">(.*?)</script>', r.text, re.S)
    ch = json.loads(m.group(1))["challenge"]
    print(f"[pow] difficulty={ch['difficulty']}", flush=True)
    h, nonce = solve(ch["randomData"], ch["difficulty"])
    from urllib.parse import quote
    pc = (f"https://datadryad.org/.within.website/x/cmd/anubis/api/pass-challenge"
          f"?id={quote(ch['id'])}&response={h}&nonce={nonce}&redir={quote(target)}&elapsedTime=3000")
    r2 = s.get(pc, timeout=60, allow_redirects=False)
    r3 = s.get(target, timeout=60, allow_redirects=False)
    if r3.status_code not in (301, 302):
        raise RuntimeError(f"no redirect: {r3.status_code} {r3.text[:200]}")
    return r3.headers["Location"]

if __name__ == "__main__":
    print(get_s3_url(sys.argv[1]))
