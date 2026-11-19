# Wine map definitions. Coordinates are (lat, lon). Region shapes are approximate
# illustrations (Wine Folly style), not legal appellation boundaries.
#
#   blob(lat, lon, r_km)                 circle
#   blob(lat, lon, (rx_km, ry_km), deg)  ellipse, rotated deg counter-clockwise
#   strip([(lat, lon), ...], width_km)   band along a path (valleys, slopes)
#   poly([(lat, lon), ...])              freeform outline

def blob(lat, lon, r, angle=0):
    return {"t": "blob", "c": (lat, lon), "r": r if isinstance(r, tuple) else (r, r), "a": angle}

def strip(pts, w):
    return {"t": "strip", "p": pts, "w": w}

def poly(pts):
    return {"t": "poly", "p": pts}

def R(id, name, *shapes, label=None, color=None, small=False):
    return {"id": id, "name": name, "shapes": list(shapes), "label": label, "color": color, "small": small}

WINE_COUNTRIES = ["FRA", "ITA", "ESP", "PRT", "DEU", "AUT", "HUN", "GRC", "USA", "CHL", "ARG",
                  "AUS", "NZL", "ZAF", "CAN", "CHE", "GEO", "ROU", "MDA", "SVN", "HRV", "BGR",
                  "URY", "CHN", "LBN", "ISR", "GBR"]

MAPS = []

def M(id, title, bbox, focus, regions, cities=(), labels=(), river_rank=10, world=False):
    # bbox = (lat_min, lon_min, lat_max, lon_max)
    MAPS.append({"id": id, "title": title, "bbox": bbox, "focus": focus, "regions": regions,
                 "cities": list(cities), "labels": list(labels), "river_rank": river_rank, "world": world})

# ---------------------------------------------------------------- world
M("world", "The wine world", (-56, -170, 72, 180), WINE_COUNTRIES, [], cities=[
    ("Bordeaux", 44.84, -0.58), ("Champagne", 49.05, 4.0), ("Mosel", 49.9, 6.9), ("Tuscany", 43.4, 11.2), ("Rioja", 42.45, -2.45),
    ("Douro", 41.16, -7.6), ("Tokaj", 48.12, 21.4), ("Napa", 38.5, -122.3), ("Willamette", 45.1, -123.1), ("Finger Lakes", 42.6, -77.0),
    ("Mendoza", -33.0, -68.8), ("Maipo", -33.7, -70.7), ("Stellenbosch", -33.9, 18.85), ("Barossa", -34.5, 138.95),
    ("Marlborough", -41.5, 173.9), ("Bekaa", 33.85, 35.9), ("Ningxia", 38.5, 106.2)], labels=[
    ("30°–50° N", 52.5, -160, "area"), ("30°–50° S", -27, -160, "area"),
    ("Atlantic Ocean", 25, -40, "sea"), ("Pacific Ocean", 5, -140, "sea"), ("Indian Ocean", -20, 80, "sea"),
], world=True)

# ---------------------------------------------------------------- France
M("france", "France", (41.3, -5.3, 51.2, 9.8), ["FRA"], [
    R("champagne", "Champagne", poly([(49.42, 3.62), (49.36, 4.28), (49.0, 4.3), (48.72, 4.08), (48.82, 3.62), (49.1, 3.45)]),
      blob(48.1, 4.4, (16, 12), 30)),
    R("alsace", "Alsace", strip([(48.72, 7.45), (48.4, 7.42), (48.15, 7.3), (47.95, 7.24), (47.72, 7.25)], 14)),
    R("burgundy", "Burgundy", blob(47.81, 3.8, 12), strip([(47.31, 4.98), (47.12, 4.94), (46.92, 4.7), (46.62, 4.73)], 12),
      blob(46.38, 4.77, (9, 18))),
    R("beaujolais", "Beaujolais", blob(46.08, 4.62, (10, 22))),
    R("jura", "Jura", blob(46.75, 5.65, (9, 18), 20), small=True),
    R("savoie", "Savoie", blob(45.6, 5.95, 13), small=True),
    R("rhone", "Rhône", strip([(45.55, 4.85), (45.2, 4.82), (44.93, 4.87)], 12), blob(44.15, 4.85, (35, 30))),
    R("provence", "Provence", blob(43.5, 6.0, (75, 32), -5)),
    R("languedoc", "Languedoc-Roussillon", strip([(43.88, 4.3), (43.62, 3.45), (43.25, 2.75), (42.7, 2.8)], 45)),
    R("southwest", "South West", blob(44.45, 1.3, 18), blob(43.6, -0.05, 15), blob(43.25, -0.4, 12), blob(44.85, 0.48, 18)),
    R("bordeaux", "Bordeaux", poly([(45.56, -1.07), (45.35, -0.62), (45.08, -0.42), (44.95, 0.12), (44.72, 0.2), (44.48, -0.15),
                                    (44.55, -0.48), (44.78, -0.72), (45.08, -0.86), (45.38, -1.08)])),
    R("loire", "Loire Valley", strip([(47.2, -1.6), (47.4, -0.6), (47.26, -0.08), (47.36, 0.7), (47.58, 1.35)], 32),
      blob(47.31, 2.88, 18)),
], cities=[("Paris", 48.857, 2.352), ("Bordeaux", 44.84, -0.58), ("Lyon", 45.76, 4.84), ("Reims", 49.26, 4.03),
           ("Dijon", 47.32, 5.04), ("Strasbourg", 48.57, 7.75), ("Tours", 47.39, 0.69), ("Marseille", 43.30, 5.37),
           ("Nantes", 47.22, -1.55), ("Montpellier", 43.61, 3.88)],
  labels=[("Atlantic Ocean", 46.2, -3.7, "sea"), ("Mediterranean Sea", 42.3, 5.6, "sea"), ("English Channel", 50.2, -2.3, "sea"),
          ("Loire", 47.65, 0.3, "river"), ("Rhône", 44.6, 4.55, "river"), ("Garonne", 44.25, 0.5, "river")],
  river_rank=6)

