# Southern-hemisphere wine maps with three levels (built by build_maps2.py `south`):
#   Chile        Decree 464 (1994, as amended): wine regions > sub-regions (valleys) > zones and areas, every one a list of comunas
#                (geoBoundaries CHL ADM3 = comunas, so these are the legal boundaries).
#   Argentina    provinces > IGs / departments > districts (IGs of Luján de Cuyo, Maipú and the Uco Valley are districts),
#                departments from geoBoundaries ARG ADM2, districts from OpenStreetMap (southern-data branch, osm_admin_ar.json).
#   New Zealand  official GI boundaries from the IPONZ register (southern-data branch, nz_gi/<slug>.geojson).
#   South Africa Wine of Origin geographical units > districts > wards, snapped to municipal wards (ZAF ADM4).
#
# Area tuple: A(id, name, level, parent, units)  -- units = names of admin units at the country's base level,
#             or ("ADM2", [names]) for another level, or {"osm": [district names], "in": [departments]} (Argentina),
#             or {"gi": slug} (New Zealand), or {"c": (lat, lon), "r": km} (a blob snapped to the base units).
# A level-0 area with no units is the union of everything inside it.

def A(id, name, lv, parent=None, units=None, **kw):
    d = {"id": id, "name": name, "lv": lv, "parent": parent, "units": units}
    d.update(kw)
    return d

