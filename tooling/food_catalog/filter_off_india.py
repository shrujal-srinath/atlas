#!/usr/bin/env python3
"""
Stream-filter the Open Food Facts CSV export to India-sold packaged products
with usable nutrition, mapped to ATLAS food_catalog rows (source 'off',
region 'IN', with barcode). Reads the tab-separated CSV on stdin (decompressed),
writes JSONL on stdout.

Usage:
  curl -sL <off-csv-gz> | gunzip -c | python3 filter_off_india.py > off_india.jsonl
"""
import csv, json, re, sys

csv.field_size_limit(50_000_000)

# minerals: g -> mg (x1000); vitamins: g -> mg or µg
NUTR = {
    "kcal": ("energy-kcal_100g", 1),
    "protein_g": ("proteins_100g", 1), "carbs_g": ("carbohydrates_100g", 1),
    "fat_g": ("fat_100g", 1), "fiber_g": ("fiber_100g", 1), "sugar_g": ("sugars_100g", 1),
    "sat_fat_g": ("saturated-fat_100g", 1), "trans_fat_g": ("trans-fat_100g", 1),
    "cholesterol_mg": ("cholesterol_100g", 1000), "sodium_mg": ("sodium_100g", 1000),
    "potassium_mg": ("potassium_100g", 1000), "calcium_mg": ("calcium_100g", 1000),
    "iron_mg": ("iron_100g", 1000), "magnesium_mg": ("magnesium_100g", 1000),
    "zinc_mg": ("zinc_100g", 1000),
    "vit_a_ug": ("vitamin-a_100g", 1_000_000), "vit_c_mg": ("vitamin-c_100g", 1000),
    "vit_d_ug": ("vitamin-d_100g", 1_000_000), "vit_e_mg": ("vitamin-e_100g", 1000),
    "vit_k_ug": ("vitamin-k_100g", 1_000_000), "b6_mg": ("vitamin-b6_100g", 1000),
    "b12_ug": ("vitamin-b12_100g", 1_000_000), "folate_ug": ("folates_100g", 1_000_000),
}

def clean(s): return re.sub(r"\s+", " ", (s or "").strip())

def serving_grams(s):
    m = re.match(r"\s*([\d.]+)\s*(g|ml)\b", (s or "").lower())
    if m:
        try:
            g = float(m.group(1))
            if 1 <= g <= 1000:
                return round(g)
        except ValueError:
            pass
    return None

def main():
    r = csv.reader(sys.stdin, delimiter="\t")
    header = next(r)
    idx = {name: i for i, name in enumerate(header)}
    ci_code, ci_name = idx["code"], idx["product_name"]
    ci_brands = idx.get("brands", -1)
    ci_ctags = idx.get("countries_tags", -1)
    ci_cen = idx.get("countries_en", -1)
    ci_serv = idx.get("serving_size", -1)
    nidx = {k: idx.get(col, -1) for k, (col, _) in NUTR.items()}

    seen = set()
    kept = 0
    seen_rows = 0
    for row in r:
        seen_rows += 1
        if seen_rows % 200000 == 0:
            sys.stderr.write(f"  scanned {seen_rows:,} rows, kept {kept:,}\n")
            sys.stderr.flush()
        if len(row) <= ci_name:
            continue
        ctags = row[ci_ctags].lower() if ci_ctags >= 0 and ci_ctags < len(row) else ""
        cen = row[ci_cen].lower() if ci_cen >= 0 and ci_cen < len(row) else ""
        if "en:india" not in ctags and "india" not in cen:
            continue
        code = clean(row[ci_code])
        name = clean(row[ci_name])
        if not code or len(name) < 2 or len(name) > 100 or code in seen:
            continue

        def num(key):
            i = nidx[key]
            if i < 0 or i >= len(row):
                return 0.0
            v = row[i].strip()
            try:
                return float(v)
            except ValueError:
                return 0.0

        kcal = num("kcal")
        if kcal <= 0 or kcal > 900:  # require sane energy → real nutrition
            continue
        out = {"id": "off:" + code, "source": "off", "barcode": code,
               "name": name, "serving_qty": 100, "serving_unit": "g",
               "region": "IN", "popularity": 4}
        out["brand"] = (clean(row[ci_brands]).split(",")[0] if ci_brands >= 0
                        and ci_brands < len(row) and row[ci_brands].strip() else None)
        for k, (_, scale) in NUTR.items():
            out[k] = round(num(k) * scale, 3)
        out["kcal"] = round(num("kcal"), 1)
        measures = [{"label": "g", "g": 1}]
        sg = serving_grams(row[ci_serv]) if ci_serv >= 0 and ci_serv < len(row) else None
        if sg:
            measures.append({"label": "Serving", "g": sg})
        measures.append({"label": "Pack", "g": 50})
        out["measures"] = measures
        out["aliases"] = []
        seen.add(code)
        kept += 1
        sys.stdout.write(json.dumps(out, ensure_ascii=False, separators=(",", ":")) + "\n")
    sys.stderr.write(f"DONE: scanned {seen_rows:,}, kept {kept:,} India products\n")

if __name__ == "__main__":
    main()
