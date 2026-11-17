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
        "colchagua": U("CHL/ADM2", ["Provincia de Colchagua", "Provincia de Cachapoal"]),
        "maule": U("CHL/ADM2", ["Provincia de Curicó", "Provincia de Talca", "Provincia de Linares", "Provincia de Cauquenes"]),
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
    "cities": [("Beirut", 33.89, 35.50), ("Zahlé", 33.85, 35.90), ("Baalbek", 34.006, 36.21), ("Tripoli", 34.43, 35.84),
               ("Byblos", 34.12, 35.65), ("Sidon", 33.56, 35.37), ("Batroun", 34.255, 35.66), ("Damascus", 33.51, 36.29)],
    "labels": [("Mediterranean Sea", 33.95, 35.15, "sea"), ("SYRIA", 34.55, 36.55, "area"), ("Litani", 33.62, 35.62, "river"),
               ("Mount Lebanon range", 34.05, 35.83, "area"), ("Anti-Lebanon", 33.85, 36.33, "area")],
}