# ================================================================= CHILE
CHILE = {
    "map": "chile", "iso": "CHL", "adm": "ADM3", "title": "Chile", "cc": "cl",
    "bbox": (-43.6, -74.6, -26.6, -69.6),
    "cities": [("Santiago", -33.45, -70.67), ("Valparaíso", -33.05, -71.62), ("Talca", -35.43, -71.66), ("Concepción", -36.83, -73.05),
               ("La Serena", -29.90, -71.25), ("Rancagua", -34.17, -70.74), ("Santa Cruz", -34.64, -71.37), ("Curicó", -34.98, -71.24),
               ("Chillán", -36.61, -72.10), ("Temuco", -38.74, -72.60), ("Osorno", -40.57, -73.14), ("Ovalle", -30.60, -71.20),
               ("Casablanca", -33.32, -71.41), ("San Antonio", -33.59, -71.61), ("Los Andes", -32.83, -70.60), ("Cauquenes", -35.97, -72.32),
               ("Copiapó", -27.37, -70.33), ("Vallenar", -28.58, -70.76), ("Castro", -42.48, -73.76), ("Linares", -35.85, -71.60)],
    "labels": [("Pacific Ocean", -33.5, -74.0, "sea"), ("ANDES", -31.0, -69.9, "area"), ("ANDES", -36.5, -70.6, "area")],
    "colors": {"cl-atacama": "ochre", "cl-coquimbo": "gold", "cl-aconcagua": "teal", "cl-central-valley": "claret", "cl-south": "violet", "cl-austral": "blue"},
    "areas": [
        # Decree 464 (1994), consolidated text (bcn.cl / WIPO Lex CL019): every valley, zone and area as the comunas or
        # provinces the law names. The Austral region (Cautín, Osorno, Chiloé) comes from later amendments (2011–2024).
        # ---- level 0: the wine regions (union of their valleys)
        A("cl-atacama", "Atacama", 0), A("cl-coquimbo", "Coquimbo", 0), A("cl-aconcagua", "Aconcagua", 0),
        A("cl-central-valley", "Central Valley", 0), A("cl-south", "South", 0), A("cl-austral", "Austral", 0),
        # ---- level 1: sub-regions (valleys)
        A("copiapo", "Copiapó Valley", 1, "cl-atacama", ("ADM2", ["Provincia de Copiapó"])),
        A("huasco", "Huasco Valley", 1, "cl-atacama", ("ADM2", ["Provincia de Huasco"])),
        A("elqui", "Elqui Valley", 1, "cl-coquimbo", ("ADM2", ["Provincia de Elqui"])),
        A("limari", "Limarí Valley", 1, "cl-coquimbo", ("ADM2", ["Provincia de Limarí"])),
        A("choapa", "Choapa Valley", 1, "cl-coquimbo", ("ADM2", ["Provincia de Choapa"])),
        A("aconcagua", "Aconcagua Valley", 1, "cl-aconcagua", ("ADM2", ["Provincia de San Felipe de Aconcagua", "Provincia de Los Andes"])),
        A("casablanca", "Casablanca Valley", 1, "cl-aconcagua", ["Casablanca"]),
        A("marga-marga", "Marga-Marga Valley", 1, "cl-aconcagua", ["Quilpué"]),
        A("san-antonio", "San Antonio Valley", 1, "cl-aconcagua", ("ADM2", ["Provincia de San Antonio"])),
        A("maipo", "Maipo Valley", 1, "cl-central-valley", ("ADM1", ["Región Metropolitana de Santiago"])),
        A("rapel", "Rapel Valley", 1, "cl-central-valley", ("ADM2", ["Provincia de Cachapoal", "Provincia de Colchagua", "Provincia de Cardenal Caro"])),
        A("curico", "Curicó Valley", 1, "cl-central-valley", ["Curicó", "Teno", "Romeral", "Rauco", "Hualañé", "Licantén", "Vichuquén",
            "Molina", "Sagrada Familia", "Río Claro"]),
        A("maule", "Maule Valley", 1, "cl-central-valley", ["Talca", "Constitución", "Curepto", "Empedrado", "Maule", "Pelarco", "Pencahue",
            "San Clemente", "San Rafael", "Linares", "Colbún", "Longaví", "Parral", "Retiro", "San Javier", "Villa Alegre", "Yerbas Buenas",
            "Cauquenes"]),
        A("itata", "Itata Valley", 1, "cl-south", ["Chillán", "Coelemu", "Ranquil", "Quillón", "Portezuelo", "Ninhue", "Treguaco",
            "Quirihue", "San Nicolás", "Bulnes", "San Carlos", "Florida"]),
        A("bio-bio", "Bío-Bío Valley", 1, "cl-south", ["Yumbel", "Nacimiento", "Mulchén", "Negrete", "Laja"]),
        A("malleco", "Malleco Valley", 1, "cl-south", ["Angol", "Collipulli", "Ercilla", "Los Sauces", "Lumaco", "Purén", "Renaico",
            "Traiguén", "Victoria"]),
        A("cautin", "Cautín Valley", 1, "cl-austral", ["Temuco", "Galvarino", "Lautaro", "Perquenco", "Vilcún", "Freire", "Pitrufquén",
            "Padre Las Casas", "Nueva Imperial", "Gorbea", "Cholchol"]),
        A("osorno", "Osorno Valley", 1, "cl-austral", ["Osorno", "San Pablo", "Puyehue", "Río Negro", "Purranque", "Puerto Octay"]),
        A("chiloe", "Chiloé", 1, "cl-austral", ["Ancud", "Castro", "Chonchi", "Dalcahue", "Quinchao", "Curaco de Vélez", "Puqueldón",
            "Quemchi", "Queilén", "Quellón"]),
        # ---- level 2: zones
        A("leyda", "Leyda Valley", 2, "san-antonio", ["San Antonio", "Santo Domingo"]),
        A("cachapoal", "Cachapoal Valley", 2, "rapel", ("ADM2", ["Provincia de Cachapoal"])),
        A("colchagua", "Colchagua Valley", 2, "rapel", ("ADM2", ["Provincia de Colchagua", "Provincia de Cardenal Caro"])),
        A("teno", "Teno Valley", 2, "curico", ["Teno", "Romeral", "Rauco", "Hualañé"]),
        A("lontue", "Lontué Valley", 2, "curico", ["Curicó", "Molina", "Sagrada Familia", "Río Claro"]),
        A("claro", "Claro Valley", 2, "maule", ["Talca", "San Clemente", "Pencahue", "Maule", "Pelarco", "San Rafael"]),
        A("loncomilla", "Loncomilla Valley", 2, "maule", ["San Javier", "Villa Alegre", "Retiro", "Parral", "Linares", "Yerbas Buenas"]),
        A("tutuven", "Tutuvén Valley", 2, "maule", ["Cauquenes"]),
        # ---- level 2: the decree's areas in valleys without zones (each a named group of comunas)
        *[A(i, n, 2, p, c) for i, n, p, c in [
            ("cl-vicuna", "Vicuña", "elqui", ["Vicuña"]), ("cl-paihuano", "Paiguano", "elqui", ["Paihuano"]),
            ("cl-ovalle", "Ovalle", "limari", ["Ovalle"]), ("cl-monte-patria", "Monte Patria", "limari", ["Monte Patria"]),
            ("cl-punitaqui", "Punitaqui", "limari", ["Punitaqui"]), ("cl-rio-hurtado", "Río Hurtado", "limari", ["Río Hurtado"]),
            ("cl-salamanca", "Salamanca", "choapa", ["Salamanca"]), ("cl-illapel", "Illapel", "choapa", ["Illapel"]),
            ("cl-panquehue", "Panquehue", "aconcagua", ["Panquehue"]),
            ("cl-santiago", "Santiago", "maipo", ["Peñalolén", "La Florida"]), ("cl-pirque", "Pirque", "maipo", ["Pirque"]),
            ("cl-puente-alto", "Puente Alto", "maipo", ["Puente Alto"]), ("cl-buin", "Buin", "maipo", ["Buin", "Paine", "San Bernardo"]),
            ("cl-isla-de-maipo", "Isla de Maipo", "maipo", ["Isla de Maipo"]),
            ("cl-talagante", "Talagante", "maipo", ["Talagante", "Peñaflor", "El Monte", "Padre Hurtado"]),
            ("cl-melipilla", "Melipilla", "maipo", ["Melipilla"]), ("cl-alhue", "Alhué", "maipo", ["Alhué"]),
            ("cl-maria-pinto", "María Pinto", "maipo", ["María Pinto"]),
            ("cl-chillan", "Chillán", "itata", ["Chillán", "Bulnes", "San Carlos"]), ("cl-quillon", "Quillón", "itata", ["Quillón", "Ranquil", "Florida"]),
            ("cl-portezuelo", "Portezuelo", "itata", ["Portezuelo", "Ninhue", "Quirihue", "San Nicolás"]),
            ("cl-coelemu", "Coelemu", "itata", ["Coelemu", "Treguaco"]),
            ("cl-yumbel", "Yumbel", "bio-bio", ["Yumbel", "Laja"]), ("cl-mulchen", "Mulchén", "bio-bio", ["Mulchén", "Nacimiento", "Negrete"]),
            ("cl-traiguen", "Traiguén", "malleco", ["Traiguén"]),
        ]],
    ],
}

