# Italy (comuni from openpolis/geojson-italy, ISTAT data) and USA (AVA boundaries, UC Davis Library AVA project).
from specs_fr import A

# --------------------------------------------------------------- Italy: zones by comuni inside polygons (per region)
def Z(id, name, reg, polys, color, label=None, grapes=None):
    return dict(id=id, name=name, lv=0, reg=reg, polys=polys, color=color, label=label, grapes=grapes, communes=[])

ITALY = [
    Z("piedmont", "Piedmont", "Piemonte", [
        [(45.15, 7.75), (45.15, 8.62), (44.75, 8.95), (44.45, 8.78), (44.40, 7.80), (44.70, 7.68)],
        [(45.72, 8.22), (45.72, 8.52), (45.48, 8.52), (45.48, 8.22)]], "claret", (45.35, 7.0), "Nebbiolo · Barbera · Moscato"),
    Z("lombardy", "Lombardy", "Lombardia", [
        [(45.68, 9.88), (45.68, 10.18), (45.50, 10.18), (45.50, 9.88)],
        [(46.25, 9.62), (46.28, 10.18), (46.12, 10.18), (46.10, 9.62)],
        [(45.06, 8.95), (45.06, 9.38), (44.78, 9.38), (44.78, 8.95)]], "violet", (46.4, 9.3), "Franciacorta · Nebbiolo"),
    Z("trentino-alto-adige", "Trentino-Alto Adige", "Trentino-Alto Adige/Südtirol", [
        [(46.78, 11.05), (46.75, 11.48), (46.30, 11.30), (45.82, 11.20), (45.82, 10.95), (46.30, 11.02)]], "teal",
        (46.85, 11.9), "Pinot Grigio · Gewürztraminer"),
    Z("veneto", "Veneto", "Veneto", [
        [(45.62, 10.68), (45.60, 11.38), (45.35, 11.38), (45.40, 10.68)],
        [(46.00, 11.88), (45.96, 12.42), (45.78, 12.42), (45.80, 11.88)],
        [(45.60, 12.40), (45.75, 12.90), (45.55, 12.95), (45.42, 12.45)]], "magenta", (45.2, 12.0), "Corvina · Glera · Garganega"),
    Z("friuli", "Friuli", "Friuli-Venezia Giulia", [
        [(46.25, 13.12), (46.15, 13.66), (45.86, 13.62), (45.95, 13.18)],
        [(46.10, 12.55), (46.10, 13.10), (45.85, 13.10), (45.85, 12.55)]], "green", (46.45, 13.3), "Friulano · Pinot Grigio"),
    Z("emilia-romagna", "Emilia-Romagna", "Emilia-Romagna", [
        [(44.88, 10.35), (44.88, 11.15), (44.52, 11.15), (44.52, 10.35)],
        [(44.42, 11.55), (44.42, 12.35), (44.02, 12.35), (44.02, 11.55)]], "orange", (44.95, 11.75), "Lambrusco · Sangiovese"),
    Z("tuscany", "Tuscany", "Toscana", [
        [(43.97, 10.85), (43.97, 11.58), (43.30, 11.98), (42.92, 11.88), (42.92, 11.35), (43.35, 10.98)],
        [(43.32, 10.48), (43.20, 10.78), (42.55, 11.48), (42.42, 11.15), (43.05, 10.52)]], "rose", (43.2, 10.1),
        "Sangiovese · Super Tuscans"),
    Z("umbria", "Umbria", "Umbria", [[(43.05, 12.30), (43.02, 12.78), (42.68, 12.78), (42.68, 12.02)]], "plum",
        (42.6, 12.95), "Sagrantino · Grechetto"),
    Z("marche", "Marche", "Marche", [[(43.68, 12.88), (43.66, 13.62), (43.22, 13.62), (43.28, 12.88)]], "gold",
        (43.75, 13.75), "Verdicchio · Montepulciano"),
    Z("abruzzo", "Abruzzo", "Abruzzo", [[(42.68, 13.82), (42.55, 14.32), (42.05, 14.72), (42.02, 14.35), (42.40, 13.78)]],
        "coral", (42.55, 14.85), "Montepulciano · Trebbiano"),
    Z("campania", "Campania", "Campania", [[(41.38, 14.38), (41.38, 15.22), (40.72, 15.22), (40.72, 14.38)]], "claret",
        (40.75, 13.6), "Aglianico · Fiano · Greco"),
    Z("basilicata", "Basilicata", "Basilicata", [[(41.08, 15.48), (41.08, 15.88), (40.78, 15.88), (40.78, 15.48)]],
        "violet", (40.45, 15.6), "Aglianico"),
    Z("puglia", "Puglia", "Puglia", [
        [(41.22, 15.88), (41.22, 16.42), (40.82, 16.42), (40.82, 15.88)],
        [(40.62, 17.28), (40.62, 18.12), (40.02, 18.42), (40.02, 17.78)]], "orange", (41.3, 17.0), "Primitivo · Negroamaro"),
    Z("sicily", "Sicily", "Sicilia", [
        [(37.97, 14.78), (37.97, 15.26), (37.58, 15.26), (37.58, 14.78)],
        [(38.18, 12.38), (38.18, 13.02), (37.58, 13.02), (37.58, 12.38)],
        [(37.12, 14.28), (37.12, 14.82), (36.78, 14.82), (36.78, 14.28)]], "teal", (38.4, 14.2), "Nero d'Avola · Nerello"),
    Z("sardinia", "Sardinia", "Sardegna", [
        [(41.22, 8.98), (41.22, 9.62), (40.83, 9.62), (40.83, 8.98)],
        [(40.48, 9.22), (40.48, 9.78), (39.83, 9.78), (39.83, 9.22)],
        [(39.48, 8.58), (39.48, 9.22), (39.08, 9.22), (39.08, 8.58)]], "green", (40.1, 8.0), "Cannonau · Vermentino"),
]

