# France: appellations built from real commune boundaries (gregoiredavid/france-geojson, from IGN data).
# Each area: id, name, color, depts, and either communes=[...] (exact names) or within=[(lat,lon),...]
# (communes whose centroid lies inside the polygon). Explicit lists are claimed first; polygon areas
# skip communes already used. lv: 0 region, 1 appellation/district, 2 cru/village.

def A(id, name, lv, depts, communes=None, within=None, color=None, parent=None, label=None, grapes=None):
    return dict(id=id, name=name, lv=lv, depts=depts, communes=communes or [], within=within, color=color,
                parent=parent, label=label, grapes=grapes)

# ------------------------------------------------------------------ Bordeaux
BORDEAUX = [
    A("saint-estephe", "Saint-Estèphe", 2, ["33"], ["Saint-Estèphe"], parent="haut-medoc"),
    A("pauillac", "Pauillac", 2, ["33"], ["Pauillac"], parent="haut-medoc"),
    A("saint-julien", "Saint-Julien", 2, ["33"], ["Saint-Julien-Beychevelle"], parent="haut-medoc"),
    A("margaux", "Margaux", 2, ["33"], ["Margaux-Cantenac", "Soussans", "Arsac", "Labarde"], parent="haut-medoc"),
    A("listrac", "Listrac", 2, ["33"], ["Listrac-Médoc"], parent="haut-medoc"),
    A("moulis", "Moulis", 2, ["33"], ["Moulis-en-Médoc"], parent="haut-medoc"),
    A("haut-medoc", "Haut-Médoc", 1, ["33"], ["Saint-Seurin-de-Cadourne", "Cissac-Médoc", "Vertheuil", "Saint-Sauveur",
        "Saint-Laurent-Médoc", "Cussac-Fort-Médoc", "Lamarque", "Arcins", "Avensan", "Castelnau-de-Médoc", "Macau",
        "Ludon-Médoc", "Le Pian-Médoc", "Parempuyre", "Le Taillan-Médoc", "Blanquefort", "Saint-Aubin-de-Médoc",
        "Saint-Estèphe", "Pauillac", "Saint-Julien-Beychevelle", "Margaux-Cantenac", "Soussans", "Arsac", "Labarde",
        "Listrac-Médoc", "Moulis-en-Médoc"], color="claret", label=(45.05, -0.98), grapes="Cabernet Sauvignon · Merlot"),
    A("medoc", "Médoc", 1, ["33"], ["Saint-Yzans-de-Médoc", "Couquèques", "Ordonnac", "Saint-Germain-d'Esteuil",
        "Bégadan", "Blaignan-Prignac", "Lesparre-Médoc", "Civrac-en-Médoc", "Saint-Christoly-Médoc", "Valeyrac",
        "Queyrac", "Gaillan-en-Médoc", "Jau-Dignac-et-Loirac", "Vensac", "Saint-Vivien-de-Médoc"], color="plum",
        label=(45.45, -1.2), grapes="Merlot · Cabernet Sauvignon"),
    A("pessac-leognan", "Pessac-Léognan", 1, ["33"], ["Pessac", "Talence", "Gradignan", "Villenave-d'Ornon", "Léognan",
        "Cadaujac", "Canéjan", "Martillac", "Saint-Médard-d'Eyrans", "Mérignac"], color="rose", label=(44.78, -0.95)),
    A("sauternes", "Sauternes & Barsac", 1, ["33"], ["Sauternes", "Bommes", "Fargues", "Preignac", "Barsac"],
        color="gold", label=(44.47, -0.6), grapes="Sémillon · Sauvignon Blanc"),
    A("graves", "Graves", 1, ["33"], ["Portets", "Podensac", "Cérons", "Illats", "Landiras", "Budos", "Saint-Pierre-de-Mons",
        "Langon", "Toulenne", "Castres-Gironde", "Beautiran", "Ayguemorte-les-Graves", "Saint-Selve", "Saint-Morillon",
        "La Brède", "Arbanats", "Virelade", "Pujols-sur-Ciron", "Saint-Michel-de-Rieufret", "Mazères", "Roaillan",
        "Saint-Médard-d'Eyrans"], color="coral", label=(44.6, -0.75)),
    A("saint-emilion", "Saint-Émilion", 1, ["33"], ["Saint-Émilion", "Saint-Christophe-des-Bardes", "Saint-Laurent-des-Combes",
        "Saint-Hippolyte", "Saint-Étienne-de-Lisse", "Saint-Pey-d'Armens", "Saint-Sulpice-de-Faleyrens", "Vignonet"],
        color="claret", label=(44.82, -0.02), grapes="Merlot · Cabernet Franc"),
    A("pomerol", "Pomerol", 1, ["33"], ["Pomerol"], color="magenta", label=(44.97, -0.14)),
    A("lalande", "Lalande-de-Pomerol", 1, ["33"], ["Lalande-de-Pomerol", "Néac"], color="rose"),
    A("satellites", "Saint-Émilion satellites", 1, ["33"], ["Montagne", "Lussac", "Puisseguin"], color="plum"),
    A("fronsac", "Fronsac", 1, ["33"], ["Fronsac", "La Rivière", "Saint-Germain-de-la-Rivière", "Saint-Aignan",
        "Saillans", "Saint-Michel-de-Fronsac"], color="violet", label=(45.02, -0.32)),
    A("castillon", "Castillon", 1, ["33"], ["Castillon-la-Bataille", "Belvès-de-Castillon", "Saint-Magne-de-Castillon",
        "Gardegan-et-Tourtirac", "Sainte-Colombe", "Saint-Genès-de-Castillon", "Saint-Philippe-d'Aiguille",
        "Les Salles-de-Castillon"], color="coral"),
    A("bourg", "Côtes de Bourg", 1, ["33"], ["Bourg", "Bayon-sur-Gironde", "Gauriac", "Comps", "Saint-Seurin-de-Bourg",
        "Villeneuve", "Lansac", "Tauriac", "Pugnac", "Prignac-et-Marcamps", "Mombrier", "Samonac", "Saint-Ciers-de-Canesse",
        "Saint-Trojan", "Teuillac"], color="orange"),
    A("blaye", "Blaye", 1, ["33"], within=[(45.38, -0.78), (45.38, -0.35), (45.08, -0.30), (45.08, -0.62), (45.22, -0.70)],
        color="ochre", label=(45.3, -0.25)),
    A("entre-deux-mers", "Entre-Deux-Mers", 1, ["33"], within=[(45.0, -0.55), (44.92, -0.30), (44.86, -0.05), (44.72, 0.10),
        (44.58, 0.05), (44.55, -0.25), (44.72, -0.50), (44.85, -0.55)], color="teal", label=(44.68, -0.1),
        grapes="Sauvignon Blanc · Sémillon · Merlot"),
]

