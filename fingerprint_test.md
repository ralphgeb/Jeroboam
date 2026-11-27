# Label fingerprint test

182,312 shop photos fingerprinted from 68 shops; Vision revisions {2: 182312}; 768 numbers per print.

## Test 1: shop photo vs other shops' photos

20,000 photos of wines sold by 2+ shops, each looked up among 182,312 prints of the other shops.

| print | right (nearest is the same wine) | right in top 5 | same picture file | wrong: look-alike (same producer) | wrong: other |
|---|---|---|---|---|---|
| whole photo | 3,309 (17%) | 6,620 (33%) | 22 (0%) | 6,244 (31%) | 10,447 (52%) |
| label crop | 3,512 (18%) | 6,804 (34%) | 19 (0%) | 6,563 (33%) | 9,925 (50%) |
| both | 3,846 (19%) | 7,586 (38%) | 16 (0%) | 6,871 (34%) | 9,283 (46%) |

Without identical picture files (what a phone photo would face), and how sure a match can be by distance:

| print | right | accept if nearest closer than | accepted | of those right |
|---|---|---|---|---|
| whole photo | 16% | 0.318 | 10% | 30% |
| whole photo | 16% | 0.360 | 25% | 24% |
| whole photo | 16% | 0.411 | 50% | 22% |
| label crop | 17% | 0.446 | 10% | 28% |
| label crop | 17% | 0.512 | 25% | 22% |
| label crop | 17% | 0.585 | 49% | 19% |
| both | 19% | 0.432 | 10% | 32% |
| both | 19% | 0.486 | 25% | 24% |
| both | 19% | 0.551 | 50% | 22% |

Some wrong answers (both prints):

- Peay Vineyards West Sonoma Coast Chardonnay (allywines.com) -> Peay Vineyards, Chardonnay 'Maritima - Estate' (www.winechateau.com), distance 0.534
- Colgin IX Estate Proprietary Red Blend (allywines.com) -> Colgin IX Estate Proprietary Red Blend (zyn.ca), distance 1.017
- Clos Saron Carte Blanche (allywines.com) -> Clos Saron Pinot Noir Old Block Home Vineyard (winetherapynyc.com), distance 0.856
- Haarmeyer Nebbiolo (allywines.com) -> By Farr Shiraz Geelong (sf.vervewine.com), distance 0.996
- Domaine Jean Fournier, Marsannay Rouge 'Cuvée Saint Urbain' (bgwm.co.uk) -> Domaine Bruno Clair Marsannay Rouge Les Grasses Tetes (www.winechateau.com), distance 0.629
- Domaine du Coulet, Cornas 'Brise Cailloux' (bgwm.co.uk) -> Coulet (Matthieu Barret) Cornas Brise Cailloux (www.chambersstwines.com), distance 0.518
- Domaine de Montille, Bourgogne Blanc (bgwm.co.uk) -> Domaine de Montille Le Clos du Château Magnum (www.thecorkscrew.ie), distance 0.526
- Domaine de L'Enclos, Chablis (bgwm.co.uk) -> Domaine de l'Enclos Chablis (Case only) (www.winechateau.com), distance 0.539
- Domaine Corinne Perchaud, `Eve Grossot` Chablis (bgwm.co.uk) -> Maison Louis Latour Louis Latour - Montagny - Les Buys (www.winechateau.com), distance 0.780
- Champagne Devaux - Coeur Des Bar - Blanc De Noirs (bgwm.co.uk) -> Devaux Blanc De Noir (www.winechateau.com), distance 0.400
- David Moret, Meursault `Sous La Velle` (bgwm.co.uk) -> David Moret Meursault `Narvaux` Côte de Beaune, Burgundy (wineonline.ie), distance 0.468
- Dandelion Vineyards Lionheart Of The Barossa Shiraz (bgwm.co.uk) -> Dandelion Vineyards Pride of the Fleurieu Cabernet Sauvignon (wineonline.ie), distance 0.440
- Clos Venturi, `1769` Blanc (bgwm.co.uk) -> Clos Venturi, 1769 Rose (wine.sothebys.com), distance 0.453
- Cleto Chiarli, Vecchia Modena Lambrusco Sorbara (bgwm.co.uk) -> Chiarli Lambrusco Di Sorbara (www.winechateau.com), distance 0.533
- Chatto, `Lutruwita` Tasmania Pinot Noir (bgwm.co.uk) -> Chatto Franklinii Pinot Noir (camperdowncellars.com.au), distance 0.399
- Château Laville, Sauternes (bgwm.co.uk) -> Chateau Laville Bordeaux Sauternes 13% ABV Semillon Sauvignon Blanc (www.twelvegreenbottleswine.co.uk), distance 0.507
- Château Fontarèche, Tradition Blanc IGP Pays d'Oc (bgwm.co.uk) -> Di Meno, Catarrato (www.thegoodwineshop.co.uk), distance 0.817
- Chateau De Pitray Les Prairies Castillon Cotes De Bordeaux (bgwm.co.uk) -> Madame Chateau de Pitray (hedonism.co.uk), distance 0.815
- Château Capbern, Saint-Estèphe (bgwm.co.uk) -> Château Calon-Ségur Château Capbern, Saint-Estèphe (www.tanners-wines.co.uk), distance 0.524
- Charles Heidsieck Millesime Rose Vintage (bgwm.co.uk) -> Charles Heidsieck, Rosé Millésime (wineonline.ie), distance 0.372
- Casa Ferreirinha, `Vinha Grande` Douro Branco (bgwm.co.uk) -> Casa Ferreirinha, `Vinha Grande` Douro Tinto (wineonline.ie), distance 0.499
- Capezzana - Villa de Capezzana - Carmignano (bgwm.co.uk) -> Capezzana Villa Di Capezzana Di Carmignano Docg (www.tannico.it), distance 0.581
- Amarone della Valpolicella Torre del Falasco (bgwm.co.uk) -> Falasco Amarone Della Valpolicella (zyn.ca), distance 0.506
- By Farr, Geelong Shiraz (bgwm.co.uk) -> By Farr, `Farrside` Geelong Pinot Noir (wineonline.ie), distance 0.696
- By Farr, Geelong Chardonnay (bgwm.co.uk) -> By Farr Chardonnay (hedonism.co.uk), distance 0.675

Phone scans could not be read: HTTP Error 403: Forbidden

## Test 2: phone scans vs shop photos

0 phone prints in the worker, 0 of the same revision (2).
