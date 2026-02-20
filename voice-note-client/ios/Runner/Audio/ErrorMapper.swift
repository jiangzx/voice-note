import Foundation

struct NormalizedError {
  let code: String
  let message: String
  let rawCode: String

  var toMap: [String: String] {
    [
      "code": code,
      "message": message,
      "rawCode": rawCode
    ]
  }
}

enum ErrorMapper {
  static func normalize(rawCode: String?, fallbackMessage: String) -> NormalizedError {
    let safeRawCode = (rawCode?.isEmpty == false ? rawCode! : "unknown_error")
    let code: String

    if safeRawCode == "missing_session_id" || safeRawCode == "missing_snapshot" {
      code = "invalid_argument"
    } else if safeRawCode == "not_initialized" {
      code = "not_initialized"
    } else if safeRawCode.hasSuffix("_init_failed") {
      code = "init_failed"
    } else if safeRawCode == "tts_not_ready" {
      code = "tts_unavailable"
    } else if safeRawCode.hasPrefix("tts_error") {
      code = "tts_failed"
    } else {
      code = "internal_error"
    }

    return NormalizedError(code: code, message: fallbackMessage, rawCode: safeRawCode)
  }
}
