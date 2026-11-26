"""Shared rules for the price list: what counts as a wine, who the producer is, bottle size, case size, vintage.

Used by shopify_to_sources.py (raw shop catalogues) and merge_prices.py (every source).
Rules of thumb (owner, Nov 2026): no fake wines (spirits, beer, food, gift bags, mixed cases, tastings),
no fake producers (importers, consignor codes, the shop's own name), no CaskCartel-style resellers."""
import re, unicodedata


def fold(s):
    s = unicodedata.normalize("NFKD", s or "").encode("ascii", "ignore").decode().lower()
    return re.sub(r"[‐-―-]", " ", s)


def toks(s):
    return re.findall(r"[a-z0-9]+", fold(s))


# ---------------------------------------------------------------- what is not wine
NONWINE = re.compile(r"""\b(
  gift\s*(?:card|voucher|wrap|bag|box|set|certificate|tag)s?|e[- ]?gift|voucher|giftcard|
  whisk(?:e)?y|bourbon|scotch|rye\s+whiskey|gin|vodka|rum|rhum|tequila|mezcal|cognac|armagnac|calvados|brandy|grappa|eau[- ]de[- ]vie|
  pisco|liquore|lik[oö]r|amaro|amari|aperitivo|bitters?|vermouth|vermut|absinthe|ouzo|raki|arak|schnapps|sake|nihonshu|shochu|soju|umeshu|baijiu|
  beer|biere|birra|cerveza|ipa|lager|pilsner?|stout|kolsch|seltzer|hard\s+seltzer|cider|cidre|sidra|kombucha|
  non[- ]?alcoholic|alcohol[- ]?free|alcoholfree|de[- ]?alcoholi[sz]ed|alcohol[- ]removed|zero[- ]alcohol|0[.,]0\s*%|0\s*%\s*(?:alc\w*|abv)|traubensaft|grape\s+juice|analcolic\w*|alkoholfrei|sans\s+alcool|
  mead|soda|tonic(?:\s+water)?|sirop|syrup|cordial|spritz|press[eé]|cycling\s+bottle|water\s+bottle|vertical|flutes?|soup|cakes?|booster|washing\s+up|multivitamins?|vits|gravy|stock\s+pot|(?:orange|lemon|lime|fruit|soft)\s+drinks?|flavou?r(?:ed)?\s+(?:sparkling|water|drink)|lemon\s*&\s*lime|sparkling\s+tea|tea\s+company|tea(?!\s+tree)|(?:apple|orange|grape|tomato|cranberry|fruit|pressed)\s+juice|lemonade|limonata|mineral\s+water|sparkling\s+water|still\s+water|tea\s+bags?|cheese|olive\s+oil|olio|vinegar|aceto|
  crackers?|crisps|salami|truffles?\s+(?:oil|salt)|honey\s+jar|chutney|cookbook|magazine|poster|
  candle|soap|t[- ]?shirt|hoodie|sweatshirt|baseball\s+cap|tote\s+bag|apron|socks|sneakers?|earrings?|necklace|bracelet|handbag|wallet|
  corkscrew|opener|stoppers?|decanter|carafe|glass(?:es|ware)?|tumbler|ice\s+bucket|cooler|chiller|aerator|pourer|wine\s+rack|cellar\s+book|
  ticket|tasting\s+(?:event|class|evening|night|pass|session|ticket)|masterclass|wine\s+class|workshop|supper\s+club|wine\s+tour|tasting\s+experience|
  wine\s+club|club\s+(?:membership|subscription)|membership|subscription|abonnement|bottle\s+deposit|deposit|shipping|delivery\s+charge|insurance|shipping\s+protection|donation|
  mixed\s+(?:case|dozen|pack|box)|mixed|mystery|vin\s+surprise|(?:party|explorer|combo|tray|tasting|discovery|starter|value|vertical|sampler)\s+(?:pack|case|set)|case\s+offer|wine\s+box|(?:trio|duo|quartet)\s*$|(?:trio|duo)\s+(?:gift|pack|set|box)|set\s+of\s+\d+|tasting(?!\s+(?:room|notes?))|(?:three|four|five|six|twelve)[- ]bottle|kit(?![`'\u2019]s|\s*s\s+coty)|bundle|sampler|discovery\s+(?:box|case|pack)|tasting\s+(?:box|kit|set|case|pack)|selection\s+box|
  hamper|coffret|assortment|variety\s+pack|collection\s+box|advent\s+calendar|gift\s+pack
)\b""", re.I | re.X)
NONWINE_TYPE = re.compile(r"spirit|whisk|\bgin\b|\brum\b|vodka|tequila|mezcal|liqueur|beer|\bale\b|lager|cider|\bsake\b|food|snack|pantry|grocer|deli|"
                          r"accessor|glass|merch|apparel|cloth|gift ?card|voucher|book|event|ticket|class|subscription|membership|club|"
                          r"non[- ]?alc|alcohol[- ]?free|soft drink|mixer|tobacco|cigar|bundle|mixed|hamper|gift set|gift box|case deal|fashion|jewel|bag", re.I)