# ================================================================= SOUTH AFRICA (Wine of Origin)
# Districts: municipal wards (ADM4) whose centre lies within r km of the district's centre (B), or whole local municipalities.
# Wards: a circle around the ward clipped to its district and to the real vineyards around it (`vin` km), so the shape
# follows the vines. The Wine of Origin boundaries are gazetted as text only (no open GIS data); these are close approximations.
def B(lat, lon, km, **kw):
    d = {"c": (lat, lon), "r": km}; d.update(kw); return d
def W(lat, lon, km, vin=1.5):
    return {"c": (lat, lon), "r": km, "free": True, "vin": vin}
SOUTH_AFRICA = {
    "map": "south-africa", "iso": "ZAF", "adm": "ADM4", "title": "Western Cape", "cc": "za",
    "bbox": (-34.85, 17.75, -31.35, 23.6),
    "cities": [("Cape Town", -33.92, 18.42), ("Stellenbosch", -33.94, 18.86), ("Hermanus", -34.42, 19.23), ("Paarl", -33.73, 18.97),
               ("Worcester", -33.65, 19.45), ("Robertson", -33.80, 19.89), ("Franschhoek", -33.91, 19.12), ("Malmesbury", -33.46, 18.73),
               ("Tulbagh", -33.29, 19.14), ("Wellington", -33.64, 19.01), ("Swellendam", -34.02, 20.44), ("Oudtshoorn", -33.59, 22.20),
               ("Vredendal", -31.67, 18.50), ("Citrusdal", -32.59, 19.01), ("Plettenberg Bay", -34.05, 23.37), ("Elgin", -34.15, 19.04),
               ("Calitzdorp", -33.53, 21.69), ("Darling", -33.38, 18.38), ("Montagu", -33.79, 20.12)],
    "labels": [("Atlantic Ocean", -33.0, 17.95, "sea"), ("Indian Ocean", -34.6, 21.6, "sea"), ("False Bay", -34.2, 18.65, "sea")],
    "colors": {"za-coastal": "claret", "za-breede": "orange", "za-cape-south-coast": "teal", "za-olifants": "violet", "za-klein-karoo": "gold"},
    "areas": [
        A("za-coastal", "Coastal Region", 0), A("za-breede", "Breede River Valley", 0), A("za-cape-south-coast", "Cape South Coast", 0),
        A("za-olifants", "Olifants River", 0), A("za-klein-karoo", "Klein Karoo", 0),
        # ---- districts
        A("cape-town", "Cape Town", 1, "za-coastal", ("ADM3", ["City of Cape Town"]), minus=["stellenbosch"]),
        A("darling", "Darling", 1, "za-coastal", B(-33.40, 18.40, 16)),
        A("swartland", "Swartland", 1, "za-coastal", ("ADM3", ["Swartland"]), minus=["darling"]),
        A("tulbagh", "Tulbagh", 1, "za-coastal", B(-33.27, 19.13, 14)),
        A("wellington", "Wellington", 1, "za-coastal", B(-33.62, 19.02, 11)),
        A("paarl", "Paarl", 1, "za-coastal", B(-33.71, 18.91, 12), minus=["wellington"]),
        A("franschhoek", "Franschhoek", 1, "za-coastal", B(-33.90, 19.10, 9)),
        A("stellenbosch", "Stellenbosch", 1, "za-coastal", B(-33.97, 18.81, 16), minus=["franschhoek", "paarl"]),
        A("breedekloof", "Breedekloof", 1, "za-breede", B(-33.57, 19.28, 15)),
        A("worcester", "Worcester", 1, "za-breede", B(-33.62, 19.55, 20), minus=["breedekloof"]),
        A("robertson", "Robertson", 1, "za-breede", ("ADM3", ["Langeberg"]), minus=["montagu"]),
        A("elgin", "Elgin", 1, "za-cape-south-coast", B(-34.17, 19.05, 10)),
        A("walker-bay", "Walker Bay", 1, "za-cape-south-coast", ("ADM3", ["Overstrand"])),
        A("elim", "Cape Agulhas", 1, "za-cape-south-coast", ("ADM3", ["Cape Agulhas"])),
        A("overberg", "Overberg", 1, "za-cape-south-coast", ("ADM3", ["Theewaterskloof"]), minus=["elgin"]),
        A("swellendam", "Swellendam", 1, "za-cape-south-coast", ("ADM3", ["Swellendam"])),
        A("plettenberg-bay", "Plettenberg Bay", 1, "za-cape-south-coast", ("ADM3", ["Bitou"])),
        A("citrusdal-mountain", "Citrusdal Mountain", 1, "za-olifants", B(-32.55, 18.95, 22)),
        A("citrusdal-valley", "Citrusdal Valley", 1, "za-olifants", B(-32.15, 18.75, 28), minus=["citrusdal-mountain"]),
        A("lutzville-valley", "Lutzville Valley", 1, "za-olifants", B(-31.55, 18.35, 22)),
        A("montagu", "Montagu", 1, "za-klein-karoo", B(-33.78, 20.12, 10)),
        A("calitzdorp", "Calitzdorp", 1, "za-klein-karoo", B(-33.53, 21.69, 14)),
        A("langeberg-garcia", "Langeberg-Garcia", 1, "za-klein-karoo", B(-33.97, 21.30, 16)),
        A("oudtshoorn", "Oudtshoorn & Outeniqua", 1, "za-klein-karoo", ("ADM3", ["Oudtshoorn"])),
        # ---- wards
        A("constantia", "Constantia", 2, "cape-town", B(-34.025, 18.43, 4)),
        A("durbanville", "Durbanville", 2, "cape-town", B(-33.82, 18.64, 7)),
    ],
}