M("bordeaux", "Bordeaux", (44.45, -1.3, 45.6, 0.35), ["FRA"], [
    R("medoc", "Médoc", poly([(45.57, -1.08), (45.5, -0.92), (45.33, -0.8), (45.3, -0.95), (45.45, -1.1)])),
    R("haut-medoc", "Haut-Médoc", poly([(45.33, -0.8), (45.2, -0.72), (45.05, -0.63), (44.92, -0.61), (44.9, -0.72), (45.05, -0.8),
                                        (45.25, -0.88), (45.3, -0.95)])),
    R("saint-estephe", "Saint-Estèphe", blob(45.26, -0.78, 3.2), small=True),
    R("pauillac", "Pauillac", blob(45.195, -0.76, 3.2), small=True),
    R("saint-julien", "Saint-Julien", blob(45.155, -0.74, 2.4), small=True),
    R("margaux", "Margaux", blob(45.04, -0.67, 3.4), small=True),
    R("pessac-leognan", "Pessac-Léognan", poly([(44.83, -0.64), (44.8, -0.57), (44.7, -0.55), (44.68, -0.62), (44.75, -0.69)])),
    R("graves", "Graves", poly([(44.7, -0.55), (44.62, -0.4), (44.52, -0.22), (44.48, -0.27), (44.58, -0.45), (44.68, -0.6)])),
    R("sauternes", "Sauternes & Barsac", blob(44.535, -0.33, (5, 4))),
    R("entre-deux-mers", "Entre-Deux-Mers", poly([(45.0, -0.52), (44.9, -0.3), (44.86, -0.1), (44.73, 0.05), (44.59, -0.1),
                                                  (44.58, -0.24), (44.75, -0.47)])),
    R("saint-emilion", "Saint-Émilion", poly([(44.925, -0.22), (44.92, -0.1), (44.87, -0.08), (44.86, -0.18)])),
    R("pomerol", "Pomerol", blob(44.935, -0.21, 2.6), small=True),
    R("fronsac", "Fronsac", blob(44.955, -0.29, 3.2), small=True),
    R("castillon", "Castillon", blob(44.86, 0.02, (6, 3.5))),
    R("bourg", "Côtes de Bourg", blob(45.05, -0.52, (5, 6))),
    R("blaye", "Blaye", poly([(45.25, -0.7), (45.25, -0.45), (45.1, -0.42), (45.1, -0.62)])),
], cities=[("Bordeaux", 44.84, -0.58), ("Libourne", 44.915, -0.243), ("Langon", 44.553, -0.249), ("Arcachon", 44.66, -1.17),
           ("Blaye", 45.128, -0.662)],
  labels=[("Atlantic Ocean", 45.05, -1.22, "sea"), ("Garonne", 44.66, -0.4, "river"), ("Dordogne", 44.83, 0.2, "river"),
          ("Gironde", 45.38, -0.84, "river"), ("LEFT BANK", 45.15, -1.0, "area"), ("RIGHT BANK", 45.05, -0.05, "area")])

M("burgundy", "Burgundy", (45.95, 3.4, 48.0, 5.4), ["FRA"], [
    R("chablis", "Chablis", blob(47.81, 3.8, (11, 9))),
    R("cote-de-nuits", "Côte de Nuits", strip([(47.31, 5.0), (47.2, 4.97), (47.12, 4.93)], 5)),
    R("cote-de-beaune", "Côte de Beaune", strip([(47.1, 4.9), (47.02, 4.84), (46.98, 4.77), (46.91, 4.69)], 6)),
    R("cote-chalonnaise", "Côte Chalonnaise", strip([(46.87, 4.71), (46.78, 4.74), (46.68, 4.76)], 8)),
    R("maconnais", "Mâconnais", blob(46.38, 4.77, (9, 17))),
    R("beaujolais", "Beaujolais", blob(46.08, 4.62, (10, 19))),
], cities=[("Dijon", 47.32, 5.04), ("Beaune", 47.025, 4.84), ("Mâcon", 46.31, 4.83), ("Chablis", 47.81, 3.8),
           ("Auxerre", 47.8, 3.57), ("Nuits-St-Georges", 47.137, 4.95), ("Meursault", 46.98, 4.77)],
  labels=[("Saône", 46.6, 5.0, "river"), ("Yonne", 47.6, 3.45, "river")])

