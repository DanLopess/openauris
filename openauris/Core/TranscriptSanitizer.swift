import Foundation

/// Removes WhisperKit hallucination markers and special tokens from raw transcription output
/// before the text is displayed or inserted into the focused app.
///
/// WhisperKit can emit various artefacts that must never reach the user:
///   • Bracketed tokens: `[BLANK_AUDIO]`, `[MUSIC]`, `[INAUDIBLE]`, `[NOISE]`,
///     `[LAUGHTER]`, `[APPLAUSE]`, `[CROSSTALK]`, `[SILENCE]`, and any future variants.
///   • Parenthesized non-speech markers: `(paper rustling)`, `(noise)`, `(laughter)`, etc.
///   • Timestamp tokens: `<|0.00|>`, `<|transcribe|>`, `<|en|>`, etc.
///
/// All bracketed content is removed — in speech-to-text output every `[…]` expression
/// is a machine-generated marker, never actual transcribed speech.
func sanitizeTranscriptText(_ raw: String) -> String {
    var cleaned = raw

    // 1. Remove any [bracketed token] — catches all WhisperKit hallucination markers.
    cleaned = cleaned.replacingOccurrences(
        of: #"\[[^\]]*\]"#,
        with: " ",
        options: .regularExpression
    )

    // 2. Remove timestamp / control tokens such as <|0.00|>, <|en|>, <|transcribe|>.
    cleaned = cleaned.replacingOccurrences(
        of: #"<\|[^|]+?\|>"#,
        with: " ",
        options: .regularExpression
    )

    // 3. Remove known parenthesized non-speech markers produced by transcription models.
    cleaned = cleaned.replacingOccurrences(
        of: #"\(\s*(?:paper\s+rustling|rustling|noise|background\s+noise|music|laughter|laugh(?:ing|s)?|applause|inaudible|crosstalk|silence|cough(?:ing|s)?|sigh(?:ing|s)?)\s*\)"#,
        with: " ",
        options: [.regularExpression, .caseInsensitive]
    )

    // 4. Remove spaces that were introduced immediately before punctuation marks.
    cleaned = cleaned.replacingOccurrences(
        of: #"\s+([.,!?;:…])"#,
        with: "$1",
        options: .regularExpression
    )

    // 5. Collapse remaining runs of whitespace.
    cleaned = cleaned.replacingOccurrences(
        of: #"\s+"#,
        with: " ",
        options: .regularExpression
    )

    return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
}