# ================================================================= ARGENTINA
# Level 1 = IG regions made of whole departments (geoBoundaries ARG ADM2, chosen inside their province);
# level 2 = IG districts and parajes: OpenStreetMap district boundaries when the name is found there, else a circle around
# the district, shared with its neighbours and trimmed to the real vineyards.
def D(prov, *deps):
    return {"dep": list(deps), "prov": prov}
def X(lat, lon, km, osm=None, vin=1.2):
    return {"c": (lat, lon), "r": km, "free": True, "vin": vin, "osm": osm}
ARGENTINA = {
    "map": "argentina", "iso": "ARG", "adm": "ADM2", "title": "Argentina", "cc": "ar",
    "bbox": (-39.6, -70.6, -22.6, -64.6),
    "cities": [("Mendoza", -32.89, -68.84), ("San Juan", -31.54, -68.53), ("Salta", -24.79, -65.41), ("Neuquén", -38.95, -68.06),
               ("San Rafael", -34.62, -68.33), ("Cafayate", -26.07, -65.98), ("Tupungato", -33.37, -69.15), ("Tunuyán", -33.58, -69.02),
               ("San Carlos", -33.77, -69.04), ("Chilecito", -29.16, -67.50), ("Luján de Cuyo", -33.04, -68.88), ("Maipú", -32.98, -68.78),
               ("General Roca", -39.03, -67.58), ("Cachi", -25.12, -66.16), ("Fiambalá", -27.69, -67.62), ("Santa María", -26.70, -66.05),
               ("San Martín", -33.08, -68.47), ("General Alvear", -34.98, -67.69), ("Tilcara", -23.58, -65.40), ("Jáchal", -30.24, -68.75)],
    "labels": [("ANDES", -29.0, -69.9, "area"), ("ANDES", -35.5, -70.2, "area")],
    "colors": {"mendoza": "claret", "san-juan": "orange", "ar-la-rioja": "gold", "ar-catamarca": "olive", "salta": "teal",
               "ar-tucuman": "green", "ar-jujuy": "blue", "patagonia": "violet"},
    "areas": [
        A("ar-jujuy", "Jujuy", 0), A("salta", "Salta", 0), A("ar-tucuman", "Tucumán", 0), A("ar-catamarca", "Catamarca", 0),
        A("ar-la-rioja", "La Rioja", 0), A("san-juan", "San Juan", 0), A("mendoza", "Mendoza", 0), A("patagonia", "Patagonia", 0),
        # ---- level 1: IG regions / departments
        A("quebrada-humahuaca", "Quebrada de Humahuaca", 1, "ar-jujuy", D("Jujuy", "Tumbaya", "Tilcara", "Humahuaca")),
        A("cafayate", "Cafayate", 1, "salta", D("Salta", "Cafayate")),
        A("calchaqui-salta", "Calchaquí Valleys (Salta)", 1, "salta", D("Salta", "San Carlos", "Molinos", "Cachi", "La Poma")),
        A("tafi", "Tafí & Amaicha", 1, "ar-tucuman", D("Tucumán", "Tafí del Valle")),
        A("calchaqui-catamarca", "Santa María", 1, "ar-catamarca", D("Catamarca", "Santa María")),
        A("belen", "Belén", 1, "ar-catamarca", D("Catamarca", "Belén")),
        A("tinogasta", "Tinogasta & Fiambalá", 1, "ar-catamarca", D("Catamarca", "Tinogasta")),
        A("famatina", "Famatina Valley", 1, "ar-la-rioja", D("La Roja", "Chilecito", "Famatina")),
        A("felipe-varela", "Felipe Varela", 1, "ar-la-rioja", D("La Roja", "Coronel Felipe Varela")),
        A("castro-barros", "Castro Barros & Arauco", 1, "ar-la-rioja", D("La Roja", "Castro Barros", "Arauco", "San Blas de los Sauces")),
        A("jachal", "Jáchal", 1, "san-juan", D("San Juan", "Jáchal")),
        A("iglesia", "Iglesia", 1, "san-juan", D("San Juan", "Iglesia")),
        A("calingasta", "Calingasta Valley", 1, "san-juan", D("San Juan", "Calingasta")),
        A("ullum-zonda", "Ullum & Zonda Valleys", 1, "san-juan", D("San Juan", "Ullum", "Zonda")),
        A("tulum", "Tulum Valley", 1, "san-juan", D("San Juan", "Pocito", "Rawson", "Sarmiento", "25 de Mayo", "Caucete", "San Martín",
            "Angaco", "Albardón", "Chimbas", "Rivadavia", "Santa Lucía", "9 de julio", "Capital")),
        A("mendoza-north", "Northern Mendoza", 1, "mendoza", D("Mendoza", "Lavalle", "Las Heras", "Guaymallén", "Capital", "Godoy Cruz")),
        A("lujan-de-cuyo", "Luján de Cuyo", 1, "mendoza", D("Mendoza", "Luján de Cuyo")),
        A("maipu", "Maipú", 1, "mendoza", D("Mendoza", "Maipú")),
        A("mendoza-east", "Eastern Mendoza", 1, "mendoza", D("Mendoza", "San Martín", "Junín", "Rivadavia", "Santa Rosa", "La Paz")),
        A("uco-valley", "Uco Valley", 1, "mendoza", D("Mendoza", "Tupungato", "Tunuyán", "San Carlos")),
        A("san-rafael", "San Rafael", 1, "mendoza", D("Mendoza", "San Rafael")),
        A("general-alvear", "General Alvear", 1, "mendoza", D("Mendoza", "General Alvear")),
        A("neuquen", "Neuquén", 1, "patagonia", D("Neuquén", "Anelo", "Confluencia")),
        A("alto-valle", "Alto Valle del Río Negro", 1, "patagonia", D("Río Negro", "General Roca")),
        A("valle-medio", "Valle Medio", 1, "patagonia", D("Río Negro", "Avellaneda")),
        # ---- level 2: IG districts and parajes
    ],
}

