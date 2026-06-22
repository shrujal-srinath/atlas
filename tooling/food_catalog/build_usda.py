#!/usr/bin/env python3
"""
Build an ATLAS food_catalog seed from USDA FoodData Central — SR Legacy.

Source: USDA FDC SR Legacy (CC0 public domain). ~7,800 generic whole foods
with complete micronutrients. Units are already per-100 g in each nutrient's
native unit (kcal / g / mg / µg), so no conversion is needed.

Output: usda_catalog.json — rows matching public.food_catalog. Tagged region
'US' and ranked below IFCT staples so Indian foods still win shared queries.

Run:  python3 build_usda.py
"""
import csv, io, json, os, re, urllib.request, zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
ZIP = os.path.join(HERE, "usda_sr_legacy.zip")
OUT = os.path.join(HERE, "usda_catalog.json")
URL = "https://fdc.nal.usda.gov/fdc-datasets/FoodData_Central_sr_legacy_food_csv_2018-04.zip"

# nutrient.id (FDC id, what food_nutrient.nutrient_id references) -> (column, scale)
NUTR = {
    "1008": ("kcal", 1), "1003": ("protein_g", 1), "1004": ("fat_g", 1),
    "1005": ("carbs_g", 1), "1079": ("fiber_g", 1), "2000": ("sugar_g", 1),
    "1258": ("sat_fat_g", 1), "1257": ("trans_fat_g", 1),
    "1253": ("cholesterol_mg", 1), "1093": ("sodium_mg", 1), "1092": ("potassium_mg", 1),
    "1087": ("calcium_mg", 1), "1089": ("iron_mg", 1), "1090": ("magnesium_mg", 1),
    "1095": ("zinc_mg", 1),
    "1106": ("vit_a_ug", 1), "1162": ("vit_c_mg", 1), "1114": ("vit_d_ug", 1),
    "1109": ("vit_e_mg", 1), "1185": ("vit_k_ug", 1),
    "1175": ("b6_mg", 1), "1178": ("b12_ug", 1), "1177": ("folate_ug", 1),
}
NUM_COLS = ["kcal", "protein_g", "carbs_g", "fat_g", "fiber_g", "sugar_g",
            "sat_fat_g", "trans_fat_g", "cholesterol_mg", "sodium_mg", "potassium_mg",
            "calcium_mg", "iron_mg", "magnesium_mg", "zinc_mg", "vit_a_ug", "vit_c_mg",
            "vit_d_ug", "vit_e_mg", "vit_k_ug", "b6_mg", "b12_ug", "folate_ug"]

CAT_MEASURES = {
    "Dairy and Egg Products":          [("Cup", 245), ("Glass", 200), ("Tbsp", 15)],
    "Beverages":                       [("Glass", 250), ("Cup", 240)],
    "Fruits and Fruit Juices":         [("Piece", 120), ("Cup", 150)],
    "Vegetables and Vegetable Products":[("Cup", 150), ("Katori", 120)],
    "Legumes and Legume Products":     [("Katori", 150), ("Cup", 175)],
    "Cereal Grains and Pasta":         [("Katori", 150), ("Cup", 180), ("Bowl", 200)],
    "Breakfast Cereals":               [("Bowl", 50), ("Cup", 40)],
    "Baked Products":                  [("Piece", 60), ("Slice", 30)],
    "Nut and Seed Products":           [("Handful", 30), ("Tbsp", 15)],
    "Poultry Products":                [("Piece", 100), ("Katori", 150)],
    "Beef Products":                   [("Piece", 100), ("Katori", 150)],
    "Pork Products":                   [("Piece", 100), ("Katori", 150)],
    "Finfish and Shellfish Products":  [("Piece", 100), ("Katori", 150)],
    "Fats and Oils":                   [("Tbsp", 14), ("Tsp", 5)],
    "Sweets":                          [("Piece", 30), ("Tbsp", 12)],
    "Fast Foods":                      [("Piece", 120), ("Serving", 150)],
    "Meals, Entrees, and Side Dishes": [("Bowl", 240), ("Serving", 200)],
    "Snacks":                          [("Handful", 30), ("Serving", 50)],
}
DEFAULT_MEASURES = [("Cup", 200), ("Serving", 100), ("Piece", 50)]
SKIP_CATEGORIES = {"Baby Foods", "American Indian/Alaska Native Foods", "Spices and Herbs"}

