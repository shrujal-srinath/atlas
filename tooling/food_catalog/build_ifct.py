#!/usr/bin/env python3
"""
Build an ATLAS food_catalog seed from IFCT 2017 (Indian Food Composition Tables).

Source: @ifct2017/compositions v2.0.9 (MIT, © Subhajit Sahu); underlying data
is IFCT 2017 by ICMR–National Institute of Nutrition. 542 foods, full micros.

Output: ifct_catalog.json — rows matching the public.food_catalog schema, with
parsed regional-name aliases and category-derived household measures.

Run:  python3 build_ifct.py
"""
import csv, json, os, re, subprocess, sys, urllib.request, tarfile, io

HERE = os.path.dirname(os.path.abspath(__file__))
CSV = os.path.join(HERE, "ifct_index.csv")
OUT = os.path.join(HERE, "ifct_catalog.json")
TARBALL = "https://registry.npmjs.org/@ifct2017/compositions/-/compositions-2.0.9.tgz"

# IFCT energy is kJ; minerals & vitamins are stored in GRAMS per 100 g.
KJ_TO_KCAL = 1 / 4.184

def ensure_csv():
    if os.path.exists(CSV):
        return
    print("downloading IFCT tarball…")
    data = urllib.request.urlopen(TARBALL, timeout=60).read()
    with tarfile.open(fileobj=io.BytesIO(data), mode="r:gz") as t:
        member = t.getmember("package/index.csv")
        with t.extractfile(member) as f, open(CSV, "wb") as out:
            out.write(f.read())

# ── household measures by IFCT food group ──────────────────────────────
# Every food also gets an implicit {g:1}. Values are grams per 1 unit.
GROUP_MEASURES = {
    "Cereals and Millets":        [("Katori", 150), ("Bowl", 200), ("Cup", 180)],
    "Grain Legumes":              [("Katori", 150), ("Bowl", 200)],
    "Green Leafy Vegetables":     [("Cup", 100), ("Katori", 100)],
    "Other Vegetables":           [("Katori", 120), ("Cup", 150), ("Piece", 50)],
    "Roots and Tubers":           [("Katori", 130), ("Piece", 60)],
    "Fruits":                     [("Piece", 120), ("Cup", 150), ("Katori", 100)],
    "Milk and Milk Products":     [("Glass", 200), ("Katori", 150), ("Cup", 240), ("Tbsp", 15)],
    "Nuts and Oil Seeds":         [("Handful", 30), ("Tbsp", 10), ("Piece", 5)],
    "Condiments and Spices":      [("Tsp", 5), ("Tbsp", 10)],
    "Spices and Condiments":      [("Tsp", 5), ("Tbsp", 10)],
    "Fats and Oils":              [("Tbsp", 14), ("Tsp", 5)],
    "Sugars":                     [("Tbsp", 12), ("Tsp", 5)],
    "Egg and Egg Products":       [("Piece", 50), ("Katori", 120)],
    "Poultry":                    [("Piece", 100), ("Katori", 150)],
    "Animal Meat":                [("Piece", 100), ("Katori", 150)],
    "Marine Fish":                [("Piece", 100), ("Katori", 150)],
    "Marine Shellfish":           [("Katori", 120), ("Piece", 40)],
    "Fresh Water Fish":           [("Piece", 100), ("Katori", 150)],
    "Mushrooms":                  [("Cup", 70), ("Katori", 100)],
    "Beverages":                  [("Glass", 250), ("Cup", 200)],
}
DEFAULT_MEASURES = [("Katori", 150), ("Bowl", 200), ("Cup", 240), ("Piece", 50)]

STAPLE_GROUPS = {
    "Cereals and Millets", "Grain Legumes", "Milk and Milk Products",
    "Fruits", "Other Vegetables", "Green Leafy Vegetables",
    "Egg and Egg Products", "Poultry",
}
POPULAR_WORDS = [
    "rice", "wheat", "roti", "chapati", "dal", "milk", "paneer", "curd",
    "yogurt", "egg", "chicken", "banana", "apple", "potato", "onion",
    "tomato", "bread", "tea", "coffee", "sugar", "oil", "ghee", "dosa",
    "idli", "lentil", "chickpea", "rajma", "spinach", "carrot", "mango",
]

LANG_PREFIX = re.compile(r"^[A-Za-z]{1,5}\.\s*")  # "H. Chawal" -> "Chawal"

def clean(s):
    return re.sub(r"\s+", " ", (s or "").strip())