# ================================================================= GERMANY
# Level 0: the 13 Anbaugebiete (official PDO boundaries). Level 1: the Bereiche, each the share of its Anbaugebiet around
# the Bereich's centre (together they cover it). Level 2: famous wine villages (a circle clipped to their Bereich).
def P(name): return {"pdo": name, "cc": "DE"}
def Q(lat, lon): return {"cell": (lat, lon)}
def V(lat, lon, km=2.2): return {"c": (lat, lon), "r": km, "free": True}
GERMANY = {
    "map": "germany", "iso": "DEU", "adm": "ADM3", "title": "Germany", "W": 3000,
    "bbox": (47.3, 5.8, 51.6, 13.9),
    "cities": [("Frankfurt", 50.11, 8.68), ("Koblenz", 50.36, 7.59), ("Trier", 49.75, 6.64), ("Mainz", 50.0, 8.27), ("Stuttgart", 48.78, 9.18),
               ("Würzburg", 49.79, 9.95), ("Munich", 48.14, 11.58), ("Freiburg", 47.99, 7.85), ("Dresden", 51.05, 13.74), ("Heidelberg", 49.40, 8.69),
               ("Bernkastel-Kues", 49.92, 7.07), ("Rüdesheim", 49.98, 7.92), ("Bad Kreuznach", 49.84, 7.87), ("Neustadt", 49.35, 8.14),
               ("Heilbronn", 49.14, 9.22), ("Naumburg", 51.15, 11.81), ("Meissen", 51.16, 13.47), ("Bingen", 49.97, 7.90), ("Cochem", 50.15, 7.17)],
    "labels": [("Rhine", 49.0, 8.25, "river"), ("Mosel", 49.85, 6.75, "river"), ("Main", 49.95, 9.3, "river")],
    "lod": [1.6, 3.2],
    "areas": [
        A("ahr", "Ahr", 0, None, P("Ahr")), A("mittelrhein", "Mittelrhein", 0, None, P("Mittelrhein")), A("mosel", "Mosel", 0, None, P("Mosel")),
        A("nahe", "Nahe", 0, None, P("Nahe")), A("rheingau", "Rheingau", 0, None, P("Rheingau")), A("rheinhessen", "Rheinhessen", 0, None, P("Rheinhessen")),
        A("pfalz", "Pfalz", 0, None, P("Pfalz")), A("hessische-bergstrasse", "Hessische Bergstraße", 0, None, P("Hessische Bergstraße")),
        A("franken", "Franken", 0, None, P("Franken")), A("wurttemberg", "Württemberg", 0, None, P("Württemberg")), A("baden", "Baden", 0, None, P("Baden")),
        A("saale-unstrut", "Saale-Unstrut", 0, None, P("Saale-Unstrut")), A("sachsen", "Sachsen", 0, None, P("Sachsen")),
        # ---- Bereiche
        # ---- famous villages
    ],
}

