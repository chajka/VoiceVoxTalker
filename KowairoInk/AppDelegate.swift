//
//  AppDelegate.swift
//  KowairoInk
//
//  Created by Чайка on 2023/12/12.
//

import Cocoa

let SpeakersURL: String = "http://localhost:50032/v1/speakers"
let ProsodyURL: String = "http://localhost:50032/v1/estimate_prosody"
let SynthesisURL: String = "http://localhost:50032/v1/synthesis"

struct Style: Codable {
	let styleName: String
	let styleId: Int
	let base64Icon: String
}

struct KoeiroInkSpeaker: Codable {
	let speakerName: String
	let speakerUuid: String
	let styles: Array<Style>
	let version: String
}

struct Variation {
	let speakerName: String
	let speakerUuid: String
	let styleName: String
	let styleId: Int
}

struct Text: Codable {
	let text: String
}

struct KoeiroInkMora: Codable {
	let phoneme: String
	let hira: String
	let accent: Int
}

struct KoeiroInkProsody: Codable {
	let plain: Array<String>
	let detail: Array<Array<KoeiroInkMora>>
}

struct KoeiroInkSynthesis: Codable {
	let speakerUuid: String
	let styleId: Int
	let text: String
	let prosodyDetail: Array<Array<KoeiroInkMora>>
	var speedScale: Float
	let volumeScale: Float
	let pitchScale: Float
	let intonationScale: Float
	let prePhonemeLength: Float
	let postPhonemeLength: Float
	let outputSamplingRate: Int
}

let VoiceVoxVoicenamesURL: String = "http://localhost:50021/speakers"
let VoiceVoxQueryURL: String = "http://localhost:50021/audio_query"
let VoicVoxSynthesisURL: String = "http://localhost:50021/synthesis"

struct VoiceVoxFeatures: Codable {
	let permitted_synthesis_morphing: String
}

struct VoiceVoxStyle: Codable {
	let name: String
	let id: Int
}

struct VoiceVoxName: Codable {
	let supported_features: VoiceVoxFeatures
	let name: String
	let speaker_uuid: String
	let styles: Array<VoiceVoxStyle>
	let version: String
}

struct VoiceVoxAqudioQuery: Codable {
	let text: String
	let speaker: Int
}

struct VoiceVoxMora: Codable {
	let text: String
	let consonant: String?
	let consonant_length: Float?
	let vowel: String
	let vowel_length: Float
	let pitch: Float
}

struct VoiceVoxAccentPhrase: Codable {
	let moras: Array<VoiceVoxMora>
	let accent: Int
	let pause_mora: VoiceVoxMora?
	let is_interrogative: Bool?
}

struct VoicVoxAccentQuery: Codable {
	let accent_phrases: Array<VoiceVoxAccentPhrase>
	var speedScale: Float
	let pitchScale: Float
	let intonationScale: Float
	let volumeScale: Float
	let prePhonemeLength: Float
	let postPhonemeLength: Float
	let outputSamplingRate: Int
	let outputStereo: Bool
	let kana: String?
}

enum Talker {
	case KoeiroInk
	case VoiceVox
}

public enum HTTPMethod: String {
	case get = "GET"
	case post = "POST"
	case put = "PUT"
	case delete = "DELETE"
	case patch = "PATCH"
}// end enum httpMehod

internal let ContentTypeKey: String = "Content-type"
internal let ContentTypeJSON: String = "application/json"

public extension URLRequest {
	var method: HTTPMethod? {
		get {
			if let method: String = self.httpMethod {
				return HTTPMethod(rawValue: method)
			}// end get
			return nil
		}// end get
		set {
			if let httpMethod: HTTPMethod = newValue {
				self.httpMethod = httpMethod.rawValue
			} else {
				self.httpMethod = HTTPMethod.get.rawValue
			}// end optional binding check for new value is member of enum HTTPMethod
		}// end set
	}// end computed property extension of URLRequest
}// end of extension of URLRequest

extension DecodingError {
	
	var debugDescription: String {
		return context?.debugDescription ?? ""
	}
	
	var key: String {
		return context?.codingPath.first?.stringValue ?? ""
	}
	
