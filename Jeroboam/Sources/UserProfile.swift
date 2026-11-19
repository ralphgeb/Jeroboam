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
    }
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
                pickerRow("Age", $age, ["", "18–24", "25–34", "35–44", "45–54", "55–64", "65+"])
                pickerRow("Wine experience", $experience, ["", "Just starting", "Enthusiast", "Studying WSET 1", "Studying WSET 2",
                                                            "Studying WSET 3", "Trade professional", "Sommelier"])
                pickerRow("Favorite style", $favorite, ["", "Crisp whites", "Rich whites", "Rosé", "Light reds", "Bold reds",
                                                        "Sparkling", "Sweet & fortified"])
                HStack {
                    Text("Country").font(.system(size: 15)).foregroundStyle(Palette.ink)
                    Spacer()
                    TextField("Where you live", text: $country).multilineTextAlignment(.trailing).font(.system(size: 15))
                        .foregroundStyle(Palette.inkSoft)
                }
                .padding(.horizontal, 14).padding(.vertical, 12)
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

    private func pickerRow(_ title: String, _ value: Binding<String>, _ options: [String]) -> some View {
        HStack {
            Text(title).font(.system(size: 15)).foregroundStyle(Palette.ink)
            Spacer()
            Picker(title, selection: value) {
                ForEach(options, id: \.self) { Text($0.isEmpty ? "Not set" : $0).tag($0) }
            }
            .tint(Palette.inkSoft)
        }
        .padding(.horizontal, 14).padding(.vertical, 4)
        .overlay(alignment: .bottom) { Hairline().padding(.leading, 14) }
    }
}

// MARK: - Page with a big title that shrinks into a slim top bar on scroll

struct CollapsingPage<Content: View>: View {
    let eyebrow: String
    let title: String
    var subtitle: String? = nil
    var showStatus = false
    @ViewBuilder let content: Content
    @State private var collapse: CGFloat = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ScreenHeader(eyebrow: eyebrow, title: title, subtitle: subtitle)
                    .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named("collapsingPage")).minY } action: { y in
                        let p = min(1, max(0, (-12 - y) / 50))
                        if abs(p - collapse) > 0.01 { collapse = p }
                    }
                content
            }
            .padding(.horizontal, Metrics.margin)
        }
        .coordinateSpace(name: "collapsingPage")
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .top, spacing: 0) { bar }
    }

    private var bar: some View {
        ZStack {
            if showStatus {
                TopStatusBar()
                    .opacity(1 - collapse)
                    .offset(y: -6 * collapse)
                    .allowsHitTesting(collapse < 0.5)
            }
            HStack {
                Text(title).font(.system(size: 17, weight: .semibold)).foregroundStyle(Palette.ink)
                    .opacity(collapse).offset(y: 6 * (1 - collapse))
                Spacer()
                if !showStatus || collapse > 0.5 { AvatarButton(size: 30) }
            }
        }
        .frame(height: 44)
        .padding(.horizontal, Metrics.margin)
        .padding(.top, 4)
        .background(Palette.paper.ignoresSafeArea(edges: .top))
        .overlay(alignment: .bottom) { Hairline().opacity(collapse) }
    }
}
