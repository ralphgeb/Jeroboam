# Label fingerprint test

182,312 shop photos fingerprinted from 68 shops; Vision revisions {2: 182312}; 768 numbers per print.

## Test 1: shop photo vs other shops' photos

20,000 photos of wines sold by 2+ shops, each looked up among 182,312 prints of the other shops.

Right = the nearest print is the same wine (judged on its words, see FILLER/CONFLICT; the strict figure in brackets
needs the exact same producer + name key). Look-alike = same producer, another wine.

| print | right (strict) | right in top 5 | same picture file | wrong: look-alike (same producer) | wrong: other |
|---|---|---|---|---|---|
| whole photo | 6,782 (34%) (17%) | 10,430 (52%) | 29 (0%) | 5,351 (27%) | 7,867 (39%) |
| label crop | 7,244 (36%) (18%) | 10,644 (53%) | 28 (0%) | 5,698 (28%) | 7,058 (35%) |
| both | 7,864 (39%) (19%) | 11,476 (57%) | 23 (0%) | 5,854 (29%) | 6,282 (31%) |

Without identical picture files (what a phone photo would face), and how sure a match can be by distance:

| print | right | accept if nearest closer than | accepted | of those right |
|---|---|---|---|---|
| whole photo | 34% | 0.242 | 2% | 68% |
| whole photo | 34% | 0.288 | 5% | 65% |
| whole photo | 34% | 0.318 | 10% | 60% |
| whole photo | 34% | 0.360 | 25% | 52% |
| whole photo | 34% | 0.411 | 50% | 45% |
| label crop | 36% | 0.353 | 2% | 66% |
| label crop | 36% | 0.404 | 5% | 60% |
| label crop | 36% | 0.446 | 10% | 54% |
| label crop | 36% | 0.512 | 25% | 46% |
| label crop | 36% | 0.585 | 48% | 41% |
| both | 39% | 0.361 | 2% | 69% |
| both | 39% | 0.401 | 5% | 62% |
| both | 39% | 0.433 | 10% | 60% |
| both | 39% | 0.486 | 25% | 51% |
| both | 39% | 0.551 | 50% | 47% |

When both the same wine and a look-alike are in the top 5 (7,126 photos): the same wine is closer in 59%; median margin 0.012.

Some wrong answers (both prints):

- Peay Vineyards West Sonoma Coast Chardonnay (allywines.com) -> Peay Vineyards, Chardonnay 'Maritima - Estate' (www.winechateau.com), distance 0.534
- Clos Saron Carte Blanche (allywines.com) -> Clos Saron Pinot Noir Old Block Home Vineyard (winetherapynyc.com), distance 0.856
- Haarmeyer Nebbiolo (allywines.com) -> By Farr Shiraz Geelong (sf.vervewine.com), distance 0.996
- Domaine Jean Fournier, Marsannay Rouge 'Cuvée Saint Urbain' (bgwm.co.uk) -> Domaine Bruno Clair Marsannay Rouge Les Grasses Tetes (www.winechateau.com), distance 0.629
- Domaine de Montille, Bourgogne Blanc (bgwm.co.uk) -> Domaine de Montille Le Clos du Château Magnum (www.thecorkscrew.ie), distance 0.526
- Domaine Corinne Perchaud, `Eve Grossot` Chablis (bgwm.co.uk) -> Maison Louis Latour Louis Latour - Montagny - Les Buys (www.winechateau.com), distance 0.780
- Champagne Devaux - Coeur Des Bar - Blanc De Noirs (bgwm.co.uk) -> Devaux Blanc De Noir (www.winechateau.com), distance 0.400
- David Moret, Meursault `Sous La Velle` (bgwm.co.uk) -> David Moret Meursault `Narvaux` Côte de Beaune, Burgundy (wineonline.ie), distance 0.468
- Dandelion Vineyards Lionheart Of The Barossa Shiraz (bgwm.co.uk) -> Dandelion Vineyards Pride of the Fleurieu Cabernet Sauvignon (wineonline.ie), distance 0.440
- Clos Venturi, `1769` Blanc (bgwm.co.uk) -> Clos Venturi, 1769 Rose (wine.sothebys.com), distance 0.453
- Chatto, `Lutruwita` Tasmania Pinot Noir (bgwm.co.uk) -> Chatto Franklinii Pinot Noir (camperdowncellars.com.au), distance 0.399
- Château Laville, Sauternes (bgwm.co.uk) -> Chateau Laville Bordeaux Sauternes 13% ABV Semillon Sauvignon Blanc (www.twelvegreenbottleswine.co.uk), distance 0.507
- Château Fontarèche, Tradition Blanc IGP Pays d'Oc (bgwm.co.uk) -> Di Meno, Catarrato (www.thegoodwineshop.co.uk), distance 0.817
- Chateau De Pitray Les Prairies Castillon Cotes De Bordeaux (bgwm.co.uk) -> Madame Chateau de Pitray (hedonism.co.uk), distance 0.815
- Casa Ferreirinha, `Vinha Grande` Douro Branco (bgwm.co.uk) -> Casa Ferreirinha, `Vinha Grande` Douro Tinto (wineonline.ie), distance 0.499
- By Farr, Geelong Shiraz (bgwm.co.uk) -> By Farr, `Farrside` Geelong Pinot Noir (wineonline.ie), distance 0.696
- Borgo Selene Catarratto / Inzolia (bgwm.co.uk) -> Kusuda Riesling (fieldandfawcett.co.uk), distance 0.722
- Bodegas Lan Bodegas Lan - Rioja - Reserva (bgwm.co.uk) -> Cantina Diomede, `Canace` Nero di Troia (www.thecorkscrew.ie), distance 0.726
- Axel Pauly, `Lieserer Niederberg-Helden` Mosel Riesling Kabinett (bgwm.co.uk) -> Axel Pauly, `Tres Naris` Mosel Riesling Trocken (wineonline.ie), distance 0.526
- Axel Pauly, `Tres Naris` Mosel Riesling Trocken (bgwm.co.uk) -> Axel Pauly, `Helden` Riesling Trocken (wineonline.ie), distance 0.559
- Domaine Fournillon, Crémant de Bourgogne (bgwm.co.uk) -> Pol Roger Rich Demi-Sec (www.winechateau.com), distance 0.678
- De Martino, Estate Cabernet Sauvignon (bgwm.co.uk) -> Waterford Estate Cabernet Sauvignon (wineonline.ie), distance 0.657
- AA Badenhorst Family Wines, Secateurs Red Blend (bgwm.co.uk) -> A.A. Badenhorst Secateurs Chenin Blanc Swartland, South Africa (www.winechateau.com), distance 0.532
- Blank Canvas, `Abstract` Three Rows Marlborough Sauvignon Blanc (bgwm.co.uk) -> Blank Canvas, Escaroth Chardonnay, Marlborough (www.thegoodwineshop.co.uk), distance 0.569
- Crystallum, `Ferrum` Chardonnay (bgwm.co.uk) -> Crystallum Mabalel Pinot Noir (www.winechateau.com), distance 0.476
