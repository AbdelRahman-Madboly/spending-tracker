#!/usr/bin/env python3
"""Writes assets/seed/seed_shared.json, the seed of the shared build.

It starts from assets/seed/seed.json and keeps only what is not the owner's
own: the categories and subcategories, plus the ones imports and the product
catalogue add, and the generic items with their default prices. Entries and
salary periods are dropped, every item's use count and last use are reset,
and item descriptions that name the owner's providers or his phone are
replaced with generic ones.

Run from the repo root:  uv run python tool/build_shared_seed.py
"""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "assets" / "seed" / "seed.json"
TARGET = ROOT / "assets" / "seed" / "seed_shared.json"
CATALOG = ROOT / "assets" / "catalog" / "egypt_products.json"

# Categories and subcategories the import packs and the catalogue create on
# the owner's phone, and a subscriptions category. The catalogue's
# own `catalogueAdditions` are merged in below as well.
EXTRA_CATEGORIES = [
    {"key": "Health", "labelAr": "صحة", "iconName": "medication",
     "colorKey": "Health"},
    {"key": "Home", "labelAr": "البيت", "iconName": "home",
     "colorKey": "Home"},
    {"key": "Subscriptions", "labelAr": "اشتراكات",
     "iconName": "subscriptions", "colorKey": "Education"},
]

EXTRA_SUBCATEGORIES = [
    {"key": "Medicine", "categoryKey": "Health", "labelAr": "أدوية",
     "iconName": "medication"},
    {"key": "Cleaning", "categoryKey": "Home", "labelAr": "منظفات",
     "iconName": "cleaning_services"},
    {"key": "Laundry", "categoryKey": "Personal Care", "labelAr": "غسيل",
     "iconName": "local_laundry_service"},
    {"key": "FamilySupport", "categoryKey": "Family/Social",
     "labelAr": "مصروف البيت", "iconName": "family_restroom"},
    {"key": "Software", "categoryKey": "Subscriptions", "labelAr": "برامج",
     "iconName": "code"},
    {"key": "Cloud", "categoryKey": "Subscriptions",
     "labelAr": "تخزين سحابي", "iconName": "cloud"},
    {"key": "Courses", "categoryKey": "Subscriptions", "labelAr": "كورسات",
     "iconName": "school"},
    {"key": "QuickMeals", "categoryKey": "Food",
     "labelAr": "أكل سريع التحضير", "iconName": "ramen_dining"},
]

# Item descriptions that are generic for anyone, by item id, and items that
# belong somewhere clearer for a new user.
GENERIC_NAME_EN = {
    "item-01": "Bakery",
    "item-04": "Milk",
    "item-05": "Instant noodles",
    "item-06": "Chocolate",
    "item-10": "Mobile credit top-up",
    "item-11": "Mobile phone bill",
    "item-12": "Internet bundle",
}
SUBCATEGORY_OF = {
    "item-05": "QuickMeals",
    "item-10": "PhoneBill",
}


def _merge(rows, extra):
    keys = {r["key"] for r in rows}
    return rows + [r for r in extra if r["key"] not in keys]


def build():
    seed = json.loads(SOURCE.read_text(encoding="utf-8"))
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    additions = catalog.get("catalogueAdditions", {})

    categories = [dict(c, colorKey=c.get("colorKey", c["key"]))
                  for c in seed["categories"]]
    categories = _merge(categories, EXTRA_CATEGORIES)
    categories = _merge(categories, additions.get("categories", []))

    subcategories = _merge(list(seed["subcategories"]), EXTRA_SUBCATEGORIES)
    subcategories = _merge(subcategories, additions.get("subcategories", []))

    items = []
    for item in seed["items"]:
        item = dict(item)
        item["nameEn"] = GENERIC_NAME_EN.get(item["id"], item["nameEn"])
        item["subcategoryKey"] = SUBCATEGORY_OF.get(
            item["id"], item["subcategoryKey"])
        item["useCount"] = 0
        item["lastUsedAt"] = None
        items.append(item)

    return {
        "categories": categories,
        "subcategories": subcategories,
        "items": items,
        "entries": [],
        "salaryPeriods": [],
    }


if __name__ == "__main__":
    TARGET.write_text(
        json.dumps(build(), ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"wrote {TARGET.relative_to(ROOT)}")