WINE_TYPE = re.compile(r"\bwines?\b|\bvins?\b|\bvino\b|\bvini\b|\bwein\b|\bred\b|\bwhite\b|\bros[eé]\b|rosado|rosato|sparkling|champagne|"
                       r"fortified|\bport\b|sherry|madeira|dessert|sweet|orange|pet[- ]?nat|cava|prosecco|cr[eé]mant|natural|rouge|blanc|rosso|bianco|tinto", re.I)
WINE_WORDS = re.compile(r"\b(wine|vin|vino|wein|weingut|weinbau|domaine|dom|chateau|clos|bodegas?|cantina|tenuta|azienda|fattoria|podere|quinta|"
                        r"cuvee|grand cru|premier cru|1er cru|cru|riserva|reserva|gran reserva|crianza|spatlese|kabinett|auslese|trocken|brut|extra brut|"
                        r"blanc de blancs|blanc de noirs|rouge|blanc|rose|rosso|bianco|rosato|tinto|blanco|branco|red|white|sparkling|pet nat|petillant|"
                        r"frizzante|spumante|sekt|champagne|cremant|cava|prosecco|port|porto|sherry|madeira|tokaji|aszu|vin jaune|igt|doc|docg|aoc|aop|igp|vdf|"
                        r"vin de france|landwein|qualitatswein|ava|vineyard|vignoble|vigneron|vignerons|estate|old vines?|vieilles vignes|alte reben|magnum)\b")


LIQUEUR = re.compile(r"\bliqueurs?\b", re.I)
LIQUEUR_WINE = re.compile(r"muscat|muscadelle|topaque|tokay|vin de liqueur|pineau|ratafia|floc", re.I)


PACKAGING = re.compile(r"\b(?:in|with|w/|incl\.?|including|\+)\s+(?:an?\s+)?(?:\w+\s+){0,2}(?:gift\s*box|wooden\s+box|presentation\s+box|box|tube|coffret|case|astuccio|cassetta(?:\s+di\s+legno)?)\b|\bgift\s*boxed\b|\(\s*(?:gift\s*box|giftbox|owc|ocb|coffret|astuccio)\s*\)", re.I)


def is_nonwine(title, ptype="", tags=()):
    f = PACKAGING.sub(" ", fold(title))
    if NONWINE.search(f):
        return True
    if LIQUEUR.search(f) and not LIQUEUR_WINE.search(f):
        return True
    if ptype and NONWINE_TYPE.search(ptype) and not WINE_TYPE.search(ptype):
        return True
    return False


def wine_signal(title, ptype, tags, grape_rx=None, place_rx=None):
    """True when something says this is a wine: product type, tags, wine words, a grape or a wine place in the title."""
    if ptype and WINE_TYPE.search(ptype):
        return True
    ft = fold(title)
    if WINE_WORDS.search(ft):
        return True
    if grape_rx is not None and grape_rx.search(ft):
        return True
    if place_rx is not None and place_rx.search(ft):
        return True
    tg = fold(" ".join(tags))
    if re.search(r"\b(red|white|rose|sparkling|orange|natural|fortified|dessert) wine\b|\bwine\b|\bgrape\b|varietal|appellation", tg):
        return True
    return False


