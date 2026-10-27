import Flutter
import UIKit
import Speech
import AVFoundation

/// Manejador de voz nativa: canales com.nanoai/speech y com.nanoai/speech_partial.
/// Implementa Speech Recognition mediante SFSpeechRecognizer y TTS con AVSpeechSynthesizer.
internal final class NanoSpeechHandler: NSObject, NanoChannelHandler, FlutterStreamHandler {
  private var methodChannel: FlutterMethodChannel?
  private var eventChannel: FlutterEventChannel?
  private var eventSink: FlutterEventSink?

  private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "es_ES"))
  private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
  private var recognitionTask: SFSpeechRecognitionTask?
  private let audioEngine = AVAudioEngine()
  private let speechSynthesizer = AVSpeechSynthesizer()

  func register(with messenger: FlutterBinaryMessenger) {
    methodChannel = FlutterMethodChannel(name: "com.nanoai/speech", binaryMessenger: messenger)
    methodChannel?.setMethodCallHandler { [weak self] (call, result) in
      self?.handle(call: call, result: result)
    }

    eventChannel = FlutterEventChannel(name: "com.nanoai/speech_partial", binaryMessenger: messenger)
    eventChannel?.setStreamHandler(self)
  }

  func detach() {
    stopListening()
    methodChannel?.setMethodCallHandler(nil)
    eventChannel?.setStreamHandler(nil)
    methodChannel = nil
    eventChannel = nil
  }

  private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isAvailable":
      result(speechRecognizer?.isAvailable ?? false)

    case "startListening":
      startListening(result: result)

    case "stop":
      stopListening()
      result(true)

    case "cancel":
      cancelListening()
      result(true)

    case "speak":
      let text = (call.arguments as? [String: Any])?["text"] as? String ?? ""
      speak(text: text)
      result(true)

    case "stopSpeaking":
      speechSynthesizer.stopSpeaking(at: .immediate)
      result(true)

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func startListening(result: @escaping FlutterResult) {
    if audioEngine.isRunning {
      stopListening()
    }

    guard let recognizer = speechRecognizer, recognizer.isAvailable else {
      result(FlutterError(code: "speech_unavailable", message: "SpeechRecognizer no disponible", details: nil))
      return
    }

    do {
      let audioSession = AVAudioSession.sharedInstance()
      try audioSession.setCategory(.playAndRecord, mode: .measurement, options: .duckOthers)
      try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

      recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
      guard let request = recognitionRequest else {
        result(FlutterError(code: "request_failed", message: "No se pudo crear recognition request", details: nil))
        return
      }
      request.shouldReportPartialResults = true

      let inputNode = audioEngine.inputNode
      let recordingFormat = inputNode.outputFormat(forBus: 0)
      inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] (buffer, _) in
        self?.recognitionRequest?.append(buffer)
      }

      audioEngine.prepare()
      try audioEngine.start()

      recognitionTask = recognizer.recognitionTask(with: request) { [weak self] (taskResult, error) in
        if let text = taskResult?.bestTranscription.formattedString {
          self?.eventSink?(["partial": text, "isFinal": taskResult?.isFinal ?? false])
        }
        if error != nil || (taskResult?.isFinal ?? false) {
          self?.stopListening()
        }
      }
      result(true)
    } catch {
      result(FlutterError(code: "audio_error", message: error.localizedDescription, details: nil))
    }
  }

  private func stopListening() {
    audioEngine.stop()
    audioEngine.inputNode.removeTap(onBus: 0)
    recognitionRequest?.endAudio()
    recognitionTask?.finish()
    recognitionRequest = nil
    recognitionTask = nil
  }

  private func cancelListening() {
    audioEngine.stop()
    audioEngine.inputNode.removeTap(onBus: 0)
    recognitionRequest?.endAudio()
    recognitionTask?.cancel()
    recognitionRequest = nil
    recognitionTask = nil
  }

  private func speak(text: String) {
    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
    let utterance = AVSpeechUtterance(string: text)
    utterance.voice = AVSpeechSynthesisVoice(language: "es-ES")
    utterance.rate = AVSpeechUtteranceDefaultSpeechRate
    speechSynthesizer.speak(utterance)
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    self.eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    self.eventSink = nil
    return nil
  }
}
