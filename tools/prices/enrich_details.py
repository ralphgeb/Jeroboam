#!/usr/bin/env python3
"""Adds country, region, appellation, colour, grapes, aromas, short notes and critics' scores to every wine in
content/prices/wine_prices.csv and writes content/prices/wine_details.csv (same wine/vintage/size keys).

Input: a folder of JSONL files saved from the shops' catalogues ({url,title,type,vendor,tags,text}).
Run:   python3 tools/prices/enrich_details.py <details_dir>
Place names come from shop tags first, then content/regions.yaml (+ the list below) matched in the name, then in the
description. Notes are generated from the facts found (not copied); `details_link` opens the shop page with the full text.
Scores are read from shop pages that quote them; `score_links` lists those pages."""
import csv, json, os, re, sys, glob, unicodedata, statistics as S, collections as C
import yaml
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
P = os.path.join(ROOT, 'content/prices/')
def fold(s): return unicodedata.normalize('NFKD', s or '').encode('ascii', 'ignore').decode().lower()

# ---------- places ----------
regs = yaml.safe_load(open(os.path.join(ROOT, 'content/regions.yaml')))
byid = {r['id']: r for r in regs}
parent = {}
for r in regs:
    for s in r.get('sub') or []: parent.setdefault(s, r['id'])
def chain(rid):
    out = [rid]
    while out[-1] in parent and parent[out[-1]] not in out: out.append(parent[out[-1]])
    return out
PLACES = {}   # folded name -> (appellation, region, country)
for r in regs:
    if r['kind'] == 'country': continue
    ch = [byid[x] for x in chain(r['id']) if byid[x]['kind'] != 'country']
    top = ch[-1]['name']
    for nm in re.split(r'\s*(?:&|\(|\)|/)\s*', r['name']) + [r['name']]:
        nm = nm.strip()
        if len(nm) >= 4: PLACES.setdefault(fold(nm), (r['name'], top, r['country']))
