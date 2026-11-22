import Foundation

/// What each country calls its wine-place levels, so the map buttons, hints and lists use the local system
/// (Italy's DOC/DOCG, Spain's DO, the US's AVAs, South Africa's wards...) instead of one word for everywhere.
struct MapTerms {
    /// Plural name of each level on the map: 0 = biggest areas, then the ones inside.
    let level: [String]
    /// One line under the map title for each level.
    let hint: [String]
    /// What the place names written on the map at the closest zoom are (towns and villages inside the areas).
    var places = "Villages"

    static func `for`(_ mapID: String) -> MapTerms {
        switch mapID {
        case "france":
            return MapTerms(level: ["Regions", "Sub-regions", "Appellations (AOC)", "Grand crus"],
                            hint: ["The big wine regions", "Sub-regions of each region", "Appellations (AOC): villages and communes", "Grand cru vineyards"],
                            places: "Communes")
        case "italy":
            return MapTerms(level: ["Regions", "Zones", "Denominations (DOC/DOCG)"],
                            hint: ["The wine regions", "Zones of each region", "Denominations (DOC/DOCG)"])
        case "bordeaux":
            return MapTerms(level: ["Appellations", "Communal AOCs"], hint: ["Regional appellations (AOC)", "Communal appellations (AOC)"], places: "Communes")
        case "burgundy":
            return MapTerms(level: ["Areas", "Appellations (AOC)"], hint: ["The main areas of Burgundy", "Village and cru appellations (AOC)"], places: "Communes")
        case "champagne":
            return MapTerms(level: ["Sub-regions"], hint: ["The five growing areas of Champagne"], places: "Villages")
        case "loire":
            return MapTerms(level: ["Areas", "Appellations (AOC)"], hint: ["The areas along the river", "Appellations (AOC) inside the areas"], places: "Communes")
        case "rhone":
            return MapTerms(level: ["North and south", "Appellations (AOC)"], hint: ["Northern and southern Rhône", "Appellations (AOC), many of them crus"], places: "Communes")
        case "piedmont":
            return MapTerms(level: ["Denominations (DOCG/DOC)", "Communes"], hint: ["The denominations (DOCG/DOC) of Piedmont", "Communes inside the denominations"], places: "Communes")
        case "tuscany":
            return MapTerms(level: ["Denominations (DOC/DOCG)", "Communes"], hint: ["Denominations (DOC/DOCG) of Tuscany", "Communes inside the denominations"], places: "Communes")
        case "spain":
            return MapTerms(level: ["Regions", "Denominations (DO/DOCa)"], hint: ["The autonomous regions", "Denominations (DO/DOCa) inside them"])
        case "portugal":
            return MapTerms(level: ["Regions", "Denominations (DOC)"], hint: ["The wine regions", "Denominations (DOC) and sub-regions"])
        case "germany":
            return MapTerms(level: ["Regions (Anbaugebiete)", "Districts"], hint: ["The 13 wine regions (Anbaugebiete)", "Districts inside the regions"])
        case "austria":
            return MapTerms(level: ["Regions", "Districts (DAC)"], hint: ["The wine regions", "Districts, many of them DAC"])
        case "hungary":
            return MapTerms(level: ["Regions", "Districts"], hint: ["The wine regions", "Wine districts inside the regions"])
        case "greece":
            return MapTerms(level: ["Regions", "Zones (PDO/PGI)"], hint: ["The regions", "Zones (PDO/PGI) inside them"])
        case "california", "napa-sonoma", "pacific-northwest":
            return MapTerms(level: ["Regions", "AVAs"], hint: ["The big wine regions", "American Viticultural Areas (AVAs)"])
        case "australia", "south-australia":
            return MapTerms(level: ["States", "Regions (GI)"], hint: ["The wine states", "Wine regions (Geographical Indications)"])
        case "new-zealand":
            return MapTerms(level: ["Regions", "Sub-regions"], hint: ["The wine regions", "Sub-regions inside them"])
        case "south-africa":
            return MapTerms(level: ["Regions", "Districts and wards"], hint: ["The wine regions", "Districts and wards inside them"])
        case "chile":
            return MapTerms(level: ["Regions", "Valleys"], hint: ["The wine regions", "Valleys inside the regions"])
        case "argentina":
            return MapTerms(level: ["Provinces", "Zones"], hint: ["The wine provinces", "Zones inside the provinces"])
        case "lebanon":
            return MapTerms(level: ["Regions", "Winery areas"], hint: ["The wine regions", "Winery areas inside the regions"])
        default:
            return MapTerms(level: ["Regions", "Areas", "Places"], hint: ["The big regions", "Areas inside the regions", "Places inside the areas"])
        }
    }

    func name(_ l: Int) -> String { level[min(max(l, 0), level.count - 1)] }
    /// The same name without the bracketed abbreviation, short enough for a button on one line.
    func button(_ l: Int) -> String { name(l).components(separatedBy: " (").first ?? name(l) }
    func line(_ l: Int) -> String { hint[min(max(l, 0), hint.count - 1)] }
}