# ================================================================= AUSTRIA
AUSTRIA = {
    "map": "austria", "iso": "AUT", "adm": "ADM3", "title": "Austria", "W": 3000,
    "bbox": None,   # filled from the legacy spec
    "areas": [
        A("at-niederosterreich", "Niederösterreich", 0, None, P("Niederösterreich") | {"cc": "AT"}), A("at-wien", "Wien", 0, None, {"pdo": "Wien", "cc": "AT"}),
        A("at-burgenland", "Burgenland", 0, None, {"pdo": "Burgenland", "cc": "AT"}), A("steiermark", "Steiermark", 0, None, {"pdo": "Steiermark", "cc": "AT"}),
        *[A(i, n, 1, p, {"pdo": q, "cc": "AT"}) for i, n, p, q in [
            ("wachau", "Wachau", "at-niederosterreich", "Wachau"), ("kremstal", "Kremstal", "at-niederosterreich", "Kremstal"),
            ("kamptal", "Kamptal", "at-niederosterreich", "Kamptal"), ("traisental", "Traisental", "at-niederosterreich", "Traisental"),
            ("wagram", "Wagram", "at-niederosterreich", "Wagram"), ("weinviertel", "Weinviertel", "at-niederosterreich", "Weinviertel"),
            ("carnuntum", "Carnuntum", "at-niederosterreich", "Carnuntum"), ("thermenregion", "Thermenregion", "at-niederosterreich", "Thermenregion"),
            ("neusiedlersee", "Neusiedlersee", "at-burgenland", "Neusiedlersee"), ("leithaberg", "Leithaberg", "at-burgenland", "Leithaberg"),
            ("mittelburgenland", "Mittelburgenland", "at-burgenland", "Mittelburgenland"), ("eisenberg", "Eisenberg", "at-burgenland", "Eisenberg"),
            ("sudsteiermark", "Südsteiermark", "steiermark", "Südsteiermark"), ("vulkanland", "Vulkanland Steiermark", "steiermark", "Süd-Oststeiermark"),
            ("weststeiermark", "Weststeiermark", "steiermark", "Weststeiermark")]],
        # ---- famous wine villages
    ],
}

