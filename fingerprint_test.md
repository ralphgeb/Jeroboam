# Label fingerprint test

184,530 shop photos fingerprinted from 69 shops; Vision revisions {2: 184530}; 768 numbers per print.

## Test 1: shop photo vs other shops' photos

20,000 photos of wines sold by 2+ shops, each looked up among 184,530 prints of the other shops.

Right = the nearest print is the same wine (judged on its words, see FILLER/CONFLICT; the strict figure in brackets
needs the exact same producer + name key). Look-alike = same producer, another wine.

| print | right (strict) | right in top 5 | same picture file | wrong: look-alike (same producer) | wrong: other |
|---|---|---|---|---|---|
| whole photo | 6,676 (33%) (16%) | 10,285 (51%) | 30 (0%) | 5,338 (27%) | 7,986 (40%) |
| label crop | 7,187 (36%) (17%) | 10,604 (53%) | 26 (0%) | 5,691 (28%) | 7,122 (36%) |
| both | 7,765 (39%) (19%) | 11,373 (57%) | 23 (0%) | 5,902 (30%) | 6,333 (32%) |

Without identical picture files (what a phone photo would face), and how sure a match can be by distance:

| print | right | accept if nearest closer than | accepted | of those right |
|---|---|---|---|---|
| whole photo | 33% | 0.245 | 2% | 62% |
| whole photo | 33% | 0.287 | 5% | 61% |
| whole photo | 33% | 0.318 | 10% | 58% |
| whole photo | 33% | 0.360 | 25% | 50% |
| whole photo | 33% | 0.413 | 50% | 45% |
| label crop | 36% | 0.352 | 2% | 62% |
| label crop | 36% | 0.406 | 5% | 59% |
| label crop | 36% | 0.448 | 10% | 55% |
| label crop | 36% | 0.513 | 25% | 46% |
| label crop | 36% | 0.585 | 50% | 39% |
| both | 39% | 0.360 | 2% | 68% |
| both | 39% | 0.400 | 5% | 61% |
| both | 39% | 0.434 | 10% | 60% |
| both | 39% | 0.488 | 25% | 52% |
| both | 39% | 0.553 | 50% | 48% |

When both the same wine and a look-alike are in the top 5 (7,076 photos): the same wine is closer in 58%; median margin 0.012.

Some wrong answers (both prints):