PIEDMONT = [
    A("barolo", "Barolo", 1, ["Piemonte"], ["Barolo", "Castiglione Falletto", "Serralunga d'Alba", "Monforte d'Alba",
        "La Morra", "Verduno", "Grinzane Cavour", "Novello", "Cherasco", "Diano d'Alba", "Roddi"], color="claret",
        label=(44.55, 7.72), grapes="Nebbiolo"),
    A("barbaresco", "Barbaresco", 1, ["Piemonte"], ["Barbaresco", "Neive", "Treiso"], color="magenta", grapes="Nebbiolo"),
    A("roero", "Roero", 1, ["Piemonte"], ["Canale", "Vezza d'Alba", "Monticello d'Alba", "Santo Stefano Roero", "Monteu Roero",
        "Montà", "Castellinaldo d'Alba", "Guarene", "Priocca", "Govone", "Corneliano d'Alba", "Piobesi d'Alba", "Castagnito",
        "Baldissero d'Alba", "Pocapaglia", "Sommariva Perno", "Santa Vittoria d'Alba", "Montaldo Roero"], color="rose",
        grapes="Nebbiolo · Arneis"),
    A("dogliani", "Dogliani", 1, ["Piemonte"], ["Dogliani", "Belvedere Langhe", "Bastia Mondovì", "Cigliè", "Clavesana",
        "Farigliano", "Monchiero", "Rocca Cigliè", "Somano"], color="violet", grapes="Dolcetto"),
    A("gavi", "Gavi", 1, ["Piemonte"], ["Gavi", "Bosio", "Carrosio", "Francavilla Bisio", "Parodi Ligure", "San Cristoforo",
        "Serravalle Scrivia", "Tassarolo", "Pasturana", "Capriata d'Orba", "Novi Ligure"], color="gold", grapes="Cortese"),
    A("moscato-dasti", "Moscato d'Asti", 1, ["Piemonte"], within=[(44.82, 8.12), (44.82, 8.48), (44.55, 8.48), (44.55, 8.20)],
        color="ochre", grapes="Moscato Bianco"),
    A("barbera-dasti", "Barbera d'Asti", 1, ["Piemonte"], within=[(45.08, 7.98), (45.08, 8.58), (44.82, 8.58), (44.82, 7.98)],
        color="coral", grapes="Barbera"),
]
TUSCANY = [
    A("chianti-classico", "Chianti Classico", 1, ["Toscana"], ["Greve in Chianti", "Radda in Chianti", "Gaiole in Chianti",
        "Castellina in Chianti", "Castelnuovo Berardenga", "San Casciano in Val di Pesa", "Barberino Tavarnelle", "Poggibonsi"],
        color="claret", grapes="Sangiovese"),
    A("montalcino", "Brunello di Montalcino", 1, ["Toscana"], ["Montalcino"], color="magenta", grapes="Sangiovese"),
    A("montepulciano", "Vino Nobile di Montepulciano", 1, ["Toscana"], ["Montepulciano"], color="plum", grapes="Sangiovese"),
    A("bolgheri", "Bolgheri", 1, ["Toscana"], ["Castagneto Carducci"], color="violet", grapes="Cabernet · Merlot"),
    A("carmignano", "Carmignano", 1, ["Toscana"], ["Carmignano", "Poggio a Caiano"], color="coral"),
    A("san-gimignano", "San Gimignano", 1, ["Toscana"], ["San Gimignano"], color="gold", grapes="Vernaccia"),
    A("maremma", "Maremma", 1, ["Toscana"], ["Scansano", "Magliano in Toscana", "Manciano", "Roccalbegna", "Campagnatico",
        "Semproniano"], color="orange", grapes="Sangiovese (Morellino)"),
    A("chianti", "Chianti", 1, ["Toscana"], within=[(43.97, 10.75), (43.97, 11.72), (43.30, 11.98), (43.12, 11.62),
        (43.35, 10.92)], color="rose", grapes="Sangiovese"),
]

