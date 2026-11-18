# Wine regions built from real administrative boundaries (geoBoundaries gbOpen, CC BY 4.0).
# Files: ~/geo/gb/<ISO>-<ADM>.geojson  (download: media.githubusercontent.com/media/wmgeolab/geoBoundaries/main/
#        releaseData/gbOpen/<ISO>/<ADM>/geoBoundaries-<ISO>-<ADM>_simplified.geojson)
#
# Each region is one of:
#   U(adm, [names])            union of named admin units (duplicates resolved by distance to the legacy sketch)
#   U(adm, [names], clip=km)   same, trimmed to the legacy sketch buffered by km (valley floors, slopes)
#   S(adm, km=0, within=...)   "snap": every unit at this level whose centre lies inside the legacy sketch
#                              (buffered by km); the result follows real municipal boundaries
# `minus` removes other regions (nested appellations). Regions are then inset and smoothed by the builder.

def U(adm, names, clip=None, minus=()):
    return {"mode": "units", "adm": adm, "names": names, "clip": clip, "minus": list(minus)}

def S(adm, km=0.0, within=None, minus=()):
    return {"mode": "snap", "adm": adm, "km": km, "within": within, "minus": list(minus)}

COUNTRIES = {
    "portugal": {"iso": "PRT", "regions": {
        "vinho-verde": U("ADM2", ["Melgaco", "Moncao", "Valenca", "Vila Nova de Cerveira", "Caminha", "Paredes de Coura",
                                  "Arcos de Valdevez", "Ponte da Barca", "Ponte de Lima", "Viana do Castelo", "Barcelos",
                                  "Esposende", "Braga", "Amares", "Vila Verde", "Terras de Bouro", "Povoa de Lanhosa",
                                  "Vieira do Minho", "Guimaraes", "Fafe", "Vila Nova de Famalicao", "Cabeceiras de Basto",
                                  "Celorico de Basto", "Mondim de Basto", "Felgueiras", "Lousada", "Amarante",
                                  "Marco de Canaveses", "Penafiel", "Paredes", "Pacos de Ferreira", "Santo Tirso", "Trofa",
                                  "Vizela", "Baiao", "Cinfaes", "Castelo de Paiva"]),
        "douro": U("ADM2", ["Mesao Frio", "Peso da Regua", "Santa Marta de Penaguiao", "Vila Real", "Sabrosa", "Alijo",
                            "Murca", "Carrazeda de Ansiaes", "Vila Flor", "Torre de Moncorvo", "Freixo de Espada a Cinta",
                            "Vila Nova de Foz Coa", "Figueira de Castelo Rodrigo", "Meda", "Sao Joao da Pesqueira",
                            "Tabuaco", "Armamar", "Lamego", "Resende"]),
        "dao": U("ADM2", ["Viseu", "Mangualde", "Nelas", "Carregal do Sal", "Santa Comba Dao", "Tondela",
                          "Penalva do Castelo", "Satao", "Tabua", "Oliveira do Hospital", "Seia", "Gouveia", "Mortagua",
                          "Fornos de Algodres", "Aguiar da Beira"]),
        "bairrada": U("ADM2", ["Anadia", "Mealhada", "Oliveira do Bairro", "Cantanhede", "Agueda", "Vagos"]),
        "lisboa": U("ADM2", ["Alenquer", "Arruda dos Vinhos", "Sobral de Monte Agraco", "Torres Vedras", "Lourinha",
                             "Bombarral", "Cadaval", "Obidos", "Caldas da Rainha", "Alcobaca", "Mafra", "Azambuja"]),
        "tejo": U("ADM2", ["Santarem", "Cartaxo", "Almeirim", "Alpiarca", "Chamusca", "Golega", "Salvaterra de Magos",
                           "Benavente", "Coruche", "Rio Maior", "Tomar", "Torres Novas", "Abrantes", "Constancia",
                           "Vila Nova da Barquinha", "Entroncamento"]),
        "setubal": U("ADM2", ["Palmela", "Setubul", "Montijo", "Sesimbra"]),
        "alentejo": U("ADM2", ["Portalegre", "Borba", "Estremoz", "Redondo", "Reguengos de Monsaraz", "Vidigueira", "Evora",
                               "Moura", "Vila Vicosa", "Arraiolos", "Cuba", "Alvito", "Beja", "Serpa", "Portel",
                               "Montemor-o-Novo", "Mourao", "Alandroal", "Monforte"]),
    }},
    "spain": {"iso": "ESP", "regions": {r: S("ADM3") for r in
        ["rias-baixas", "bierzo", "rioja", "navarra", "ribera-del-duero", "rueda", "toro", "priorat", "penedes",
         "la-mancha", "jumilla", "jerez"]}},
    "austria": {"iso": "AUT", "regions": {r: S("ADM3") for r in
        ["wachau", "kremstal", "kamptal", "wagram", "weinviertel", "carnuntum", "thermenregion", "neusiedlersee",
         "leithaberg", "mittelburgenland", "steiermark"]}},
    "hungary": {"iso": "HUN", "regions": {r: S("ADM3") for r in
        ["tokaj", "eger", "somlo", "balaton", "kunsag", "szekszard", "villany"]}},
    "greece": {"iso": "GRC", "regions": {r: S("ADM3", km=3) for r in
        ["naoussa", "amyndeo", "patras", "nemea", "mantinia", "santorini", "crete"]}},
    "germany": {"iso": "DEU", "regions": {
        "ahr": U("ADM3", ["Ahrweiler"], clip=4),
        "mittelrhein": U("ADM3", ["Mayen-Koblenz", "Rhein-Lahn-Kreis", "Rhein-Hunsrück-Kreis", "Neuwied",
                                  "Koblenz, Kreisfreie Stadt"], clip=3),
        "mosel": U("ADM3", ["Trier-Saarburg", "Bernkastel-Wittlich", "Cochem-Zell", "Trier, Kreisfreie Stadt",
                            "Mayen-Koblenz"], clip=4),
        "nahe": U("ADM3", ["Bad Kreuznach"], clip=6),
        "rheingau": U("ADM3", ["Rheingau-Taunus-Kreis", "Wiesbaden, Kreisfreie Stadt"], clip=3),
        "rheinhessen": U("ADM3", ["Mainz-Bingen", "Alzey-Worms", "Worms, Kreisfreie Stadt", "Mainz, Kreisfreie Stadt"]),
        "pfalz": U("ADM3", ["Bad Dürkheim", "Südliche Weinstraße", "Neustadt an der Weinstraße, Kreisfreie Stadt",
                            "Landau in der Pfalz, Kreisfreie Stadt"], clip=8),
        "franken": U("ADM3", ["Würzburg, Landkreis", "Würzburg, Kreisfreie Stadt", "Kitzingen", "Main-Spessart",
                              "Schweinfurt, Landkreis"]),
        "wurttemberg": U("ADM3", ["Heilbronn, Landkreis", "Heilbronn, Stadtkreis", "Ludwigsburg", "Rems-Murr-Kreis",
                                  "Stuttgart, Stadtkreis", "Esslingen", "Hohenlohekreis"]),
        "baden": U("ADM3", ["Ortenaukreis", "Emmendingen", "Breisgau-Hochschwarzwald", "Freiburg im Breisgau, Stadtkreis",
                            "Rastatt", "Baden-Baden, Stadtkreis", "Karlsruhe, Landkreis", "Lörrach",
                            "Rhein-Neckar-Kreis"], clip=6),
        "saale-unstrut": U("ADM3", ["Burgenlandkreis", "Saalekreis"]),
        "sachsen": U("ADM3", ["Meißen", "Dresden, Kreisfreie Stadt"]),
    }},
    "south-america": {"iso": ["CHL", "ARG"], "regions": {
        "elqui-limari": U("CHL/ADM2", ["Provincia de Elqui", "Provincia de Limarí"]),
        "aconcagua": U("CHL/ADM2", ["Provincia de Los Andes", "Provincia de San Felipe de Aconcagua", "Provincia de Quillota"]),
        "casablanca": U("CHL/ADM3", ["Casablanca"]),
        "maipo": U("CHL/ADM2", ["Provincia de Maipo", "Provincia de Talagante", "Provincia de Cordillera"], clip=25),
        "colchagua": U("CHL/ADM2", ["Provincia de Colchagua"]),
        "maule": U("CHL/ADM2", ["Provincia de Talca", "Provincia de Linares", "Provincia de Cauquenes"]),
        "itata-bio-bio": U("CHL/ADM2", ["Provincia de Itata", "Provincia de Diguillín", "Provincia de Punilla",
                                        "Provincia de Bío-Bío"]),
        "salta": U("ARG/ADM2", ["Cafayate", "San Carlos", "Molinos", "Cachi"]),
        "san-juan": U("ARG/ADM2", ["Pocito", "Rawson", "Sarmiento", "25 de Mayo", "Caucete", "San Martín", "Angaco",
                                   "Albardón", "Chimbas", "Rivadavia", "Santa Lucía", "9 de julio", "Ullum", "Zonda",
                                   "Capital"]),
        "mendoza": U("ARG/ADM2", ["Luján de Cuyo", "Maipú", "Godoy Cruz", "Guaymallén", "Capital", "Junín", "Rivadavia",
                                  "San Martín", "Santa Rosa"]),
        "uco-valley": U("ARG/ADM2", ["Tupungato", "Tunuyán", "San Carlos"]),
        "patagonia": U("ARG/ADM2", ["Confluencia", "General Roca", "Anelo"], clip=30),
    }},
    "australia": {"iso": "AUS", "regions": {
        "margaret-river": U("ADM2", ["Augusta Margaret River", "Busselton"], clip=10),
        "great-southern": U("ADM2", ["Plantagenet", "Denmark", "Cranbrook", "Albany"]),
        "swan-valley": U("ADM2", ["Swan"], clip=12),
        "clare": U("ADM2", ["Clare and Gilbert Valleys"]),
        "barossa": U("ADM2", ["Barossa", "Light"]),
        "mclaren-vale": U("ADM2", ["Onkaparinga"], clip=20),
        "coonawarra": U("ADM2", ["Wattle Range", "Naracoorte Lucindale"], clip=20),
        "riverland": U("ADM2", ["Renmark Paringa", "Berri Barmera", "Loxton Waikerie"]),
        "yarra-valley": U("ADM2", ["Yarra Ranges", "Nillumbik"], clip=20),
        "rutherglen": U("ADM2", ["Indigo", "Wodonga"], clip=25),
        "riverina": U("ADM2", ["Griffith", "Leeton", "Murrumbidgee"]),
        "hunter-valley": U("ADM2", ["Cessnock", "Singleton"]),
        "tasmania": U("ADM2", ["West Tamar", "George Town", "Launceston", "Clarence", "Sorell", "Derwent Valley", "Brighton",
                               "Huon Valley", "Glamorgan-Spring Bay", "Kingborough", "Glenorchy", "Hobart"]),
    }},
    "south-australia": {"iso": "AUS", "regions": {
        "clare": U("ADM2", ["Clare and Gilbert Valleys"]),
        "barossa": U("ADM2", ["Barossa", "Light"], minus=["eden-valley"]),
        "eden-valley": U("ADM2", ["Barossa"], clip=0),
        "adelaide-hills": U("ADM2", ["Adelaide Hills", "Mount Barker"]),
        "mclaren-vale": U("ADM2", ["Onkaparinga"], clip=6),
        "langhorne-creek": U("ADM2", ["Alexandrina"], clip=4),
        "riverland": U("ADM2", ["Renmark Paringa", "Berri Barmera", "Loxton Waikerie"]),
        "padthaway": U("ADM2", ["Naracoorte Lucindale", "Tatiara"], clip=4),
        "coonawarra": U("ADM2", ["Wattle Range", "Naracoorte Lucindale"], clip=3),
    }},
    "new-zealand": {"iso": "NZL", "regions": {r: S("ADM3", km=6) for r in
        ["auckland", "hawkes-bay", "martinborough", "nelson", "waipara", "central-otago"]} | {
        "gisborne": U("ADM2", ["Gisborne District"], clip=22), "marlborough": U("ADM2", ["Marlborough District"], clip=22)}},
    "south-africa": {"iso": "ZAF", "regions": dict({r: S("ADM4", km=1) for r in
        ["swartland", "tulbagh", "durbanville", "constantia", "paarl", "stellenbosch", "franschhoek", "elgin",
         "walker-bay", "robertson"]}, breedekloof=S("ADM4", km=5), elim=U("ADM3", ["Cape Agulhas"], clip=5))},
}