EXTRA = {  # appellation: (region, country)
 'France': {'Burgundy': "Corton,Corton-Charlemagne,Montrachet,Batard-Montrachet,Chevalier-Montrachet,Clos de Vougeot,Echezeaux,Grands-Echezeaux,Richebourg,La Tache,Romanee-Conti,Romanee-Saint-Vivant,La Romanee,Musigny,Bonnes-Mares,Clos de la Roche,Clos Saint-Denis,Clos de Tart,Chambertin,Clos de Beze,Charmes-Chambertin,Mazis-Chambertin,Latricieres-Chambertin,Griotte-Chambertin,Chapelle-Chambertin,Ruchottes-Chambertin,Pouilly-Fuisse,Saint-Veran,Macon,Vire-Clesse,Bourgogne,Hautes-Cotes de Nuits,Hautes-Cotes de Beaune,Cote de Nuits-Villages,Irancy,Petit Chablis,Aligote",
            'Beaujolais': "Morgon,Fleurie,Moulin-a-Vent,Brouilly,Cote de Brouilly,Chiroubles,Julienas,Chenas,Regnie,Saint-Amour",
            'Rhone Valley': "Lirac,Tavel,Rasteau,Cairanne,Vinsobres,Ventoux,Luberon,Costieres de Nimes,Saint-Peray,Beaumes-de-Venise,Chateau-Grillet,Cotes du Rhone Villages",
            'Loire Valley': "Quincy,Reuilly,Menetou-Salon,Saumur-Champigny,Coteaux du Layon,Quarts de Chaume,Bonnezeaux,Jasnieres,Cheverny,Anjou,Pouilly-Fume,Sancerre",
            'Languedoc-Roussillon': "Pic Saint-Loup,Faugeres,Saint-Chinian,Minervois,Corbieres,Fitou,La Clape,Terrasses du Larzac,Limoux,Collioure,Banyuls,Maury,Cotes du Roussillon,Cotes Catalanes,Pays d'Oc",
            'Provence': "Bandol,Cassis,Bellet,Palette,Cotes de Provence,Coteaux d'Aix",
            'South West France': "Cahors,Madiran,Jurancon,Bergerac,Monbazillac,Gaillac,Irouleguy,Marcillac,Fronton",
            'Jura': "Arbois,Chateau-Chalon,Cotes du Jura,L'Etoile,Vin Jaune",
            'Bordeaux': "Listrac,Moulis,Lalande-de-Pomerol,Barsac,Sauternes,Cotes de Bordeaux,Bordeaux Superieur,Saint-Georges-Saint-Emilion,Montagne-Saint-Emilion,Lussac-Saint-Emilion,Cadillac",
            'Champagne': "Champagne,Coteaux Champenois", 'Alsace': "Alsace", 'Savoie': "Savoie,Bugey"},
 'Italy': {'Piedmont': "Langhe,Nebbiolo d'Alba,Barbera d'Alba,Dolcetto d'Alba,Gattinara,Ghemme,Boca,Lessona,Bramaterra,Carema,Roero,Moscato d'Asti,Ruche,Timorasso,Colli Tortonesi",
           'Lombardy': "Valtellina,Sforzato,Franciacorta,Lugana,Oltrepo Pavese", 'Veneto': "Soave,Valpolicella,Amarone,Ripasso,Recioto,Prosecco,Bardolino,Conegliano,Valdobbiadene",
           'Friuli': "Collio,Friuli Colli Orientali,Carso,Isonzo", 'Trentino-Alto Adige': "Alto Adige,Sudtirol,Trentino,Trento",
           'Emilia-Romagna': "Lambrusco", 'Umbria': "Montefalco,Sagrantino,Orvieto", 'Marche': "Verdicchio dei Castelli di Jesi,Rosso Conero,Matelica",
           'Abruzzo': "Montepulciano d'Abruzzo,Trebbiano d'Abruzzo,Cerasuolo d'Abruzzo", 'Campania': "Taurasi,Fiano di Avellino,Greco di Tufo,Irpinia,Falerno",
           'Basilicata': "Aglianico del Vulture", 'Puglia': "Primitivo di Manduria,Salice Salentino,Salento",
           'Sicily': "Etna,Cerasuolo di Vittoria,Marsala,Pantelleria,Vittoria", 'Sardinia': "Cannonau,Vermentino di Gallura",
           'Tuscany': "Rosso di Montalcino,Montalcino,Sant'Antimo,Morellino di Scansano,Toscana,Super Tuscan,Vin Santo,Montecucco,Rosso di Montepulciano,Chianti Rufina,Chianti Colli Senesi"},
 'Spain': {'Penedès': "Cava,Corpinnat", 'Jerez (Sherry)': "Sherry,Manzanilla,Fino,Amontillado,Oloroso,Palo Cortado,Sanlucar", 'Rioja': "Rioja Alavesa,Rioja Alta", 'Galicia': "Godello"},
 'Portugal': {'Douro': "Port,Porto,Tawny,Colheita", 'Madeira': "Madeira", 'Alentejo': "Alentejano"},
 'United States': {'California': "Sonoma County,Santa Barbara,Sta. Rita Hills,Santa Rita Hills,Santa Cruz Mountains,Paso Robles,Anderson Valley,Chalk Hill,Knights Valley,Spring Mountain,Diamond Mountain,Atlas Peak,Calistoga,St. Helena,Saint Helena,Yountville,Coombsville,Santa Lucia Highlands,Edna Valley,Arroyo Grande,Ballard Canyon,Happy Canyon,Santa Ynez,Sonoma,Napa,California,Monterey,Petaluma Gap,Fort Ross-Seaview,Green Valley,Carneros,El Dorado,Amador",
                   'Oregon': "Eola-Amity Hills,Dundee Hills,Chehalem Mountains,Ribbon Ridge,Yamhill-Carlton,McMinnville,Oregon", 'Washington': "Red Mountain,Yakima Valley,Horse Heaven Hills,Washington State", 'New York': "Finger Lakes,Long Island,North Fork"},
 'New Zealand': {'Canterbury': "Waipara", 'Wairarapa': "Wairarapa"}, 'South Africa': {'Walker Bay': "Hemel-en-Aarde"},
 'Georgia': {'Kakheti': "Kakheti,Kindzmarauli,Mukuzani,Tsinandali"}, 'Austria': {'Burgenland': "Burgenland"}, 'Germany': {'Mosel': "Saar,Ruwer"},
 'Hungary': {'Tokaj': "Tokaji,Aszu"}, 'Lebanon': {'Bekaa Valley': "Bekaa"},
 'Switzerland': {'Valais': "Valais,Wallis,Fendant,Sion,Fully,Chamoson,Salgesch,Visperterminen", 'Vaud': "Vaud,Lavaux,Dezaley,Calamin,Epesses,Chablais,Yvorne,Aigle,La Cote,Mont-sur-Rolle,Fechy,Chardonne,Villette,Saint-Saphorin",
                 'Neuchatel': "Neuchatel,Oeil de Perdrix", 'Geneva': "Geneve,Geneva", 'Ticino': "Ticino,Merlot del Ticino", 'Graubunden': "Graubunden,Bundner Herrschaft,Malans,Flasch,Jenins,Maienfeld"},
 'China': {'Ningxia': "Ningxia,Helan Mountain,Helan Shan", 'Yunnan': "Yunnan,Shangri-La,Ao Yun", 'Shandong': "Shandong,Penglai,Yantai", 'Xinjiang': "Xinjiang", 'Hebei': "Huailai"},
 'Japan': {'Yamanashi': "Yamanashi,Koshu Valley", 'Nagano': "Nagano", 'Hokkaido': "Hokkaido,Yoichi"},
 'Canada': {'British Columbia': "Okanagan,Similkameen,Naramata,Golden Mile Bench,British Columbia", 'Ontario': "Niagara,Niagara Peninsula,Prince Edward County,Beamsville Bench,Twenty Mile Bench,Lake Erie North Shore,Ontario", 'Nova Scotia': "Nova Scotia,Annapolis Valley,Tidal Bay", 'Quebec': "Quebec"},
 'Uruguay': {'Canelones': "Canelones", 'Maldonado': "Maldonado,Garzon", 'Montevideo': "Montevideo"},
 'Mexico': {'Baja California': "Valle de Guadalupe,Baja California,Ensenada", 'Coahuila': "Parras,Coahuila", 'Queretaro': "Queretaro"},
 'Brazil': {'Serra Gaucha': "Serra Gaucha,Vale dos Vinhedos,Campanha Gaucha", 'Santa Catarina': "Santa Catarina"},
 'Croatia': {'Istria': "Istria,Istra", 'Dalmatia': "Dalmatia,Peljesac,Dingac,Postup,Hvar,Korcula", 'Slavonia': "Slavonia,Kutjevo"},
 'Slovenia': {'Primorska': "Brda,Goriska Brda,Vipava,Kras,Primorska", 'Podravje': "Stajerska,Styria Slovenia,Podravje,Ptuj"},
 'Romania': {'Dealu Mare': "Dealu Mare", 'Dragasani': "Dragasani", 'Moldova region': "Cotnari", 'Dobrogea': "Dobrogea,Murfatlar"},
 'Bulgaria': {'Thracian Valley': "Thracian Valley,Thracian Lowlands", 'Struma Valley': "Melnik,Struma Valley"},
 'Moldova': {'Codru': "Codru", 'Stefan Voda': "Stefan Voda,Purcari", 'Valul lui Traian': "Valul lui Traian"},
 'Cyprus': {'Commandaria': "Commandaria"}, 'Armenia': {'Vayots Dzor': "Vayots Dzor,Areni"},
 'Israel': {'Galilee': "Galilee,Upper Galilee", 'Golan Heights': "Golan Heights,Golan", 'Judean Hills': "Judean Hills"},
 'Turkey': {'Anatolia': "Anatolia,Cappadocia", 'Thrace': "Turkish Thrace"},
 'England': {'England': "English Sparkling,English Wine"}, 'Wales': {'Wales': "Welsh Wine"},
}
for country, regd in EXTRA.items():
    for region, names in regd.items():
        for nm in names.split(','):
            PLACES.setdefault(fold(nm), (nm, region, country))
