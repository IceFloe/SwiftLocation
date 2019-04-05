//
//  FindPlaceRequest.swift
//  SwiftLocation
//
//  Created by danielemargutti on 28/10/2017.
//  Copyright © 2017 Daniele Margutti. All rights reserved.
//

import Foundation

public typealias FindPlaceRequest_Success = (([PlaceMatch]) -> (Void))
public typealias FindPlaceRequest_Failure = ((LocationError) -> (Void))

/// Public protocol for place find request
public protocol FindPlaceRequest {
	
	/// Success handler
	var success: FindPlaceRequest_Success? { get set }
	
	/// Failure handler
	var failure: FindPlaceRequest_Failure? { get set }
	
	/// Timeout interval
	var timeout: TimeInterval { get set }
	
	/// Execute operation
	func execute()
	
	/// Cancel current execution (if any)
	func cancel()
}

/// Find Place with Google
public class FindPlaceRequest_Google: FindPlaceRequest {
	
	/// session task
	private var task: JSONOperation? = nil
	
	/// Success callback
	public var success: FindPlaceRequest_Success?
	
	/// Failure callback
	public var failure: FindPlaceRequest_Failure?
	
	/// Timeout interval
	public var timeout: TimeInterval
	
	/// Input to search
	public private(set) var input: String

    /// Language in which the results are displayed
    public private(set) var language: FindPlaceRequest_Google_Language?
	
	/// Init new find place operation
	///
	/// - Parameters:
	///   - operation: operation to execute
	///   - timeout: timeout, `nil` uses default timeout of 10 seconds
    public init(input: String, timeout: TimeInterval? = nil, language: FindPlaceRequest_Google_Language? = nil) {
		self.input = input
		self.timeout = timeout ?? 10
        self.language = language ?? FindPlaceRequest_Google_Language.english
	}
	
	public func execute() {
		guard let APIKey = Locator.api.googleAPIKey else {
			self.failure?(LocationError.missingAPIKey(forService: "google"))
			return
		}
        let lang = language?.rawValue ?? "en"
		let url = URL(string: "https://maps.googleapis.com/maps/api/place/autocomplete/json?input=\(input.urlEncoded)&language=\(lang)&key=\(APIKey)")!
		self.task = JSONOperation(url, timeout: self.timeout)
		self.task?.onFailure = { [weak self] err in
            guard let `self` = self else { return }
			self.failure?(err)
		}
		self.task?.onSuccess = { [weak self] json in
            guard let `self` = self else { return }
            guard let json = (try? JSONSerialization.jsonObject(with: json, options: [])) as? [String: Any],
                let status = json["status"] as? String, status != "OK" else {
				self.failure?(LocationError.other("Wrong google response"))
				return
			}
            guard let anyData = json["predictions"],
                let data = try? JSONSerialization.data(withJSONObject: anyData, options: []),
                let places = try? PlaceMatch.load(list: data) else {
                self.failure?(LocationError.dataParserError)
                return
            }
			self.success?(places)
		}
		self.task?.execute()
	}
	
	public func cancel() {
		self.task?.cancel()
	}
	
}

