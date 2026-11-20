import SwiftUI
import PhotosUI

/// "About you": name, photo and a few details, kept on the device.
enum UserProfile {
    static var photoURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("avatar.jpg")
    }
    static func savePhoto(_ image: UIImage) {
        let side: CGFloat = 512
        let s = side / min(image.size.width, image.size.height)
        let size = CGSize(width: image.size.width * s, height: image.size.height * s)
        let img = UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { _ in
            image.draw(in: CGRect(x: (side - size.width) / 2, y: (side - size.height) / 2, width: size.width, height: size.height))
        }
        try? img.jpegData(compressionQuality: 0.85)?.write(to: photoURL, options: .atomic)
    }
    static func removePhoto() { try? FileManager.default.removeItem(at: photoURL) }
    static func photo() -> UIImage? { UIImage(contentsOfFile: photoURL.path) }
}

/// Round profile picture (or initials) that opens Profile & settings.
struct AvatarButton: View {
    var size: CGFloat = 30
    @AppStorage("jero.avatarVersion") private var version = 0
    @AppStorage("jero.name") private var name = ""
    @State private var showProfile = false

    var body: some View {
        Button { showProfile = true } label: { Avatar(size: size, version: version, name: name) }
            .accessibilityLabel("Profile and settings")
            .sheet(isPresented: $showProfile) { ProfileView() }
            .onAppear {
                #if DEBUG
                if DebugScreens.screen == "profile" && !AvatarButton.debugShown {
                    AvatarButton.debugShown = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { showProfile = true }
                }
                #endif
            }
    }
    #if DEBUG
    static var debugShown = false
    #endif
}

struct Avatar: View {
    var size: CGFloat
    var version: Int = 0
    var name: String = ""
    var body: some View {
        Group {
            if let img = UserProfile.photo() {
                Image(uiImage: img).resizable().scaledToFill()
            } else if let initial = name.trimmingCharacters(in: .whitespaces).first {
                Text(String(initial).uppercased()).font(.system(size: size * 0.45, weight: .semibold)).foregroundStyle(Palette.onWine)
                    .frame(maxWidth: .infinity, maxHeight: .infinity).background(Palette.wine)
            } else {
                Image(systemName: "person.fill").font(.system(size: size * 0.48)).foregroundStyle(Palette.inkSoft)
                    .frame(maxWidth: .infinity, maxHeight: .infinity).background(Palette.cardAlt)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().strokeBorder(Palette.line, lineWidth: 0.5))
        .id(version)
    }
}

/// Editable "About you" card used in Profile.
struct AboutYouSection: View {
    @AppStorage("jero.avatarVersion") private var version = 0
    @AppStorage("jero.name") private var name = ""
    @AppStorage("jero.ageRange") private var age = ""
    @AppStorage("jero.experience") private var experience = ""
    @AppStorage("jero.country") private var country = ""
    @AppStorage("jero.favorite") private var favorite = ""
    @State private var item: PhotosPickerItem? = nil
    @State private var open = false

    static func countries(including current: String) -> [String] {
        var names = Set(Locale.Region.isoRegions.compactMap { r -> String? in
            guard r.subRegions.isEmpty, r.identifier.count == 2 else { return nil }
            return Locale.current.localizedString(forRegionCode: r.identifier)
        })
        if !current.isEmpty { names.insert(current) }
        return [""] + names.sorted()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 16) {
                PhotosPicker(selection: $item, matching: .images) {
                    ZStack(alignment: .bottomTrailing) {
                        Avatar(size: 76, version: version, name: name)
                        Image(systemName: "camera.fill").font(.system(size: 11)).foregroundStyle(Palette.onWine)
                            .frame(width: 24, height: 24).background(Circle().fill(Palette.wine))
                            .overlay(Circle().strokeBorder(Palette.paper, lineWidth: 2))
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Your name", text: $name).font(.system(size: 20, weight: .semibold))
                    Text(experience.isEmpty ? "Tell us a little about you" : experience)
                        .font(.system(size: 13)).foregroundStyle(Palette.inkSoft)
                }
            }
            GroupCard {
                Button { withAnimation(.easeInOut(duration: 0.2)) { open.toggle() } } label: {
                    HStack {
                        Image(systemName: "person.text.rectangle").foregroundStyle(Palette.wine)
                        Text("About you").font(.system(size: 16, weight: .semibold)).foregroundStyle(Palette.ink)
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Palette.inkSoft).rotationEffect(.degrees(open ? 90 : 0))
                    }
                    .padding(.horizontal, 14).padding(.vertical, 14).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if open {
                    Hairline()
                    pickerRow("Age", $age, ["", "18–24", "25–34", "35–44", "45–54", "55–64", "65+"])
                    pickerRow("Experience", $experience, ["", "Just starting", "Enthusiast", "Studying WSET 1", "Studying WSET 2",
                                                                "Studying WSET 3", "Trade professional", "Sommelier"])
                    pickerRow("Favorite style", $favorite, ["", "Crisp whites", "Rich whites", "Rosé", "Light reds", "Bold reds",
                                                            "Sparkling", "Sweet & fortified"])
                    pickerRow("Country", $country, Self.countries(including: country), last: true)
                }
            }
            if UserProfile.photo() != nil {
                Button("Remove photo") { UserProfile.removePhoto(); version += 1 }
                    .font(.system(size: 13)).foregroundStyle(Palette.inkSoft)
            }
        }
        .onChange(of: item) { _, it in
            guard let it else { return }
            Task {
                if let data = try? await it.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                    UserProfile.savePhoto(img)
                    version += 1
                }
            }
        }
    }

    private func pickerRow(_ title: String, _ value: Binding<String>, _ options: [String], last: Bool = false) -> some View {
        HStack(spacing: 12) {
            Text(title).font(.system(size: 15)).foregroundStyle(Palette.ink).fixedSize()
            Spacer(minLength: 8)
            Menu {
                Picker(title, selection: value) {
                    ForEach(options, id: \.self) { Text($0.isEmpty ? "Not set" : $0).tag($0) }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(value.wrappedValue.isEmpty ? "Not set" : value.wrappedValue)
                        .lineLimit(1).minimumScaleFactor(0.75)
                    Image(systemName: "chevron.up.chevron.down").font(.system(size: 11))
                }
                .font(.system(size: 15)).foregroundStyle(Palette.inkSoft)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 13)
        .overlay(alignment: .bottom) { if !last { Hairline().padding(.leading, 14) } }
    }
}