# ================================================================= SOUTH AUSTRALIA (official GIs: zones > regions > subregions)
def F(name): return {"file": "Australia/South_Australia/" + name + ".geojson"}
SOUTH_AUSTRALIA = {
    "map": "south-australia", "iso": "AUS", "adm": "ADM2", "bbox": None,
    "areas": [
        A("sa-barossa-zone", "Barossa (zone)", 0, None, F("Barossa")), A("sa-mount-lofty", "Mount Lofty Ranges", 0, None, F("Mount_Lofty_Ranges")),
        A("sa-fleurieu", "Fleurieu", 0, None, F("Fleurieu")), A("sa-limestone-coast", "Limestone Coast", 0, None, F("Limestone_Coast")),
        A("sa-lower-murray", "Lower Murray", 0, None, F("Lower_Muurray")), A("sa-far-north", "Far North", 0, None, F("Far_North")),
        A("sa-peninsulas", "The Peninsulas", 0, None, F("The_Peninsulas")),
        A("barossa", "Barossa Valley", 1, "sa-barossa-zone", F("Barossa_Valley")), A("eden-valley", "Eden Valley", 1, "sa-barossa-zone", F("Eden_Valley")),
        A("clare", "Clare Valley", 1, "sa-mount-lofty", F("Clare_Valley")), A("adelaide-hills", "Adelaide Hills", 1, "sa-mount-lofty", F("Adelaide_Hills")),
        A("adelaide-plains", "Adelaide Plains", 1, "sa-mount-lofty", F("Adelaide_Plains")),
        A("mclaren-vale", "McLaren Vale", 1, "sa-fleurieu", F("McLaren_Vale")), A("langhorne-creek", "Langhorne Creek", 1, "sa-fleurieu", F("Langhorne_Creek")),
        A("currency-creek", "Currency Creek", 1, "sa-fleurieu", F("Currency_Creek")), A("southern-fleurieu", "Southern Fleurieu", 1, "sa-fleurieu", F("Southern_Fleurieu")),
        A("kangaroo-island", "Kangaroo Island", 1, "sa-fleurieu", F("Kangaroo_Island")),
        A("coonawarra", "Coonawarra", 1, "sa-limestone-coast", F("Coonawarra")), A("padthaway", "Padthaway", 1, "sa-limestone-coast", F("Padthaway")),
        A("wrattonbully", "Wrattonbully", 1, "sa-limestone-coast", F("Wrattonbully")), A("mount-benson", "Mount Benson", 1, "sa-limestone-coast", F("Mount_Benson")),
        A("robe", "Robe", 1, "sa-limestone-coast", F("Robe")), A("mount-gambier", "Mount Gambier", 1, "sa-limestone-coast", F("Mount_Gambier")),
        A("riverland", "Riverland", 1, "sa-lower-murray", F("Riverland")), A("southern-flinders", "Southern Flinders Ranges", 1, "sa-far-north", F("Southern_Flinders_Ranges")),
        A("high-eden", "High Eden", 2, "eden-valley", F("High_Eden")), A("lenswood", "Lenswood", 2, "adelaide-hills", F("Lenswood")),
        A("piccadilly-valley", "Piccadilly Valley", 2, "adelaide-hills", F("Piccadilly_Valley")),
    ],
}

# ================================================================= NEW ZEALAND (official GIs from the IPONZ register)
# {"gi": slug} = the registered boundary (southern-data/nz_gi/<slug>.geojson); "fb" = admin districts used until it is there.
def G(slug, *fb, adm="ADM2", within=None):
    return {"gi": slug, "fb": (adm, list(fb)), "within": within}
def S2(lat, lon, km, vin=1.2):
    return {"c": (lat, lon), "r": km, "free": True, "vin": vin}
NEW_ZEALAND = {
    "map": "new-zealand", "iso": "NZL", "adm": "ADM2", "cc": "nz", "bbox": None, "max_pois": 300,
    "colors": {"marlborough": "claret", "central-otago": "violet", "hawkes-bay": "orange"},
    "areas": [
        # ---- level 0: the regional GIs
        A("northland", "Northland", 0, None, G("northland", "Far North District", "Whangarei District", "Kaipara District")),
        A("auckland", "Auckland", 0, None, G("auckland", adm="ADM1", *[]) | {"fb": ("ADM1", ["Auckland Region"])}),
        A("gisborne", "Gisborne", 0, None, G("gisborne", "Gisborne District")),
        A("hawkes-bay", "Hawke's Bay", 0, None, G("hawkes-bay", "Hastings District", "Napier City", "Central Hawke's Bay District")),
        A("wairarapa", "Wairarapa", 0, None, G("wairarapa", "South Wairarapa District", "Carterton District", "Masterton District")),
        A("nelson", "Nelson", 0, None, G("nelson", "Nelson City", "Tasman District")),
        A("marlborough", "Marlborough", 0, None, G("marlborough", "Marlborough District")),
        A("canterbury", "Canterbury", 0, None, G("canterbury", "Hurunui District", "Waimakariri District", "Christchurch City", "Selwyn District")),
        A("waitaki", "Waitaki Valley North Otago", 0, None, G("waitaki-valley-north-otago", "Waitaki District")),
        A("central-otago", "Central Otago", 0, None, G("central-otago", "Central Otago District", "Queenstown-Lakes District")),
        # ---- level 1: GIs inside them, and the sub-regions
        A("matakana", "Matakana", 1, "auckland", G("matakana") | {"fb": None, "c": (-36.36, 174.72), "r": 9, "free": True}),
        A("kumeu", "Kumeu", 1, "auckland", G("kumeu") | {"fb": None, "c": (-36.77, 174.55), "r": 8, "free": True}),
        A("waiheke", "Waiheke Island", 1, "auckland", G("waiheke-island", "Waiheke Local Board Area")),
        A("central-hawkes-bay", "Central Hawke's Bay", 1, "hawkes-bay", G("central-hawkes-bay", "Central Hawke's Bay District")),
        A("martinborough", "Martinborough", 1, "wairarapa", G("martinborough") | {"fb": None, "c": (-41.22, 175.46), "r": 7, "free": True}),
        A("gladstone", "Gladstone", 1, "wairarapa", G("gladstone") | {"fb": None, "c": (-41.08, 175.65), "r": 8, "free": True}),
        A("waipara", "North Canterbury", 1, "canterbury", G("north-canterbury", "Hurunui District", "Waimakariri District")),
        A("bannockburn", "Bannockburn", 1, "central-otago", G("bannockburn") | {"fb": None, "c": (-45.08, 169.16), "r": 4, "free": True}),
        # ---- level 2
        A("waipara-valley", "Waipara Valley", 2, "waipara", G("waipara-valley") | {"fb": None, "c": (-43.06, 172.75), "r": 10, "free": True}),
    ],
}

