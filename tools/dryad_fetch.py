# Dryad Anubis PoW bypass downloader
# 用法: python dryad_fetch.py <file_id> <output_path>
import hashlib, json, re, sys, time
import requests

UA = ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
      "(KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36")

def solve(random_data: str, difficulty: int):
    n_zero_bytes = difficulty // 2
    odd = difficulty % 2 != 0
    nonce = 0
    while True:
        h = hashlib.sha256((random_data + str(nonce)).encode()).digest()
        if h[:n_zero_bytes] == b"\x00" * n_zero_bytes and (not odd or h[n_zero_bytes] >> 4 == 0):
            return h.hex(), nonce
        nonce += 1

def fetch(file_id: str, out_path: str):
    s = requests.Session()
    s.headers.update({"User-Agent": UA, "Referer": "https://datadryad.org/"})
    target = f"https://datadryad.org/downloads/file_stream/{file_id}"
    r = s.get(target, timeout=60)
    if "anubis" not in r.text.lower() or "challenge" not in r.text:
        # 无挑战，直接是文件
        open(out_path, "wb").write(r.content)
        return "direct"
    m = re.search(r'<script id="anubis_challenge" type="application/json">(.*?)</script>', r.text, re.S)
    ch = json.loads(m.group(1))["challenge"]
    print(f"[pow] id={ch['id'][:8]}... difficulty={ch['difficulty']} method={ch['method']}")
    t0 = time.time()
    h, nonce = solve(ch["randomData"], ch["difficulty"])
    print(f"[pow] solved nonce={nonce} hash={h[:16]}... in {time.time()-t0:.1f}s")
    from urllib.parse import quote
    pc = (f"https://datadryad.org/.within.website/x/cmd/anubis/api/pass-challenge"
          f"?id={quote(ch['id'])}&response={h}&nonce={nonce}&redir={quote(target)}&elapsedTime=3000")
    r2 = s.get(pc, timeout=60, allow_redirects=False)
    print(f"[pass] {r2.status_code} location={r2.headers.get('Location', '')[:60]}")
    r3 = s.get(target, timeout=120, stream=True, allow_redirects=True)
    print(f"[file] status={r3.status_code} cd={r3.headers.get('Content-Disposition','')[:60]} len={r3.headers.get('Content-Length')}")
    r3.raise_for_status()
    done = 0
    with open(out_path, "wb") as f:
        for chunk in r3.iter_content(1 << 20):
            f.write(chunk)
            done += len(chunk)
            if done % (100 << 20) < (1 << 20):
                print(f"  {done/(1<<20):.0f} MiB", flush=True)
    return "pow"

if __name__ == "__main__":
    print(fetch(sys.argv[1], sys.argv[2]))