COUNTRIES = {fold(c): c for c in "France,Italy,Spain,Portugal,Germany,Austria,Hungary,Greece,United States,Chile,Argentina,Australia,New Zealand,South Africa,Lebanon,Georgia,Slovenia,Croatia,Switzerland,England,Canada,Uruguay,Brazil,Mexico,Israel,Japan,China,Armenia,Moldova,Romania,Bulgaria,Cyprus,Turkey,Czech Republic,Slovakia,Serbia,Macedonia,Wales,Luxembourg,Morocco,Peru,Bolivia,India".split(',')}
COUNTRIES.update({'usa': 'United States', 'us': 'United States', 'united states of america': 'United States', 'america': 'United States', 'uk': 'England', 'united kingdom': 'England', 'nz': 'New Zealand', 'rsa': 'South Africa'})
PLACE_RX = re.compile(r'\b(' + '|'.join(sorted(map(re.escape, PLACES), key=len, reverse=True)) + r')\b')

# ---------- grapes ----------
gr = yaml.safe_load(open(os.path.join(ROOT, 'content/grapes.yaml')))
GRAPES, BERRY = {}, {}
for g in gr:
    for nm in [g['name']] + list(g.get('aka') or []) + re.split(r'\s*&\s*', g['name']):
        if len(nm) >= 4: GRAPES[fold(nm)] = g['name']
    BERRY[g['name']] = (g.get('berry') or '')
for a, b in {'Garnacha Blanca':'Grenache Blanc','Grenache Blanc':'Grenache Blanc','Garnatxa Blanca':'Grenache Blanc','Pinot Noir Precoce':'Pinot Noir','Shiraz':'Syrah','Garnacha':'Grenache','Monastrell':'Mourvèdre','Mataro':'Mourvèdre','Primitivo':'Zinfandel','Pinot Gris':'Pinot Grigio','Grauburgunder':'Pinot Grigio','Spatburgunder':'Pinot Noir','Pinot Nero':'Pinot Noir','Weissburgunder':'Pinot Blanc','Pinot Bianco':'Pinot Blanc','Alvarinho':'Albariño','Tinta Roriz':'Tempranillo','Tinto Fino':'Tempranillo','Kekfrankos':'Blaufränkisch','Lemberger':'Blaufränkisch','Pinot Meunier':'Meunier','Cinsaut':'Cinsault','Carignane':'Carignan','Carinena':'Carignan','Samso':'Carignan','Semillon':'Sémillon','Moscato':'Muscat','Moscatel':'Muscat','Muskateller':'Muscat','Sylvaner':'Silvaner','Prugnolo Gentile':'Sangiovese','Morellino':'Sangiovese','Spanna':'Nebbiolo','Chiavennasca':'Nebbiolo','Cot':'Malbec','Steen':'Chenin Blanc','Ugni Blanc':'Trebbiano','Viura':'Macabeo','Cabernet':'Cabernet Sauvignon'}.items():
    GRAPES.setdefault(fold(a), b)
