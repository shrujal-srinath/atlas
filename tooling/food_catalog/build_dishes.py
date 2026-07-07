#!/usr/bin/env python3
"""
Build curated composite Indian DISHES for the ATLAS food_catalog by composing
them from IFCT + USDA ingredients (full micros, legally clean — recipes are our
own compositions over MIT/CC0 ingredient data).

Each dish = a list of (ingredient_id, raw_grams) + a final cooked weight. We sum
every nutrient across ingredients, add salt as sodium, divide by the cooked
weight → per-100 g, and recompute kcal via Atwater (IFCT stores oil energy as 0).

Output: dishes_catalog.json — rows for public.food_catalog (source 'curated').

Run:  python3 build_dishes.py   (needs ifct_catalog.json + usda_catalog.json)
"""
import json, os, re

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "dishes_catalog.json")

NUM_COLS = ["protein_g", "carbs_g", "fat_g", "fiber_g", "sugar_g", "sat_fat_g",
            "trans_fat_g", "cholesterol_mg", "sodium_mg", "potassium_mg",
            "calcium_mg", "iron_mg", "magnesium_mg", "zinc_mg", "vit_a_ug",
            "vit_c_mg", "vit_d_ug", "vit_e_mg", "vit_k_ug", "b6_mg", "b12_ug",
            "folate_ug"]

# ── ingredient pins (resolved from the catalogs) ─────────────────────
RICE='ifct:A015'; ATTA='ifct:A019'; MAIDA='ifct:A018'
TOOR='ifct:B021'; CHANA_DAL='ifct:B001'; MOONG='ifct:B010'; URAD='ifct:B003'
MASOOR='ifct:B013'; RAJMA='ifct:B020'; CHOLE='ifct:B002'; PEAS='ifct:B017'
ONION='ifct:G017'; TOMATO='ifct:D076'; POTATO='ifct:F008'; CAULI='ifct:D036'
SPINACH='ifct:C033'; OKRA='ifct:D056'; CARROT='ifct:F003'
PANEER='ifct:L003'; CHICKEN='ifct:N003'; EGG='ifct:M001'
MILK='usda:171265'; YOGURT='usda:171284'; BUTTER='usda:173430'; CREAM='usda:170859'
GHEE='ifct:T013'; OIL='ifct:T005'; SUGAR='usda:169656'; JAGGERY='ifct:I001'
SEMOLINA='ifct:A022'; POHA='ifct:A011'; CASHEW='ifct:H005'; COCONUT='ifct:H007'
GROUNDNUT='ifct:H012'; TAMARIND='ifct:E064'; BESAN='ifct:B002'
GINGER='ifct:G014'; GARLIC='ifct:G011'; GCHILLI='ifct:G001'
CUMIN='ifct:G025'; CURRYLEAF='ifct:G010'

KAT=[("Katori",150),("Bowl",200),("Cup",240)]
PLATE=[("Katori",150),("Plate",300),("Bowl",200)]

def pc(label, g): return [{"label":"g","g":1}] + [{"label":l,"g":w} for l,w in label]
def piece(w, extra=None):
    return [{"label":"g","g":1},{"label":"Piece","g":w}] + ([{"label":l,"g":x} for l,x in (extra or [])])