def parse_aliases(lang):
    out = []
    for part in (lang or "").split(";"):
        # trim whitespace FIRST so the anchored "H. " prefix actually matches
        a = LANG_PREFIX.sub("", clean(part))
        # drop parentheticals & overly long/again-comma'd noise
        a = clean(re.sub(r"\(.*?\)", "", a))
        if 2 <= len(a) <= 28 and not a.lower().startswith("local"):
            out.append(a)
    # dedup case-insensitively, preserve order
    seen, dedup = set(), []
    for a in out:
        k = a.lower()
        if k not in seen:
            seen.add(k); dedup.append(a)
    return dedup[:12]

def measures_for(group):
    base = GROUP_MEASURES.get(group, DEFAULT_MEASURES)
    return [{"label": "g", "g": 1}] + [{"label": l, "g": g} for l, g in base]

def popularity(name, group):
    p = 10 + (20 if group in STAPLE_GROUPS else 0)
    low = name.lower()
    if any(w in low for w in POPULAR_WORDS):
        p += 50
    return p

def main():
    ensure_csv()
    rows = list(csv.reader(open(CSV, newline="", encoding="utf-8")))
    hdr = rows[0]
    code_idx = {}
    for i, h in enumerate(hdr):
        code_idx[h.split(";")[-1].strip()] = i

    def num(row, code):
        i = code_idx.get(code)
        if i is None or i >= len(row):
            return 0.0
        v = row[i].strip()
        try:
            return float(v)
        except ValueError:
            return 0.0

    def txt(row, code):
        i = code_idx.get(code)
        return row[i].strip() if i is not None and i < len(row) else ""

    out = []
    for r in rows[1:]:
        name = clean(txt(r, "name"))
        if not name:
            continue
        group = clean(txt(r, "grup"))
        aliases = parse_aliases(txt(r, "lang"))
        kcal = round(num(r, "enerc") * KJ_TO_KCAL, 1)
        row = {
            "id": "ifct:" + txt(r, "code"),
            "source": "ifct",
            "name": name,
            "brand": None,
            "serving_qty": 100,
            "serving_unit": "g",
            # macros (g)
            "kcal": kcal,
            "protein_g": round(num(r, "protcnt"), 2),
            "carbs_g": round(num(r, "choavldf"), 2),
            "fat_g": round(num(r, "fatce"), 2),
            "fiber_g": round(num(r, "fibtg"), 2),
            "sugar_g": round(num(r, "fsugar"), 2),
            "sat_fat_g": round(num(r, "fasat"), 3),
            "trans_fat_g": round(num(r, "fatrn"), 3),
            # minerals (g -> mg)
            "cholesterol_mg": round(num(r, "cholc") * 1000, 2),
            "sodium_mg": round(num(r, "na") * 1000, 2),
            "potassium_mg": round(num(r, "k") * 1000, 2),
            "calcium_mg": round(num(r, "ca") * 1000, 2),
            "iron_mg": round(num(r, "fe") * 1000, 3),
            "magnesium_mg": round(num(r, "mg") * 1000, 2),
            "zinc_mg": round(num(r, "zn") * 1000, 3),
            # vitamins (g -> mg/µg)
            "vit_a_ug": round(num(r, "vita") * 1e6, 1),
            "vit_c_mg": round(num(r, "vitc") * 1000, 2),
            "vit_d_ug": round(num(r, "vitd") * 1e6, 2),
            "vit_e_mg": round(num(r, "vite") * 1000, 2),
            "vit_k_ug": round(num(r, "vitk") * 1e6, 1),
            "b6_mg": round(num(r, "vitb6c") * 1000, 3),
            "b12_ug": 0,  # not measured in IFCT top-level
            "folate_ug": round(num(r, "folsum") * 1e6, 1),
            # search / display metadata
            "aliases": aliases,
            "measures": measures_for(group),
            "food_group": group,
            "region": "IN",
            "popularity": popularity(name, group),
        }
        st = " ".join([name] + aliases + [group]).lower()
        row["search_text"] = re.sub(r"\s+", " ", st).strip()
        out.append(row)

    json.dump(out, open(OUT, "w", encoding="utf-8"), ensure_ascii=False, indent=0)
    print(f"wrote {len(out)} foods -> {OUT}")
    # quick sanity
    by = {x["name"]: x for x in out}
    for k in ["Rice, raw, milled", "Paneer", "Spinach", "Banana, ripe, montham"]:
        if k in by:
            x = by[k]
            print(f"  {k:26} {x['kcal']:>5} kcal  Ca {x['calcium_mg']:>6} mg  "
                  f"Fe {x['iron_mg']:>5} mg  VitC {x['vit_c_mg']:>5} mg  aliases={x['aliases'][:4]}")

if __name__ == "__main__":
    main()