/// Google Autocomplete supported languages
///
/// - arabic: Arabic
/// - bulgarian: Bulgarian
/// - bengali: Bengali
/// - catalan: Catalan
/// - czech: Czech
/// - danish: Danish
/// - dutch: Dutch
/// - german: German
/// - greek: Greek
/// - english: English
/// - english_AU: English (Australia)
/// - english_GB: English (Great Britain)
/// - spanish: Spanish
/// - basque: Basque
/// - chinese_simplified: Chinese (Simplified)
/// - chinese_traditional: Chinese (Traditional)
/// - farsi: Farsi
/// - finnish: Finnish
/// - filipino: Filipino
/// - french: French
/// - galician: Galician
/// - gujarati: Gujarati
/// - hindi: Hindi
/// - croatian: Croatian
/// - hungarian: Hungarian
/// - indonesian: Indonesian
/// - italian: Italian
/// - hebrew: Hebrew
/// - japanese: Japanese
/// - kannada: Kannada
/// - korean: Korean
/// - lithuanian: Lithuanian
/// - latvian: Latvian
/// - malayalam: Malayalam
/// - marathi: Marathi
/// - norwegian: Norwegian
/// - polish: Polish
/// - portuguese: Portuguese
/// - portuguese_BR: Portuguese (Brasil)
/// - portuguese_PT: portuguese (Portugal)
/// - romanian: Romanian
/// - russian: Russian
/// - slovak: Slovak
/// - slovenian: Slovenian
/// - serbian: Serbian
/// - swedish: Swedish
/// - tamil: Tamil
/// - telugu: Telugu
/// - thai: Hhai
/// - tagalog: Tagalog
/// - turkish: Turkish
/// - ukrainian: Ukrainian
/// - vietnamese: Vietnamese
public enum FindPlaceRequest_Google_Language: String {
    case arabic = "ar"
    case bulgarian = "bg"    
    case bengali = "bn"
    case catalan    = "ca"
    case czech = "cs"
    case danish = "da"
    case dutch = "nl"
    case german = "de"
    case greek = "el"    
    case english = "en"    
    case english_AU = "en-AU"
    case english_GB = "en-GB"
    case spanish = "es"
    case basque = "eu"    
    case chinese_simplified = "zh-CN"
    case chinese_traditional = "zh-TW"
    case farsi = "fa"
    case finnish = "fi"
    case filipino = "fil"
    case french = "fr"
    case galician    = "gl"
    case gujarati = "gu"
    case hindi = "hi"
    case croatian = "hr"
    case hungarian = "hu"
    case indonesian = "id"
    case italian = "it"
    case hebrew = "iw"
    case japanese = "ja"
    case kannada = "kn"
    case korean = "ko"
    case lithuanian = "lt"
    case latvian = "lv"
    case malayalam = "ml"
    case marathi = "mr"
    case norwegian = "no"
    case polish = "pl"
    case portuguese = "pt"
    case portuguese_BR = "pt-BR"
    case portuguese_PT = "pt-PT"
    case romanian = "ro"
    case russian = "ru"
    case slovak = "sk"
    case slovenian = "sl"
    case serbian = "sr"
    case swedish = "sv"
    case tamil = "ta"
    case telugu = "te"
    case thai = "th"
    case tagalog = "tl"
    case turkish = "tr"
    case ukrainian = "uk"
    case vietnamese = "vi"
}

/// Identify a single match entry for a place search
public class PlaceMatch: Decodable {

    enum CodingKeys: String, CodingKey {
        case placeID = "place_id"
        case name = "description"
        case text = "structured_formatting"
        case types
    }

    struct PlaceMatchText: Decodable {
        /// Main text of the place
        let mainText: String
        let secondaryText: String

        enum CodingKeys: String, CodingKey {
            case mainText = "main_text"
            case secondaryText = "secondary_text"
        }
    }

    private let text: PlaceMatchText
	
	/// Identifier of the place
	public let placeID: String
	
	/// Name of the place
	public let name: String
	
	/// Main text of the place
    public var mainText: String {
        return text.mainText
    }
	
	/// Secondary text of the place
    public var secondaryText: String {
        return text.secondaryText
    }
	
	/// Place types string (google)
	public internal(set) var types: [String]
	
	/// Place detail cache
	public private(set) var detail: Place?
	
    public static func load(list: Data) throws -> [PlaceMatch] {
		return try JSONDecoder().decode([PlaceMatch].self, from: list)
	}
	
	public func detail(timeout: TimeInterval? = nil,
	                   onSuccess: @escaping ((Place) -> (Void)),
	                   onFail: ((LocationError) -> (Void))? = nil) {
		if let p = self.detail {
			onSuccess(p)
			return
		}
		guard let APIKey = Locator.api.googleAPIKey else {
			onFail?(LocationError.missingAPIKey(forService: "google"))
			return
		}
		let url = URL(string: "https://maps.googleapis.com/maps/api/place/details/json?placeid=\(self.placeID)&key=\(APIKey)")!
		let task = JSONOperation(url, timeout: timeout ?? 10)
		task.onSuccess = { [weak self] json in
            guard let `self` = self else { return }
            guard let json = (try? JSONSerialization.jsonObject(with: json, options: [])) as? [String: Any],
            let result = json["result"] as? [String: Any] else {
                onFail?(LocationError.dataParserError)
                return
            }
			self.detail = Place(googleJSON: result)
			onSuccess(self.detail!)
		}
		task.onFailure = { err in
			onFail?(err)
		}
		task.execute()
	}

}