- Peay Vineyards West Sonoma Coast Chardonnay (allywines.com) -> Peay Vineyards, Chardonnay 'Maritima - Estate' (www.winechateau.com), distance 0.534
- Clos Saron Carte Blanche (allywines.com) -> Clos Saron Pinot Noir Old Block Home Vineyard (winetherapynyc.com), distance 0.856
- Haarmeyer Nebbiolo (allywines.com) -> By Farr Shiraz Geelong (sf.vervewine.com), distance 0.996
- Domaine Jean Fournier, Marsannay Rouge 'Cuvée Saint Urbain' (bgwm.co.uk) -> Domaine Bruno Clair Marsannay Rouge Les Grasses Tetes (www.winechateau.com), distance 0.629
- Domaine de Montille, Bourgogne Blanc (bgwm.co.uk) -> Domaine de Montille Le Clos du Château Magnum (www.thecorkscrew.ie), distance 0.526
- Domaine de Montille, Clos de Vougeot Grand Cru (bgwm.co.uk) -> Domaine de Montille, Corton Clos du Roi Grand Cru (wineonline.ie), distance 0.630
- Domaine de Montille, Nuits-Saint-Georges 1er Cru `Aux Thorey` (bgwm.co.uk) -> Domaine de Montille, Corton Clos du Roi Grand Cru (wineonline.ie), distance 0.580
- Domaine Corsin, Saint-Véran `Tirage Précoce` (bgwm.co.uk) -> Domaine Corsin, Pouilly Fuisse Aux Chailloux (www.thegoodwineshop.co.uk), distance 0.692
- Domaine Chantal Lescure Vosne-Romanée 1er Cru Les Suchots (bgwm.co.uk) -> Chantal Lescure Nuits-St-Georges 1er Cru Les Damodes (vinosite.com), distance 0.518
- Champagne Devaux - Coeur Des Bar - Blanc De Noirs (bgwm.co.uk) -> Devaux Blanc De Noir (www.winechateau.com), distance 0.400
- David Moret, Meursault `Sous La Velle` (bgwm.co.uk) -> David Moret Meursault `Narvaux` Côte de Beaune, Burgundy (wineonline.ie), distance 0.468
- Dandelion Vineyards Lionheart Of The Barossa Shiraz (bgwm.co.uk) -> Dandelion Vineyards Pride of the Fleurieu Cabernet Sauvignon (wineonline.ie), distance 0.440
- Curatolo Arini, Marsala Superiore Riserva (bgwm.co.uk) -> Marco de Bartoli Marsala Superiore Riserva (www.biondivino.com), distance 0.741
- Clos Venturi, `1769` Blanc (bgwm.co.uk) -> Clos Venturi, 1769 Rose (wine.sothebys.com), distance 0.453
- Chatto, `Lutruwita` Tasmania Pinot Noir (bgwm.co.uk) -> Chatto Franklinii Pinot Noir (camperdowncellars.com.au), distance 0.399
- Château Fontarèche, Tradition Blanc IGP Pays d'Oc (bgwm.co.uk) -> Di Meno, Catarrato (www.thegoodwineshop.co.uk), distance 0.817
- Château Fleur de Lisse, Saint-Émilion Grand Cru (bgwm.co.uk) -> Chateau Fleur De Lisse, St Emilion (www.thegoodwineshop.co.uk), distance 0.559
- Château Delmond, Sauternes (bgwm.co.uk) -> Château Romer Sauternes (www.winechateau.com), distance 0.811
- Chateau De Pitray Les Prairies Castillon Cotes De Bordeaux (bgwm.co.uk) -> Madame Chateau de Pitray (hedonism.co.uk), distance 0.815
- Chateau Beaulieu Coteaux d'Aix-En-Provence Rose (bgwm.co.uk) -> Château Beaulieu, `Cuvée Alexandre` Rosé (wineonline.ie), distance 0.468
- Valpolicella Ripasso Superiore Torre del Falasco (bgwm.co.uk) -> Falasco Amarone Della Valpolicella (zyn.ca), distance 0.640
- Ata Rangi, `Potiki` Martinborough Chardonnay (bgwm.co.uk) -> Ata Rangi, Martinborough Pinot Noir (wineonline.ie), distance 0.638
- Ata Rangi, `Masters Vineyard` Pinot Noir (bgwm.co.uk) -> Ata Rangi, Martinborough Pinot Noir (wineonline.ie), distance 0.496
- Domaine Alain Chavy, Puligny-Montrachet ‘Les Charmes’ (bgwm.co.uk) -> Domaine Alain Chavy, Puligny-Montrachet 1er Cru `Les Clavoillons` (wineonline.ie), distance 0.260
- Badenhorst Family Wines Chenin Blanc Secateurs (bgwm.co.uk) -> A.A. Badenhorst Secateurs Chenin Blanc Swartland, South Africa (www.winechateau.com), distance 0.358

## Test 2: phone scans vs shop photos

28 phone prints in the worker, 28 of the same revision (2).

### nearest shop photos (whole photo)