# ---------------------------------------------------------------- bottle size, case size, vintage
FMT = [("double magnum", 3000), ("magnum", 1500), ("jeroboam", 3000), ("rehoboam", 4500), ("methuselah", 6000), ("imperial", 6000),
       ("salmanazar", 9000), ("balthazar", 12000), ("nebuchadnezzar", 15000), ("half bottle", 375), ("half", 375), ("demi", 375),
       ("clavelin", 620), ("jennie", 500), ("piccolo", 187), ("split", 187)]
SIZES = (187, 200, 250, 375, 500, 620, 700, 750, 1000, 1500, 3000, 4500, 5000, 6000, 9000, 12000, 15000, 18000)


def size_ml(*texts):
    """Bottle size from a title or a variant title; None if nothing says."""
    for t in texts:
        f = fold(t)
        m = re.search(r"(?<![\d.])(\d+(?:[.,]\d+)?)\s*(ml|cl|ltr|litres?|liters?|l)\b", f)
        if m:
            v = float(m.group(1).replace(",", ".")); u = m.group(2)
            ml = round(v if u == "ml" else v * 10 if u == "cl" else v * 1000)
            if ml in SIZES:
                return ml
            if 740 <= ml <= 760:
                return 750
        for k, v in FMT:
            if re.search(r"\b" + k + r"\b", f):
                if k in ("half", "demi") and not re.search(r"\b(half|demi)[- ]?(bottle|bouteille)\b|\bdemi\b(?! sec)", f):
                    continue
                return v
    return None