# ------------------------------------------------------------------ Burgundy & Beaujolais
BURGUNDY = [
    A("chablis", "Chablis", 1, ["89"], ["Chablis", "Fontenay-près-Chablis", "Fyé", "Milly", "Chichée", "Courgis", "Préhy",
        "Beine", "Lignorelles", "Ligny-le-Châtel", "Maligny", "Villy", "La Chapelle-Vaupelteigne", "Poilly-sur-Serein",
        "Fleys", "Béru", "Viviers", "Collan", "Saint-Cyr-les-Colons", "Courgis", "Fontenay-près-Chablis"], color="gold",
        grapes="Chardonnay"),
    A("cote-d-or", "Côte d'Or", 0, ["21", "71"], [], color="claret", label=(47.1, 5.1), grapes="Pinot Noir · Chardonnay"),
    A("cote-de-nuits", "Côte de Nuits", 1, ["21"], ["Marsannay-la-Côte", "Couchey", "Fixin", "Brochon", "Gevrey-Chambertin",
        "Morey-Saint-Denis", "Chambolle-Musigny", "Vougeot", "Flagey-Echézeaux", "Vosne-Romanée", "Nuits-Saint-Georges",
        "Premeaux-Prissey", "Comblanchien", "Corgoloin"], color="claret", label=(47.22, 5.2), grapes="Pinot Noir", parent="cote-d-or"),
    A("cote-de-beaune", "Côte de Beaune", 1, ["21", "71"], ["Ladoix-Serrigny", "Aloxe-Corton", "Pernand-Vergelesses",
        "Savigny-lès-Beaune", "Chorey-lès-Beaune", "Beaune", "Pommard", "Volnay", "Monthelie", "Auxey-Duresses",
        "Saint-Romain", "Meursault", "Puligny-Montrachet", "Chassagne-Montrachet", "Saint-Aubin", "Santenay",
        "Cheilly-lès-Maranges", "Dezize-lès-Maranges", "Sampigny-lès-Maranges"], color="magenta", label=(46.98, 5.15),
        grapes="Chardonnay · Pinot Noir", parent="cote-d-or"),
    A("cote-chalonnaise", "Côte Chalonnaise", 1, ["71"], ["Bouzeron", "Rully", "Chassey-le-Camp", "Mercurey",
        "Saint-Martin-sous-Montaigu", "Givry", "Jambles", "Dracy-le-Fort", "Montagny-lès-Buxy", "Buxy", "Saint-Vallerin",
        "Jully-lès-Buxy"], color="rose"),
    A("maconnais", "Mâconnais", 1, ["71"], within=[(46.62, 4.68), (46.60, 4.92), (46.22, 4.90), (46.20, 4.66)],
        color="ochre", label=(46.45, 5.1), grapes="Chardonnay"),
    A("pouilly-fuisse", "Pouilly-Fuissé", 2, ["71"], ["Fuissé", "Solutré-Pouilly", "Vergisson", "Chaintré"], parent="maconnais"),
    A("beaujolais", "Beaujolais", 0, ["69", "71"], within=[(46.30, 4.52), (46.30, 4.80), (46.05, 4.78), (45.85, 4.72),
        (45.80, 4.50), (46.00, 4.42)], color="violet", label=(46.0, 4.25), grapes="Gamay"),
    A("moulin-a-vent", "Moulin-à-Vent", 2, ["69", "71"], ["Romanèche-Thorins", "Chénas"], parent="beaujolais"),
    A("fleurie", "Fleurie", 2, ["69"], ["Fleurie"], parent="beaujolais"),
    A("morgon", "Morgon", 2, ["69"], ["Villié-Morgon"], parent="beaujolais"),
    A("brouilly", "Brouilly", 2, ["69"], ["Odenas", "Saint-Lager", "Cercié", "Charentay"], parent="beaujolais"),
    A("julienas", "Juliénas", 2, ["69"], ["Juliénas", "Jullié"], parent="beaujolais"),
    A("saint-amour", "Saint-Amour", 2, ["71"], ["Saint-Amour-Bellevue"], parent="beaujolais"),
    A("chiroubles", "Chiroubles", 2, ["69"], ["Chiroubles"], parent="beaujolais"),
    A("regnie", "Régnié", 2, ["69"], ["Régnié-Durette"], parent="beaujolais"),
]
_cn = [a for a in BURGUNDY if a["id"] == "cote-de-nuits"][0]["communes"] + [a for a in BURGUNDY if a["id"] == "cote-de-beaune"][0]["communes"]
[a for a in BURGUNDY if a["id"] == "cote-d-or"][0]["communes"] = _cn
VILLAGES_BURGUNDY = ["Gevrey-Chambertin", "Morey-Saint-Denis", "Chambolle-Musigny", "Vougeot", "Vosne-Romanée",
                     "Nuits-Saint-Georges", "Aloxe-Corton", "Beaune", "Pommard", "Volnay", "Meursault", "Puligny-Montrachet",
                     "Chassagne-Montrachet", "Santenay", "Mercurey", "Givry", "Rully", "Chablis", "Fuissé"]