for nm in "Trousseau,Poulsard,Savagnin,Aligote,Chasselas,Godello,Hondarrabi Zuri,Saperavi,Rkatsiteli,Frappato,Nerello Mascalese,Carricante,Lagrein,Schiava,Teroldego,Refosco,Ribolla Gialla,Friulano,Arneis,Freisa,Grignolino,Ruche,Pelaverga,Timorasso,Sagrantino,Pecorino,Passerina,Falanghina,Piedirosso,Bobal,Graciano,Verdelho,Sercial,Malvasia,Petite Sirah,Petit Manseng,Gros Manseng,Negrette,Mauzac,Colombard,Picpoul,Clairette,Rolle,Counoise,Grolleau,Pineau d'Aunis,Romorantin,Welschriesling,Rotgipfler,Zierfandler,St. Laurent,Harslevelu,Kadarka,Moschofilero,Malagousia,Roditis,Mavrodaphne,Limniona,Vidiano,Loureiro,Arinto,Encruzado,Touriga Franca,Castelao,Alicante Bouschet,Valdiguie,Sauvignon Gris,Kerner,Muller-Thurgau,Scheurebe,Bacchus,Carmenere,Listan Negro,Mazuelo,Cannonau,Nero di Troia,Uva di Troia,Susumaniello,Ciliegiolo,Canaiolo,Colorino,Vernaccia,Ansonica,Grillo,Catarratto,Inzolia,Zibibbo".split(','):
    GRAPES.setdefault(fold(nm), nm)
GRAPE_RX = re.compile(r'\b(' + '|'.join(sorted(map(re.escape, GRAPES), key=len, reverse=True)) + r')\b')

# ---------- aromas ----------
ar = yaml.safe_load(open(os.path.join(ROOT, 'content/aromas.yaml')))
AROMA = {fold(it): it for t in ar for c in t['categories'] for it in c['items']}
for a, b in {'cassis':'Blackcurrant','black currant':'Blackcurrant','red currant':'Redcurrant','cherries':'Cherry','cherry':'Cherry','morello cherry':'Black cherry','sour cherry':'Red cherry','plum':'Plum','plums':'Plum','citrus':'Citrus','orange':'Orange peel','tangerine':'Orange peel','blood orange':'Blood orange','cocoa':'Chocolate','dark chocolate':'Chocolate','espresso':'Coffee','mocha':'Coffee','graphite':'Graphite','pencil lead':'Graphite','pencil shavings':'Graphite','iodine':'Saline','sea spray':'Saline','salinity':'Saline','salty':'Saline','oyster shell':'Saline','tar':'Tar','rose petal':'Rose','rose petals':'Rose','violets':'Violet','herbs':'Dried herbs','sage':'Sage','rosemary':'Rosemary','bay leaf':'Bay leaf','tea':'Tea','black tea':'Tea','olive':'Olive','olives':'Olive','iron':'Iron','ginger':'Ginger','cinnamon':'Cinnamon','anise':'Anise','star anise':'Anise','menthol':'Mint','pine':'Pine','beeswax':'Beeswax','lanolin':'Wet wool','honeyed':'Honey','licorice':'Liquorice','pepper':'Black pepper','peppery':'Black pepper','tobacco leaf':'Tobacco','cigar box':'Cedar','cedarwood':'Cedar','toasty':'Toast','smoky':'Smoke','nutty':'Hazelnut','almonds':'Almond','brioche':'Brioche','lemon curd':'Lemon','lemons':'Lemon','limes':'Lime','apples':'Green apple','apple':'Green apple','pears':'Pear','peaches':'Peach','apricots':'Apricot','raspberries':'Raspberry','strawberries':'Strawberry','blackberries':'Blackberry','blueberries':'Blueberry','figs':'Fig','minerality':'Wet stones','mineral':'Wet stones','flinty':'Flint','gunflint':'Flint','earthy':'Earth','mushrooms':'Mushroom','truffles':'Truffle','leathery':'Leather','gamey':'Game','game':'Game','violet':'Violet','jasmine':'Jasmine','white flowers':'Blossom','floral':'Blossom','elderflower':'Elderflower','grapefruit':'Grapefruit','pineapple':'Pineapple','passionfruit':'Passion fruit','lychees':'Lychee','marmalade':'Marmalade','caramel':'Caramel','toffee':'Toffee','walnuts':'Walnut','hazelnuts':'Hazelnut','vanilla':'Vanilla','spice':'Sweet spice','spices':'Sweet spice','baking spice':'Sweet spice','clove':'Cloves','dried fruit':'Dried fruit','raisins':'Raisin','petrol':'Petrol','kerosene':'Petrol','smoke':'Smoke','forest floor':'Forest floor','underbrush':'Forest floor','sous bois':'Forest floor','garrigue':'Garrigue','thyme':'Thyme','lavender':'Lavender','honeysuckle':'Honeysuckle'}.items():
    AROMA.setdefault(fold(a), b)