def pack_count(*texts):
    """Bottles in a case offer ('Case of 6', '6 x 75cl', '12 bottles', '6-pack'); 1 when single."""
    for t in texts:
        f = fold(t)
        for rx in (r"\bcase of (\d{1,2})\b", r"\b(\d{1,2})\s*[x×]\s*\d+(?:[.,]\d+)?\s*(?:ml|cl|l)\b", r"\b(\d{1,2})\s*(?:bottles|btls|bouteilles|flaschen|bottiglie)\b",
                   r"\b(\d{1,2})\s*[- ]?pack\b", r"\bpack of (\d{1,2})\b", r"\b(\d{1,2})\s*[- ]?bottle case\b", r"\bdozen\b"):
            m = re.search(rx, f)
            if m:
                n = 12 if rx == r"\bdozen\b" else int(m.group(1))
                if 2 <= n <= 24:
                    return n
        m = re.search(r"\b(two|three|four|five|six|nine|twelve)[- ](?:bottles?|btls?)\b", f)
        if m:
            return {"two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "nine": 9, "twelve": 12}[m.group(1)]
        if re.search(r"\b(case|carton|owc|ocb|cassa|caisse|kiste)\b", f) and not re.search(r"\b(single|bottle|btl|each)\b", f):
            return -1   # a case of unknown size
    return 1


YEAR = re.compile(r"(?<![\d/.-])(19[0-9]\d|20[0-2]\d)(?![\d/])")


def vintage_of(title, *more):
    f = title or ""
    if re.search(r"\bNV\b|non[- ]vintage|sans ann[eé]e|sans mill[eé]sime|\bS\.?A\.?\b(?=\s*$)", f, re.I):
        return "NV"
    ys = [y for y in YEAR.findall(f) if not re.search(r"(est\.?|since|founded|depuis|anniversary|years?)\s*" + y, f, re.I)]
    if ys:
        return ys[-1] if len(ys) > 1 and re.search(r"\b(19|20)\d\d\s*[-/]\s*(19|20)\d\d\b", f) is None else ys[0]
    for t in more:
        m = YEAR.search(t or "")
        if m:
            return m.group(1)
    return ""


# ---------------------------------------------------------------- producers
NOT_PRODUCER = re.compile(r"""^(
  |\d+|0|n/?a|none|null|default|vendor|unknown|various|misc\w*|other|test|sample|wine|wines|vin|vins|vino|red|white|rose|sparkling|
  (?:chateau|ch|domaine|dom|clos|bodegas?|maison|tenuta|weingut|cantina|quinta|castello|casa|cave|caves|cellars?|estate|winery|vineyards?|famille|azienda(?:\ agricola)?)
    (?:\ (?:de|du|des|la|le|les|di|del|della|dei|da|do|dos|das|d|l|von|van|der|y|et|e))*|
  .*\bitems?\b.*|.*\bgcc\b.*|.*\bsku\b.*|.*\bcollection\b.*|en\ primeur|fine\ wine.*|rare\ wine.*|
  \d{3}\s.*|natural\ wine|spanish\ natural\ wine|naturwein\w*|naturweine|organic|biodynamic|gift|gifts|shop|store|online|private.*|\d{4,}\s*-.*|
  .*\[[a-z]{2,6}\]|.*\b(imports?|importers?|importing|selections?|distribut\w*|merchants?|wine\s*&\s*spirits|wines\s*and\s*spirits|spirits|
  trading|portfolio|wholesale|wine\s*group|beverages?|drinks|liquors?|ltd|limited|inc|llc|gmbh|pty|bv|s\.?a\.?s|sarl|plc|corp(?:oration)?|foods)\b.*
)$""", re.I | re.X)
GENERIC_LEAD = re.compile(r"^(the|le|la|les|il|lo|el|los|las|der|die|das)$")
STYLE_WORDS = re.compile(r"\b(blanc|blanco|branco|bianco|rouge|rosso|rose|rosado|rosato|red|white|brut|nature|extra|sec|demi|riserva|reserva|crianza|"
                         r"grand cru|premier cru|1er cru|cru|vineyard|vigna|vino|vin|wine|cuvee|reserve|selection|old vines|vieilles vignes|igt|igp|doc|docg|aoc|aop|vdf|vdp|nv|magnum)\b")
STOP = set("the a an and et e y und de du des la le les di del della dei d l of wine wines vin vino vini red white rose rouge blanc rosso bianco tinto blanco "
           "domaine dom chateau ch clos bodega bodegas cantina tenuta azienda agricola weingut maison famille estate estates winery vineyards vineyard cellars "
           "cellar family wines co company vignerons nv brut".split())


def key_tokens(producer):
    return [t for t in toks(producer) if t not in STOP and len(t) >= 3]


def names_in_title(producer, title):
    """Does the title already name this producer? (any distinctive word of the producer in the title; 'WildEarth' = 'Wild Earth')"""
    kt = key_tokens(producer)
    if not kt:
        return fold(producer).strip() in fold(title)
    tt = set(toks(title))
    if any(t in tt for t in kt):
        return True
    squash = "".join(toks(title))
    return len("".join(kt)) >= 6 and "".join(kt) in squash


def lead_segment(title):
    """'Producer, Wine 2020' / 'Producer - Wine' / 'PRODUCER Wine' -> 'Producer' (or '')."""
    t = re.sub(r"^\s*(?:(?:19|20)\d\d|NV|N\.V\.)\s+", "", title.strip(), flags=re.I)
    t = re.sub(r"^(?:champagne|maison|bodegas?)\s+(?=[A-Z])", "", t, flags=re.I) if re.match(r"(?i)champagne\s+\S+\s*,", t) or re.match(r"(?i)champagne\s+[A-Z]", t) else t
    m = re.match(r"^(.{2,60}?)\s*(?:,|\s[-–—|:]\s)\s*\S", t)
    if m:
        seg = m.group(1).strip(" '\"‘’“”")
        if not YEAR.search(seg) and 1 <= len(seg.split()) <= 7:
            return seg
    return ""


def tidy_title(title):
    t = re.sub(r"\s+", " ", (title or "").replace("\t", " ")).strip()
    t = re.sub(r"\s*\((?:one|limit|max)[^)]*per (?:order|customer)[^)]*\)", "", t, flags=re.I)
    t = re.sub(r"\s*[\(\[](?:[^)\]]*\b(?:pre[- ]?sale|pre[- ]?order|presale|arriving|eta|allocation|in stock|back in stock|offer|sold out|limited stock|new arrival|special price)\b[^)\]]*)[\)\]]", "", t, flags=re.I)
    t = re.sub(r"\s*[-|]\s*(?:pre[- ]?order|sold out|last bottles?|new arrival|on sale|sale)\s*$", "", t, flags=re.I)
    t = re.sub(r"^BX\s+[A-Z]{2,4}\s+(?=[A-Z])", "", t)          # Wine Chateau bin codes: 'BX MED Cap Royal Bordeaux Superieur'
    return t.strip(" -|")