# (slug, name, aliases, group, measures, final_g, salt_g, [(id,grams)], popularity)
R = [
 ("plain-rice","Cooked Rice (plain)",["chawal","steamed rice","boiled rice"],"Rice & grains",pc(PLATE,0),140,0.5,[(RICE,50)],88),
 ("jeera-rice","Jeera Rice",["cumin rice","jeera chawal"],"Rice & grains",pc(PLATE,0),150,0.8,[(RICE,55),(GHEE,6),(CUMIN,1)],80),
 ("veg-pulao","Vegetable Pulao",["pulav","veg pulav","fried rice veg"],"Rice & grains",pc(PLATE,0),175,1.0,[(RICE,55),(OIL,7),(ONION,20),(CARROT,15),(PEAS,8)],80),
 ("veg-biryani","Vegetable Biryani",["veg biryani","biriyani","biryani"],"Rice & grains",pc(PLATE,0),200,1.2,[(RICE,65),(OIL,9),(ONION,25),(TOMATO,15),(POTATO,20),(CARROT,15),(YOGURT,15)],86),
 ("chicken-biryani","Chicken Biryani",["chiken biryani","murgh biryani","biriyani"],"Rice & grains",pc(PLATE,0),210,1.2,[(RICE,65),(OIL,9),(CHICKEN,45),(ONION,25),(TOMATO,15),(YOGURT,20)],90),
 ("egg-biryani","Egg Biryani",["anda biryani"],"Rice & grains",pc(PLATE,0),205,1.1,[(RICE,65),(OIL,8),(EGG,50),(ONION,22),(TOMATO,15),(YOGURT,15)],74),
 ("curd-rice","Curd Rice",["dahi rice","thayir sadam","yogurt rice"],"Rice & grains",pc(KAT,0),170,0.6,[(RICE,50),(YOGURT,80),(MILK,15)],74),
 ("lemon-rice","Lemon Rice",["chitranna","nimbu chawal"],"Rice & grains",pc(KAT,0),150,0.8,[(RICE,55),(OIL,7),(GROUNDNUT,5),(CURRYLEAF,1)],68),
 ("roti","Roti / Chapati",["chapati","phulka","roti","wheat roti"],"Breads",piece(38),38,0.2,[(ATTA,30),(OIL,1)],94),
 ("paratha","Paratha (plain)",["parantha","tawa paratha"],"Breads",piece(50),50,0.4,[(ATTA,35),(GHEE,6)],84),
 ("aloo-paratha","Aloo Paratha",["potato paratha","alu paratha"],"Breads",piece(90),90,0.8,[(ATTA,35),(POTATO,35),(OIL,6)],84),
 ("poori","Poori / Puri",["puri","fried bread"],"Breads",piece(32),32,0.2,[(MAIDA,25),(OIL,6)],74),
 ("naan","Naan",["butter naan","plain naan"],"Breads",piece(80),80,0.6,[(MAIDA,50),(YOGURT,10),(OIL,4)],78),
 ("dal-tadka","Dal Tadka",["dal","daal","tadka dal","arhar dal","toor dal"],"Dals & legumes",pc(KAT,0),120,1.0,[(TOOR,28),(GHEE,5),(ONION,12),(TOMATO,12)],88),
 ("dal-fry","Dal Fry",["dal fry","yellow dal"],"Dals & legumes",pc(KAT,0),120,1.0,[(TOOR,28),(OIL,5),(ONION,15),(TOMATO,12)],82),
 ("sambar","Sambar",["sambhar","sambar dal"],"Dals & legumes",pc(KAT,0),160,1.2,[(TOOR,22),(OIL,4),(TOMATO,15),(ONION,12),(TAMARIND,3),(CARROT,10)],82),
 ("rajma","Rajma (curry)",["rajmah","kidney bean curry","rajma masala"],"Dals & legumes",pc(KAT,0),160,1.2,[(RAJMA,35),(OIL,6),(ONION,20),(TOMATO,20)],84),
 ("chole","Chole / Chana Masala",["chana masala","chole","chickpea curry","chhole"],"Dals & legumes",pc(KAT,0),160,1.2,[(CHOLE,35),(OIL,7),(ONION,20),(TOMATO,20)],86),
 ("chana-dal","Chana Dal (cooked)",["chana dal","split bengal gram"],"Dals & legumes",pc(KAT,0),125,1.0,[(CHANA_DAL,30),(OIL,5),(ONION,12),(TOMATO,10)],72),
 ("moong-dal","Moong Dal (cooked)",["yellow moong dal","mung dal"],"Dals & legumes",pc(KAT,0),120,1.0,[(MOONG,28),(GHEE,4),(ONION,10),(TOMATO,10)],74),
 ("kadhi","Kadhi",["kadhi pakora","besan kadhi"],"Dals & legumes",pc(KAT,0),150,1.0,[(YOGURT,60),(BESAN,12),(OIL,5),(ONION,10)],68),
 ("paneer-butter-masala","Paneer Butter Masala",["paneer makhani","butter paneer","pbm"],"Curries",pc(KAT,0),140,1.0,[(PANEER,55),(BUTTER,8),(CREAM,15),(TOMATO,40),(CASHEW,8),(ONION,15)],88),
 ("palak-paneer","Palak Paneer",["saag paneer","spinach paneer"],"Curries",pc(KAT,0),160,1.0,[(PANEER,45),(SPINACH,90),(OIL,6),(ONION,15),(TOMATO,10),(CREAM,8)],84),
 ("shahi-paneer","Shahi Paneer",["shahi paneer"],"Curries",pc(KAT,0),140,1.0,[(PANEER,55),(CREAM,18),(CASHEW,10),(TOMATO,30),(ONION,15),(BUTTER,6)],76),
 ("matar-paneer","Matar Paneer",["mutter paneer","peas paneer"],"Curries",pc(KAT,0),155,1.0,[(PANEER,45),(PEAS,18),(OIL,6),(ONION,18),(TOMATO,25)],76),
 ("aloo-gobi","Aloo Gobi",["potato cauliflower","gobi aloo"],"Curries",pc(KAT,0),170,1.0,[(POTATO,60),(CAULI,70),(OIL,8),(ONION,15),(TOMATO,15)],80),
 ("bhindi-masala","Bhindi Masala",["okra masala","ladies finger fry","bhindi fry"],"Curries",pc(KAT,0),130,1.0,[(OKRA,100),(OIL,9),(ONION,20),(TOMATO,15)],78),
 ("mixed-veg","Mixed Veg Curry",["mixed vegetable","veg curry","sabzi"],"Curries",pc(KAT,0),165,1.0,[(POTATO,30),(CAULI,30),(CARROT,25),(PEAS,12),(OIL,8),(ONION,15),(TOMATO,15)],74),
 ("chicken-curry","Chicken Curry",["chiken curry","murgh curry","chicken masala","chicken gravy"],"Curries",pc(KAT,0),190,1.3,[(CHICKEN,70),(OIL,8),(ONION,30),(TOMATO,25),(YOGURT,10)],88),
 ("butter-chicken","Butter Chicken",["murgh makhani","chicken makhani"],"Curries",pc(KAT,0),180,1.2,[(CHICKEN,70),(BUTTER,8),(CREAM,18),(TOMATO,40),(CASHEW,6),(ONION,12)],86),
 ("egg-curry","Egg Curry",["anda curry","egg masala"],"Curries",pc(KAT,0),190,1.0,[(EGG,100),(OIL,7),(ONION,25),(TOMATO,25)],78),
 ("egg-bhurji","Egg Bhurji",["anda bhurji","scrambled egg masala"],"Egg dishes",pc(KAT,0),130,0.8,[(EGG,100),(OIL,6),(ONION,25),(TOMATO,20)],82),
 ("boiled-egg","Boiled Egg",["egg boiled","uble ande","hard boiled egg"],"Egg dishes",piece(50),100,0.3,[(EGG,100)],90),
 ("fried-egg","Fried Egg",["fried egg","egg fry","anda fry","sunny side up","poached egg"],"Egg dishes",piece(52),52,0.3,[(EGG,50),(OIL,4)],90),
 ("scrambled-egg","Scrambled Eggs",["scrambled egg","egg scramble"],"Egg dishes",pc([("Katori",120),("Bowl",150)],0),120,0.5,[(EGG,100),(OIL,5),(MILK,10)],82),
 ("omelette","Omelette",["omlet","masala omelette","anda omelette","egg omelette"],"Egg dishes",piece(115),115,0.5,[(EGG,100),(OIL,5),(ONION,15)],86),
 ("idli","Idli",["iddli","idly","steamed rice cake"],"South Indian",piece(40),95,0.6,[(RICE,30),(URAD,12)],86),
 ("dosa","Dosa (plain)",["dosai","plain dosa"],"South Indian",piece(75),75,0.6,[(RICE,35),(URAD,12),(OIL,3)],88),
 ("masala-dosa","Masala Dosa",["masala dosai","potato dosa"],"South Indian",piece(140),140,0.8,[(RICE,35),(URAD,12),(OIL,6),(POTATO,50),(ONION,12)],86),
 ("upma","Upma",["uppma","rava upma","sooji upma"],"South Indian",pc(KAT,0),130,0.9,[(SEMOLINA,35),(OIL,7),(ONION,15),(CARROT,10)],78),
 ("poha","Poha",["pohe","aval","flattened rice"],"South Indian",pc(KAT,0),120,0.8,[(POHA,35),(OIL,6),(ONION,18),(POTATO,15),(GROUNDNUT,5)],82),
 ("medu-vada","Medu Vada",["vada","ulundu vadai","urad vada"],"South Indian",piece(45),45,0.5,[(URAD,28),(OIL,6)],72),
 ("uttapam","Uttapam",["uthappam","onion uttapam"],"South Indian",piece(110),110,0.7,[(RICE,35),(URAD,12),(OIL,5),(ONION,15),(TOMATO,10)],66),
 ("samosa","Samosa",["singara","samosas","veg samosa"],"Snacks",piece(68),68,0.6,[(MAIDA,25),(POTATO,40),(OIL,11),(PEAS,8)],84),
 ("pav-bhaji","Pav Bhaji (bhaji)",["bhaji","pao bhaji"],"Snacks",pc(KAT,0),180,1.2,[(POTATO,50),(CAULI,25),(PEAS,15),(BUTTER,12),(ONION,25),(TOMATO,30)],80),
 ("dhokla","Dhokla",["khaman","besan dhokla"],"Snacks",piece(40),110,0.8,[(BESAN,40),(YOGURT,15),(OIL,5)],68),
 ("curd","Curd / Dahi",["dahi","yogurt","plain curd","thayir","mosaru"],"Dairy",pc([("Cup",240),("Katori",150),("Bowl",200)],0),100,0.0,[(YOGURT,100)],90),
 ("raita","Raita (plain)",["boondi raita","veg raita","cucumber raita"],"Dairy",pc([("Cup",200),("Katori",100),("Bowl",150)],0),110,0.6,[(YOGURT,85),(ONION,10),(BESAN,4)],72),
 ("lassi","Sweet Lassi",["lassi","sweet lassi","punjabi lassi"],"Beverages",pc([("Glass",200),("Cup",150)],0),150,0.0,[(YOGURT,80),(MILK,20),(SUGAR,15)],78),
 ("buttermilk","Buttermilk / Chaas",["chaas","chhaas","mattha","majjige"],"Beverages",pc([("Glass",200),("Cup",150)],0),200,0.5,[(YOGURT,50)],72),
 ("masala-chai","Masala Chai",["chai","tea","milk tea","cutting chai"],"Beverages",pc([("Cup",150),("Glass",200)],0),150,0.0,[(MILK,80),(SUGAR,8)],90),
 ("gulab-jamun","Gulab Jamun",["gulab jamun","jamun"],"Sweets",piece(50),50,0.0,[(MAIDA,15),(MILK,20),(SUGAR,20),(GHEE,4)],78),
 ("kheer","Kheer",["payasam","rice pudding","payasa"],"Sweets",pc([("Katori",150),("Bowl",200)],0),130,0.0,[(MILK,120),(RICE,12),(SUGAR,15),(CASHEW,4)],76),
 ("suji-halwa","Suji Halwa",["sooji halwa","rava sheera","sheera"],"Sweets",pc([("Katori",100),("Bowl",150)],0),90,0.0,[(SEMOLINA,30),(GHEE,12),(SUGAR,20),(MILK,30)],72),
 # ── added: user's daily foods ──
 ("butter-dosa","Butter Dosa",["butter dosai","ghee dosa","benne dosa"],"South Indian",piece(80),80,0.6,[(RICE,35),(URAD,12),(OIL,3),(BUTTER,8)],84),
 ("channa","Channa (boiled)",["channa","chana sundal","boiled chana","kadalai","sundal","chickpea snack"],"Snacks",pc(KAT,0),110,0.8,[(CHOLE,45),(COCONUT,8),(OIL,3)],82),
 ("coconut-chutney","Coconut Chutney",["chutney","coconut chutney","thengai chutney","nariyal chutney"],"Sides",pc([("Tbsp",20),("Katori",50)],0),75,0.5,[(COCONUT,45),(CHANA_DAL,6),(OIL,2)],80),
 ("idli-sambar","Idli Sambar",["idli sambhar","idly sambar","idli sambar","2 idli sambar"],"South Indian",pc([("Plate",290),("Bowl",240)],0),290,1.4,[(RICE,45),(URAD,18),(TOOR,18),(OIL,3),(TOMATO,12),(ONION,10),(TAMARIND,2),(CARROT,8)],84),
 ("shavige","Shavige (rice vermicelli)",["shavige","semiya","sevai","vermicelli","idiyappam","rice noodles","shavige bath"],"South Indian",pc(KAT,0),125,0.8,[(RICE,40),(OIL,5),(ONION,8),(COCONUT,5)],78),
 ("kesari-bath","Kesari Bath",["kesari bath","rava kesari","kesari","kesaribath"],"Sweets",pc([("Katori",100),("Bowl",150)],0),100,0.0,[(SEMOLINA,30),(GHEE,12),(SUGAR,22),(MILK,25)],80),
]

