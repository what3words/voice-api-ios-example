//
//  VoiceApi.swift
//  VoiceApiDemo
//
//  Created by Dave Duprey on 23/04/2020.
//  Copyright © 2020 Dave Duprey. All rights reserved.
//

import Foundation
import CoreLocation




class VoiceApi {

  // MARK: Variables

  /// the VoiceAPI endpoint
  let endpoint = "wss://voiceapi.what3words.com/v1/autosuggest"

  /// the VoiceAPI API key
  var key = ""
  
  /// default language
  var language           = "en"

  /// Socket session
  var socket: WebSocket?

  /// we need to count the number of data packages sent for the endSamples() function
  var sequenceNumber = 0
  
  // MARK: Callbacks
  
  /// a callback block for when recognition is complete
  var suggestions: ([VoiceSuggestion]) -> ()? = { _ in }
  
  /// a callback block for when an error happens
  var closed: (String) -> () = { _ in }
  
  /// a callback block for when an error happens
  var error: (String) -> () = { _ in }

  
  // MARK: Initialization

  
  /// init with the API key for the voice service
  init(apiKey: String) {
    key = apiKey
  }


  // MARK: Open and Close Socket
  
  
  /// open a websocket and communicate the parameters to Voice API
  /// autoSuggest parameters are passed in the URL querystring, and audio parameters are passed as a JSON message
  ///   - parameter sampleRate: the sample rate of the recording
  ///   - parameter encoding: the encoding of the audio, pcm_f32le (32 bit float little endian), pcm_s16le (16 bit signed int little endian), mulaw (8 bit mu-law encoding) supported
  ///   - parameter language: the two leeter langauge code fo rthe language being spoken
  ///   - parameter resultCount: The number of AutoSuggest results to return. A maximum of 100 results can be specified, if a number greater than this is requested, this will be truncated to the maximum. The default is 3
  ///   - parameter focus: This is a location, specified as a latitude (often where the user making the query is). If specified, the results will be weighted to give preference to those near the focus. For convenience, longitude is allowed to wrap around the 180 line, so 361 is equivalent to 1.
  ///   - parameter focusCount: Specifies the number of results (must be less than or equal to n-results) within the results set which will have a focus. Defaults to n-results. This allows you to run autosuggest with a mix of focussed and unfocussed results, to give you a "blend" of the two. This is exactly what the old V2 standarblend did, and standardblend behaviour can easily be replicated by passing n-focus-results=1, which will return just one focussed result and the rest unfocussed.
  ///   - parameter country: only show results for thi country
  ///   - parameter cicleCenter: Restrict autosuggest results to a circle, specified by focus
  ///   - parameter cicleRadius: Restrict autosuggest results to a circle, specified by focus
  func open(sampleRate:Int, encoding:String = "pcm_f32le", language:String = "en", resultCount:Int? = nil, focus:CLLocationCoordinate2D? = nil, focusCount:Int? = nil, country:String? = nil, circleCenter:CLLocationCoordinate2D? = nil, cicleRadius:Double? = nil) {

    // don't allow socket to be opened if it is already in use
    if socket != nil {
      error("Socket is already open")
      
    // we are good to go
    } else {
      
      // Build the URL for the call begining with the api key and including all the AutoSuggest paramters, and use that to initialze the socket
      let urlString = endpoint + "?key=\(key)&" + makeQueryStringFromAutoSuggestParameters(language: language, resultCount: resultCount, focus: focus, focusCount: focusCount, country: country, circleCenter: circleCenter, cicleRadius: cicleRadius)
      socket = WebSocket(urlString)
      
      // configure callback events and send the handshake
      if let s = socket {
        // Assign some websocket events to member functions
        s.event.close   = { code, reason, clean in self.closed(reason) }
        s.event.error   = { error in self.error(error.localizedDescription) }
        s.event.message = { message in self.recieved(message: message) }

        // send server the audio parameters with the initial message
        let handshakeMessage = "{\"message\": \"StartRecognition\", \"audio_format\": { \"type\": \"raw\", \"encoding\": \"\(encoding)\", \"sample_rate\": \(sampleRate) } }"
        socket?.send(text: handshakeMessage)
        
      // socket failed
      } else {
        self.error("Couldn't create websocket")
      }
    }
  }

  
  /// close the socket
  func close() {
    socket?.close()
    socket = nil
  }
  

  
  // MARK: Send and Recieve
  

  /// send a block of 32 bit floating point audio sample data
  func send(samples: Data) {

    if let s = socket {
      s.send(samples)
    }

    // if the socket isn't there
    else {
      self.error("Couldn't send data because the socket is closed")
    }
  }
  

  
  /// All incoming websocket messages come through here
  ///   - parameter message: the message from the socket
  private func recieved(message: Any) {
    switch message {
      case is String:
        self.recieved(text: message as! String)  // inform the caller that a message came in.
        
      case is Data:
        error("Unexpected data was returned by server")
        
      default:
        error("An unexpected data type was returned by server")
    }
  }