POPULAR_WORDS = [
    "egg", "milk", "yogurt", "yoghurt", "cheese", "butter", "oats", "oatmeal",
    "bread", "rice", "chicken", "banana", "apple", "orange", "potato", "peanut",
    "almond", "salmon", "tuna", "beef", "broccoli", "spinach", "carrot", "honey",
    "tofu", "lentil", "bean", "corn", "tomato", "onion", "coffee", "tea",
]

def ensure_zip():
    if os.path.exists(ZIP):
        return
    print("downloading USDA SR Legacy zip (~16 MB)…")
    urllib.request.urlretrieve(URL, ZIP)

def measures_for(cat):
    base = CAT_MEASURES.get(cat, DEFAULT_MEASURES)
    return [{"label": "g", "g": 1}] + [{"label": l, "g": g} for l, g in base]

def popularity(name, cat):
    p = 8
    low = name.lower()
    if any(w in low for w in POPULAR_WORDS):
        p += 25
    if "," in name and name.count(",") >= 3:
        p -= 4  # very specific variants rank a touch lower
    return max(p, 1)

def main():
    ensure_zip()
    z = zipfile.ZipFile(ZIP)
    base = z.namelist()[0].split("/")[0]

    def reader(fn):
        return csv.DictReader(io.TextIOWrapper(z.open(f"{base}/{fn}"), encoding="utf-8-sig"))

    # category id -> description
    cat = {}
    for r in reader("food_category.csv"):
        cat[r["id"]] = r["description"].strip()

    # sr_legacy foods
    foods = {}
    for r in reader("food.csv"):
        if r["data_type"] != "sr_legacy_food":
            continue
        c = cat.get(r.get("food_category_id", ""), "")
        if c in SKIP_CATEGORIES:
            continue
        foods[r["fdc_id"]] = {"name": r["description"].strip(), "cat": c,
                              "n": {col: 0.0 for col in NUM_COLS}}

    # stream nutrients, keep only target nutrients for kept foods
    kept = 0
    for r in reader("food_nutrient.csv"):
        fid = r["fdc_id"]
        f = foods.get(fid)
        if f is None:
            continue
        m = NUTR.get(r["nutrient_id"])
        if not m:
            continue
        try:
            amt = float(r["amount"])
        except (ValueError, KeyError):
            continue
        f["n"][m[0]] = round(amt * m[1], 3)
        kept += 1

    out = []
    for fid, f in foods.items():
        name = re.sub(r"\s+", " ", f["name"])
        if not name or f["n"]["kcal"] <= 0:
            continue  # drop entries with no energy (water, etc. keep? skip noise)
        row = {
            "id": "usda:" + fid, "source": "usda", "name": name, "brand": None,
            "serving_qty": 100, "serving_unit": "g",
            **f["n"],
            "aliases": [], "measures": measures_for(f["cat"]),
            "food_group": f["cat"], "region": "US",
            "popularity": popularity(name, f["cat"]),
            "search_text": re.sub(r"\s+", " ", f"{name} {f['cat']}").strip().lower(),
        }
        out.append(row)

    json.dump(out, open(OUT, "w", encoding="utf-8"), ensure_ascii=False, separators=(",", ":"))
    print(f"wrote {len(out)} USDA foods -> {OUT}  ({kept} nutrient cells)")
    by = {x["name"]: x for x in out}
    for k in ["Yogurt, plain, whole milk", "Egg, whole, raw, fresh",
              "Oats", "Cheese, cheddar"]:
        if k in by:
            x = by[k]
            print(f"  {k:34} {x['kcal']:>5} kcal  Ca {x['calcium_mg']:>5}  "
                  f"B12 {x['b12_ug']:>4}  VitD {x['vit_d_ug']:>4}")

if __name__ == "__main__":
    main()
