# app.py  (updated backup backend)
#
# What changed vs. the old backup:
#   1. Browser-like headers on every upstream request (gov sites often reject python-requests).
#   2. /api/farms and /api/bugs no longer fail silently: errors carry status / content-type / snippet.
#   3. NEW /api/bug-med-list  -> proxies /information/Query/BugMedList/ (generic table parser,
#      because I could not verify its HTML structure).
#   4. bug-farm-list / bug-farm-userange keep the old selectors, but fall back to a generic
#      table parser if the old selectors find nothing (site layout changed).
#   5. NEW /api/debug/probe -> fetch ANY upstream path and see exactly what comes back.
#   6. NEW MOCK mode (env MOCK=1) -> /api/farms and /api/bugs return sample data so you can
#      tell whether the Flutter UI works at all, independent of the upstream site.
#   7. Small fixes: duplicate import, bug_id int + str crash in /api/azai/bug-detail.
#
# Run:   python app.py            (real upstream)
#        MOCK=1 python app.py     (sample data for /api/farms and /api/bugs)
#        VERIFY_SSL=0 python app.py   (if you get SSLError from the gov site)

import json
import os
import re
from urllib.parse import parse_qs, urlparse

import requests
from bs4 import BeautifulSoup
from flask import Flask, jsonify, request

app = Flask(__name__)
app.config["JSON_AS_ASCII"] = False

BASE_URL = "https://pesticide.aphia.gov.tw"
Other_URL = "https://azai.tari.gov.tw/WebService/Data.asmx"

MOCK = os.getenv("MOCK", "0") == "1"
VERIFY_SSL = os.getenv("VERIFY_SSL", "1") != "0"
ENABLE_DEBUG = os.getenv("ENABLE_DEBUG", "0") == "1"

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
        "(KHTML, like Gecko) Chrome/124.0 Safari/537.36"
    ),
    "Accept": "application/json, text/html;q=0.9, */*;q=0.8",
    "Accept-Language": "zh-TW,zh;q=0.9,en;q=0.5",
    "Referer": BASE_URL + "/",
}

http = requests.Session()
http.headers.update(HEADERS)


# --------------------------------------------------------------------------
# helpers
# --------------------------------------------------------------------------
def clean_text(value):
    """清除 <i>、</i>、() 相關字元"""
    if not isinstance(value, str):
        return value
    value = re.sub(r"</?i>", "", value)
    return value.replace("(", "").replace(")", "")