M("rhone", "Rhône Valley", (43.75, 4.0, 45.7, 5.6), ["FRA"], [
    R("cote-rotie", "Côte-Rôtie", strip([(45.51, 4.8), (45.45, 4.77)], 3), small=True),
    R("condrieu", "Condrieu", blob(45.42, 4.76, 3), small=True),
    R("saint-joseph", "Saint-Joseph", strip([(45.37, 4.78), (45.2, 4.8), (45.02, 4.83)], 4)),
    R("crozes-hermitage", "Crozes-Hermitage", blob(45.11, 4.88, (6, 9))),
    R("hermitage", "Hermitage", blob(45.07, 4.84, 2.2), small=True),
    R("cornas", "Cornas", blob(44.965, 4.85, 2.2), small=True),
    R("cotes-du-rhone", "Côtes du Rhône", blob(44.2, 4.82, (26, 24))),
    R("gigondas", "Gigondas", blob(44.165, 5.0, 4), small=True),
    R("vacqueyras", "Vacqueyras", blob(44.13, 4.97, 3), small=True),
    R("chateauneuf-du-pape", "Châteauneuf-du-Pape", blob(44.06, 4.83, 6)),
    R("tavel", "Tavel & Lirac", blob(44.01, 4.7, 5)),
], cities=[("Lyon", 45.76, 4.84), ("Vienne", 45.52, 4.87), ("Valence", 44.93, 4.89), ("Montélimar", 44.56, 4.75),
           ("Orange", 44.14, 4.81), ("Avignon", 43.95, 4.81)],
  labels=[("Rhône", 44.75, 4.6, "river"), ("NORTHERN RHÔNE", 45.3, 5.3, "area"), ("SOUTHERN RHÔNE", 44.45, 5.3, "area")])

M("loire", "Loire Valley", (46.75, -2.3, 47.95, 3.25), ["FRA"], [
    R("muscadet", "Muscadet", blob(47.12, -1.35, (24, 14))),
    R("anjou", "Anjou", blob(47.25, -0.62, (22, 15))),
    R("savennieres", "Savennières", blob(47.39, -0.67, 3.5), small=True),
    R("saumur", "Saumur", blob(47.2, -0.05, (12, 9))),
    R("chinon", "Chinon", blob(47.16, 0.24, (9, 6))),
    R("bourgueil", "Bourgueil", blob(47.28, 0.17, (7, 4))),
    R("vouvray", "Vouvray", blob(47.43, 0.8, (6, 4))),
    R("montlouis", "Montlouis", blob(47.375, 0.85, (5, 3)), small=True),
    R("touraine", "Touraine", blob(47.27, 1.2, (30, 14))),
    R("sancerre", "Sancerre", blob(47.33, 2.8, 11)),
    R("pouilly-fume", "Pouilly-Fumé", blob(47.28, 2.98, (5, 8))),
], cities=[("Nantes", 47.22, -1.55), ("Angers", 47.47, -0.55), ("Saumur", 47.26, -0.08), ("Tours", 47.39, 0.69),
           ("Blois", 47.59, 1.33), ("Sancerre", 47.33, 2.84)],
  labels=[("Loire", 47.5, 1.9, "river"), ("Atlantic", 47.0, -2.15, "sea")])

M("champagne", "Champagne", (47.8, 3.2, 49.5, 4.9), ["FRA"], [
    R("montagne-de-reims", "Montagne de Reims", blob(49.15, 4.03, (14, 7))),
    R("vallee-de-la-marne", "Vallée de la Marne", strip([(49.08, 3.4), (49.07, 3.75), (49.06, 4.05)], 7)),
    R("cote-des-blancs", "Côte des Blancs", strip([(49.02, 3.96), (48.92, 3.98), (48.85, 4.0)], 5)),
    R("cote-de-sezanne", "Côte de Sézanne", blob(48.72, 3.75, (5, 9))),
    R("cote-des-bar", "Côte des Bar", blob(48.1, 4.4, (20, 14), 25)),
], cities=[("Reims", 49.26, 4.03), ("Épernay", 49.04, 3.96), ("Troyes", 48.3, 4.08)],
  labels=[("Marne", 49.0, 4.5, "river"), ("Seine", 48.4, 4.0, "river")])