# Direct branded / manufactured items (not composed from ingredients) — values
# from the product label, per 100 g.
DIRECT = [
  {"id": "brand:yogabar-protein-oats", "source": "curated", "name": "Protein Oats",
   "brand": "Yogabar", "kcal": 400, "protein_g": 24, "carbs_g": 50, "fat_g": 11,
   "fiber_g": 10, "sugar_g": 8, "sat_fat_g": 2.6, "sodium_mg": 110, "calcium_mg": 120,
   "iron_mg": 4.5, "potassium_mg": 300,
   "aliases": ["yogabar oats", "yoga bar oats", "protein oats", "yogabar protein oats",
               "high protein oats"],
   "measures": [{"label": "g", "g": 1}, {"label": "Serving", "g": 40}, {"label": "Bowl", "g": 50}],
   "food_group": "Breakfast cereals", "region": "IN", "popularity": 72},
]

def main():
    pool = {}
    for fn in ["ifct_catalog.json", "usda_catalog.json"]:
        for x in json.load(open(os.path.join(HERE, fn))):
            pool[x["id"]] = x

    out, table = [], []
    for slug, name, aliases, group, measures, final_g, salt_g, ings, pop in R:
        tot = {c: 0.0 for c in NUM_COLS}
        missing = [i for i, _ in ings if i not in pool]
        if missing:
            raise SystemExit(f"{slug}: missing ingredient ids {missing}")
        for iid, grams in ings:
            ing = pool[iid]
            f = grams / 100.0
            for c in NUM_COLS:
                tot[c] += (ing.get(c) or 0) * f
        tot["sodium_mg"] += salt_g * 388.0  # salt → sodium
        per = {c: round(tot[c] / final_g * 100, 3) for c in NUM_COLS}
        # Atwater kcal (IFCT stores oil energy as 0, so don't sum kcal)
        kcal = round(4 * per["protein_g"] + 4 * per["carbs_g"]
                     + 9 * per["fat_g"] + 2 * per["fiber_g"], 1)
        row = {"id": "dish:" + slug, "source": "curated", "name": name,
               "brand": None, "serving_qty": 100, "serving_unit": "g",
               "kcal": kcal, **per, "aliases": aliases, "measures": measures,
               "food_group": group, "region": "IN", "popularity": pop}
        row["search_text"] = re.sub(r"\s+", " ",
            f"{name} {' '.join(aliases)} {group}").strip().lower()
        out.append(row)
        table.append((name, kcal, per["protein_g"], per["carbs_g"],
                      per["fat_g"], per["calcium_mg"], per["iron_mg"]))

    # direct branded items (label values, per 100 g)
    for d in DIRECT:
        row = {"id": d["id"], "source": d.get("source", "curated"), "name": d["name"],
               "brand": d.get("brand"), "serving_qty": 100, "serving_unit": "g",
               "kcal": d.get("kcal", 0), **{c: d.get(c, 0) for c in NUM_COLS},
               "aliases": d.get("aliases", []),
               "measures": d.get("measures", [{"label": "g", "g": 1}]),
               "food_group": d.get("food_group"), "region": d.get("region", "IN"),
               "popularity": d.get("popularity", 50)}
        row["search_text"] = re.sub(r"\s+", " ",
            f"{d['name']} {d.get('brand','')} {' '.join(d.get('aliases', []))} "
            f"{d.get('food_group','')}").strip().lower()
        out.append(row)
        table.append((f"{d.get('brand','')} {d['name']}", d.get("kcal", 0),
                      d.get("protein_g", 0), d.get("carbs_g", 0), d.get("fat_g", 0),
                      d.get("calcium_mg", 0), d.get("iron_mg", 0)))

    json.dump(out, open(OUT, "w", encoding="utf-8"), ensure_ascii=False,
              separators=(",", ":"))
    print(f"wrote {len(out)} dishes -> {OUT}\n")
    print(f"{'dish':28} {'kcal':>5} {'P':>5} {'C':>6} {'F':>5} {'Ca':>5} {'Fe':>4}  /100g")
    for n, k, p, c, f, ca, fe in table:
        flag = "  <-- check" if (k < 70 or k > 420) else ""
        print(f"{n[:28]:28} {k:>5} {p:>5} {c:>6} {f:>5} {ca:>5.0f} {fe:>4.1f}{flag}")

if __name__ == "__main__":
    main()