# ---------------------------------------------------------------- Lebanon (new)
LEBANON = {
    "id": "lebanon", "title": "Lebanon", "bbox": (32.95, 34.95, 34.75, 36.75), "focus": ["LBN"],
    "regions": [  # (id, name, cazas)
        ("bekaa-valley", "Bekaa Valley", ["Zahle"]),
        ("west-bekaa", "West Bekaa", ["West Bekaa", "Rachaya"]),
        ("baalbek", "Baalbek", ["Baalbek"]),
        ("mount-lebanon", "Mount Lebanon", ["Aley", "Baabda", "El Metn", "Kesrouan", "Chouf", "Jbail"]),
        ("batroun", "Batroun", ["Batroun", "Koura"]),
        ("jezzine", "Jezzine", ["Jezzine"]),
    ],
    # vineyard zones (valley floor / hill pockets) the cazas are trimmed to
    # vineyard zones the cazas are trimmed to: the Bekaa valley floor between the two ranges, the western slopes, coastal hills
    "zones": {
        "bekaa-valley": [{"t": "poly", "p": [(33.50,35.66),(33.60,35.71),(33.70,35.79),(33.80,35.86),(33.88,35.93),(33.97,36.02),(34.06,36.11),(34.16,36.22),(34.24,36.32),(34.20,36.42),(34.08,36.30),(33.98,36.17),(33.88,36.06),(33.78,35.97),(33.68,35.90),(33.58,35.82),(33.48,35.76)]}],
        "west-bekaa": [{"t": "poly", "p": [(33.50,35.66),(33.60,35.71),(33.70,35.79),(33.80,35.86),(33.88,35.93),(33.97,36.02),(34.06,36.11),(34.16,36.22),(34.24,36.32),(34.20,36.42),(34.08,36.30),(33.98,36.17),(33.88,36.06),(33.78,35.97),(33.68,35.90),(33.58,35.82),(33.48,35.76)]}],
        "baalbek": [{"t": "poly", "p": [(33.50,35.66),(33.60,35.71),(33.70,35.79),(33.80,35.86),(33.88,35.93),(33.97,36.02),(34.06,36.11),(34.16,36.22),(34.24,36.32),(34.20,36.42),(34.08,36.30),(33.98,36.17),(33.88,36.06),(33.78,35.97),(33.68,35.90),(33.58,35.82),(33.48,35.76)]}],
        # scattered hillside vineyards: clusters of small patches around the wine villages
        "mount-lebanon": [{"t": "patches", "c": [(34.02, 35.66), (33.97, 35.70), (33.88, 35.70), (33.83, 35.64), (33.70, 35.60), (33.66, 35.66)], "r": 2.6}],
        "batroun": [{"t": "patches", "c": [(34.26, 35.70), (34.23, 35.75), (34.20, 35.79), (34.28, 35.78)], "r": 2.4}],
        "jezzine": [{"t": "patches", "c": [(33.55, 35.58), (33.52, 35.62), (33.58, 35.55)], "r": 2.2}],
    },
    "cities": [("Beirut", 33.89, 35.50), ("Zahlé", 33.85, 35.90), ("Baalbek", 34.006, 36.21), ("Tripoli", 34.43, 35.84),
               ("Byblos", 34.12, 35.65), ("Sidon", 33.56, 35.37), ("Batroun", 34.255, 35.66), ("Damascus", 33.51, 36.29)],
    "labels": [("Mediterranean Sea", 33.95, 35.15, "sea"), ("SYRIA", 34.55, 36.55, "area"), ("Litani", 33.62, 35.62, "river"),
               ("Mount Lebanon range", 34.05, 35.83, "area"), ("Anti-Lebanon", 33.85, 36.33, "area")],
}

