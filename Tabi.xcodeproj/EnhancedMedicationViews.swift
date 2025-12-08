//
//  EnhancedMedicationViews.swift
//  Tabi
//
//  Enhanced UI views leveraging new Visual Intelligence features
//

import SwiftUI

// MARK: - Add Medication with Enhanced Metadata

struct EnhancedAddMedicationView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var medicationManager: MedicationManager
    
    @State private var name = ""
    @State private var emoji = "💊"
    @State private var dosageTime = Date()
    @State private var points = 10
    
    // Enhanced metadata
    @State private var genericName = ""
    @State private var brandNames: [String] = []
    @State private var newBrandName = ""
    @State private var dosageAmount = ""
    @State private var activeIngredient = ""
    @State private var pillColor: Medication.PillColor?
    @State private var pillShape: Medication.PillShape?
    @State private var ndcCode = ""
    @State private var notes = ""
    
    // AI assistance
    @State private var showingAIAssist = false
    @State private var aiSuggestions: [String] = []
    
    var body: some View {
        NavigationStack {
            Form {
                // Basic Information
                Section("Basic Information") {
                    TextField("Medication Name", text: $name)
                        .onChange(of: name) { _, newValue in
                            loadSuggestions(for: newValue)
                        }
                    
                    if !aiSuggestions.isEmpty {
                        DisclosureGroup("Suggestions") {
                            ForEach(aiSuggestions, id: \.self) { suggestion in
                                Button(suggestion) {
                                    name = suggestion
                                    if let common = CommonMedication.find(matching: suggestion) {
                                        applyCommonMedication(common)
                                    }
                                }
                            }
                        }
                    }
                    
                    TextField("Emoji", text: $emoji)
                    DatePicker("Dosage Time", selection: $dosageTime, displayedComponents: .hourAndMinute)
                    Stepper("Points: \(points)", value: $points, in: 1...50)
                }
                
                // Enhanced Details
                Section("Medication Details") {
                    TextField("Generic Name", text: $genericName)
                        .textContentType(.none)
                    
                    TextField("Dosage (e.g., 500mg)", text: $dosageAmount)
                    
                    TextField("Active Ingredient", text: $activeIngredient)
                    
                    TextField("NDC Code (Barcode)", text: $ndcCode)
                        .keyboardType(.numberPad)
                }
                
                // Brand Names
                Section("Brand Names") {
                    ForEach(brandNames, id: \.self) { brand in
                        HStack {
                            Text(brand)
                            Spacer()
                            Button(role: .destructive) {
                                brandNames.removeAll { $0 == brand }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    
                    HStack {
                        TextField("Add brand name", text: $newBrandName)
                        Button {
                            if !newBrandName.isEmpty {
                                brandNames.append(newBrandName)
                                newBrandName = ""
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                }
                
                // Appearance
                Section("Pill Appearance") {
                    Picker("Color", selection: $pillColor) {
                        Text("Not specified").tag(nil as Medication.PillColor?)
                        ForEach(Medication.PillColor.allCases, id: \.self) { color in
                            Text(color.description).tag(color as Medication.PillColor?)
                        }
                    }
                    
                    Picker("Shape", selection: $pillShape) {
                        Text("Not specified").tag(nil as Medication.PillShape?)
                        ForEach(Medication.PillShape.allCases, id: \.self) { shape in
                            Text(shape.description).tag(shape as Medication.PillShape?)
                        }
                    }
                }
                
                // Notes
                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Add Medication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveMedication()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private func loadSuggestions(for text: String) {
        guard !text.isEmpty else {
            aiSuggestions = []
            return
        }
        
        // Get suggestions from common database
        let suggestions = CommonMedication.suggestions(for: text, limit: 5)
        aiSuggestions = suggestions.map { $0.name }
    }
    
    private func applyCommonMedication(_ common: CommonMedication) {
        genericName = common.genericName ?? ""
        brandNames = common.brandNames
        activeIngredient = common.activeIngredient
        if let firstDosage = common.commonDosages.first {
            dosageAmount = firstDosage
        }
    }
    
    private func saveMedication() {
        let medication = Medication(
            name: name,
            emoji: emoji,
            dosageTime: dosageTime,
            points: points
        )
        
        let metadata = Medication.EnhancedMetadata(
            genericName: genericName.isEmpty ? nil : genericName,
            brandNames: brandNames,
            activeIngredient: activeIngredient.isEmpty ? nil : activeIngredient,
            dosageAmount: dosageAmount.isEmpty ? nil : dosageAmount,
            pillColor: pillColor,
            pillShape: pillShape,
            ndcCode: ndcCode.isEmpty ? nil : ndcCode,
            notes: notes.isEmpty ? nil : notes
        )
        
        medicationManager.addMedication(medication)
        
        // Save metadata
        if let encoded = try? JSONEncoder().encode(metadata) {
            UserDefaults.standard.set(encoded, forKey: "medication_metadata_\(medication.id.uuidString)")
        }
        
        dismiss()
    }
}

// MARK: - Enhanced Medication Detail View

struct EnhancedMedicationDetailView: View {
    let medication: Medication
    @State private var metadata: Medication.EnhancedMetadata?
    @State private var explanation: String?
    @State private var isLoadingExplanation = false
    
    var body: some View {
        List {
            // Basic Info
            Section("Basic Information") {
                LabeledContent("Name", value: medication.name)
                LabeledContent("Emoji", value: medication.emoji)
                LabeledContent("Points", value: "\(medication.points)")
                LabeledContent("Streak", value: "\(medication.streak) days")
            }
            
            // Enhanced Details
            if let metadata = metadata {
                if let generic = metadata.genericName {
                    Section("Generic Name") {
                        Text(generic)
                    }
                }
                
                if let dosage = metadata.dosageAmount {
                    Section("Dosage") {
                        Text(dosage)
                    }
                }
                
                if let ingredient = metadata.activeIngredient {
                    Section("Active Ingredient") {
                        Text(ingredient)
                    }
                }
                
                if !metadata.brandNames.isEmpty {
                    Section("Brand Names") {
                        ForEach(metadata.brandNames, id: \.self) { brand in
                            Text(brand)
                        }
                    }
                }
                
                Section("Appearance") {
                    if let color = metadata.pillColor {
                        LabeledContent("Color", value: color.description)
                    }
                    if let shape = metadata.pillShape {
                        LabeledContent("Shape", value: shape.description)
                    }
                }
                
                if let ndc = metadata.ndcCode {
                    Section("NDC Code") {
                        Text(ndc)
                            .font(.system(.body, design: .monospaced))
                    }
                }
                
                if let notes = metadata.notes {
                    Section("Notes") {
                        Text(notes)
                    }
                }
            }
            
            // AI Explanation
            if #available(iOS 18.0, *) {
                Section("Information") {
                    if let explanation = explanation {
                        Text(explanation)
                            .font(.body)
                    } else {
                        Button {
                            loadExplanation()
                        } label: {
                            HStack {
                                Text("Learn More")
                                Spacer()
                                if isLoadingExplanation {
                                    ProgressView()
                                } else {
                                    Image(systemName: "sparkles")
                                }
                            }
                        }
                        .disabled(isLoadingExplanation)
                    }
                }
            }
        }
        .navigationTitle(medication.name)
        .onAppear {
            loadMetadata()
        }
    }
    
    private func loadMetadata() {
        guard let data = UserDefaults.standard.data(forKey: "medication_metadata_\(medication.id.uuidString)"),
              let decoded = try? JSONDecoder().decode(Medication.EnhancedMetadata.self, from: data) else {
            return
        }
        metadata = decoded
    }
    
    @available(iOS 18.0, *)
    private func loadExplanation() {
        isLoadingExplanation = true
        
        Task {
            let analyzer = MedicationAIAnalyzer()
            
            guard analyzer.isAvailable else {
                explanation = "Apple Intelligence is not available on this device."
                isLoadingExplanation = false
                return
            }
            
            do {
                explanation = try await analyzer.explainMedication(medication.name)
            } catch {
                explanation = "Unable to load information. Please try again."
            }
            
            isLoadingExplanation = false
        }
    }
}

// MARK: - Medication Search View with AI

@available(iOS 18.0, *)
struct AIAssistedSearchView: View {
    @State private var searchText = ""
    @State private var searchResults: [String] = []
    @State private var isSearching = false
    
    var body: some View {
        NavigationStack {
            VStack {
                TextField("Describe medication...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                
                Button("Search with AI") {
                    performAISearch()
                }
                .disabled(searchText.isEmpty || isSearching)
                
                if isSearching {
                    ProgressView()
                        .padding()
                }
                
                List(searchResults, id: \.self) { result in
                    Text(result)
                }
            }
            .navigationTitle("AI Medication Search")
        }
    }
    
    private func performAISearch() {
        isSearching = true
        
        Task {
            let analyzer = MedicationAIAnalyzer()
            
            do {
                searchResults = try await analyzer.generateSearchQueries(from: searchText)
            } catch {
                searchResults = ["Search failed. Please try again."]
            }
            
            isSearching = false
        }
    }
}

// MARK: - Visual Intelligence Info Banner

struct VisualIntelligenceBanner: View {
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "viewfinder.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading) {
                    Text("Visual Intelligence Enabled")
                        .font(.headline)
                    Text("Circle medications with your camera")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button {
                    withAnimation {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                }
            }
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    Text("How to use:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Label("Open Visual Intelligence camera", systemImage: "camera")
                    Label("Point at medication bottle or pill", systemImage: "pill")
                    Label("Circle the medication", systemImage: "circle.dashed")
                    Label("Tap Tabi in results", systemImage: "hand.tap")
                }
                .font(.caption)
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

// MARK: - Preview

#Preview("Add Medication") {
    EnhancedAddMedicationView(medicationManager: MedicationManager())
}

#Preview("Visual Intelligence Banner") {
    VisualIntelligenceBanner()
}
