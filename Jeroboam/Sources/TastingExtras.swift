import PhotosUI
import SwiftUI

/// Up to 3 photos with a tasting's notes (the table, the food, the friends): taken or picked, shrunk to 900 px JPEG and kept inside
/// the tasting, so they go to iCloud with it.
struct NotePhotosRow: View {
    @Binding var photos: [Data]
    @State private var picks: [PhotosPickerItem] = []
    @State private var camera = false
    @State private var shot: UIImage? = nil
    static let limit = 3

    var body: some View {
        HStack(spacing: 10) {
            ForEach(Array(photos.enumerated()), id: \.offset) { i, d in
                if let img = UIImage(data: d) {
                    Image(uiImage: img).resizable().scaledToFill().frame(width: 72, height: 72)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(alignment: .topTrailing) {
                            Button { photos.remove(at: i) } label: {
                                Image(systemName: "xmark").font(.system(size: 9, weight: .bold)).foregroundStyle(.white)
                                    .frame(width: 20, height: 20).background(Circle().fill(.black.opacity(0.55)))
                            }
                            .accessibilityLabel("Remove photo").offset(x: 6, y: -6)
                        }
                }
            }
            if photos.count < Self.limit {
                Menu {
                    Button { camera = true } label: { Label("Take a photo", systemImage: "camera") }
                    PhotosPicker(selection: $picks, maxSelectionCount: Self.limit - photos.count, matching: .images) {
                        Label("Choose from photos", systemImage: "photo.on.rectangle")
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "camera").font(.system(size: 18))
                        Text(photos.isEmpty ? "Add photos" : "\(photos.count)/\(Self.limit)").font(.system(size: 10.5, weight: .medium))
                    }
                    .foregroundStyle(Palette.wine)
                    .frame(width: 72, height: 72)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.wineSoft))
                }
            }
            Spacer(minLength: 0)
        }
        .onChange(of: picks) { _, items in
            Task {
                for item in items where photos.count < Self.limit {
                    if let d = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: d), let small = Self.shrink(img) {
                        photos.append(small)
                    }
                }
                picks = []
            }
        }
        .onChange(of: shot) { _, img in
            if let img, photos.count < Self.limit, let small = Self.shrink(img) { photos.append(small) }
            shot = nil
        }
        .fullScreenCover(isPresented: $camera) { CameraPicker(image: $shot).ignoresSafeArea() }
    }

    /// 900 px on the long side, JPEG 0.6 (about 80–150 KB): small enough to travel inside the tasting.
    static func shrink(_ image: UIImage) -> Data? {
        let side = max(image.size.width, image.size.height)
        let k = min(1, 900 / max(1, side))
        let size = CGSize(width: image.size.width * k, height: image.size.height * k)
        let fmt = UIGraphicsImageRendererFormat(); fmt.scale = 1; fmt.opaque = true
        return UIGraphicsImageRenderer(size: size, format: fmt).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
            .jpegData(compressionQuality: 0.6)
    }
}

/// The Tastings tab before the first tasting: an invitation to taste blind, how the score works, and what you'll see.
struct TastingsWelcome: View {
    var onBlind: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text("BLIND TASTING").font(.jero(size: 11, weight: .semibold)).kerning(1.2).foregroundStyle(.white.opacity(0.75))
                Text("Can you guess the wine?").font(.jero(size: 22, weight: .semibold)).foregroundStyle(.white)
                Text("Snap the label, Jero hides it. Look, smell and taste, guess the grape and the country, then see how close you were.")
                    .font(.jero(size: 14)).foregroundStyle(.white.opacity(0.85)).fixedSize(horizontal: false, vertical: true)
                Button(action: onBlind) {
                    Label("Start a blind tasting", systemImage: "eye.slash")
                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.bordeaux)
                        .padding(.horizontal, 16).padding(.vertical, 11)
                        .background(Capsule().fill(.white))
                }
                .buttonStyle(PressableStyle())
                .padding(.top, 4)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(HeroCardBackground())
            .clipShape(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous))

            VStack(alignment: .leading, spacing: 10) {
                Text("How you score").font(.jero(size: 16, weight: .semibold)).foregroundStyle(Palette.ink)
                HStack(spacing: 8) {
                    part("Grape", 30); part("Country", 20); part("Aromas", 30); part("Structure", 20)
                }
                Text("Out of 100. Tasting a bottle you know works too: tap a bottle in your cellar, then Taste this bottle.")
                    .font(.jero(size: 12.5)).foregroundStyle(Palette.inkSoft).fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardStyle(padding: 0)
        }
    }

    private func part(_ name: String, _ points: Int) -> some View {
        VStack(spacing: 2) {
            Text("\(points)").font(.system(size: 20, weight: .semibold).monospacedDigit()).foregroundStyle(Palette.wine)
            Text(name).font(.system(size: 11.5)).foregroundStyle(Palette.inkSoft)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Palette.wineSoft))
    }
}

/// The Cellar tab before the first bottle.
struct CellarWelcome: View {
    var onScan: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("YOUR CELLAR").font(.jero(size: 11, weight: .semibold)).kerning(1.2).foregroundStyle(.white.opacity(0.75))
            Text("Know what every bottle is worth").font(.jero(size: 22, weight: .semibold)).foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            Text("Scan the bottles you own: Jero adds their price, score and when to open them, and tells you when each is ready.")
                .font(.jero(size: 14)).foregroundStyle(.white.opacity(0.85)).fixedSize(horizontal: false, vertical: true)
            Button(action: onScan) {
                Label("Scan a bottle", systemImage: "camera.viewfinder")
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(Palette.bordeaux)
                    .padding(.horizontal, 16).padding(.vertical, 11)
                    .background(Capsule().fill(.white))
            }
            .buttonStyle(PressableStyle())
            .padding(.top, 4)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HeroCardBackground())
        .clipShape(RoundedRectangle(cornerRadius: Metrics.radius, style: .continuous))
    }
}