def deep_clean(obj):
    """遞迴清洗所有字串內容"""
    if isinstance(obj, dict):
        return {k: deep_clean(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [deep_clean(i) for i in obj]
    if isinstance(obj, str):
        return clean_text(obj)
    return obj


def upstream_get(path, params=None, timeout=15):
    return http.get(
        BASE_URL + path, params=params, timeout=timeout, verify=VERIFY_SSL
    )


def describe(resp):
    """Short, JSON-safe description of an upstream response (for error messages)."""
    return {
        "status": resp.status_code,
        "final_url": resp.url,
        "content_type": resp.headers.get("Content-Type"),
        "snippet": resp.text[:300],
    }


def upstream_error(label, detail):
    return jsonify({"error": f"remote {label} failed", "detail": detail}), 502


def parse_tables(soup):
    """
    Generic parser: every <table> -> {columns, items}. Each row also gets "_links"
    (all <a href> in that row, with parsed query-string) so codes such as bug/farm ids
    can be recovered even when the layout changes.
    """
    out = []
    for table in soup.find_all("table"):
        header_cells = table.select("thead th")
        if not header_cells:
            first = table.find("tr")
            header_cells = first.find_all("th") if first else []
        labels = [th.get_text(" ", strip=True) for th in header_cells]
        keys = [lbl or f"col_{i}" for i, lbl in enumerate(labels)]

        body_rows = table.select("tbody tr") or table.find_all("tr")
        items = []
        for tr in body_rows:
            cells = tr.find_all(["th", "td"], recursive=False)
            if not cells:
                continue
            row = {}
            for i, cell in enumerate(cells):
                key = keys[i] if i < len(keys) else f"col_{i}"
                row[key] = cell.get_text(" ", strip=True)
            links = []
            for a in tr.find_all("a", href=True):
                href = a["href"]
                full = BASE_URL + href if href.startswith("/") else href
                links.append(
                    {
                        "text": a.get_text(" ", strip=True),
                        "url": full,
                        "query": {
                            k: v[0] for k, v in parse_qs(urlparse(href).query).items()
                        },
                    }
                )
            if links:
                row["_links"] = links
            items.append(row)

        out.append(
            {
                "columns": [{"key": k, "label": l} for k, l in zip(keys, labels)],
                "count": len(items),
                "items": items,
            }
        )
    return out


def page_title(soup):
    for sel in ("div.txt-block h2", "div.unit-title-block h2", "h2", "h1"):
        el = soup.select_one(sel)
        if el:
            return el.get_text(" ", strip=True)
    return None


# --------------------------------------------------------------------------
# azai helpers (unchanged)
# --------------------------------------------------------------------------
def login(session: requests.Session):
    url = f"{Other_URL}/loginacc"
    resp = session.post(
        url,
        json={"a1": "2"},
        headers={"Content-Type": "application/json; charset=utf-8"},
        timeout=10,
    )
    resp.raise_for_status()
    return resp


def parse_dotnet_json(resp: requests.Response):
    outer = resp.json()
    d = outer.get("d", "[]")
    try:
        return json.loads(d)
    except json.JSONDecodeError:
        return []


# --------------------------------------------------------------------------
# 0) health check  ->  open http://<host>:10000/ in a browser first
# --------------------------------------------------------------------------
@app.get("/")
def index():
    return jsonify({"ok": True, "mock": MOCK, "verify_ssl": VERIFY_SSL})


# --------------------------------------------------------------------------
# 1) farms / bugs lookup (JSON endpoints)
# --------------------------------------------------------------------------
MOCK_FARMS = [
    {"farmid": "D135901", "farmna": "紅龍果", "farmga": ""},
    {"farmid": "E215901", "farmna": "芭樂", "farmga": ""},
]
MOCK_BUGS = [
    {"instid": "A0301", "instn1": "粉介殼蟲類"},
    {"instid": "B30", "instn1": "炭疽病"},
]


def _json_lookup_tree(
    script_id, id_field, name_field, output_id_field, output_name_field,
    output_path_field, query, label, include_parent_matches=False,
):
    try:
        resp = upstream_get("/information/Query/Bug")
    except requests.RequestException as e:
        return upstream_error(label, str(e))

    if resp.status_code != 200:
        return upstream_error(label, describe(resp))

    soup = BeautifulSoup(resp.text, "html.parser")
    script = soup.find("script", id=script_id)
    if script is None:
        return upstream_error(label, f"Lookup tree {script_id} was not found.")

    try:
        tree = json.loads(script.string or script.get_text())
    except ValueError as e:
        return upstream_error(label, f"Lookup tree {script_id} was invalid JSON: {e}")

    if not isinstance(tree, list):
        return upstream_error(label, f"Lookup tree {script_id} was not a list.")

    normalized_query = query.casefold()
    items = []

    def visit(node):
        if not isinstance(node, dict):
            return

        children = node.get("Children")
        children = children if isinstance(children, list) else []
        item_id = str(node.get(id_field) or "").strip()
        name = str(node.get(name_field) or "").strip()
        path = str(node.get("HierarchyPath") or name).strip()
        if (
            item_id
            and name
            and (include_parent_matches or not children)
            and normalized_query in name.casefold()
        ):
            items.append(
                {
                    output_id_field: item_id,
                    output_name_field: name,
                    output_path_field: path,
                }
            )

        for child in children:
            visit(child)

    for node in tree:
        visit(node)

    return jsonify({label: query, "count": len(items), "items": items})


def _json_lookup(path, param_name, value, label, mock_items):
    if MOCK:
        return jsonify(
            {"mock": True, param_name: value, "count": len(mock_items), "items": mock_items}
        )
    try:
        resp = upstream_get(path, params={param_name: value})
    except requests.RequestException as e:
        return upstream_error(label, str(e))

    if resp.status_code != 200:
        return upstream_error(label, describe(resp))
    try:
        data = resp.json()
    except ValueError:
        return upstream_error(label + " (not JSON)", describe(resp))

    return jsonify({param_name: value, "count": len(data), "items": data})


@app.get("/api/farms")
def api_get_farms():
    farm_name = request.args.get("farm", default="火龍果")
    if MOCK:
        return _json_lookup(
            "/information/Query/GetFarm/", "farm", farm_name, "GetFarm", MOCK_FARMS
        )
    return _json_lookup_tree(
        "farmListData", "Farmid", "DisplayName", "farmid", "farmna", "farmga",
        farm_name, "farm",
    )


@app.get("/api/bugs")
def api_get_bugs():
    bug = request.args.get("bug", default="炭疽病")
    if MOCK:
        return _json_lookup(
            "/information/Query/GetBug/", "bug", bug, "GetBug", MOCK_BUGS
        )
    return _json_lookup_tree(
        "bugListData", "Instid", "DisplayName", "instid", "instn1", "hierarchy",
        bug, "bug", include_parent_matches=True,
    )


# --------------------------------------------------------------------------
# 2) BugFarmList  (HTML -> JSON)
#    GET /api/bug-farm-list?farm=E215901,D135901&bug=&flag=&userange=
# --------------------------------------------------------------------------
@app.get("/api/bug-farm-list")
def api_bug_farm_list():
    params = {
        "flag": request.args.get("flag", ""),
        "farm": request.args.get("farm", ""),
        "bug": request.args.get("bug", ""),
        "userange": request.args.get("userange", ""),
    }
    try:
        resp = upstream_get("/information/Query/BugFarmList/", params=params)
    except requests.RequestException as e:
        return upstream_error("BugFarmList", str(e))
    if resp.status_code != 200:
        return upstream_error("BugFarmList", describe(resp))

    soup = BeautifulSoup(resp.text, "html.parser")
    title = page_title(soup)

    # --- old selectors (same output shape the Flutter page expects) ---
    rows = []
    for tr in soup.select("div.table-data-list tbody tr"):
        tds = tr.find_all("td")
        if len(tds) < 2:
            continue
        crop_name = tds[0].get_text(strip=True)
        bug_a = tds[1].find("a")
        if bug_a:
            bug_name = bug_a.get_text(strip=True)
            bug_href = bug_a.get("href", "")
        else:
            bug_name = tds[1].get_text(strip=True)
            bug_href = ""

        bug_code = farm_code = full_url = None
        if bug_href:
            full_url = BASE_URL + bug_href if bug_href.startswith("/") else bug_href
            qs = parse_qs(urlparse(bug_href).query)
            bug_code = qs.get("bug", [None])[0]
            farm_code = qs.get("farm", [None])[0]

        rows.append(
            {
                "crop_name": crop_name,
                "bug_name": bug_name,
                "bug_code": bug_code,
                "farm_code": farm_code,
                "bug_url": full_url,
            }
        )

    parser = "legacy"

    # --- fallback: layout changed, use generic tables ---
    if not rows:
        parser = "generic"
        for t in parse_tables(soup):
            for it in t["items"]:
                links = it.get("_links", [])
                first_link = links[0] if links else {}
                q = first_link.get("query", {})
                vals = [v for k, v in it.items() if k != "_links"]
                rows.append(
                    {
                        "crop_name": vals[0] if vals else "",
                        "bug_name": vals[1] if len(vals) > 1 else "",
                        "bug_code": q.get("bug"),
                        "farm_code": q.get("farm"),
                        "bug_url": first_link.get("url"),
                    }
                )

    return jsonify(
        {
            "title": title,
            "params": params,
            "parser": parser,
            "count": len(rows),
            "items": rows,
        }
    )


# --------------------------------------------------------------------------
# 3) BugMedList  (NEW)  -- structure unverified, so output is generic.
#    GET /api/bug-med-list?<same query params you would send upstream>
#    e.g. /api/bug-med-list?flag=&farm=D135901&bug=A0301
# --------------------------------------------------------------------------
@app.get("/api/bug-med-list")
def api_bug_med_list():
    params = request.args.to_dict()
    try:
        resp = upstream_get("/information/Query/BugMedList/", params=params)
    except requests.RequestException as e:
        return upstream_error("BugMedList", str(e))
    if resp.status_code != 200:
        return upstream_error("BugMedList", describe(resp))

    soup = BeautifulSoup(resp.text, "html.parser")
    tables = parse_tables(soup)
    # flatten to a single "items" list (first non-empty table) for easy Flutter use
    main = next((t for t in tables if t["count"] > 0), None)
    columns = main["columns"] if main else []
    items = (
        [
            {key: value for key, value in item.items() if key != "_links"}
            for item in main["items"]
        ]
        if main
        else []
    )

    return jsonify(
        {
            "title": page_title(soup),
            "params": params,
            "columns": columns,
            "count": len(items),
            "items": items,
        }
    )


# --------------------------------------------------------------------------
# 4) BugFarmUserange  (HTML -> JSON)
#    GET /api/bug-farm-userange?farm=D135901&bug=A0301
# --------------------------------------------------------------------------
HEADER_MAP = {
    "作物名稱": "crop_name",
    "病蟲名稱": "bug_name",
    "普通名稱": "common_name",
    "含量": "content",
    "劑型代碼": "formulation_code",
    "每公頃每次用量": "dose_per_hectare",
    "稀釋倍數": "dilution_factor",
    "使用時期": "usage_timing",
    "施藥間隔": "spray_interval",
    "施用次數": "spray_times",
    "安全採收期": "pre_harvest_interval",
    "施藥方法": "spray_method",
    "注意事項": "precautions",
    "說明": "description",
    "核准日期": "approved_date",
    "原始登記廠商名稱": "registrant",
}


@app.get("/api/bug-farm-userange")
def api_bug_farm_userange():
    params = {
        "flag": request.args.get("flag", ""),
        "farm": request.args.get("farm", ""),
        "bug": request.args.get("bug", ""),
    }
    try:
        resp = upstream_get("/information/Query/BugFarmUserange/", params=params)
    except requests.RequestException as e:
        return upstream_error("BugFarmUserange", str(e))
    if resp.status_code != 200:
        return upstream_error("BugFarmUserange", describe(resp))

    soup = BeautifulSoup(resp.text, "html.parser")

    summary_text = total_count = None
    for div in soup.select("div.txt-block"):
        text = div.get_text(strip=True)
        if "總計有" in text and "筆資料符合您的查詢條件" in text:
            summary_text = text
            m = re.search(r"總計有\s*(\d+)\s*筆", text)
            if m:
                total_count = int(m.group(1))
            break

    title_el = soup.select_one("div.unit-title-block h2")
    title = title_el.get_text(strip=True) if title_el else page_title(soup)

    header_cells = soup.select("div.unit-info-block thead tr th")
    headers, header_keys = [], []
    for idx, th in enumerate(header_cells):
        label = th.get_text(strip=True)
        headers.append(label)
        header_keys.append(HEADER_MAP.get(label) or f"col_{idx}")

    items = []
    for tr in soup.select("div.unit-info-block tbody tr"):
        cells = tr.find_all(["th", "td"], recursive=False)
        if not cells:
            continue
        row = {}
        for i, cell in enumerate(cells):
            if i >= len(header_keys):
                break
            row[header_keys[i]] = cell.get_text(strip=True)
        items.append(row)

    parser = "legacy"
    columns = [{"key": k, "label": l} for k, l in zip(header_keys, headers)]

    # fallback: generic tables, still mapping known Chinese headers to English keys
    if not items:
        parser = "generic"
        main = next((t for t in parse_tables(soup) if t["count"] > 0), None)
        if main:
            columns = [
                {"key": HEADER_MAP.get(c["label"], c["key"]), "label": c["label"]}
                for c in main["columns"]
            ]
            for it in main["items"]:
                items.append(
                    {
                        HEADER_MAP.get(k, k): v
                        for k, v in it.items()
                        if k != "_links"
                    }
                )

    if total_count is None:
        total_count = len(items)

    return jsonify(
        {
            "title": title,
            "summary": {"raw_text": summary_text, "total": total_count},
            "params": params,
            "parser": parser,
            "columns": columns,
            "count": len(items),
            "items": items,
        }
    )


# --------------------------------------------------------------------------
# 5) DEBUG PROBE (NEW) -- see exactly what any upstream path returns.
#    /api/debug/probe?path=/information/Query/BugMedList/&farm=D135901&bug=A0301
#    /api/debug/probe?path=/information/Query/GetFarm/&farm=火龍果
#    Everything except "path" and "raw" is forwarded as query params.
#    Add &raw=1 to get the full body (text) instead of a 2000-char preview.
# --------------------------------------------------------------------------
@app.get("/api/debug/probe")
def debug_probe():
    if not ENABLE_DEBUG:
        return jsonify({"error": "debug disabled"}), 404

    path = request.args.get("path", "")
    if not path.startswith("/"):
        return jsonify({"error": "path must start with '/'"}), 400

    params = {k: v for k, v in request.args.items() if k not in ("path", "raw")}
    try:
        resp = upstream_get(path, params=params or None)
    except requests.RequestException as e:
        return jsonify({"error": "request failed", "detail": str(e)}), 502

    body = resp.text
    soup = BeautifulSoup(body, "html.parser") if "html" in (
        resp.headers.get("Content-Type", "").lower()
    ) else None

    return jsonify(
        {
            "requested": resp.request.url,
            "status": resp.status_code,
            "final_url": resp.url,
            "redirects": [r.url for r in resp.history],
            "content_type": resp.headers.get("Content-Type"),
            "length": len(body),
            "is_json": _is_json(body),
            "title": page_title(soup) if soup else None,
            "tables_found": len(soup.find_all("table")) if soup else None,
            "body": body if request.args.get("raw") == "1" else body[:2000],
        }
    )


def _is_json(text):
    try:
        json.loads(text)
        return True
    except ValueError:
        return False


# --------------------------------------------------------------------------
# azai proxies (logic unchanged)
# --------------------------------------------------------------------------
@app.route("/api/azai/search", methods=["POST"])
def search_result():
    body = request.get_json(silent=True) or {}
    term = body.get("term")
    ty = body.get("ty", "y,y,y,y,y,y")
    if not term:
        return jsonify({"error": "term 為必填欄位"}), 400

    with requests.Session() as s:
        login(s)
        resp = s.post(
            f"{Other_URL}/searchResult",
            json={"term": term, "ty": ty},
            headers={"Content-Type": "application/json; charset=utf-8"},
            timeout=15,
        )
        resp.raise_for_status()
        data = deep_clean(parse_dotnet_json(resp))

        for item in data:
            bug_id = item.get("id")
            pic_name = item.get("pic")
            item["refer"] = "農業病蟲害智能管理決策系統"
            if bug_id and pic_name:
                item["pic"] = (
                    f"https://azai.tari.gov.tw/BugFile/{bug_id}/pic/圖鑑/{pic_name}"
                )
            else:
                item["pic"] = None

        if body.get("summary") is True:
            summary_fields = (
                "id",
                "CName",
                "SName",
                "Peculiarity",
                "Harm",
                "HarmDatail",
                "pic",
            )
            data = [
                {key: item.get(key) for key in summary_fields}
                for item in data
            ]

        return jsonify({"data": data})


@app.route("/api/azai/bug-pics", methods=["POST"])
def bug_pic_list():
    body = request.get_json(silent=True) or {}
    bug_id = body.get("bug_id")
    if not bug_id:
        return jsonify({"error": "bug_id 為必填欄位"}), 400

    with requests.Session() as s:
        login(s)
        resp = s.post(
            f"{Other_URL}/bugPicList",
            json={"a1": str(bug_id), "a2": "pic"},
            headers={"Content-Type": "application/json; charset=utf-8"},
            timeout=15,
        )
        resp.raise_for_status()
        data = parse_dotnet_json(resp)

        style = "圖鑑"
        for item in data:
            Bid, name, ext = item.get("Bid"), item.get("Name"), item.get("Type")
            if Bid and name and ext:
                item["image_url"] = (
                    f"https://azai.tari.gov.tw/BugFile/{Bid}/pic/{style}/{name}{ext}"
                )
            else:
                item["image_url"] = None
            style = "危害照片"

        return jsonify({"data": data})


@app.route("/api/azai/bug-detail", methods=["POST"])
def bug_detail():
    body = request.get_json(silent=True) or {}
    bug_id = body.get("bug_id")
    if not bug_id:
        return jsonify({"error": "bug_id 為必填欄位"}), 400

    with requests.Session() as s:
        login(s)
        resp = s.post(
            f"{Other_URL}/loadDetail",
            json={"n1": str(bug_id)},
            headers={"Content-Type": "application/json; charset=utf-8"},
            timeout=15,
        )
        resp.raise_for_status()
        cleaned = deep_clean(parse_dotnet_json(resp))

        for item in cleaned:
            item["refer"] = "農業病蟲害智能管理決策系統"
            item["url"] = "https://azai.tari.gov.tw/search/bug/detail?id=" + str(bug_id)

        return jsonify({"data": cleaned})


if __name__ == "__main__":
    # Local testing only. In production the host runs gunicorn (see requirements.txt),
    # which imports `app` directly and never reaches this block.
    app.run(host="127.0.0.1", port=int(os.getenv("PORT", "10000")), debug=False)