	var context: DecodingError.Context? {
		switch self {
		case .dataCorrupted(let context):
			return context
		case .keyNotFound(_, let context):
			return context
		case .typeMismatch(_, let context):
			return context
		case .valueNotFound(_, let context):
			return context
		default:
			// 上記の4つでcaseをカバレッジできているが、
			// 将来追加の可能性により、defaultがないと警告が出る
			return nil
		}
	}
}

@main
class AppDelegate: NSObject, NSApplicationDelegate, URLSessionDelegate {
		// MARK: Static properties
		// MARK: - Class Method
		// MARK: - Outlets
	@IBOutlet var window: NSWindow!
	@IBOutlet weak var textfieldTextToSpeak: NSTextField!
	@IBOutlet weak var popupVoiceKind: NSPopUpButton!

		// MARK: - Properties
	private let session: URLSession = URLSession(configuration: URLSessionConfiguration.default)
	private var speakersDict: Dictionary<String, Variation> = Dictionary()
	private var talkersDict: Dictionary<String, Talker> = Dictionary()

		// MARK: - Member variables
		// MARK: - Constructor/Destructor
		// MARK: - Override
		// MARK: - Actions
	@IBAction func speak(_ sender: NSButton) {
		let title: String = popupVoiceKind.selectedItem!.title
		let text: String = textfieldTextToSpeak.stringValue
		let talker: Talker = talkersDict[title]!
		Task {
			switch talker {
			case .KoeiroInk:
				await synthesisKoeiroInk(of: title, with: text)
				break
			case .VoiceVox:
				await synthesisVoiceVox(of: title, with: text)
			}
		}
	}
	
		// MARK: - Public methods
		// MARK: - Private methods
	private func synthesisVoiceVox (of title: String, with textToSpeech: String) async {
		let variation: Variation = speakersDict[title]!
		let textURLEncoding : String = textToSpeech.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
		var urlString: String = String(format: "\(VoiceVoxQueryURL)?text=%@&speaker=%d", textURLEncoding, variation.styleId)
		let url: URL = URL(string: urlString)!
		var request: URLRequest = URLRequest(url: url)
		request.method = .post
		request.addValue(ContentTypeJSON, forHTTPHeaderField: ContentTypeKey)
		let query: VoiceVoxAqudioQuery = VoiceVoxAqudioQuery(text: textToSpeech, speaker: variation.styleId)
		do {
			let json: Data = try JSONEncoder().encode(query)
			request.httpBody = json
			var config: URLSessionConfiguration = URLSessionConfiguration.default
			config.timeoutIntervalForRequest = 30
			config.timeoutIntervalForResource = 30
			let sessin: URLSession = URLSession(configuration: config)
			var result: (data: Data, resp: URLResponse) = try await sessin.data(for: request)
			let decoder: JSONDecoder = JSONDecoder()
			var audioQuery: VoicVoxAccentQuery = try decoder.decode(VoicVoxAccentQuery.self, from: result.data)
			audioQuery.speedScale = 1.0
			let jsonVoice: Data = try JSONEncoder().encode(audioQuery)
			urlString = String(format: "\(VoicVoxSynthesisURL)?speaker=%d", variation.styleId)
			request = URLRequest(url: URL(string: urlString)!)
			request.method = .post
			request.setValue(ContentTypeJSON, forHTTPHeaderField: ContentTypeKey)
			request.httpBody = jsonVoice
			let wav: (data: Data, resp: URLResponse) = try await sessin.data(for: request)
			if let resp: HTTPURLResponse = wav.resp as? HTTPURLResponse, resp.statusCode == 200 {
				let wavURL: URL = URL(string:"file://" +  NSHomeDirectory())!.appendingPathComponent("Downloads/test").appendingPathExtension("wav")
				try wav.data.write(to: wavURL)
			}
		} catch let error as DecodingError {
			print(error.key)
			print(error.debugDescription)
			print(error.localizedDescription)
		} catch let error {
			print(error)
		}
	}

