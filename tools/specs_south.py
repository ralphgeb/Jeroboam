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
_MAIPO = ["Pirque", "Puente Alto", "Buin", "Paine", "Isla de Maipo", "Talagante", "Peñaflor", "Padre Hurtado", "El Monte",
          "Calera de Tango", "San Bernardo", "Melipilla", "Alhué", "María Pinto", "Curacaví", "San Pedro", "La Florida",
          "Peñalolén", "Macul", "La Reina", "Las Condes", "Lo Barnechea", "Vitacura", "Santiago", "Colina", "Lampa", "Tiltil",
          "Maipú", "Pudahuel", "Cerrillos"]
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
        # ---- level 0: the six wine regions (union of their valleys)
        A("cl-atacama", "Atacama", 0), A("cl-coquimbo", "Coquimbo", 0), A("cl-aconcagua", "Aconcagua", 0),
        A("cl-central-valley", "Central Valley", 0), A("cl-south", "South", 0), A("cl-austral", "Austral", 0),
        # ---- level 1: sub-regions (valleys)
        A("copiapo", "Copiapó Valley", 1, "cl-atacama", ["Copiapó", "Tierra Amarilla"]),
        A("huasco", "Huasco Valley", 1, "cl-atacama", ["Vallenar", "Alto del Carmen", "Freirina", "Huasco"]),
        A("elqui", "Elqui Valley", 1, "cl-coquimbo", ["Vicuña", "Paihuano", "La Serena", "La Higuera", "Coquimbo", "Andacollo"]),
        A("limari", "Limarí Valley", 1, "cl-coquimbo", ["Ovalle", "Monte Patria", "Punitaqui", "Río Hurtado", "Combarbalá"]),
        A("choapa", "Choapa Valley", 1, "cl-coquimbo", ["Salamanca", "Illapel", "Canela", "Los Vilos"]),
        A("aconcagua", "Aconcagua Valley", 1, "cl-aconcagua", ["Panquehue", "Los Andes", "San Felipe", "Santa María", "Calle Larga",
            "Rinconada", "San Esteban", "Putaendo", "Catemu", "Llaillay", "Quillota", "Hijuelas", "La Cruz", "Calera", "Nogales",
            "Zapallar", "Papudo", "La Ligua", "Cabildo", "Petorca", "Puchuncaví", "Quintero"]),
        A("casablanca", "Casablanca Valley", 1, "cl-aconcagua", ["Casablanca"]),
        A("marga-marga", "Marga Marga Valley", 1, "cl-aconcagua", ["Quilpué", "Villa Alemana", "Limache", "Olmué"]),
        A("san-antonio", "San Antonio Valley", 1, "cl-aconcagua", ["San Antonio", "Cartagena", "Santo Domingo", "El Tabo", "El Quisco", "Algarrobo"]),
        A("maipo", "Maipo Valley", 1, "cl-central-valley", _MAIPO),
        A("rapel", "Rapel Valley", 1, "cl-central-valley", None),
        A("curico", "Curicó Valley", 1, "cl-central-valley", None),
        A("maule", "Maule Valley", 1, "cl-central-valley", None),
        A("itata", "Itata Valley", 1, "cl-south", ["Chillán", "Chillán Viejo", "Quillón", "Portezuelo", "Coelemu", "Ranquil", "Ninhue",
            "Treguaco", "Quirihue", "Cobquecura", "San Nicolás", "Bulnes", "San Ignacio", "Pemuco", "El Carmen", "Pinto", "Coihueco",
            "San Carlos", "Ñiquén", "San Fabián", "Florida", "Tomé"]),
        A("bio-bio", "Bío Bío Valley", 1, "cl-south", ["Yumbel", "Mulchén", "Los Angeles", "Nacimiento", "Negrete", "Laja", "San Rosendo",
            "Cabrero", "Santa Bárbara", "Quilaco", "Quilleco", "Tucapel", "Yungay"]),
        A("malleco", "Malleco Valley", 1, "cl-south", ["Traiguén", "Angol", "Renaico", "Collipulli", "Ercilla", "Los Sauces", "Purén", "Lumaco", "Victoria"]),
        A("cautin", "Cautín Valley", 1, "cl-austral", ["Temuco", "Galvarino", "Lautaro", "Perquenco", "Vilcún", "Freire", "Pitrufquén",
            "Padre Las Casas", "Nueva Imperial", "Gorbea", "Cholchol"]),
        A("osorno", "Osorno Valley", 1, "cl-austral", ["Osorno", "San Pablo", "Puyehue", "Río Negro", "Purranque", "Puerto Octay"]),
        A("chiloe", "Chiloé", 1, "cl-austral", ["Ancud", "Castro", "Chonchi", "Dalcahue", "Quinchao", "Curaco de Vélez", "Puqueldón", "Quemchi", "Queilén", "Quellón"]),
        # ---- level 2: zones
        A("leyda", "Leyda Valley", 2, "san-antonio", ["San Antonio", "Santo Domingo"]),
        A("cachapoal", "Cachapoal Valley", 2, "rapel", ["Rancagua", "Machalí", "Graneros", "Codegua", "Mostazal", "Requínoa", "Rengo", "Olivar",
            "Doñihue", "Coinco", "Coltauco", "Quinta de Tilcoco", "Malloa", "San Vicente", "Pichidegua", "Peumo", "Las Cabras"]),
        A("colchagua", "Colchagua Valley", 2, "rapel", ["San Fernando", "Chimbarongo", "Placilla", "Nancagua", "Chépica", "Santa Cruz", "Lolol",
            "Palmilla", "Peralillo", "Pumanque", "Marchigüe", "Paredones", "Pichilemu", "La Estrella", "Litueche", "Navidad"]),
        A("teno", "Teno Valley", 2, "curico", ["Teno", "Rauco", "Romeral", "Hualañé", "Licantén", "Vichuquén"]),
        A("lontue", "Lontué Valley", 2, "curico", ["Curicó", "Molina", "Sagrada Familia"]),
        A("claro", "Claro Valley", 2, "maule", ["Talca", "Pencahue", "San Clemente", "San Rafael", "Pelarco", "Río Claro", "Maule", "Curepto",
            "Constitución", "Empedrado"]),
        A("loncomilla", "Loncomilla Valley", 2, "maule", ["San Javier", "Villa Alegre", "Yerbas Buenas", "Linares", "Colbún", "Longaví", "Retiro", "Parral"]),
        A("tutuven", "Tutuvén Valley", 2, "maule", ["Cauquenes", "Chanco", "Pelluhue"]),
        # ---- level 2: the official areas (comunas named in the decree) of valleys without zones
        *[A("cl-" + n.lower().replace(" ", "-").replace("í", "i").replace("é", "e").replace("ú", "u").replace("á", "a").replace("ñ", "n"), n, 2, p, [n])
          for p, ns in [("elqui", ["Vicuña", "Paihuano"]), ("limari", ["Ovalle", "Monte Patria", "Punitaqui", "Río Hurtado"]),
                        ("choapa", ["Salamanca", "Illapel"]), ("aconcagua", ["Panquehue"]),
                        ("maipo", ["Santiago", "Pirque", "Puente Alto", "Buin", "Isla de Maipo", "Talagante", "Melipilla", "Alhué", "María Pinto"]),
                        ("itata", ["Chillán", "Quillón", "Portezuelo", "Coelemu"]), ("bio-bio", ["Yumbel", "Mulchén"]), ("malleco", ["Traiguén"])]
          for n in ns],
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
        A("constantia", "Constantia", 2, "cape-town", W(-34.025, 18.43, 4)),
        A("durbanville", "Durbanville", 2, "cape-town", W(-33.82, 18.64, 7)),
        A("philadelphia", "Philadelphia", 2, "cape-town", W(-33.67, 18.58, 7)),
        A("hout-bay", "Hout Bay", 2, "cape-town", W(-34.03, 18.37, 3)),
        A("groenekloof", "Groenekloof", 2, "darling", W(-33.43, 18.33, 10)),
        A("malmesbury", "Malmesbury", 2, "swartland", W(-33.45, 18.70, 12)),
        A("riebeekberg", "Riebeekberg", 2, "swartland", W(-33.36, 18.88, 6)),
        A("paardeberg", "Paardeberg", 2, "swartland", W(-33.56, 18.80, 6)),
        A("porseleinberg", "Porseleinberg", 2, "swartland", W(-33.27, 18.92, 5)),
        A("st-helena-bay", "St Helena Bay", 2, "swartland", W(-32.76, 18.02, 7)),
        A("voor-paardeberg", "Voor Paardeberg", 2, "paarl", W(-33.63, 18.85, 6)),
        A("agter-paarl", "Agter-Paarl", 2, "paarl", W(-33.71, 18.86, 6)),
        A("simonsberg-paarl", "Simonsberg-Paarl", 2, "paarl", W(-33.80, 18.93, 5)),
        A("bovlei", "Bovlei", 2, "wellington", W(-33.62, 19.06, 4)),
        A("groenberg", "Groenberg", 2, "wellington", W(-33.59, 18.97, 4)),
        A("limietberg", "Limietberg", 2, "wellington", W(-33.55, 19.05, 4)),
        A("simonsberg-stellenbosch", "Simonsberg-Stellenbosch", 2, "stellenbosch", W(-33.865, 18.90, 4)),
        A("banghoek", "Banghoek", 2, "stellenbosch", W(-33.91, 18.97, 3.5)),
        A("jonkershoek-valley", "Jonkershoek Valley", 2, "stellenbosch", W(-33.965, 18.93, 2.5)),
        A("devon-valley", "Devon Valley", 2, "stellenbosch", W(-33.905, 18.82, 2.2)),
        A("papegaaiberg", "Papegaaiberg", 2, "stellenbosch", W(-33.935, 18.835, 1.6)),
        A("bottelary", "Bottelary", 2, "stellenbosch", W(-33.88, 18.74, 5)),
        A("polkadraai-hills", "Polkadraai Hills", 2, "stellenbosch", W(-33.96, 18.72, 4)),
        A("vlottenburg", "Vlottenburg", 2, "stellenbosch", W(-33.965, 18.79, 2.6)),
        A("slanghoek", "Slanghoek", 2, "breedekloof", W(-33.62, 19.22, 6)),
        A("goudini", "Goudini", 2, "breedekloof", W(-33.68, 19.30, 5)),
        A("hex-river-valley", "Hex River Valley", 2, "worcester", W(-33.47, 19.65, 10)),
        A("nuy", "Nuy", 2, "worcester", W(-33.68, 19.62, 5)),
        A("scherpenheuvel", "Scherpenheuvel", 2, "worcester", W(-33.73, 19.53, 5)),
        A("ashton", "Ashton", 2, "robertson", W(-33.83, 20.05, 5)),
        A("bonnievale", "Bonnievale", 2, "robertson", W(-33.93, 20.10, 7)),
        A("mcgregor", "McGregor", 2, "robertson", W(-33.95, 19.83, 5)),
        A("klaasvoogds", "Klaasvoogds", 2, "robertson", W(-33.78, 19.98, 4)),
        A("le-chasseur", "Le Chasseur", 2, "robertson", W(-33.80, 19.80, 4)),
        A("eilandia", "Eilandia", 2, "robertson", W(-33.84, 19.95, 3)),
        A("agterkliphoogte", "Agterkliphoogte", 2, "robertson", W(-33.86, 19.73, 4)),
        A("hemel-en-aarde-valley", "Hemel-en-Aarde Valley", 2, "walker-bay", W(-34.39, 19.255, 3)),
        A("upper-hemel-en-aarde", "Upper Hemel-en-Aarde Valley", 2, "walker-bay", W(-34.36, 19.30, 3)),
        A("hemel-en-aarde-ridge", "Hemel-en-Aarde Ridge", 2, "walker-bay", W(-34.32, 19.34, 3)),
        A("bot-river", "Bot River", 2, "walker-bay", W(-34.23, 19.20, 6)),
        A("stanford-foothills", "Stanford Foothills", 2, "walker-bay", W(-34.43, 19.49, 5)),
        A("sundays-glen", "Sunday's Glen", 2, "walker-bay", W(-34.50, 19.53, 3)),
        A("elim-ward", "Elim", 2, "elim", W(-34.59, 19.76, 8)),
        A("greyton", "Greyton", 2, "overberg", W(-34.05, 19.61, 6)),
        A("theewater", "Theewater", 2, "overberg", W(-34.05, 19.28, 6)),
        A("piekenierskloof", "Piekenierskloof", 2, "citrusdal-mountain", W(-32.62, 18.98, 7)),
        A("koekenaap", "Koekenaap", 2, "lutzville-valley", W(-31.52, 18.30, 7)),
        A("vredendal", "Vredendal", 2, "za-olifants", W(-31.67, 18.50, 9), clip=False),
        A("spruitdrift", "Spruitdrift", 2, "za-olifants", W(-31.76, 18.62, 6), clip=False),
        A("outeniqua", "Outeniqua", 2, "oudtshoorn", W(-33.80, 22.45, 12)),
        A("upper-langkloof", "Upper Langkloof", 2, "za-klein-karoo", W(-33.73, 23.05, 12), clip=False),
        A("tradouw", "Tradouw", 2, "za-klein-karoo", W(-33.95, 20.70, 8), clip=False),
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
        A("agrelo", "Agrelo", 2, "lujan-de-cuyo", X(-33.12, -68.90, 7, "Agrelo")),
        A("alto-agrelo", "Alto Agrelo", 2, "lujan-de-cuyo", X(-33.14, -69.00, 6)),
        A("perdriel", "Perdriel", 2, "lujan-de-cuyo", X(-33.07, -68.87, 4, "Perdriel")),
        A("vistalba", "Vistalba", 2, "lujan-de-cuyo", X(-33.03, -68.92, 3, "Vistalba")),
        A("las-compuertas", "Las Compuertas", 2, "lujan-de-cuyo", X(-33.04, -68.98, 4, "Las Compuertas")),
        A("mayor-drummond", "Mayor Drummond", 2, "lujan-de-cuyo", X(-33.00, -68.885, 2.5, "Mayor Drummond")),
        A("ugarteche", "Ugarteche", 2, "lujan-de-cuyo", X(-33.21, -68.88, 8, "Ugarteche")),
        A("el-carrizal", "El Carrizal", 2, "lujan-de-cuyo", X(-33.30, -68.78, 8, "El Carrizal")),
        A("anchoris", "Anchoris", 2, "lujan-de-cuyo", X(-33.32, -68.92, 6, "Anchoris")),
        A("lunlunta", "Lunlunta", 2, "maipu", X(-33.04, -68.80, 3, "Lunlunta")),
        A("cruz-de-piedra", "Cruz de Piedra", 2, "maipu", X(-33.04, -68.76, 3.5, "Cruz de Piedra")),
        A("barrancas", "Barrancas", 2, "maipu", X(-33.09, -68.73, 5, "Barrancas")),
        A("russell", "Russell", 2, "maipu", X(-33.00, -68.79, 3, "Russell")),
        A("coquimbito", "Coquimbito", 2, "maipu", X(-32.97, -68.75, 3, "Coquimbito")),
        A("medrano", "Medrano", 2, "mendoza-east", X(-33.18, -68.62, 7, "Medrano")),
        A("gualtallary", "Gualtallary", 2, "uco-valley", X(-33.39, -69.26, 8, "Gualtallary")),
        A("la-arboleda", "La Arboleda", 2, "uco-valley", X(-33.32, -69.17, 4, "La Arboleda")),
        A("el-peral", "El Peral", 2, "uco-valley", X(-33.37, -69.19, 3.5, "El Peral")),
        A("villa-bastias", "Villa Bastías", 2, "uco-valley", X(-33.34, -69.11, 4, "Villa Bastías")),
        A("san-jose-tupungato", "San José", 2, "uco-valley", X(-33.29, -69.11, 4, "San José")),
        A("cordon-del-plata", "Cordón del Plata", 2, "uco-valley", X(-33.27, -69.20, 5, "Cordón del Plata")),
        A("los-arboles", "Los Árboles", 2, "uco-valley", X(-33.55, -69.17, 6, "Los Árboles")),
        A("san-pablo", "San Pablo", 2, "uco-valley", X(-33.55, -69.33, 8)),
        A("los-chacayes", "Los Chacayes", 2, "uco-valley", X(-33.66, -69.27, 8, "Los Chacayes")),
        A("vista-flores", "Vista Flores", 2, "uco-valley", X(-33.65, -69.15, 5, "Vista Flores")),
        A("campo-de-los-andes", "Campo de los Andes", 2, "uco-valley", X(-33.70, -69.10, 5, "Campo de los Andes")),
        A("paraje-altamira", "Paraje Altamira", 2, "uco-valley", X(-33.76, -69.13, 6)),
        A("la-consulta", "La Consulta", 2, "uco-valley", X(-33.71, -69.05, 4, "La Consulta")),
        A("eugenio-bustos", "Eugenio Bustos", 2, "uco-valley", X(-33.79, -69.05, 4, "Eugenio Bustos")),
        A("el-cepillo", "Pampa El Cepillo", 2, "uco-valley", X(-33.85, -69.15, 6)),
        A("pedernal", "Pedernal", 2, "tulum", X(-31.99, -68.78, 8), clip=False),
        A("cachi", "Cachi", 2, "calchaqui-salta", X(-25.12, -66.17, 10)),
        A("molinos", "Molinos & Colomé", 2, "calchaqui-salta", X(-25.42, -66.27, 12)),
        A("san-patricio", "San Patricio del Chañar", 2, "neuquen", X(-38.62, -68.30, 10)),
    ],
}