AROMA_RX = re.compile(r'\b(' + '|'.join(sorted(map(re.escape, AROMA), key=len, reverse=True)) + r')\b')
STYLE = [('full-bodied', r'full[- ]bodied|full body|powerful|opulent'), ('medium-bodied', r'medium[- ]bodied'), ('light-bodied', r'light[- ]bodied|light and fresh|delicate'),
         ('dry', r'\bbone[- ]dry|\bdry\b'), ('off-dry', r'off[- ]dry|feinherb|halbtrocken'), ('sweet', r'\bsweet wine|lusciously sweet|dessert wine|botrytis|late harvest|ice ?wine'),
         ('firm tannins', r'firm tannins|grippy|tannic'), ('silky tannins', r'silky|supple tannins|fine[- ]grained tannins|velvety'), ('high acidity', r'high acidity|bright acidity|racy|vibrant acidity|crisp'),
         ('oaked', r'new oak|oak[- ]aged|barrique|aged in oak|french oak'), ('unoaked', r'unoaked|no oak|stainless steel'), ('long finish', r'long finish|lingering finish|persistent finish'),
         ('organic/biodynamic', r'organic|biodynamic'), ('natural', r'natural wine|low[- ]intervention|no added sulfites|zero sulfur'), ('age-worthy', r'age[- ]?worthy|will age|cellar(?:ing)? potential|reward (?:cellaring|patience)')]

# ---------- scores ----------
CRIT = [('Wine Advocate', r"wine advocate|robert parker|parker's|\bparker\b"), ('Wine Spectator', r'wine spectator'), ('James Suckling', r'james suckling|suckling'),
        ('Vinous', r'vinous|antonio galloni|galloni|stephen tanzer|tanzer'), ('Jeb Dunnuck', r'jeb dunnuck|dunnuck'), ('Decanter', r'decanter'), ('Wine Enthusiast', r'wine enthusiast'),
        ('Burghound', r'burghound|allen meadows'), ('Jancis Robinson', r'jancis robinson|jancis'), ('Tim Atkin', r'tim atkin'), ('Wine & Spirits', r'wine (?:&|and) spirits magazine'),
        ('Falstaff', r'falstaff'), ('James Halliday', r'halliday'), ('Neal Martin', r'neal martin'), ('Jane Anson', r'jane anson'), ('Lisa Perrotti-Brown', r'perrotti[- ]brown'),
        ('William Kelley', r'william kelley'), ('Bob Campbell', r'bob campbell'), ('Raymond Chan', r'raymond chan'), ('Wine Align', r'winealign'), ('Gilbert & Gaillard', r'gilbert (?:&|et) gaillard'),
        ('Andreas Larsson', r'andreas larsson'), ('Jasper Morris', r'jasper morris'), ('Wine Independent', r'the wine independent'), ('Owen Bargreen', r'owen bargreen')]
ABBR = {'RP':'Wine Advocate','WA':'Wine Advocate','TWA':'Wine Advocate','WS':'Wine Spectator','JS':'James Suckling','VM':'Vinous','AG':'Vinous','JD':'Jeb Dunnuck','WE':'Wine Enthusiast',
        'BH':'Burghound','JR':'Jancis Robinson','TA':'Tim Atkin','NM':'Neal Martin','JA':'Jane Anson','LPB':'Lisa Perrotti-Brown','JH':'James Halliday','DEC':'Decanter','DE':'Decanter','W&S':'Wine & Spirits','FAL':'Falstaff'}
NUM = r'(\d{2,3}(?:\.\d)?)(?:\s*[-–]\s*(\d{2,3}))?\s*\+?(?!\d)'
RX_A = [(n, re.compile(r'(?:' + p + r")(?:'s)?[^0-9.]{0,40}?" + NUM + r'\s*(?:points?|pts?|/100|/20|\b)', re.I)) for n, p in CRIT]
RX_B = [(n, re.compile(NUM + r'\s*(?:points?|pts?|/100|/20)[^0-9.]{0,25}?(?:' + p + ')', re.I)) for n, p in CRIT]
AB = '|'.join(sorted(map(re.escape, ABBR), key=len, reverse=True))
RX_C = re.compile(r'(?<![A-Za-z])(' + AB + r')\s*[:\-]?\s*' + NUM, re.I)
RX_D = re.compile(r'(?<![\d.])' + NUM + r'\s*(?:pts?|points?)?\s*[(\[]?(' + AB + r')(?![A-Za-z])', re.I)
def score_ok(c, v, hi):
    s = (v + hi) / 2 if hi and hi > v else v
    if c == 'Jancis Robinson' and 12 <= s <= 20: return s, '/20'
    if 80 <= s <= 100: return s, ''
    return None, None