# ---------------------------------------------------------------- Italy
M("italy", "Italy", (36.4, 6.4, 47.2, 18.7), ["ITA"], [
    R("piedmont", "Piedmont", blob(44.75, 8.1, (40, 30))),
    R("trentino-alto-adige", "Trentino-Alto Adige", strip([(46.6, 11.35), (46.3, 11.25), (46.06, 11.12), (45.85, 11.0)], 22)),
    R("lombardy", "Lombardy (Franciacorta)", blob(45.6, 10.0, 15)),
    R("veneto", "Veneto", blob(45.55, 11.6, (65, 30), 10)),
    R("friuli", "Friuli", blob(46.0, 13.35, 28)),
    R("emilia-romagna", "Emilia-Romagna", blob(44.55, 11.0, (60, 22), -20)),
    R("tuscany", "Tuscany", blob(43.35, 11.2, (55, 70))),
    R("umbria", "Umbria", blob(42.95, 12.55, 22)),
    R("marche", "Marche", blob(43.4, 13.2, 22)),
    R("abruzzo", "Abruzzo", blob(42.25, 14.0, 32)),
    R("campania", "Campania", blob(41.0, 14.8, 35)),
    R("puglia", "Puglia", blob(40.7, 17.1, (85, 30), -35)),
    R("basilicata", "Basilicata", blob(40.95, 15.65, 12)),
    R("sicily", "Sicily", blob(37.6, 14.1, (95, 50))),
    R("sardinia", "Sardinia", blob(40.1, 9.0, (40, 75))),
], cities=[("Rome", 41.9, 12.5), ("Milan", 45.46, 9.19), ("Turin", 45.07, 7.69), ("Florence", 43.77, 11.25),
           ("Venice", 45.44, 12.33), ("Naples", 40.85, 14.27), ("Verona", 45.44, 10.99), ("Palermo", 38.12, 13.36)],
  labels=[("Tyrrhenian Sea", 40.0, 12.0, "sea"), ("Adriatic Sea", 43.0, 15.5, "sea"), ("Ionian Sea", 38.0, 18.0, "sea"),
          ("Po", 45.1, 10.4, "river")],
  river_rank=6)

M("piedmont", "Piedmont", (44.35, 7.55, 45.1, 8.95), ["ITA"], [
    R("barolo", "Barolo", blob(44.59, 7.94, (6, 8))),
    R("barbaresco", "Barbaresco", blob(44.73, 8.1, (4, 5))),
    R("roero", "Roero", blob(44.79, 7.92, (8, 6))),
    R("dogliani", "Dogliani", blob(44.5, 7.95, (6, 5))),
    R("barbera-dasti", "Barbera d'Asti", blob(44.88, 8.3, (18, 12))),
    R("moscato-dasti", "Moscato d'Asti", blob(44.7, 8.28, (12, 8))),
    R("gavi", "Gavi", blob(44.69, 8.8, 7)),
], cities=[("Alba", 44.7, 8.035), ("Asti", 44.9, 8.21), ("Barolo", 44.61, 7.94), ("Cuneo", 44.39, 7.55)],
  labels=[("Tanaro", 44.8, 8.45, "river"), ("LANGHE", 44.6, 8.15, "area")])

M("tuscany", "Tuscany", (42.3, 10.0, 44.1, 12.3), ["ITA"], [
    R("chianti", "Chianti", blob(43.55, 11.25, (32, 24))),
    R("chianti-classico", "Chianti Classico", blob(43.48, 11.33, (12, 15))),
    R("carmignano", "Carmignano", blob(43.81, 11.01, 4), small=True),
    R("san-gimignano", "San Gimignano", blob(43.47, 11.04, 5), small=True),
    R("bolgheri", "Bolgheri", blob(43.22, 10.62, (5, 9))),
    R("montalcino", "Brunello di Montalcino", blob(43.06, 11.49, 9)),
    R("montepulciano", "Vino Nobile di Montepulciano", blob(43.1, 11.79, 7)),
    R("maremma", "Maremma (Morellino)", blob(42.72, 11.2, (22, 14))),
], cities=[("Florence", 43.77, 11.25), ("Siena", 43.32, 11.33), ("Pisa", 43.72, 10.40), ("Livorno", 43.55, 10.31),
           ("Grosseto", 42.76, 11.11)],
  labels=[("Tyrrhenian Sea", 42.65, 10.35, "sea"), ("Arno", 43.72, 10.75, "river")])

