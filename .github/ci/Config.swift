// Dummy Config.swift for CI only - see .github/workflows/tests.yml.
// The real Tabi/Config.swift is gitignored (per-developer, holds the real
// Gemini API key). TabiTests never calls GeminiService's live API, so this
// placeholder just needs to exist and compile.
enum Config {
    static let geminiAPIKey = "dummy-ci-key"
}