# --------------------------------------------------------------- USA (AVA names exactly as in the dataset)
# (ava name, id, color) ; children found via the dataset's 'within' field
CALIFORNIA = [("North Coast", "north-coast", "claret"), ("Central Coast", "central-coast", "teal"),
              ("Sierra Foothills", "sierra-foothills", "gold"), ("Lodi", "lodi", "orange"), ("South Coast", "south-coast", "violet"),
              ("Clarksburg", "clarksburg", "coral")]
NAPA_SONOMA = [("Napa Valley", "napa-valley", "claret"), ("Northern Sonoma", "northern-sonoma", "magenta"),
               ("Sonoma Coast", "sonoma-coast", "teal"), ("Sonoma Valley", "sonoma-valley", "rose"),
               ("Los Carneros", "carneros", "gold"), ("Russian River Valley", "russian-river", "violet"),
               ("Alexander Valley", "alexander-valley", "orange"), ("Dry Creek Valley", "dry-creek", "coral")]
NORTHWEST = [("Willamette Valley", "willamette", "claret"), ("Columbia Valley", "columbia-valley", "gold"),
             ("Walla Walla Valley", "walla-walla", "magenta"), ("Southern Oregon", "southern-oregon", "violet"),
             ("Yakima Valley", "yakima", "orange"), ("Columbia Gorge", "columbia-gorge", "teal"), ("Puget Sound", "puget-sound", "green")]
AVA_IDS = {"Oakville": "oakville", "Rutherford": "rutherford", "Stags Leap District": "stags-leap", "Howell Mountain": "howell-mountain",
           "Mt. Veeder": "mount-veeder", "Mount Veeder": "mount-veeder", "Mendocino": "mendocino", "Mendocino County": "mendocino",
           "Paso Robles": "paso-robles", "Santa Rita Hills": "santa-rita-hills", "Sta. Rita Hills": "santa-rita-hills"}