# ---------------------------------------------------------------- Spain & Portugal
M("spain", "Spain", (35.8, -9.6, 44.0, 3.5), ["ESP"], [
    R("rias-baixas", "Rías Baixas", blob(42.4, -8.65, (14, 28))),
    R("bierzo", "Bierzo", blob(42.6, -6.7, 18)),
    R("rioja", "Rioja", strip([(42.65, -2.98), (42.47, -2.45), (42.2, -1.8)], 22)),
    R("navarra", "Navarra", blob(42.62, -1.62, (18, 24))),
    R("ribera-del-duero", "Ribera del Duero", strip([(41.65, -4.3), (41.64, -3.7), (41.6, -3.3)], 16)),
    R("rueda", "Rueda", blob(41.38, -4.95, 18)),
    R("toro", "Toro", blob(41.52, -5.4, 12)),
    R("priorat", "Priorat", blob(41.18, 0.8, 11)),
    R("penedes", "Penedès (Cava)", blob(41.38, 1.7, 20)),
    R("la-mancha", "La Mancha", blob(39.3, -3.0, (95, 55))),
    R("jumilla", "Jumilla", blob(38.47, -1.33, 18)),
    R("jerez", "Jerez (Sherry)", blob(36.72, -6.2, 18)),
], cities=[("Madrid", 40.42, -3.7), ("Barcelona", 41.39, 2.17), ("Logroño", 42.465, -2.445), ("Seville", 37.39, -5.98),
           ("Valladolid", 41.65, -4.72), ("Bilbao", 43.26, -2.93), ("Valencia", 39.47, -0.38)],
  labels=[("Atlantic Ocean", 43.2, -9.0, "sea"), ("Mediterranean Sea", 39.0, 1.8, "sea"), ("Ebro", 41.75, -0.6, "river"),
          ("Duero", 41.25, -4.0, "river")],
  river_rank=6)

M("portugal", "Portugal", (36.9, -9.8, 42.2, -6.0), ["PRT"], [
    R("vinho-verde", "Vinho Verde", blob(41.62, -8.4, (35, 45))),
    R("douro", "Douro", strip([(41.15, -7.9), (41.18, -7.5), (41.1, -7.0)], 22)),
    R("dao", "Dão", blob(40.55, -7.9, 28)),
    R("bairrada", "Bairrada", blob(40.45, -8.47, 18)),
    R("lisboa", "Lisboa", blob(39.2, -9.15, (20, 40))),
    R("tejo", "Tejo", blob(39.3, -8.55, 28)),
    R("setubal", "Setúbal", blob(38.55, -8.9, 18)),
    R("alentejo", "Alentejo", blob(38.6, -7.75, 60)),
], cities=[("Porto", 41.15, -8.61), ("Lisbon", 38.72, -9.14), ("Coimbra", 40.21, -8.43), ("Évora", 38.57, -7.91),
           ("Pinhão", 41.19, -7.55)],
  labels=[("Atlantic Ocean", 39.6, -9.6, "sea"), ("Douro", 41.0, -8.25, "river"), ("Tagus", 39.0, -8.25, "river")],
  river_rank=8)

# ---------------------------------------------------------------- Central Europe
M("germany", "Germany", (47.3, 5.8, 51.6, 13.9), ["DEU"], [
    R("ahr", "Ahr", blob(50.53, 7.0, 6), small=True),
    R("mittelrhein", "Mittelrhein", strip([(50.35, 7.6), (50.15, 7.7), (50.0, 7.8)], 5)),
    R("mosel", "Mosel", strip([(49.68, 6.55), (49.76, 6.66), (49.92, 7.07), (50.05, 7.13), (50.15, 7.17), (50.33, 7.55)], 7)),
    R("nahe", "Nahe", blob(49.8, 7.75, 11)),
    R("rheingau", "Rheingau", strip([(50.0, 7.88), (50.02, 8.1), (50.04, 8.3)], 6)),
    R("rheinhessen", "Rheinhessen", blob(49.83, 8.15, 20)),
    R("pfalz", "Pfalz", strip([(49.55, 8.15), (49.3, 8.12), (49.05, 8.0)], 13)),
    R("franken", "Franken", blob(49.85, 10.0, 28)),
    R("wurttemberg", "Württemberg", blob(49.0, 9.3, 24)),
    R("baden", "Baden", strip([(49.3, 8.62), (48.85, 8.25), (48.5, 8.0), (47.9, 7.65), (47.65, 7.6)], 16)),
    R("saale-unstrut", "Saale-Unstrut", blob(51.2, 11.8, 14)),
    R("sachsen", "Sachsen", blob(51.1, 13.55, 12)),
], cities=[("Frankfurt", 50.11, 8.68), ("Koblenz", 50.36, 7.59), ("Trier", 49.75, 6.64), ("Mainz", 50.0, 8.27),
           ("Stuttgart", 48.78, 9.18), ("Würzburg", 49.79, 9.95), ("Munich", 48.14, 11.58), ("Freiburg", 47.99, 7.85)],
  labels=[("Rhine", 49.0, 8.25, "river"), ("Mosel", 49.85, 6.75, "river"), ("Main", 49.95, 9.3, "river")],
  river_rank=8)