def scores_in(text):
    found = {}
    for n, rx in RX_A + RX_B:
        for m in rx.finditer(text):
            s, sc = score_ok(n, float(m.group(1)), float(m.group(2)) if m.group(2) else None)
            if s: found.setdefault(n, (s, sc))
    for m in RX_C.finditer(text):
        n = ABBR[m.group(1).upper()]; s, sc = score_ok(n, float(m.group(2)), float(m.group(3)) if m.group(3) else None)
        if s and m.group(1).isupper(): found.setdefault(n, (s, sc))
    for m in RX_D.finditer(text):
        n = ABBR[m.group(3).upper()]; s, sc = score_ok(n, float(m.group(1)), float(m.group(2)) if m.group(2) else None)
        if s and m.group(3).isupper(): found.setdefault(n, (s, sc))
    return found

# ---------- tags ----------
def tag_value(tags, keys):
    for t in tags:
        m = re.match(r'^\s*(' + keys + r')\s*[_:|]\s*(.+?)\s*$', t, re.I) or re.match(r'^\s*(.+?)_(' + keys + r')\s*$', t, re.I)
        if m:
            v = m.group(2) if m.re.pattern.startswith('^\\s*(' + keys) else m.group(1)
            if v and not re.search(r'undefined|other|n/a', v, re.I): return v.strip()
    return None
COLORS = [('Sparkling', r'sparkling|champagne|cr[eé]mant|cava|prosecco|pet[- ]?nat|franciacorta|spumante|sekt|\bbrut\b|blanc de blancs|blanc de noirs|frizzante|lambrusco'),
          ('Fortified', r'\bport\b|porto|sherry|madeira|marsala|fortified|manzanilla|\bfino\b|oloroso|amontillado|palo cortado|banyuls|\bmaury\b|tawny|vin doux naturel'),
          ('Sweet', r'sauternes|barsac|tokaji|aszu|\bsweet\b|dessert|late harvest|ice ?wine|eiswein|beerenauslese|\bTBA\b|vin santo|recioto|passito|moscato d.asti|vendange tardive'),
          ('Rosé', r'\bros[eé]\b|rosado|rosato|cerasuolo|\bblush\b|\btavel\b'), ('Orange', r'\borange wine|skin[- ]contact|amber wine|\bramato\b'),
          ('White', r'\bwhite\b|\bblanc\b|bianco|blanco|weiss|branco'), ('Red', r'\bred\b|\brouge\b|rosso|tinto|\brot\b')]
def color_of(blob, grapes):
    for c, rx in COLORS:
        if re.search(rx, blob, re.I): return c
    for g in grapes:
        b = BERRY.get(g, '').lower()
        if 'black' in b or 'red' in b or 'dark' in b: return 'Red'
        if 'green' in b or 'white' in b or 'gold' in b or 'yellow' in b: return 'White'
    return ''

def place_from(text):
    for m in PLACE_RX.finditer(fold(text)):
        return PLACES[m.group(1)]
    return None
