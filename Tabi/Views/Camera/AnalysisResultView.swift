import SwiftUI

// MARK: - Analysis Result View (shown after AI analyzes a captured pill photo)

struct AnalysisResultView: View {
    let capturedImage: UIImage
    let medicationName: String
    let medicationPoints: Int
    let analysisResult: MedicationAnalyzer.AnalysisResult?
    let onContinue: () -> Void
    let onRetake: () -> Void
    let onCancel: () -> Void

    @State private var isAnalyzing = true
    @State private var showScheduleInfo = false

    var body: some View {
        VStack(spacing: 24) {
            Text(isAnalyzing ? "📊 Analyzing Photo" : "Results")
                .font(.title2).fontWeight(.bold).padding(.top, 40)

            Image(uiImage: capturedImage)
                .resizable().aspectRatio(contentMode: .fit)
                .frame(width: 200, height: 200).cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isAnalyzing ? Color.gray : (analysisResult?.isMatch == true ? Color.green : Color.orange), lineWidth: 3)
                )

            if isAnalyzing {
                VStack(spacing: 16) {
                    ProgressView().scaleEffect(1.5).padding()
                    Text("AI is analyzing your medication...").font(.subheadline).foregroundColor(.gray).multilineTextAlignment(.center)
                    Text("Checking pill shape, color, and markings").font(.caption).foregroundColor(.gray).multilineTextAlignment(.center)
                }
            } else if let result = analysisResult {
                VStack(spacing: 20) {
                    VStack(spacing: 12) {
                        Text(result.isMatch ? "✅" : "⚠️").font(.system(size: 50))

                        Text(result.isMatch ? "Pill Verified!" : "Needs Review")
                            .font(.title3).fontWeight(.bold)
                            .foregroundColor(result.isMatch ? .green : .orange)

                        if result.isMatch && result.validMedicationDetected {
                            Text("Successfully identified \(medicationName)").font(.body).multilineTextAlignment(.center).padding(.horizontal)
                            Text("Valid medication markings detected").font(.caption).foregroundColor(.green)
                        } else if result.isMatch {
                            Text("Successfully identified \(medicationName)").font(.body).multilineTextAlignment(.center).padding(.horizontal)
                        } else if result.validMedicationDetected {
                            Text("Medication detected but please verify").font(.body).multilineTextAlignment(.center).padding(.horizontal)
                            Text("Markings don't exactly match \(medicationName)").font(.caption).foregroundColor(.orange)
                        } else {
                            Text("Please verify this is \(medicationName)").font(.body).multilineTextAlignment(.center).padding(.horizontal)
                        }

                        // Confidence bar
                        VStack(spacing: 4) {
                            HStack {
                                Text("Confidence:").font(.caption).foregroundColor(.secondary)
                                Spacer()
                                Text("\(Int(result.confidence * 100))%").font(.caption.bold()).foregroundColor(result.isMatch ? .green : .orange)
                            }
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4).fill(Color.gray.opacity(0.2)).frame(height: 8)
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(result.isMatch ? Color.green : Color.orange)
                                        .frame(width: geometry.size.width * CGFloat(result.confidence), height: 8)
                                }
                            }
                            .frame(height: 8)
                        }
                        .padding(.horizontal)

                        // Detection details
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: result.shapeDetected ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(result.shapeDetected ? .green : .gray).font(.caption)
                                Text("Pill shape detected").font(.caption)
                                Spacer()
                            }
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: result.colorProfile != "unknown" ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(result.colorProfile != "unknown" ? .green : .gray).font(.caption)
                                Text("Color: \(result.colorProfile.capitalized)").font(.caption)
                                Spacer()
                            }
                            Divider()
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: !result.detectedText.isEmpty ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundColor(!result.detectedText.isEmpty ? .green : .gray).font(.caption)
                                    Text("Detected Text:").font(.caption.bold())
                                    Spacer()
                                }
                                if result.detectedText.isEmpty {
                                    Text("No text markings detected").font(.caption).foregroundColor(.secondary).padding(.leading, 24)
                                } else {
                                    ForEach(result.detectedText.prefix(5), id: \.self) { text in
                                        HStack(spacing: 4) {
                                            Text("•").font(.caption).foregroundColor(.secondary)
                                            Text(text).font(.caption).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                                        }
                                        .padding(.leading, 20)
                                    }
                                    if result.detectedText.count > 5 {
                                        Text("+ \(result.detectedText.count - 5) more").font(.caption2).foregroundColor(.secondary).padding(.leading, 24)
                                    }
                                }
                            }
                            if !result.matchedTerms.isEmpty {
                                Divider().padding(.vertical, 4)
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "checkmark.seal.fill").foregroundColor(.green).font(.caption)
                                        Text("Matched Terms:").font(.caption.bold()).foregroundColor(.green)
                                    }
                                    ForEach(result.matchedTerms.prefix(3), id: \.self) { term in
                                        Text("✓ \(term)").font(.caption).foregroundColor(.green).padding(.leading, 24)
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .padding()
                    .background(result.isMatch ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
                    .cornerRadius(16)

                    if result.isMatch {
                        Text("🎉 +\(medicationPoints) Points Earned!").font(.headline).fontWeight(.bold).foregroundColor(.white)
                            .padding()
                            .background(LinearGradient(gradient: Gradient(colors: [Color.orange, Color.orange.opacity(0.8)]), startPoint: .leading, endPoint: .trailing))
                            .cornerRadius(12)
                    } else {
                        Text("You can still record if you're confident this is the right medication")
                            .font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center).padding(.horizontal)
                    }
                }
            }

            Spacer()

            if !isAnalyzing {
                VStack(spacing: 12) {
                    Button(action: onContinue) {
                        Text(analysisResult?.isMatch == true ? "Continue - Record Dose ✓" : "Record Anyway")
                            .font(.headline).foregroundColor(.white).frame(maxWidth: .infinity).padding()
                            .background(analysisResult?.isMatch == true ? Color.green : Color.orange).cornerRadius(12)
                    }
                    HStack(spacing: 20) {
                        Button("Retake Photo", action: onRetake).foregroundColor(.blue)
                        Button("Cancel", action: onCancel).foregroundColor(.gray)
                    }
                }
            }
        }
        .padding()
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation { isAnalyzing = false }
            }
        }
    }
}