M("austria", "Austria", (46.3, 9.5, 49.1, 17.3), ["AUT"], [
    R("wachau", "Wachau", strip([(48.37, 15.33), (48.39, 15.45), (48.41, 15.57)], 5)),
    R("kremstal", "Kremstal", blob(48.43, 15.65, 7)),
    R("kamptal", "Kamptal", blob(48.52, 15.72, 8)),
    R("wagram", "Wagram", blob(48.43, 15.92, (11, 5))),
    R("weinviertel", "Weinviertel", blob(48.62, 16.4, (38, 26))),
    R("carnuntum", "Carnuntum", blob(48.08, 16.85, 8)),
    R("thermenregion", "Thermenregion", blob(47.95, 16.2, (6, 12))),
    R("neusiedlersee", "Neusiedlersee", blob(47.85, 16.9, 15)),
    R("leithaberg", "Leithaberg", blob(47.88, 16.6, 7)),
    R("mittelburgenland", "Mittelburgenland", blob(47.5, 16.5, 11)),
    R("steiermark", "Steiermark (Styria)", blob(46.8, 15.5, (40, 25))),
], cities=[("Vienna", 48.21, 16.37), ("Krems", 48.41, 15.6), ("Graz", 47.07, 15.44), ("Salzburg", 47.8, 13.04),
           ("Innsbruck", 47.27, 11.39)],
  labels=[("Danube", 48.3, 14.6, "river"), ("Lake Neusiedl", 47.6, 16.75, "river")],
  river_rank=8)

M("hungary", "Hungary", (45.6, 15.9, 48.7, 23.0), ["HUN"], [
    R("tokaj", "Tokaj", blob(48.2, 21.35, (12, 20), -30)),
    R("eger", "Eger", blob(47.9, 20.37, 14)),
    R("somlo", "Somló", blob(47.15, 17.37, 5), small=True),
    R("balaton", "Balaton", blob(46.85, 17.75, (35, 12), 30)),
    R("kunsag", "Kunság", blob(46.65, 19.7, (40, 30))),
    R("szekszard", "Szekszárd", blob(46.35, 18.7, 11)),
    R("villany", "Villány", blob(45.87, 18.45, 10)),
], cities=[("Budapest", 47.5, 19.04), ("Debrecen", 47.53, 21.63), ("Pécs", 46.07, 18.23)],
  labels=[("Danube", 46.6, 18.95, "river"), ("Tisza", 47.3, 20.3, "river")],
  river_rank=8)

M("greece", "Greece", (34.7, 19.4, 41.9, 28.6), ["GRC"], [
    R("naoussa", "Naoussa", blob(40.63, 22.07, 12)),
    R("amyndeo", "Amyndeo", blob(40.7, 21.65, 10)),
    R("patras", "Patras", blob(38.2, 21.8, 14)),
    R("nemea", "Nemea", blob(37.82, 22.65, 13)),
    R("mantinia", "Mantinia", blob(37.6, 22.4, 10)),
    R("santorini", "Santorini", blob(36.4, 25.43, 8)),
    R("crete", "Crete", blob(35.25, 25.1, (45, 20))),
], cities=[("Athens", 37.98, 23.73), ("Thessaloniki", 40.64, 22.94)],
  labels=[("Aegean Sea", 38.6, 25.3, "sea"), ("Ionian Sea", 37.8, 20.2, "sea")])

# ---------------------------------------------------------------- North America
M("usa-west", "West Coast USA", (32.3, -125.2, 49.2, -114.0), ["USA"], [
    R("columbia-valley", "Columbia Valley", blob(46.45, -119.6, (95, 65))),
    R("walla-walla", "Walla Walla", blob(46.07, -118.34, 18)),
    R("willamette", "Willamette Valley", strip([(45.55, -122.95), (45.0, -123.0), (44.5, -123.15)], 30)),
    R("southern-oregon", "Southern Oregon", blob(42.4, -123.2, 30)),
    R("mendocino", "Mendocino", blob(39.2, -123.3, 25)),
    R("napa-sonoma", "Napa & Sonoma", blob(38.45, -122.6, 30)),
    R("lodi", "Lodi", blob(38.13, -121.3, 18)),
    R("sierra-foothills", "Sierra Foothills", strip([(39.0, -121.0), (38.4, -120.75), (37.8, -120.4)], 25)),
    R("central-valley", "Central Valley", blob(36.9, -120.0, (60, 170), -35)),
    R("central-coast", "Central Coast", strip([(37.0, -121.85), (36.3, -121.2), (35.6, -120.7), (34.65, -120.2)], 35)),
], cities=[("Seattle", 47.61, -122.33), ("Portland", 45.52, -122.68), ("San Francisco", 37.77, -122.42),
           ("Los Angeles", 34.05, -118.24), ("Sacramento", 38.58, -121.49)],
  labels=[("Pacific Ocean", 40.5, -124.6, "sea"), ("Columbia", 45.75, -121.0, "river"),
          ("WASHINGTON", 48.0, -120.0, "area"), ("OREGON", 43.8, -120.0, "area"), ("CALIFORNIA", 36.0, -117.3, "area")],
  river_rank=6)