| scan was | 1st | 2nd | 3rd |
|---|---|---|---|
| michele chiarlo|palas| | Lodovico Barolo (0.705) | Borgogno, Giacomo Barolo Liste (0.723) | Barros 20 Year Old Tawny Port, Douro (0.723) |
| maison louis latour|volnay|2020 | Tenute Orestiadi - Molino a Vento Syrah (0.641) | Anders Frederik Steen Flickering Through My Naked Thoughts (0.646) | Paolo Conterno Langhe Nebbiolo A Mont (0.654) |
| terre di faiano|primitivo puglia organic| | Terrazas de los Andes Malbec Reserva (0.554) | Waterstone Cabernet Sauvignon Reserve (0.558) | Jackson Triggs Merlot Proprietor's Selection (0.565) |
| chateau rayas|cotes du rhone la pialade|2015 | Cailhol Gautran Villa Lucia Minervois Blanc, Languedoc, France (0.613) | Chateau Rayas, Cotes du Rhone, La Pialade (0.628) | Domaine Zind-Humbrecht Riesling Clos Windsbuhl, Alsace, France (0.635) |
| trivento|golden reserve|2023 | Milénico. Tinto Fino' , Ribera del Duero, Spain (0.757) | Chateau Belgrave, Haut-Medoc, France (0.758) | Societa Agricola Ampeleia Toscana Rosso 'Un Litro' (0.760) |
| trivento|reserve malbec|2026 | Nervi-Conterno, Gattinara 'Valferana' (0.798) | Milénico. Tinto Fino' , Ribera del Duero, Spain (0.804) | Societa Agricola Ampeleia Toscana Rosso 'Un Litro' (0.814) |
| el cuyo|mendoza malbec|2023 | Tiberio Six Pack (2 each Trebbiano, Pecorino, Cerasuolo) (0.713) | Sugrue, Cuvée Dr Brendon O'Regan, South Downs, England (0.727) | Trivento Reserve Malbec (Argentina) (0.734) |
| campo viejo|reserva rioja|2019 | Campo Viejo Rioja Tempranillo (Spain) (0.733) | Campo Viejo Rioja Tempranillo (Spain) (0.733) | Marca San Michele Capovolto Verdicchio dei Castelli di Jesi Classico Superiore (0.747) |
| felix solis|mucho mas|unknown | Azienda Agricola Le Coste Rosso, Lazio, Italy (0.813) | Le Sot de l'Ange Touraine Azay-le-Rideau 'La Goujonniere' Chenin Blanc, Loire, France (0.833) | Milan Nestarec 'I am not a big wine' Moravia, Czech Republic (0.837) |
| citra|montepulciano dabruzzo|2023 | Produttori Del Barbaresco Motefico Barbaresco Riserva (0.746) | Domaine Huet, Vouvray Sec 'Le Mont', Loire, France (0.754) | Domaine Ramonet Les Chaumees, Chassagne-Montrachet Premier Cru, France (0.754) |
| vista castelli|montepulciano dabruzzo|nonvintage | Giacomo Conterno, Barolo 'Arione' (0.781) | Montecillo - Rioja - Gran Reserva (0.783) | Conterno, Giacomo Barbera d'Alba Vigna Francia (0.784) |
| stellenrust|stellenbosch pinotage|1928 | Not Yet Named Wine Co, Edition #4 Barbera, South Africa (0.767) | Felix Auxerre Pinot Noir (0.776) | Oliver Zeter, Sweetheart , Late Harvest Sauvignon Blanc, Pfalz, Germany (0.776) |
| gordon ramsay|intenso rosso|nonvintage | Nuria Renom 'Donna' Pet-Nat (0.826) | Guimaro Ribera Sacra Blanco (0.833) | Guimaro, A Ponte Ribeira Sacra Spain (0.834) |
| penfolds|koonunga hill shiraz|2024 | Chateau Roc de Segur, Bordeaux, France (Magnum) (0.731) | Graziano Sassoscuro Rosso (0.733) | Sella&Mosca, Cannonau Medeus, Sardinia, Italy (0.738) |
| chateau de la gardine|la pialade|2015 | Cailhol Gautran Villa Lucia Minervois Blanc, Languedoc, France (0.613) | Chateau Rayas, Cotes du Rhone, La Pialade (0.628) | Domaine Zind-Humbrecht Riesling Clos Windsbuhl, Alsace, France (0.635) |
| chateau des tours|grande reserve|2015 | Patz & Hall Pinot Noir Moses-Hall Carneros Napa Valley (0.688) | Chateau des Tours Cotes du Rhone Reserve (0.694) | Domaine aux Moines Savennieres Roche Aux Moines (0.694) |
| chateau batailley|chateau batailley grand cru|2021 | Celler Vendrell I Rived, ' Alleu Old vines. Garnatxa & Carinyena, Montsant, Spain (0.732) | Jean Baptiste Ponsot, Rully 'Bas de Vauvry' (0.746) | Chateau Latour Le Pauillac de Latour Pauillac, France (0.749) |
| chateau nateau|premier grand cru classe|2018 | Lafouge, Jean et Gilles Meursault Les Meix Chavaux (0.735) | Champalou Chaidu Grand Vaudasniere Demi Sec Vouvray (Loire Valley, France) (0.747) | Domaine de Chevalier Blanc, Pessac-Leognan, France (0.754) |
| suertes del marques|las suertes| | L.a. cetto - Petite syrah (0.675) | Château les Amoureuses - Les Amoureuses (0.707) | La Ronceraie - La Ronceraie (0.713) |
| armit wines|tenuta san guido sassicaia bolgheri sassicaia|2023 | Sassicaia (0.723) | Bolgheri Sassicaia DOC "Sassicaia" - Tenuta San Guido (0.745) | Sassicaia (0.778) |
| celler del roure|maduresa|nonvintage or recent vintage check bottle | Celler del Roure Valencia Maduresa (0.496) | Theopetra Estate, Meteora, Malagouzia Assyrtiko (0.526) | Valdicava Brunello di Montalcino Riserva 'Madonna del Piano' (0.569) |
| chateau hautbergey|chateau hautbergey|2016 | Chateau St Jean Cabernet Sauvignon (0.475) | Tolaini Chianti Classico Gran Selezione 'Montebello Sette' (0.485) | Fattoria del Cerro Manero Rosso (0.487) |
| terre di faiano|terre di faiano primitivo organic wine|unknown | Terrazas de los Andes Malbec Reserva (0.554) | Waterstone Cabernet Sauvignon Reserve (0.558) | Jackson Triggs Merlot Proprietor's Selection (0.565) |
| guigal|cote rotie chateau dampuis|2016 | Guigal Côtes du Rhône Blanc (France) (0.503) | E. Guigal - E. Guigal - Saint Joseph (0.505) | Château Giscours (0.507) |
| chateau angelus|premier grand cru classe b saintemilion grand cru|2010 | Jean Baptiste Ponsot, Rully 'Bas de Vauvry' (0.737) | Vergelegen Reserve Cab Sauv , Stellenbosch, South Africa (0.757) | Springboard Penya Rouge (0.763) |
| peter michael winery|lapresmidi|2025 | Weingut Christ, Blauer Zweigelt Bisamberg , Vienna, Austria (0.623) | Poderi Salicutti Sorgente Brunello di Montalcino (0.626) | Vergelegen Reserve Cab Sauv , Stellenbosch, South Africa (0.640) |
| armit wines|tenuta san guido sassicaia bolgheri sassicaia|2023 | Sassicaia (0.723) | Bolgheri Sassicaia DOC "Sassicaia" - Tenuta San Guido (0.745) | Sassicaia (0.778) |
| concha y toro|casillero del diablo malbec| | Casillero Del Diablo Merlot (0.667) | Concha Y Toro Casillero del Diablo Merlot (Chile) (0.673) | Casillero Del Diablo Cabernet Sauvignon (0.673) |