# ------------------------------------------------------------------ Rhône
RHONE = [
    A("cote-rotie", "Côte-Rôtie", 2, ["69"], ["Ampuis", "Tupin-et-Semons", "Saint-Cyr-sur-le-Rhône"], parent="northern-rhone"),
    A("condrieu", "Condrieu", 2, ["69", "42", "07"], ["Condrieu", "Vérin", "Saint-Michel-sur-Rhône", "Limony"], parent="northern-rhone"),
    A("saint-joseph", "Saint-Joseph", 2, ["07", "42"], ["Chavanay", "Malleval", "Saint-Pierre-de-Boeuf", "Sarras", "Ozon",
        "Arras-sur-Rhône", "Vion", "Lemps", "Saint-Jean-de-Muzols", "Tournon-sur-Rhône", "Mauves", "Glun", "Châteaubourg",
        "Saint-Désirat", "Champagne", "Andance"], parent="northern-rhone"),
    A("hermitage", "Hermitage", 2, ["26"], ["Tain-l'Hermitage"], parent="northern-rhone"),
    A("crozes-hermitage", "Crozes-Hermitage", 2, ["26"], ["Crozes-Hermitage", "Gervans", "Érôme", "Serves-sur-Rhône",
        "Larnage", "Mercurol-Veaunes", "Chanos-Curson", "Beaumont-Monteux", "Pont-de-l'Isère", "La Roche-de-Glun"],
        parent="northern-rhone"),
    A("cornas", "Cornas", 2, ["07"], ["Cornas", "Saint-Péray"], parent="northern-rhone"),
    A("northern-rhone", "Northern Rhône", 1, ["69", "42", "07", "26"], [], color="claret", label=(45.25, 5.25), grapes="Syrah · Viognier"),
    A("chateauneuf-du-pape", "Châteauneuf-du-Pape", 2, ["84"], ["Châteauneuf-du-Pape", "Courthézon", "Bédarrides"], parent="southern-rhone"),
    A("gigondas", "Gigondas", 2, ["84"], ["Gigondas"], parent="southern-rhone"),
    A("vacqueyras", "Vacqueyras", 2, ["84"], ["Vacqueyras", "Sarrians"], parent="southern-rhone"),
    A("tavel", "Tavel & Lirac", 2, ["30"], ["Tavel", "Lirac", "Roquemaure", "Saint-Laurent-des-Arbres", "Saint-Geniès-de-Comolas"],
        parent="southern-rhone"),
    A("rasteau", "Rasteau & Cairanne", 2, ["84"], ["Rasteau", "Cairanne"], parent="southern-rhone"),
    A("beaumes", "Beaumes-de-Venise", 2, ["84"], ["Beaumes-de-Venise", "Lafare", "La Roque-Alric", "Suzette"], parent="southern-rhone"),
    A("southern-rhone", "Southern Rhône", 1, ["84", "30", "26", "07"], within=[(44.45, 4.62), (44.42, 5.15), (44.05, 5.15),
        (43.90, 4.95), (43.90, 4.55), (44.15, 4.50)], color="magenta", label=(44.05, 5.45), grapes="Grenache · Syrah · Mourvèdre"),
]