M("napa-sonoma", "Napa & Sonoma", (38.1, -123.2, 38.85, -122.15), ["USA"], [
    R("sonoma-coast", "Sonoma Coast", strip([(38.75, -123.3), (38.5, -123.05), (38.3, -122.85)], 14)),
    R("russian-river", "Russian River Valley", blob(38.47, -122.86, (9, 12))),
    R("dry-creek", "Dry Creek Valley", strip([(38.75, -123.05), (38.63, -122.92)], 4)),
    R("alexander-valley", "Alexander Valley", strip([(38.8, -122.95), (38.7, -122.83), (38.62, -122.78)], 7)),
    R("sonoma-valley", "Sonoma Valley", strip([(38.43, -122.6), (38.35, -122.52), (38.28, -122.47)], 5)),
    R("carneros", "Los Carneros", poly([(38.29, -122.48), (38.27, -122.3), (38.22, -122.3), (38.22, -122.48)])),
    R("napa-valley", "Napa Valley", strip([(38.3, -122.29), (38.4, -122.36), (38.44, -122.4), (38.505, -122.47), (38.58, -122.58)], 6)),
    R("mount-veeder", "Mount Veeder", blob(38.37, -122.42, 3.5), small=True),
    R("stags-leap", "Stags Leap", blob(38.405, -122.32, 2.2), small=True),
    R("oakville", "Oakville", blob(38.435, -122.4, 2.4), small=True),
    R("rutherford", "Rutherford", blob(38.46, -122.42, 2.4), small=True),
    R("howell-mountain", "Howell Mountain", blob(38.56, -122.43, 4), small=True),
], cities=[("Napa", 38.3, -122.29), ("Sonoma", 38.29, -122.46), ("Healdsburg", 38.61, -122.87), ("Santa Rosa", 38.44, -122.71),
           ("Calistoga", 38.58, -122.58), ("St. Helena", 38.505, -122.47)],
  labels=[("Pacific Ocean", 38.25, -123.1, "sea"), ("San Pablo Bay", 38.08, -122.4, "sea")])

# ---------------------------------------------------------------- South America
M("south-america", "Chile & Argentina", (-41.0, -76.0, -22.0, -62.0), ["CHL", "ARG"], [
    R("elqui-limari", "Elqui & Limarí", blob(-30.4, -71.2, (18, 40))),
    R("aconcagua", "Aconcagua", blob(-32.8, -70.8, 18)),
    R("casablanca", "Casablanca", blob(-33.32, -71.4, 12)),
    R("maipo", "Maipo", blob(-33.65, -70.65, 20)),
    R("colchagua", "Colchagua", blob(-34.6, -71.25, 25)),
    R("maule", "Maule", blob(-35.6, -71.6, 35)),
    R("itata-bio-bio", "Itata & Bío Bío", blob(-36.9, -72.4, (25, 50))),
    R("salta", "Salta (Cafayate)", blob(-26.07, -65.98, 28)),
    R("san-juan", "San Juan", blob(-31.6, -68.6, 30)),
    R("mendoza", "Mendoza", blob(-33.05, -68.85, 32)),
    R("uco-valley", "Uco Valley", strip([(-33.3, -69.2), (-33.7, -69.22), (-34.0, -69.25)], 25)),
    R("patagonia", "Patagonia", blob(-38.95, -67.9, (55, 30))),
], cities=[("Santiago", -33.45, -70.67), ("Mendoza", -32.89, -68.84), ("Valparaíso", -33.05, -71.62)],
  labels=[("Pacific Ocean", -30.5, -74.5, "sea"), ("ANDES", -28.5, -69.0, "area"), ("CHILE", -24.5, -70.0, "area"),
          ("ARGENTINA", -30.0, -64.5, "area")])

# ---------------------------------------------------------------- Oceania & Africa
M("australia", "Australia", (-44.0, 112.0, -25.0, 154.5), ["AUS"], [
    R("margaret-river", "Margaret River", blob(-33.9, 115.1, (12, 40))),
    R("great-southern", "Great Southern", blob(-34.7, 117.5, 40)),
    R("swan-valley", "Swan Valley", blob(-31.8, 116.0, 15)),
    R("clare", "Clare Valley", blob(-33.85, 138.6, 16)),
    R("barossa", "Barossa", blob(-34.55, 138.98, 18)),
    R("mclaren-vale", "McLaren Vale", blob(-35.22, 138.55, 12)),
    R("coonawarra", "Coonawarra", blob(-37.3, 140.83, (6, 14))),
    R("riverland", "Riverland", blob(-34.2, 140.6, 40)),
    R("yarra-valley", "Yarra Valley", blob(-37.7, 145.5, 18)),
    R("rutherglen", "Rutherglen", blob(-36.05, 146.47, 14)),
    R("riverina", "Riverina", blob(-34.5, 146.0, 45)),
    R("hunter-valley", "Hunter Valley", blob(-32.75, 151.3, 22)),
    R("tasmania", "Tasmania", blob(-41.9, 147.0, 60)),
], cities=[("Perth", -31.95, 115.86), ("Adelaide", -34.93, 138.6), ("Melbourne", -37.81, 144.96), ("Sydney", -33.87, 151.21),
           ("Hobart", -42.88, 147.33)],
  labels=[("Indian Ocean", -38.0, 113.5, "sea"), ("Southern Ocean", -41.0, 133.0, "sea"), ("Tasman Sea", -38.5, 153.0, "sea")],
  river_rank=6)