SHOP_COUNTRY = {'www.chapeldown.com': 'England', 'lymebaywinery.co.uk': 'England', 'www.ridgeview.co.uk': 'England', 'www.grapebritannia.co.uk': 'England'}
def analyse(name, d):
    """Facts from one shop product (d may be None: name only)."""
    host = re.sub(r'^https?://([^/]+)/.*$', r'\1', d['url']) if d and d.get('url') else ''
    tags = d['tags'] if d else []
    text = d['text'] if d else ''
    out = {}
    tc = tag_value(tags, 'country') or None
    if not tc:
        for t in tags + ([d['type']] if d else []):
            for part in re.split(r'[-/|,]', t):
                if fold(part.strip()) in COUNTRIES: tc = COUNTRIES[fold(part.strip())]; break
            if tc: break
    if tc: out['country'] = COUNTRIES.get(fold(tc), tc.title() if tc.islower() else tc)
    if host in SHOP_COUNTRY and 'country' not in out: out['country'] = SHOP_COUNTRY[host]
    treg = tag_value(tags, 'region')
    tapp = tag_value(tags, 'appellation|subregion|sub[- ]region')
    hit = place_from(name) or (place_from(' '.join([tapp or '', treg or ''] + tags)) if tags else None) or place_from(text[:400])
    if hit:
        out['appellation'], out['region'], c = hit
        if 'country' not in out: out['country'] = c
        elif out['country'] != c and not place_from(name): out.pop('appellation'); out.pop('region')
    if treg and 'region' not in out: out['region'] = treg
    if tapp and 'appellation' not in out: out['appellation'] = tapp
    gs = []
    for t in tags:
        m = re.match(r'^\s*(?:grape(?: variety)?|varietal|grapes?)\s*[_:|]\s*(.+)$', t, re.I) or re.match(r'^(.+)_grape$', t, re.I)
        if m:
            g = GRAPES.get(fold(m.group(1).strip()), m.group(1).strip().title())
            if g not in gs: gs.append(g)
    for m in GRAPE_RX.finditer(fold(name + ' ' + ' '.join(tags))):
        g = GRAPES[m.group(1)]
        if g not in gs: gs.append(g)
    if not gs:
        for m in GRAPE_RX.finditer(fold(text[:600])):
            g = GRAPES[m.group(1)]
            if g not in gs: gs.append(g)
            if len(gs) >= 3: break
    out['grapes'] = gs[:4]
    tcol = None
    for t in tags + ([d['type']] if d else []):
        for c, rx in COLORS:
            if re.search(r'^(?:type[_:| ]*)?' + rx + r'(?:[ _]wine)?$', t.strip(), re.I) or re.search(r'(?:^|[-_ ])(' + c + r')(?:[-_ ]|$)', t, re.I): tcol = c; break
        if tcol: break
    out['color'] = tcol or color_of(name + ' ' + ' '.join(tags), gs) or color_of(text[:300], gs)
    ft = fold(text)
    aromas = []
    for m in AROMA_RX.finditer(ft):
        a = AROMA[m.group(1)]
        if a not in aromas: aromas.append(a)
    out['aromas'] = aromas[:8]
    out['style'] = [s for s, rx in STYLE if re.search(rx, ft, re.I)][:5]
    out['scores'] = scores_in(text + ' | ' + ' | '.join(tags)) if d else {}
    return out