	private func synthesisKoeiroInk (of title: String, with textToSpeech: String) async {
		let url: URL = URL(string: ProsodyURL)!
		var request: URLRequest = URLRequest(url: url)
		request.httpMethod = "POST"
		request.addValue(ContentTypeJSON, forHTTPHeaderField: ContentTypeKey)
		let text: Text = await Text(text: textfieldTextToSpeak.stringValue)
		let encoder: JSONEncoder = JSONEncoder()
		do {
			let jsonData: Data = try encoder.encode(text)
			request.httpBody = jsonData
			let result: (data: Data, resp: URLResponse) = try await session.data(for: request)
			let decoder: JSONDecoder = JSONDecoder()
			let prosody: KoeiroInkProsody = try decoder.decode(KoeiroInkProsody.self, from: result.data)
			if let speaker: Variation = speakersDict[title] {
				let synthesis: KoeiroInkSynthesis = KoeiroInkSynthesis(speakerUuid: speaker.speakerUuid, styleId: speaker.styleId, text: textToSpeech, prosodyDetail: prosody.detail, speedScale: 1, volumeScale: 1, pitchScale: 0, intonationScale: 1, prePhonemeLength: 0.1, postPhonemeLength: 0.1, outputSamplingRate: 24000)
				let config: URLSessionConfiguration = URLSessionConfiguration.default
				config.timeoutIntervalForRequest = 10.0
				config.timeoutIntervalForRequest = 10.0
				let session: URLSession = URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue.current)
				let synthURL = URL(string: SynthesisURL)!
				var synthRequest: URLRequest = URLRequest(url: synthURL, timeoutInterval: 10.0)
				synthRequest.httpMethod = "POST"
				synthRequest.addValue(ContentTypeJSON, forHTTPHeaderField: ContentTypeKey)
				let synthJson: Data = try encoder.encode(synthesis)
				synthRequest.httpBody = synthJson
				let wav: (data: Data, resp: URLResponse) = try await session.data(for: synthRequest)
				if let resp: HTTPURLResponse = wav.resp as? HTTPURLResponse, resp.statusCode == 200 {
					let wavURL: URL = URL(string:"file://" +  NSHomeDirectory())!.appendingPathComponent("Downloads/test").appendingPathExtension("wav")
					try wav.data.write(to: wavURL)
				}
			}
		} catch let error {
			print(error)
		}

	}// end func getPhonetics

	private func getSpeakers () async {
		let speakerURL: URL = URL(string: SpeakersURL)!
		var request: URLRequest = URLRequest(url: speakerURL, timeoutInterval: 2.0)
		do {
			let result: (data: Data, resp: URLResponse) = try await session.data(for: request)
			let decoder: JSONDecoder = JSONDecoder()
			let speakers: Array<KoeiroInkSpeaker> = try decoder.decode(Array<KoeiroInkSpeaker>.self, from: result.data)
			for speaker in speakers {
				for style in speaker.styles {
					let title: String = String(format: "%@(%@)", speaker.speakerName, style.styleName)
					let variation: Variation = Variation(speakerName: speaker.speakerName, speakerUuid: speaker.speakerUuid, styleName: style.styleName, styleId: style.styleId)
					speakersDict[title] = variation
					talkersDict[title] = .KoeiroInk
				}// end foreach style
			}// end foreach speaker
		} catch let error {
			print(error)
		}
		do {
			request = URLRequest(url: URL(string: VoiceVoxVoicenamesURL)!)
			let result: (data: Data, resp: URLResponse) = try await session.data(for: request)
			let decoder: JSONDecoder = JSONDecoder()
			let names: Array<VoiceVoxName> = try decoder.decode(Array<VoiceVoxName>.self, from: result.data)
			for name: VoiceVoxName in names {
				for style: VoiceVoxStyle in name.styles {
					let title: String = String(format: "%@(%@)", name.name, style.name)
					let variation: Variation = Variation(speakerName: name.name, speakerUuid: name.speaker_uuid, styleName: style.name, styleId: style.id)
					speakersDict[title] = variation
					talkersDict[title] = .VoiceVox
				}
			}
		} catch let error {
			print(error)
		}
	}// end func getSpeakers

		// MARK: - Delegates


	func applicationDidFinishLaunching(_ aNotification: Notification) {
		Task {
			await getSpeakers()
			var variation: Array<String> = Array()
			for speaker in speakersDict.keys {
				variation.append(speaker)
			}
			variation = variation.sorted()
			popupVoiceKind.removeAllItems()
			popupVoiceKind.addItems(withTitles: variation)
		}
	}

	func applicationWillTerminate(_ aNotification: Notification) {
		// Insert code here to tear down your application
	}

	func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
		return true
	}


}

