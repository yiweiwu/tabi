import SwiftUI

// MARK: - Sharing View

struct SharingView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    let sharingPeople: [(String, String, Bool)] = [("Dad", "9:23 AM", true), ("Mom", "9:36 AM", false)]
                    ForEach(sharingPeople, id: \.0) { person in
                        let name = person.0; let time = person.1; let hasAlert = person.2
                        HStack(spacing: 14) {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(hasAlert
                                      ? LinearGradient(colors: [Color.tabiLavender.opacity(0.7), Color.tabiBlue.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                      : LinearGradient(colors: [Color.tabiOrange.opacity(0.5), Color.tabiAmber.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 52, height: 52)
                                .overlay(Image(systemName: "person.fill").font(.title3).foregroundColor(.white))

                            VStack(alignment: .leading, spacing: 3) {
                                Text(name).font(.subheadline.bold())
                                if hasAlert {
                                    Label("1 Alert", systemImage: "exclamationmark.triangle.fill")
                                        .font(.caption).foregroundColor(.tabiAmber)
                                    Label("3 Changes", systemImage: "arrow.triangle.2.circlepath")
                                        .font(.caption).foregroundColor(.tabiGray)
                                } else {
                                    Label("2 Changes", systemImage: "arrow.triangle.2.circlepath")
                                        .font(.caption).foregroundColor(.tabiGray)
                                }
                            }
                            Spacer()
                            Text(time).font(.caption).foregroundColor(.tabiGray)
                            Image(systemName: "chevron.right").font(.caption).foregroundColor(.tabiGray)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 12).background(Color.tabiCard)
                        if name != "Mom" { Divider().padding(.leading, 82) }
                    }
                }
                .background(Color.tabiCard).cornerRadius(14).padding(.horizontal, 16).padding(.top, 8)

                // Export PDF
                HStack(spacing: 12) {
                    Circle().fill(Color.tabiLavLight).frame(width: 40, height: 40)
                        .overlay(Image(systemName: "doc.fill").font(.caption).foregroundColor(.tabiLavender))
                    Text("Export PDF").font(.subheadline)
                    Spacer()
                    Image(systemName: "square.and.arrow.up").foregroundColor(.tabiGray)
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
                .background(Color.tabiCard).cornerRadius(14)
                .padding(.horizontal, 16).padding(.top, 12)
            }
            .background(Color.tabiBG)
            .navigationTitle("Sharing")
        }
    }
}
