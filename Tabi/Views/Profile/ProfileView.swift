import SwiftUI

// MARK: - Profile View

struct ProfileView: View {
    @ObservedObject var medicationManager: MedicationManager

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Avatar + Name
                    HStack(spacing: 16) {
                        Circle().fill(Color.tabiLavLight).frame(width: 72, height: 72)
                            .overlay(Image(systemName: "person.fill").font(.title).foregroundColor(.tabiLavender))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Name").font(.title2.bold())
                            Text("Gender, Age").font(.subheadline).foregroundColor(.tabiGray)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)

                    // Stats
                    HStack(spacing: 20) {
                        ZStack {
                            Circle().fill(Color.tabiLavLight).frame(width: 110, height: 110)
                            VStack(spacing: 2) {
                                Text("\(medicationManager.medications.count)").font(.system(size: 36, weight: .bold))
                                Text("Active Meds").font(.caption).foregroundColor(.tabiGray)
                            }
                        }
                        ZStack {
                            Circle().stroke(Color.tabiLavender.opacity(0.2), lineWidth: 10).frame(width: 110, height: 110)
                            Circle().trim(from: 0, to: CGFloat(medicationManager.gameStats.adherencePercent) / 100)
                                .stroke(Color.tabiLavender, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                                .frame(width: 110, height: 110).rotationEffect(.degrees(-90))
                            VStack(spacing: 2) {
                                Text("\(medicationManager.gameStats.adherencePercent)%").font(.system(size: 26, weight: .bold))
                                Text("Adherence").font(.caption).foregroundColor(.tabiGray)
                            }
                        }
                    }

                    // Menu items
                    VStack(spacing: 0) {
                        let menuItems: [(String, String, String)] = [
                            ("heart.text.square", "Allergy Profile", "Safety and Allergies"),
                            ("cross.case",         "My Pharmacies",            ""),
                            ("gearshape",          "Setting",                  ""),
                        ]
                        ForEach(menuItems, id: \.1) { item in
                            let icon = item.0; let title = item.1; let subtitle = item.2
                            HStack(spacing: 12) {
                                Circle().fill(Color.tabiLavLight).frame(width: 36, height: 36)
                                    .overlay(Image(systemName: icon).font(.caption).foregroundColor(.tabiLavender))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(title).font(.subheadline.bold())
                                    if !subtitle.isEmpty { Text(subtitle).font(.caption).foregroundColor(.tabiGray) }
                                }
                                Spacer()
                                Image(systemName: "square.and.arrow.up").foregroundColor(.tabiGray).font(.caption)
                            }
                            .padding(.horizontal, 16).padding(.vertical, 14).background(Color.tabiCard)
                            if title != "Setting" { Divider().padding(.leading, 64) }
                        }
                    }
                    .background(Color.tabiCard).cornerRadius(14).padding(.horizontal, 16)
                }
                .padding(.top, 8).padding(.bottom, 32)
            }
            .background(Color.tabiBG)
            .navigationTitle("Profile")
        }
    }
}