# ======================================================================================= atlas hierarchy
# Level 0 = the big wine regions as printed atlases show them (built from provinces/states), level 1 = the appellations
# inside (the existing regions above become level 1 and find their parent by overlap), plus extra appellations from the
# atlas drawn as B(lat, lon, radius_km) and snapped to the country's finest admin units.

def G(adm, names):
    return {"adm": adm, "names": names}

def B(name, lat, lon, r, adm=None, minus=()):
    return {"name": name, "c": (lat, lon), "r": r, "adm": adm, "minus": list(minus)}

HIERARCHY = {
    "spain": {"snap": "ADM3", "groups": {
        "es-galicia": ("Galicia", G("ADM1", ["Galicia"])),
        "es-pais-vasco": ("País Vasco", G("ADM1", ["País Vasco/Euskadi"])),
        "es-la-rioja": ("La Rioja", G("ADM1", ["La Rioja"])),
        "es-navarra": ("Navarra", G("ADM1", ["Comunidad Foral de Navarra"])),
        "es-aragon": ("Aragón", G("ADM1", ["Aragón"])),
        "es-catalonia": ("Catalonia", G("ADM1", ["Cataluña/Catalunya"])),
        "es-castilla-leon": ("Castilla y León", G("ADM1", ["Castilla y León"])),
        "es-madrid": ("Madrid", G("ADM1", ["Comunidad de Madrid"])),
        "es-castilla-la-mancha": ("Castilla-La Mancha", G("ADM1", ["Castilla-La Mancha"])),
        "es-valencia": ("Valencia", G("ADM1", ["Comunitat Valenciana"])),
        "es-murcia": ("Murcia", G("ADM1", ["Región de Murcia"])),
        "es-extremadura": ("Extremadura", G("ADM1", ["Extremadura"])),
        "es-andalucia": ("Andalucía", G("ADM1", ["Andalucía"])),
        "es-baleares": ("Balearic Islands", G("ADM1", ["Illes Balears"])),
    }, "extra": {
        "valdeorras": B("Valdeorras", 42.40, -7.00, 14), "ribeiro": B("Ribeiro", 42.32, -8.15, 10),
        "txakoli": B("Txakoli", 43.30, -2.60, 16), "carinena": B("Cariñena", 41.33, -1.22, 15),
        "campo-de-borja": B("Campo de Borja", 41.80, -1.53, 12), "calatayud": B("Calatayud", 41.35, -1.65, 18),
        "somontano": B("Somontano", 42.03, 0.10, 18), "montsant": B("Montsant", 41.22, 0.85, 12, minus=["priorat"]),
        "terra-alta": B("Terra Alta", 41.05, 0.42, 13), "emporda": B("Empordà", 42.30, 3.00, 15),
        "costers-del-segre": B("Costers del Segre", 41.55, 0.85, 20), "cigales": B("Cigales", 41.80, -4.70, 10),
        "tierra-de-leon": B("Tierra de León", 42.35, -5.45, 18), "arlanza": B("Arlanza", 42.05, -3.75, 14),
        "vinos-de-madrid": B("Vinos de Madrid", 40.25, -3.85, 25), "valdepenas": B("Valdepeñas", 38.76, -3.38, 15),
        "manchuela": B("Manchuela", 39.35, -1.80, 25), "utiel-requena": B("Utiel-Requena", 39.55, -1.15, 20),
        "alicante-do": B("Alicante", 38.55, -0.75, 20), "yecla": B("Yecla", 38.60, -1.12, 10),
        "bullas": B("Bullas", 38.05, -1.67, 10), "ribera-del-guadiana": B("Ribera del Guadiana", 38.65, -6.40, 35),
        "montilla-moriles": B("Montilla-Moriles", 37.58, -4.65, 15), "malaga-do": B("Málaga", 36.80, -4.60, 25),
        "condado-de-huelva": B("Condado de Huelva", 37.30, -6.55, 15), "binissalem": B("Binissalem", 39.68, 2.84, 8),
    }},
    "portugal": {"snap": "ADM3", "level0": True, "extra0": {
        "tras-os-montes": ("Trás-os-Montes", G("ADM2", ["Chaves", "Valpacos", "Mirandela", "Macedo de Cavaleiros", "Braganca",
                                                        "Vinhais", "Mogadouro", "Miranda do Douro", "Vimioso", "Alfandega da Fe"])),
        "tavora-varosa": ("Távora-Varosa", G("ADM2", ["Tarouca", "Moimenta da Beira", "Sernancelhe", "Penedono"])),
        "beira-interior": ("Beira Interior", G("ADM2", ["Guarda", "Pinhel", "Trancoso", "Celorico da Beira", "Belmonte", "Covilha",
                                                        "Fundao", "Castelo Branco", "Sabugal", "Almeida"])),
        "algarve": ("Algarve", G("ADM2", ["Lagos", "Portimao", "Lagoa", "Silves", "Albufeira", "Tavira", "Loule"])),
    }, "subs": {
        "moncao-melgaco": ("Monção e Melgaço", "vinho-verde", G("ADM2", ["Moncao", "Melgaco"])),
        "baixo-corgo": ("Baixo Corgo", "douro", G("ADM2", ["Mesao Frio", "Peso da Regua", "Santa Marta de Penaguiao", "Lamego", "Resende"])),
        "cima-corgo": ("Cima Corgo", "douro", G("ADM2", ["Sabrosa", "Alijo", "Sao Joao da Pesqueira", "Tabuaco", "Armamar", "Murca"])),
        "douro-superior": ("Douro Superior", "douro", G("ADM2", ["Vila Nova de Foz Coa", "Meda", "Torre de Moncorvo", "Freixo de Espada a Cinta",
                                                                 "Figueira de Castelo Rodrigo", "Carrazeda de Ansiaes", "Vila Flor"])),
        "reguengos": ("Reguengos", "alentejo", G("ADM2", ["Reguengos de Monsaraz", "Mourao"])),
        "borba": ("Borba", "alentejo", G("ADM2", ["Borba", "Estremoz"])),
        "redondo": ("Redondo", "alentejo", G("ADM2", ["Redondo"])),
        "vidigueira": ("Vidigueira", "alentejo", G("ADM2", ["Vidigueira", "Cuba", "Alvito"])),
        "evora-sub": ("Évora", "alentejo", G("ADM2", ["Evora"])),
        "portalegre-sub": ("Portalegre", "alentejo", G("ADM2", ["Portalegre"])),
        "moura-sub": ("Moura", "alentejo", G("ADM2", ["Moura", "Serpa"])),
    }},
    "south-america": {"snap": "CHL/ADM3", "groups": {
        "cl-atacama": ("Atacama", G("CHL/ADM1", ["Región de Atacama"])),
        "cl-coquimbo": ("Coquimbo", G("CHL/ADM1", ["Región de Coquimbo"])),
        "cl-aconcagua": ("Aconcagua", G("CHL/ADM1", ["Región de Valparaíso"])),
        "cl-central-valley": ("Central Valley", G("CHL/ADM1", ["Región Metropolitana de Santiago", "Región del Libertador Bernardo O'Higgins",
                                                                "Región del Maule"])),
        "cl-south": ("South", G("CHL/ADM1", ["Región de Ñuble", "Región del Bío-Bío", "Región de La Araucanía"])),
        "cl-austral": ("Austral", G("CHL/ADM1", ["Región de Los Ríos", "Región de Los Lagos"])),
        "ar-salta": ("Salta", G("ARG/ADM1", ["Salta"])),
        "ar-tucuman": ("Tucumán", G("ARG/ADM1", ["Tucumán"])),
        "ar-catamarca": ("Catamarca", G("ARG/ADM1", ["Catamarca"])),
        "ar-la-rioja": ("La Rioja", G("ARG/ADM1", ["La Roja"])),
        "ar-san-juan": ("San Juan", G("ARG/ADM1", ["San Juan"])),
        "ar-mendoza": ("Mendoza", G("ARG/ADM1", ["Mendoza"])),
        "ar-patagonia": ("Patagonia", G("ARG/ADM1", ["Neuquén", "Río Negro"])),
    }, "units1": {
        "choapa": ("Choapa", G("CHL/ADM2", ["Provincia de Choapa"])),
        "san-antonio": ("San Antonio", G("CHL/ADM2", ["Provincia de San Antonio"])),
        "cachapoal": ("Cachapoal", G("CHL/ADM2", ["Provincia de Cachapoal"])),
        "curico": ("Curicó", G("CHL/ADM2", ["Provincia de Curicó"])),
        "malleco": ("Malleco", G("CHL/ADM2", ["Provincia de Malleco"])),
        "osorno": ("Osorno", G("CHL/ADM2", ["Provincia de Osorno"])),
        "san-rafael": ("San Rafael", G("ARG/ADM2", ["San Rafael", "General Alvear"])),
        "famatina": ("Famatina", G("ARG/ADM2", ["Chilecito", "Famatina"])),
        "calchaqui-catamarca": ("Santa María", G("ARG/ADM2", ["Santa María", "Belén"])),
    }},
    "australia": {"snap": "ADM2", "groups": {
        "au-wa": ("Western Australia", G("ADM1", ["Western Australia"])),
        "au-sa": ("South Australia", G("ADM1", ["South Australia"])),
        "au-vic": ("Victoria", G("ADM1", ["Victoria"])),
        "au-nsw": ("New South Wales", G("ADM1", ["New South Wales", "Australian Capital Territory"])),
        "au-qld": ("Queensland", G("ADM1", ["Queensland"])),
        "au-tas": ("Tasmania", G("ADM1", ["Tasmania"])),
    }, "units1": {
        "mudgee": ("Mudgee", G("ADM2", ["Mid-Western"])), "orange": ("Orange", G("ADM2", ["Orange", "Cabonne"])),
        "canberra-district": ("Canberra District", G("ADM2", ["Yass Valley"])),
        "geelong": ("Geelong", G("ADM2", ["Greater Geelong"])), "mornington": ("Mornington Peninsula", G("ADM2", ["Mornington Peninsula"])),
        "pemberton": ("Pemberton", G("ADM2", ["Manjimup"])), "granite-belt": ("Granite Belt", G("ADM2", ["Southern Downs"])),
        "heathcote": ("Heathcote", G("ADM2", ["Greater Bendigo"])), "grampians": ("Grampians", G("ADM2", ["Northern Grampians", "Ararat"])),
    }},
    "austria": {"snap": "ADM3", "groups": {
        "at-niederosterreich": ("Niederösterreich", G("ADM1", ["Niederösterreich"])),
        "at-wien": ("Wien", G("ADM1", ["Wien"])),
        "at-burgenland": ("Burgenland", G("ADM1", ["Burgenland"])),
        "steiermark": ("Steiermark", G("ADM1", ["Steiermark"])),
    }, "drop": ["steiermark"], "extra": {
        "traisental": B("Traisental", 48.30, 15.68, 9), "eisenberg": B("Eisenberg", 47.08, 16.45, 10),
        "sudsteiermark": B("Südsteiermark", 46.72, 15.50, 16), "vulkanland": B("Vulkanland Steiermark", 46.88, 15.90, 20),
        "weststeiermark": B("Weststeiermark", 46.88, 15.25, 14), "wiener-gemischter-satz": B("Wiener Gemischter Satz", 48.25, 16.36, 8),
    }},
    "germany": {"snap": "ADM3", "extra0": {
        "hessische-bergstrasse": ("Hessische Bergstraße", B("Hessische Bergstraße", 49.70, 8.63, 9)),
    }},
    "hungary": {"snap": "ADM3", "groups": {
        "hu-tokaj": ("Tokaj", G("ADM1", ["Borsod-Abaúj-Zemplén"])),
        "hu-upper-hungary": ("Upper Hungary", G("ADM1", ["Heves"])),
        "hu-balaton": ("Balaton", G("ADM1", ["Veszprém", "Zala", "Somogy"])),
        "hu-pannon": ("Pannon", G("ADM1", ["Baranya", "Tolna"])),
        "hu-duna": ("Duna", G("ADM1", ["Bács-Kiskun"])),
        "hu-upper-pannon": ("Upper Pannon", G("ADM1", ["Győr-Moson-Sopron", "Komárom-Esztergom", "Fejér"])),
    }, "extra": {
        "sopron": B("Sopron", 47.68, 16.60, 10), "matra": B("Mátra", 47.80, 19.95, 14),
        "etyek-buda": B("Etyek-Buda", 47.45, 18.75, 12),
    }},
    "greece": {"snap": "ADM3", "groups": {
        "gr-macedonia": ("Macedonia & Thrace", G("ADM2", ["Kentrikis Makedonias", "Dytikis Makedonias", "Anatolikis Makedonias kai Thr*"])),
        "gr-epirus": ("Epirus", G("ADM2", ["Ipeiroy"])),
        "gr-thessaly": ("Thessaly", G("ADM2", ["Thessalias"])),
        "gr-central": ("Central Greece", G("ADM2", ["Stereas Elladas", "Attikis"])),
        "gr-peloponnese": ("Peloponnese", G("ADM2", ["Peloponnisoy", "Dytikis Elladas"])),
        "gr-ionian": ("Ionian Islands", G("ADM2", ["Ionion Nison"])),
        "gr-aegean": ("Aegean Islands", G("ADM2", ["Notioy Aigaioy", "Voreioy Aigaioy"])),
        "gr-crete": ("Crete", G("ADM2", ["Kritis"])),
    }, "extra": {
        "rapsani": B("Rapsani", 39.92, 22.55, 8), "goumenissa": B("Goumenissa", 40.95, 22.45, 10),
        "paros": B("Paros", 37.08, 25.15, 8), "samos": B("Samos", 37.73, 26.82, 10), "limnos": B("Limnos", 39.90, 25.20, 10),
        "robola": B("Robola of Cephalonia", 38.20, 20.60, 12), "attica": B("Attica", 38.05, 23.85, 20),
        "zitsa": B("Zitsa", 39.75, 20.65, 8),
    }},
    "south-africa": {"snap": "ADM4", "groups": {
        "za-coastal": ("Coastal Region", G("ADM3", ["City of Cape Town", "Stellenbosch", "Drakenstein", "Swartland", "Witzenberg"])),
        "za-breede": ("Breede River Valley", G("ADM3", ["Breede Valley", "Langeberg"])),
        "za-cape-south-coast": ("Cape South Coast", G("ADM3", ["Theewaterskloof", "Overstrand", "Cape Agulhas", "Swellendam"])),
        "za-olifants": ("Olifants River", G("ADM3", ["Matzikama", "Cederberg"])),
        "za-klein-karoo": ("Klein Karoo", G("ADM3", ["Kannaland", "Oudtshoorn"])),
    }},
    "new-zealand": {"snap": "ADM3", "extra1": {
        "wairau-valley": ("Wairau Valley", "marlborough", B("Wairau Valley", -41.52, 173.80, 8)),
        "awatere-valley": ("Awatere Valley", "marlborough", B("Awatere Valley", -41.65, 174.05, 7)),
        "gimblett-gravels": ("Gimblett Gravels", "hawkes-bay", B("Gimblett Gravels", -39.63, 176.75, 4)),
        "bannockburn": ("Bannockburn", "central-otago", B("Bannockburn", -45.08, 169.15, 5)),
        "gibbston": ("Gibbston", "central-otago", B("Gibbston", -45.02, 168.90, 5)),
        "waiheke": ("Waiheke Island", "auckland", B("Waiheke Island", -36.80, 175.10, 6)),
    }},
}