# ================================================================= HUNGARY (official PDO boundaries, Candiago et al. 2022)
# 6 wine regions > 22 districts > the smaller PDOs inside districts and the classic wine villages.
def H(name): return {"pdo": name, "cc": "HU"}
HUNGARY = {
    "map": "hungary", "iso": "HUN", "adm": "ADM2", "bbox": None, "cc": "hu", "exclusive": True,
    "colors": {"hu-tokaj": "gold", "hu-upper-hungary": "claret", "balaton": "teal", "hu-pannon": "violet", "hu-duna": "orange",
               "hu-upper-pannon": "green"},
    "areas": [
        # ---- level 0: the wine regions (Balaton, Duna, Pannon have their own regional PDO)
        A("hu-tokaj", "Tokaj", 0), A("hu-upper-hungary", "Upper Hungary", 0), A("hu-upper-pannon", "Upper Pannon", 0),
        A("balaton", "Balaton", 0, None, H("Balaton")), A("hu-duna", "Duna", 0, None, H("Duna")), A("hu-pannon", "Pannon", 0, None, H("Pannon")),
        # ---- level 1: the 22 wine districts
        A("tokaj", "Tokaj", 1, "hu-tokaj", H("Tokaj")),
        A("eger", "Eger", 1, "hu-upper-hungary", H("Eger")), A("matra", "Mátra", 1, "hu-upper-hungary", H("Mátra")),
        A("bukk", "Bükk", 1, "hu-upper-hungary", H("Bükk")),
        A("sopron", "Sopron", 1, "hu-upper-pannon", H("Sopron")), A("mor", "Mór", 1, "hu-upper-pannon", H("Mór")),
        A("neszmely", "Neszmély", 1, "hu-upper-pannon", H("Neszmély")), A("pannonhalma", "Pannonhalma", 1, "hu-upper-pannon", H("Pannonhalma")),
        A("etyek-buda", "Etyek-Buda", 1, "hu-upper-pannon", H("Etyek-Buda")),
        A("badacsony", "Badacsony", 1, "balaton", H("Badacsony")), A("balaton-felvidek", "Balaton-felvidék", 1, "balaton", H("Balaton-felvidék")),
        A("balatonfured-csopak", "Balatonfüred-Csopak", 1, "balaton", H("Balatonfüred-Csopak")),
        A("balatonboglar", "Balatonboglár", 1, "balaton", H("Balatonboglár")), A("nagy-somlo", "Nagy-Somló", 1, "balaton", H("Nagy-Somló")),
        A("zala", "Zala", 1, "balaton", H("Zala")),
        A("kunsag", "Kunság", 1, "hu-duna", H("Kunság")), A("hajos-baja", "Hajós-Baja", 1, "hu-duna", H("Hajós-Baja")),
        A("csongrad", "Csongrád", 1, "hu-duna", H("Csongrád")),
        A("pecs", "Pécs", 1, "hu-pannon", H("Pécs")), A("szekszard", "Szekszárd", 1, "hu-pannon", H("Szekszárd")),
        A("tolna", "Tolna", 1, "hu-pannon", H("Tolna")), A("villany", "Villány", 1, "hu-pannon", H("Villány")),
        # ---- level 2: the smaller PDOs inside the districts
        A("somlo", "Somló", 2, "nagy-somlo", H("Somlói")), A("tihany", "Tihany", 2, "balatonfured-csopak", H("Tihany")),
        A("csopak", "Csopak", 2, "balatonfured-csopak", H("Csopak")), A("kali", "Káli", 2, "balaton-felvidek", H("Káli"), clip=False),
        A("izsaki-arany-sarfeher", "Izsáki Arany Sárfehér", 2, "kunsag", H("Izsáki Arany Sárfehér")),
        A("soltvadkert", "Soltvadkert", 2, "kunsag", H("Soltvadkerti")), A("monor", "Monor", 2, "kunsag", H("Monor")),
        A("debroi-harslevelu", "Debrői Hárslevelű", 2, "eger", H("Debrői Hárslevelű")),
        # ---- level 2: the classic wine villages (a circle around the village, inside its district)
    ],
}
