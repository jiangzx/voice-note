/// The four states of the voice recording state machine.
enum VoiceState {
  /// Not in voice mode. Microphone off, VAD off, ASR off.
  idle,

  /// Voice recording page active. Microphone on, VAD running, ASR not connected.
  /// Zero cloud cost — waiting for speech.
  listening,

  /// VAD detected speech, ASR connected and streaming. Real-time text display.
  recognizing,

  /// ASR complete, NLP parsed. Showing confirmation card, awaiting user action.
  confirming,
}