# ------------------------------------------------------------------ Loire
LOIRE = [
    A("muscadet", "Muscadet", 1, ["44", "49"], within=[(47.27, -1.62), (47.30, -1.12), (47.10, -1.02), (46.97, -1.25),
        (46.98, -1.60)], color="teal", label=(46.85, -1.6), grapes="Melon de Bourgogne"),
    A("savennieres", "Savennières", 2, ["49"], ["Savennières", "Bouchemaine"], parent="anjou"),
    A("anjou", "Anjou", 1, ["49"], within=[(47.45, -0.95), (47.48, -0.40), (47.25, -0.30), (47.05, -0.45), (47.08, -0.90)],
        color="rose", label=(47.0, -0.9), grapes="Chenin Blanc · Cabernet Franc"),
    A("saumur", "Saumur", 1, ["49"], within=[(47.32, -0.28), (47.30, 0.12), (47.10, 0.10), (47.08, -0.25)],
        color="coral", grapes="Cabernet Franc · Chenin Blanc"),
    A("chinon", "Chinon", 2, ["37"], ["Chinon", "Beaumont-en-Véron", "Cravant-les-Côteaux", "Ligré", "Huismes",
        "Savigny-en-Véron", "Rivière", "Anché", "Sazilly", "Panzoult", "Avoine"], parent="touraine"),
    A("bourgueil", "Bourgueil", 2, ["37"], ["Bourgueil", "Benais", "Restigné", "Ingrandes-de-Touraine",
        "Saint-Nicolas-de-Bourgueil", "La Chapelle-sur-Loire", "Saint-Patrice"], parent="touraine"),
    A("vouvray", "Vouvray", 2, ["37"], ["Vouvray", "Rochecorbon", "Vernou-sur-Brenne", "Noizay", "Chançay", "Reugny",
        "Parçay-Meslay"], parent="touraine"),
    A("montlouis", "Montlouis", 2, ["37"], ["Montlouis-sur-Loire", "Lussault-sur-Loire", "Saint-Martin-le-Beau"], parent="touraine"),
    A("touraine", "Touraine", 1, ["37", "41"], within=[(47.50, 0.05), (47.62, 1.45), (47.25, 1.55), (47.15, 0.95),
        (47.08, 0.15)], color="olive", label=(47.75, 0.9), grapes="Sauvignon Blanc · Chenin · Cabernet Franc"),
    A("sancerre", "Sancerre", 1, ["18"], ["Sancerre", "Bué", "Crézancy-en-Sancerre", "Ménétréol-sous-Sancerre", "Saint-Satur",
        "Sury-en-Vaux", "Verdigny", "Sainte-Gemme-en-Sancerrois", "Thauvenay", "Vinon", "Veaugues", "Montigny", "Bannay",
        "Menetou-Râtel", "Saint-Bouize"], color="green", label=(47.45, 2.45), grapes="Sauvignon Blanc"),
    A("pouilly-fume", "Pouilly-Fumé", 1, ["58"], ["Pouilly-sur-Loire", "Saint-Andelain", "Tracy-sur-Loire", "Garchy",
        "Saint-Laurent-l'Abbaye", "Saint-Martin-sur-Nohain", "Mesves-sur-Loire"], color="teal", grapes="Sauvignon Blanc"),
]

