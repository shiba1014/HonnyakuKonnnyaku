//
//  ViewModel.swift
//  HonyakuKonnnyaku
//
//  Created by Paul McCartney on 2018/07/03.
//  Copyright © 2018年 Satsuki Hashiba. All rights reserved.
//

import Foundation
import AVFoundation
import SpeechToTextV1
import TextToSpeechV1
import LanguageTranslatorV3
import ReactiveSwift
import Result

final class ViewModel {
    struct Credentials {
        static let SpeechToTextUsername = "b6fea638-efab-4b41-bfed-941bc656f91d"
        static let SpeechToTextPassword = "oywmIDGVwQoO"
        static let languageTranslatorAPIKey = "ySCIhP998zD3ielGMesCtfForJjuPKs4VOik3y_sDi_1"
        static let TextToSpeechUsername = "eed8afd5-7294-49c3-a2ff-7de77d98c9c5"
        static let TextToSpeechPassword = "1BNXwreFAXqC"
    }
    
    enum Language: Int {
        case japanese
        case chinese
        case korean
        
        func title() -> String {
            switch self {
            case .japanese: return "日本語"
            case .chinese: return "中国語"
            case .korean: return "韓国語"
            }
        }
        
        func speechToTextModel() -> String {
            switch self {
            case .japanese: return "ja-JP_BroadbandModel"
            case .chinese: return "zh-CN_BroadbandModel"
            case .korean: return "ko-KR_BroadbandModel"
            }
        }
        
        func translateModelId() -> String {
            switch self {
            case .japanese: return "ja-en"
            case .chinese: return "zh-en"
            case .korean: return "ko-en"
            }
        }
        
        func translateSource() -> String {
            switch self {
            case .japanese: return "ja"
            case .chinese: return "zh"
            case .korean: return "ko"
            }
        }
        
        static let elements: [Language] = [.japanese, .chinese, .korean]
    }
    
    private let speechToText: SpeechToText
    private var accumulator: SpeechRecognitionResultsAccumulator
    
    private let languageTranslator: LanguageTranslator
    
    private let textToSpeech: TextToSpeech
    
    private let isStreamingProperty: MutableProperty<Bool> = .init(false)
    private let isTranslatingProperty: MutableProperty<Bool> = .init(false)
    private let originalTextStream = Signal<String, NoError>.pipe()
    private let translatedTextStream = Signal<String, NoError>.pipe()
    private var selectedLanguage: Language = .japanese
    
    init() {
        speechToText = SpeechToText(username: Credentials.SpeechToTextUsername,
                                    password: Credentials.SpeechToTextPassword)
        accumulator = SpeechRecognitionResultsAccumulator()
        
        languageTranslator = LanguageTranslator(version: "2018-07-03",
                                                apiKey: Credentials.languageTranslatorAPIKey)
        
        textToSpeech = TextToSpeech(username: Credentials.TextToSpeechUsername,
                                    password: Credentials.TextToSpeechPassword)
    }
    
    func tappedStreaming() {
        if !isStreamingProperty.value {
            startStreaming()
            isStreamingProperty.value = true
        } else {
            translate(text: accumulator.bestTranscript)
            stopStreaming()
            isStreamingProperty.value = false
        }
    }
    
    func startStreaming() {
        var settings = RecognitionSettings(contentType: "audio/ogg;codecs=opus")
        settings.interimResults = true
        speechToText.recognizeMicrophone(settings: settings,
                                         model: selectedLanguage.speechToTextModel())
        { results in
            self.accumulator.add(results: results)
            self.originalTextStream.input.send(value: self.accumulator.bestTranscript)
        }
    }
    
    func stopStreaming() {
        speechToText.stopRecognizeMicrophone()
        accumulator = SpeechRecognitionResultsAccumulator()
    }
    
    private func translate(text: String) {
        isTranslatingProperty.value = true
        let request = TranslateRequest(text: [text], modelID: selectedLanguage.translateModelId(), source: selectedLanguage.translateSource(), target: "en")
        languageTranslator.translate(request: request) { [unowned self] result in
            self.isTranslatingProperty.value = false
            guard let translation = result.translations.first else {
                self.translatedTextStream.input.send(value: "翻訳に失敗しました")
                return
            }
            self.translatedTextStream.input.send(value: translation.translationOutput)
            self.speech(text: translation.translationOutput)
        }
    }
    
    private func speech(text: String) {
        var audioPlayer = AVAudioPlayer()
        textToSpeech.synthesize(text: text, accept: "audio/wav", failure: { error in
            print("Synthesize error: \(error)")
        }) { data in
            do {
                audioPlayer = try AVAudioPlayer(data: data)
                audioPlayer.prepareToPlay()
                audioPlayer.play()
                print("play")
            } catch let error {
                print("AudioPlayer error: \(error)")
            }
        }
    }
    
    func changedSegmented(index: Int) {
        selectedLanguage = Language(rawValue: index) ?? .japanese
    }
    
    var isStreaming: SignalProducer<Bool, NoError> {
        return isStreamingProperty.producer
    }
    
    var isTranslating: SignalProducer<Bool, NoError> {
        return isTranslatingProperty.producer
    }
    
    var originalText: Signal<String, NoError> {
        return originalTextStream.output
    }
    
    var translatedText: Signal<String, NoError> {
        return translatedTextStream.output
    }
    
    var languageArray: [String] {
        return Language.elements.map { $0.title() }
    }
}