  /// tell the server that we are not going to send anymore audio
  func endSamples() {
    socket?.send(text: "{\"message\":\"EndOfStream\",\"last_seq_no\":\(sequenceNumber)}")
  }

    
  /// parse with incoming json, and send suggestions to whomever is interested
  private func recieved(text:String) {
    let jsonDecoder = JSONDecoder()
    if let suggestionArray = try? jsonDecoder.decode(VoiceApiSuggestions.self, from: text.data(using: .utf8)!).suggestions {
      suggestions(suggestionArray)
    }
  }

  
  // MARK: Utility
  
  
  /// make a querystring for a URL using the provided parameters
  ///   - parameter language: the two leeter langauge code fo rthe language being spoken
  ///   - parameter resultCount: The number of AutoSuggest results to return. A maximum of 100 results can be specified, if a number greater than this is requested, this will be truncated to the maximum. The default is 3
  ///   - parameter focus: This is a location, specified as a latitude (often where the user making the query is). If specified, the results will be weighted to give preference to those near the focus. For convenience, longitude is allowed to wrap around the 180 line, so 361 is equivalent to 1.
  ///   - parameter focusCount: Specifies the number of results (must be less than or equal to n-results) within the results set which will have a focus. Defaults to n-results. This allows you to run autosuggest with a mix of focussed and unfocussed results, to give you a "blend" of the two. This is exactly what the old V2 standarblend did, and standardblend behaviour can easily be replicated by passing n-focus-results=1, which will return just one focussed result and the rest unfocussed.
  ///   - parameter country: only show results for thi country
  ///   - parameter cicleCenter: Restrict autosuggest results to a circle, specified by focus
  ///   - parameter cicleRadius: Restrict autosuggest results to a circle, specified by focus
  private func makeQueryStringFromAutoSuggestParameters(language:String, resultCount:Int? = nil, focus:CLLocationCoordinate2D? = nil, focusCount:Int? = nil, country:String? = nil, circleCenter:CLLocationCoordinate2D? = nil, cicleRadius:Double? = nil) -> String {

    var queryString = ""
    
    // set the language
    self.language = language
    if self.language == "" {
      self.language = "en" // default to english
    }
    
    // set the language querystring parameter
    queryString += "&voice-language=\(self.language)"
    
    // set the location querystring parameter if there is one
    if let f = focus   {
      queryString += "&focus=" + String(f.latitude) + "," + String(f.longitude)
      
      // set the focus count querystring parameter if there is one
      if let fc = focusCount {
        queryString += "&n-focus-results=\(fc)"
      }
    }
    
    // set the circle bound querystring parameter if there is one
    if let c = circleCenter, let radius = cicleRadius {
        queryString += "&clip-to-circle=" + String(c.latitude) + "," + String(c.longitude) + "," + String(radius)
    }
    
    // set the result count querystring parameter if there is one
    if let count = resultCount  {
      queryString += "&n-results=" + String(count)
    }
    
    // set the country querystring parameter if there is one
    if let c = country  {
      queryString += "&clip-to-country=" + c
    }

    return queryString
  }
  

}



/// Helper object representing a W3W suggestion
struct VoiceSuggestion : Codable {
  let country : String? // ISO 3166-1 alpha-2 country code
  let nearestPlace : String?  // text description of a nearby place
  let words : String? // the three word address
  let distanceToFocusKm : Int? // number of kilometers to the nearest place
  let rank : Int? // indicates this suggestion's place in list from most probable to least probable match
  let language : String? // two letter language code
  
  enum CodingKeys: String, CodingKey {
    
    case country = "country"
    case nearestPlace = "nearestPlace"
    case words = "words"
    case distanceToFocusKm = "distanceToFocusKm"
    case rank = "rank"
    case language = "language"
  }
  
  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    country = try values.decodeIfPresent(String.self, forKey: .country)
    nearestPlace = try values.decodeIfPresent(String.self, forKey: .nearestPlace)
    words = try values.decodeIfPresent(String.self, forKey: .words)
    distanceToFocusKm = try values.decodeIfPresent(Int.self, forKey: .distanceToFocusKm)
    rank = try values.decodeIfPresent(Int.self, forKey: .rank)
    language = try values.decodeIfPresent(String.self, forKey: .language)
  }
  
}


/// helper object for decoding JSON using Codable
struct VoiceApiSuggestions : Codable {
  let message : String?
  let suggestions : [VoiceSuggestion]?
  
  enum CodingKeys: String, CodingKey {
    
    case message = "message"
    case suggestions = "suggestions"
  }
  
  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    message = try values.decodeIfPresent(String.self, forKey: .message)
    suggestions = try values.decodeIfPresent([VoiceSuggestion].self, forKey: .suggestions)
  }
  
}