M("south-australia", "South Australia", (-37.9, 137.7, -33.3, 141.3), ["AUS"], [
    R("clare", "Clare Valley", blob(-33.85, 138.6, 13)),
    R("barossa", "Barossa Valley", blob(-34.53, 138.95, (8, 14))),
    R("eden-valley", "Eden Valley", blob(-34.62, 139.12, (6, 10))),
    R("adelaide-hills", "Adelaide Hills", blob(-35.0, 138.8, (10, 18))),
    R("mclaren-vale", "McLaren Vale", blob(-35.22, 138.55, 10)),
    R("langhorne-creek", "Langhorne Creek", blob(-35.3, 139.05, 8)),
    R("riverland", "Riverland", blob(-34.2, 140.6, (40, 20))),
    R("padthaway", "Padthaway", blob(-36.6, 140.5, 9)),
    R("coonawarra", "Coonawarra", blob(-37.3, 140.83, (5, 12))),
], cities=[("Adelaide", -34.93, 138.6), ("Nuriootpa", -34.47, 139.0), ("Mount Gambier", -37.83, 140.78)],
  labels=[("Gulf St Vincent", -35.0, 138.15, "sea"), ("Murray", -34.6, 139.7, "river"), ("Southern Ocean", -36.8, 138.4, "sea")])

M("new-zealand", "New Zealand", (-47.4, 166.0, -34.3, 179.0), ["NZL"], [
    R("auckland", "Auckland & Waiheke", blob(-36.8, 175.0, 14)),
    R("gisborne", "Gisborne", blob(-38.65, 177.9, 16)),
    R("hawkes-bay", "Hawke's Bay", blob(-39.6, 176.75, 26)),
    R("martinborough", "Martinborough", blob(-41.2, 175.45, 14)),
    R("nelson", "Nelson", blob(-41.3, 173.1, 14)),
    R("marlborough", "Marlborough", strip([(-41.6, 173.4), (-41.5, 173.95)], 14), blob(-41.68, 174.05, 8)),
    R("waipara", "North Canterbury", blob(-43.05, 172.75, 15)),
    R("central-otago", "Central Otago", blob(-45.0, 169.2, 30)),
], cities=[("Auckland", -36.85, 174.76), ("Wellington", -41.29, 174.78), ("Christchurch", -43.53, 172.64),
           ("Queenstown", -45.03, 168.66), ("Blenheim", -41.51, 173.96), ("Napier", -39.49, 176.91)],
  labels=[("Tasman Sea", -39.5, 169.0, "sea"), ("Pacific Ocean", -44.0, 176.0, "sea")])

M("south-africa", "Western Cape", (-34.75, 17.8, -32.6, 21.0), ["ZAF"], [
    R("swartland", "Swartland", blob(-33.35, 18.75, 24)),
    R("tulbagh", "Tulbagh", blob(-33.28, 19.13, 6)),
    R("durbanville", "Durbanville", blob(-33.83, 18.65, 6)),
    R("constantia", "Constantia", blob(-34.03, 18.42, 5)),
    R("paarl", "Paarl", blob(-33.73, 18.97, 9)),
    R("stellenbosch", "Stellenbosch", blob(-33.94, 18.86, 11)),
    R("franschhoek", "Franschhoek", blob(-33.91, 19.12, 5)),
    R("elgin", "Elgin", blob(-34.15, 19.04, 7)),
    R("walker-bay", "Walker Bay", blob(-34.38, 19.27, 8)),
    R("breedekloof", "Breedekloof", blob(-33.6, 19.4, 12)),
    R("robertson", "Robertson", blob(-33.8, 19.88, 14)),
    R("elim", "Cape Agulhas", blob(-34.6, 19.75, 6)),
], cities=[("Cape Town", -33.92, 18.42), ("Stellenbosch", -33.94, 18.86), ("Hermanus", -34.42, 19.23)],
  labels=[("Atlantic Ocean", -33.3, 18.05, "sea"), ("Indian Ocean", -34.6, 20.6, "sea"), ("False Bay", -34.2, 18.65, "sea")])