### nearest shop photos (label crop)

| scan was | 1st | 2nd | 3rd |
|---|---|---|---|
| michele chiarlo|palas| | Ascheri, Giacomo (Fu Matteo) Barolo (0.714) | Saffirio Fratelli, Enrico e Giacomo (Monforte) Barolo (0.715) | Cappellano Barolo Pie Rupestris (0.733) |
| maison louis latour|volnay|2020 | Emmanuel Brochet, Champagne Les Hautes Vignes 'Le Mont Benoit' (0.758) | Domaine Gross, Gold R (0.771) | Domaine de la Grand'Cour, Fleurie 'Lieu-Dit Chapelle des Bois' (0.778) |
| terre di faiano|primitivo puglia organic| | Sepp & Maria Muster - Welschriesling vom Opok (0.640) | Sepp & Maria Muster - Sauvignon Blanc Vom Opok (0.650) | Château Bel Air Marquis d'Aligre (0.653) |
| chateau rayas|cotes du rhone la pialade|2015 | Domaine Zind-Humbrecht Riesling Clos Windsbuhl, Alsace, France (0.635) | Domaine Taupenot-Merme Clos des Lambrays Grand Cru, Cote de Nuits, France (0.638) | de Fermo 'Don Carlino' Abruzzo Pecorino, Italy (0.639) |
| trivento|golden reserve|2023 | Grandbois Wines - 'La Resistance' Riesling made) (0.758) | Chateau Belgrave, Haut-Medoc, France (0.758) | Societa Agricola Ampeleia Toscana Rosso 'Un Litro' (0.762) |
| trivento|reserve malbec|2026 | Domaine Huet, Vouvray Sec 'Le Mont', Loire, France (0.810) | Pepe, Emidio Montepulciano d'Abruzzo - 5cm (0.810) | Giacomo Conterno 'Cerretta', Barolo DOCG, Italy (0.817) |
| el cuyo|mendoza malbec|2023 | Sugrue, Cuvée Dr Brendon O'Regan, South Downs, England (0.727) | Rinaldi, Francesco Barolo La Brunata (0.729) | The Platinum Rioja Treble (0.744) |
| campo viejo|reserva rioja|2019 | Ferrando, Luigi Carema Etichetta Nera (Black Label) (0.739) | Ascheri, Giacomo (Fu Matteo) Barolo (0.742) | Campo Viejo Rioja Viura-Tempranillo Blanco White Wine (0.745) |
| felix solis|mucho mas|unknown | Felix Solis Mucho Mas Red Wine Gift Boxed (0.760) | Azienda Agricola Le Coste Rosso, Lazio, Italy (0.813) | Tunia Cantomoro Toscana IGT, Tuscany, Italy (0.838) |
| citra|montepulciano dabruzzo|2023 | Pepe, Emidio Montepulciano d'Abruzzo - 5cm (0.650) | Pepe, Emidio Montepulciano d'Abruzzo (0.737) | Produttori del Barbaresco Barbaresco Riserva Montefico (0.739) |
| vista castelli|montepulciano dabruzzo|nonvintage | Pepe, Emidio Montepulciano d'Abruzzo - 5cm (0.695) | Il Poggione, Brunello di Montalcino Riserva (0.758) | Produttori del Barbaresco Barbaresco Riserva Montefico (0.759) |
| stellenrust|stellenbosch pinotage|1928 | Patrick Corbineau, VdF Rouge "Conquete" (0.764) | Kamara Pure - Nimbus Albus MAGNUM (0.770) | Sorrel Hermitage Le Greal (0.773) |
| gordon ramsay|intenso rosso|nonvintage | Rinaldi, Francesco Barolo Cannubi (0.828) | Foradori Fontanasanta Nosiola (0.830) | Ramiro Ibanez UBE Paganilla (0.832) |
| penfolds|koonunga hill shiraz|2024 | Graziano Sassoscuro Rosso (0.727) | Chateau Roc de Segur, Bordeaux, France (Magnum) (0.731) | Sella&Mosca, Cannonau Medeus, Sardinia, Italy (0.738) |
| chateau de la gardine|la pialade|2015 | Domaine Zind-Humbrecht Riesling Clos Windsbuhl, Alsace, France (0.635) | Domaine Taupenot-Merme Clos des Lambrays Grand Cru, Cote de Nuits, France (0.638) | de Fermo 'Don Carlino' Abruzzo Pecorino, Italy (0.639) |
| chateau des tours|grande reserve|2015 | Domaine aux Moines Savennieres Roche Aux Moines (0.694) | Isole e Olena Cepparello Toscana IGT, Tuscany, Italy (0.699) | Domaine Pignier Cotes du Jura Savagnin, France (0.700) |
| chateau batailley|chateau batailley grand cru|2021 | Chateau Latour Le Pauillac de Latour Pauillac, France (0.751) | Naudé Wines Old Vines, Langpad, Colombard, Western Cape, South Africa (0.757) | Chateau Ducru-Beaucaillou Saint Julien (0.761) |
| chateau nateau|premier grand cru classe|2018 | Jobard, Remi Meursault Sous la Velle (0.726) | Château Margaux, Premier Cru Classé (0.728) | Chandon de Briailles Pernand Vergelesses 1er Cru Ile de Vergelesses (0.728) |
| suertes del marques|las suertes| | Robert Mondavi The Estates Chardonnay (0.858) | Moncuit, Robert Reserve Perpetuelle Blanc de Blancs (0.873) | Domaine Mark Angeli Ferme de la Sansonniere La Lune Magnum Loire, Vin de France (0.877) |
| armit wines|tenuta san guido sassicaia bolgheri sassicaia|2023 | Sassicaia Tenuta San Guido Gift Boxed (0.714) | Tenuta San Guido, Sassicaia, Tuscany, Italy (0.744) | Roagna Barbaresco (0.788) |
| celler del roure|maduresa|nonvintage or recent vintage check bottle | Domaine Gross, Toccata (0.650) | Aci Urbajs Organical Anarchy Radical (0.652) | Aci Urbajs Organical Anarchy Sivi (0.653) |
| chateau hautbergey|chateau hautbergey|2016 | Pierre Vessigaud Macon Fuisse, Burgundy, France (0.687) | Egon Muller 'Scharzhof' Riesling QbA magnum, Mosel, Germany (0.711) | Radikon, 'Pop' Vino Rosso (0.723) |
| terre di faiano|terre di faiano primitivo organic wine|unknown | Sepp & Maria Muster - Welschriesling vom Opok (0.640) | Sepp & Maria Muster - Sauvignon Blanc Vom Opok (0.650) | Château Bel Air Marquis d'Aligre (0.653) |
| guigal|cote rotie chateau dampuis|2016 | Domaine Robert Chevillon Les Cailles, Nuits-Saint-Georges Premier Cru, France (0.603) | Henri & Philippe Jouan Morey-Saint-Denis Vieilles Vignes, Cote de Nuits, France (0.607) | Domaine Robert Chevillon Nuits-Saint-Georges Vieilles Vignes, Cote de Nuits, France (0.608) |
| chateau angelus|premier grand cru classe b saintemilion grand cru|2010 | Domaine Julien Cruchandeau Bourgogne Hautes Cotes de Nuits Les Valencons, Burgundy, France (0.763) | Bera Vino Bianco Arcese (0.764) | Fabien Jouves Mas del Perie 'Les Agudes' Vin de France (0.774) |
| peter michael winery|lapresmidi|2025 | Chateau Roc de Segur, Bordeaux, France (Magnum) (0.643) | Pinot Gris 'Sunshine' Tilia Estate, Slovenia (0.643) | Nomadic Greco Mirone Archi Bianco (0.645) |
| armit wines|tenuta san guido sassicaia bolgheri sassicaia|2023 | Sassicaia Tenuta San Guido Gift Boxed (0.714) | Tenuta San Guido, Sassicaia, Tuscany, Italy (0.744) | Roagna Barbaresco (0.788) |
| concha y toro|casillero del diablo malbec| | Claude Riffault, Sancerre 'Les Desmalets' (0.816) | Ar.Pe.Pe. Rosso di Valtellina (0.817) | Claude Riffault, Sancerre 'Les Boucauds' (0.825) |