def main():
    ddir = sys.argv[1]
    DET = {}
    for f in glob.glob(os.path.join(ddir, '*.jsonl')):
        for line in open(f):
            try: p = json.loads(line)
            except Exception: continue
            DET[p['url']] = p
    print('shop products with details', len(DET))
    PAGE = {}   # url -> {critic: (score, scale)} read from product pages (optional 2nd argument: folder of JSONL)
    NORM = {'antonio galloni': 'Vinous', 'vinous media': 'Vinous', 'vinous': 'Vinous', 'robert parker': 'Wine Advocate', "robert parker's wine advocate": 'Wine Advocate',
            'the wine advocate': 'Wine Advocate', 'wine advocate': 'Wine Advocate', 'parker': 'Wine Advocate', 'jancis robinson': 'Jancis Robinson', 'jancisrobinson.com': 'Jancis Robinson',
            'allen meadows': 'Burghound', 'burghound': 'Burghound', 'stephen tanzer': 'Vinous', 'international wine cellars': 'Vinous', "kerin o'keefe": "Kerin O'Keefe", 'james suckling': 'James Suckling', 'wine spectator': 'Wine Spectator',
            'jeb dunnuck': 'Jeb Dunnuck', 'decanter': 'Decanter', 'wine enthusiast': 'Wine Enthusiast', 'neal martin': 'Neal Martin', 'jane anson': 'Jane Anson',
            'the wine independent': 'Wine Independent', 'lisa perrotti-brown': 'Lisa Perrotti-Brown', 'william kelley': 'William Kelley', 'tim atkin': 'Tim Atkin',
            'jasper morris': 'Jasper Morris', 'falstaff': 'Falstaff', 'james halliday': 'James Halliday', 'wine & spirits': 'Wine & Spirits'}
    if len(sys.argv) > 2:
        for f in glob.glob(os.path.join(sys.argv[2], '*.jsonl')):
            for line in open(f):
                try: p = json.loads(line)
                except Exception: continue
                d = {}
                for crit, val in p.get('scores') or []:
                    m = re.match(r'([\d.]+)(?:\s*-\s*([\d.]+))?(/20)?', str(val))
                    if not m: continue
                    v = float(m.group(1)); hi = float(m.group(2)) if m.group(2) else None
                    v = (v + hi) / 2 if hi and hi > v else v
                    name = NORM.get(fold(crit).strip(), crit.strip())
                    if m.group(3) or (name == 'Jancis Robinson' and v <= 20): d.setdefault(name, (v, '/20'))
                    elif 80 <= v <= 100: d.setdefault(name, (v, ''))
                if d: PAGE[p['url']] = d
        print('product pages with scores', len(PAGE))
    cols = ['wine','producer','vintage','size_ml','color','country','region','appellation','grapes','aromas','notes','avg_score','scores','score_links','details_link']
    w = csv.DictWriter(open(P + 'wine_details.csv', 'w', newline=''), fieldnames=cols)
    w.writeheader(); stats = C.Counter(); ROWS = []
    for r in csv.DictReader(open(P + 'wine_prices.csv')):
        urls = [u.split(': ', 1)[1] for u in r['links'].split(' ; ') if ': ' in u]
        facts = [(u, analyse(r['wine'], DET.get(u))) for u in urls if u in DET] or [(None, analyse(r['wine'], None))]
        for u in urls:
            if u in PAGE:
                hitf = next((f for uu, f in facts if uu == u), None)
                if hitf is None: hitf = analyse(r['wine'], DET.get(u)); facts.append((u, hitf))
                for k, v in PAGE[u].items(): hitf['scores'].setdefault(k, v)
        def vote(k):
            c = C.Counter(f[k] for _, f in facts if f.get(k))
            return c.most_common(1)[0][0] if c else ''
        country, region, app, color = vote('country'), vote('region'), vote('appellation'), vote('color')
        if app and region and fold(app) == fold(region): app = ''
        grapes = []; aromas = C.Counter(); style = []
        for _, f in facts:
            for g in f['grapes']:
                if g not in grapes: grapes.append(g)
            for i, a in enumerate(f['aromas']): aromas[a] += 10 - i
            for s in f['style']:
                if s not in style: style.append(s)
        arl = [a for a, _ in aromas.most_common(6)]
        crit = C.defaultdict(list); links = []
        for u, f in facts:
            for n, (s, sc) in f['scores'].items():
                crit[(n, sc)].append(s)
                if u and u not in links: links.append(u)
        sc_list = [(n, sc, S.mean(v)) for (n, sc), v in crit.items()]
        hundred = [s for n, sc, s in sc_list if not sc]
        avg = f'{S.mean(hundred):.1f}' if hundred else ''
        bits = []
        kind = (color + ' wine') if color and color not in ('Sparkling', 'Fortified') else (color.lower() + ' wine' if color else 'Wine')
        kind = kind[0].upper() + kind[1:]
        where = ', '.join(x for x in [app or region, country] if x)
        bits.append(kind + (f' from {where}' if where else '') + '.')
        if grapes: bits.append('Grapes: ' + ', '.join(grapes) + '.')
        if style: bits.append('Style: ' + ', '.join(style) + '.')
        if arl: bits.append('Aromas: ' + ', '.join(a.lower() for a in arl) + '.')
        if avg: bits.append(f'Critics: {avg}/100 on average from {len(hundred)} score' + ('s' if len(hundred) > 1 else '') + '.')
        detail = next((u for u in urls if u in DET and len(DET[u]['text']) > 80), (urls[0] if urls else r.get('cheapest_link', '')))
        ROWS.append({'_crit': {(n, sc): s for n, sc, s in sc_list}, '_links': links, '_bits': bits, 'wine': r['wine'], 'producer': r['producer'], 'vintage': r['vintage'], 'size_ml': r['size_ml'], 'color': color, 'country': country,
                    'region': region, 'appellation': app, 'grapes': ', '.join(grapes), 'aromas': ', '.join(arl), 'notes': ' '.join(bits), 'avg_score': avg,
                    'details_link': detail})
    def wkey(row):
        n = re.sub(r'\b(magnum|double magnum|jeroboam|imperial|half bottle|\d+(?:\.\d+)?\s*(?:ml|cl|l|ltr|litre))\b', ' ', fold(row['wine']))
        return (' '.join(sorted(set(re.findall(r'[a-z0-9]+', n)))), row['vintage'])
    share = {}
    for row in ROWS:
        if row['_crit'] and row['vintage']:
            k = wkey(row); cur = share.setdefault(k, ({}, []))
            for key, v in row['_crit'].items(): cur[0].setdefault(key, v)
            for u in row['_links']:
                if u not in cur[1]: cur[1].append(u)
    for row in ROWS:
        if row['vintage'] and wkey(row) in share:
            crit, links = share[wkey(row)]
            for key, v in crit.items(): row['_crit'].setdefault(key, v)
            for u in links:
                if u not in row['_links']: row['_links'].append(u)
        crit = row.pop('_crit'); links = row.pop('_links'); bits = row.pop('_bits')
        hundred = [v for (n, sc), v in crit.items() if not sc]
        row['avg_score'] = f'{S.mean(hundred):.1f}' if hundred else ''
        bits = [b for b in bits if not b.startswith('Critics:')]
        if hundred: bits.append(f"Critics: {row['avg_score']}/100 on average from {len(hundred)} score" + ('s' if len(hundred) > 1 else '') + '.')
        row['notes'] = ' '.join(bits)
        row['scores'] = ' ; '.join(f'{n}: {v:g}{sc}' for (n, sc), v in sorted(crit.items(), key=lambda x: -x[1]))
        row['score_links'] = ' ; '.join(links)
        w.writerow(row)
        stats['rows'] += 1
        for k in ('country', 'region', 'appellation', 'color', 'grapes', 'aromas', 'avg_score'):
            if row[k]: stats[k] += 1
    print(dict(stats))
if __name__ == '__main__':
    main()