# ------------------------------------------------------------------ Champagne
CHAMPAGNE = [
    A("montagne-de-reims", "Montagne de Reims", 1, ["51"], within=[(49.25, 3.85), (49.24, 4.20), (49.10, 4.28), (49.06, 4.12),
        (49.08, 3.90), (49.16, 3.82)], color="claret", grapes="Pinot Noir"),
    A("vallee-de-la-marne", "Vallée de la Marne", 1, ["51", "02"], within=[(49.15, 3.25), (49.12, 3.92), (49.06, 4.10),
        (48.98, 4.00), (49.00, 3.30)], color="rose", grapes="Meunier"),
    A("cote-des-blancs", "Côte des Blancs", 1, ["51"], within=[(49.03, 3.92), (49.02, 4.08), (48.86, 4.10), (48.86, 3.93)],
        color="gold", grapes="Chardonnay"),
    A("cote-de-sezanne", "Côte de Sézanne", 1, ["51"], within=[(48.80, 3.62), (48.80, 3.86), (48.62, 3.86), (48.62, 3.62)],
        color="ochre", grapes="Chardonnay"),
    A("cote-des-bar", "Côte des Bar", 1, ["10"], within=[(48.25, 4.20), (48.27, 4.85), (47.95, 4.85), (47.92, 4.25)],
        color="violet", grapes="Pinot Noir"),
]

# ------------------------------------------------------------------ Rest of France (country map regions)
OTHER = [
    A("alsace", "Alsace", 0, ["67", "68"], within=[(48.80, 7.40), (48.80, 7.55), (48.45, 7.52), (48.20, 7.42), (47.95, 7.36),
        (47.68, 7.38), (47.68, 7.18), (47.95, 7.18), (48.20, 7.22), (48.45, 7.33)], color="green", label=(48.3, 8.1),
        grapes="Riesling · Gewurztraminer · Pinot Gris"),
    A("jura", "Jura", 0, ["39"], within=[(47.05, 5.52), (47.05, 5.78), (46.45, 5.58), (46.45, 5.35)], color="ochre",
        label=(46.75, 6.15), grapes="Savagnin · Chardonnay"),
    A("savoie", "Savoie", 0, ["73"], within=[(45.78, 5.75), (45.75, 6.30), (45.45, 6.30), (45.48, 5.80)], color="teal",
        label=(45.6, 6.7)),
    A("provence", "Provence", 0, ["13", "83"], within=[(43.75, 5.35), (43.72, 6.65), (43.12, 6.65), (43.18, 5.40)],
        color="rose", label=(43.05, 6.9), grapes="Grenache · Cinsault · Mourvèdre"),
    A("languedoc", "Languedoc-Roussillon", 0, ["30", "34", "11", "66"], within=[(44.0, 4.40), (43.95, 3.30), (43.55, 2.40),
        (43.25, 2.25), (42.55, 2.55), (42.45, 3.10), (43.05, 3.10), (43.42, 3.70), (43.62, 4.25)], color="orange",
        label=(42.9, 4.1), grapes="Grenache · Syrah · Carignan"),
    A("southwest", "South West", 0, ["24", "46", "47", "81", "32", "64", "65", "82"], within=None, color="coral",
        label=(44.05, -0.9), grapes="Malbec · Tannat · Merlot"),
]
SOUTHWEST_PATCHES = [
    [(44.95, 0.20), (44.95, 0.75), (44.75, 0.75), (44.75, 0.20)],      # Bergerac
    [(44.58, 1.00), (44.58, 1.52), (44.40, 1.52), (44.40, 1.00)],      # Cahors
    [(44.02, 1.70), (44.02, 2.05), (43.80, 2.05), (43.80, 1.70)],      # Gaillac
    [(43.68, -0.20), (43.68, 0.15), (43.45, 0.15), (43.45, -0.20)],    # Madiran
    [(43.35, -0.55), (43.35, -0.28), (43.15, -0.28), (43.15, -0.55)],  # Jurançon
    [(44.65, 0.05), (44.65, 0.45), (44.25, 0.45), (44.25, 0.05)],      # Duras / Buzet
]
