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
            return MapTerms(level: ["Regions", "Sub-regions", "Appellations"],
                            hint: ["The big wine regions", "The large areas inside each region", "Appellations (AOC), village by village"],
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
            return MapTerms(level: ["Regions", "Denominations (DO/DOCa)", "Pagos & sub-zones"],
                            hint: ["The autonomous regions", "Denominations (DO/DOCa) inside them", "Vinos de Pago and sub-zones inside the DOs"])
        case "portugal":
            return MapTerms(level: ["Regions", "Denominations (DOC)", "Sub-regions"],
                            hint: ["Norte, Centro, Lisboa & Tejo, Alentejo, Algarve", "The DOC wine regions", "Sub-regions and smaller DOCs inside them"])
        case "germany":
            return MapTerms(level: ["Regions (Anbaugebiete)"], hint: ["The 13 wine regions (Anbaugebiete)"])
        case "austria":
            return MapTerms(level: ["Regions", "Districts (DAC)"], hint: ["The wine regions", "Districts, many of them DAC"])
        case "hungary":
            return MapTerms(level: ["Regions", "Districts", "Appellations"],
                            hint: ["The six wine regions", "The 22 wine districts", "Smaller appellations inside the districts"])
        case "greece":
            return MapTerms(level: ["Regions", "Zones (PDO)", "Appellations (PDO)"], hint: ["The regions", "Zones (PDO) inside them", "Appellations inside the zones"])
        case "california", "napa-sonoma", "pacific-northwest":
            return MapTerms(level: ["Regions", "AVAs"], hint: ["The big wine regions", "American Viticultural Areas (AVAs)"])
        case "south-australia":
            return MapTerms(level: ["Zones (GI)", "Regions (GI)", "Subregions (GI)"],
                            hint: ["The wine zones (Geographical Indications)", "Wine regions inside the zones", "Subregions inside the regions"])
        case "australia":
            return MapTerms(level: ["States", "Regions (GI)"], hint: ["The wine states", "Wine regions (Geographical Indications)"])
        case "new-zealand":
            return MapTerms(level: ["Regions (GI)", "Sub-regions (GI)", "Smaller GIs"],
                            hint: ["The wine regions (Geographical Indications)", "Smaller GIs inside them", "GIs inside those (Waipara Valley)"],
                            places: "Towns")
        case "south-africa":
            return MapTerms(level: ["Regions", "Districts", "Wards"],
                            hint: ["Wine of Origin regions", "Districts inside the regions", "Wards (Constantia, Durbanville)"],
                            places: "Towns")
        case "chile":
            return MapTerms(level: ["Regions", "Valleys", "Zones & areas"],
                            hint: ["The six wine regions (DO)", "Sub-regions: the valleys", "Zones and areas (comunas) inside the valleys"],
                            places: "Comunas")
        case "argentina":
            return MapTerms(level: ["Provinces", "Regions (IG)"], hint: ["The wine provinces", "Regions and departments (IG/DOC)"],
                            places: "Departments")
        case "lebanon":
            return MapTerms(level: ["Regions", "Winery areas"], hint: ["The wine regions", "Winery areas inside the regions"])
        default:
            return MapTerms(level: ["Regions", "Areas", "Appellations"], hint: ["The wine regions", "Districts and areas inside the regions", "Appellations and village zones"], places: "Places")
        }
    }

    func name(_ l: Int) -> String { level[min(max(l, 0), level.count - 1)] }
    /// The same name without the bracketed abbreviation, short enough for a button on one line.
    func button(_ l: Int) -> String { name(l).components(separatedBy: " (").first ?? name(l) }
    func line(_ l: Int) -> String { hint[min(max(l, 0), hint.count - 1)] }
}
