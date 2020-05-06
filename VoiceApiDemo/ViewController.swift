//
//  ViewController.swift
//  VoiceApiDemo
//
//  Created by Dave Duprey on 23/04/2020.
//  Copyright © 2020 Dave Duprey. All rights reserved.
//

import UIKit
import CoreLocation


class ViewController: UIViewController {

  /// Button to allow user to record
  @IBOutlet weak var microphoneButton: UIButton!

  /// The Voice API, duh...
  var voiceApi: VoiceApi?

  /// microphone for recording voice
  var microphone:Microphone?

  
  
  // MARK: Setup

  
  /// initialize the voice stuff
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidLoad()

    // NOTE: Register for your API key using the link under "Getting Started" at https://developer.what3words.com/voice-api
    //       As of May 2020, the Voice API is in beta, and therefore, access is granted upon request
    //       Please contact us at voiceapi@what3words.com to enable the Voice API for your account.
    let key = "YourApiKey"  // change this to your API key
    
    // Initialize the Voice API
    voiceApi   = VoiceApi(apiKey: key)

    // tell the Voice API who to call when suggestions, errors and socket closures happen
    voiceApi?.suggestions = { (suggestions) in self.voiceSuggestionsArrived(suggestions: suggestions) }
    voiceApi?.closed = { (reason) in self.closed(reason: reason) }
    voiceApi?.error = { (message) in self.errorHappened(message: message) }

    // instantiate the microphone and tell it where to send the audio data
    microphone = Microphone()
    microphone?.sampleArrived = { data in self.sampleArrivedFromMic(data: data) }  // direct all sound data to a function

    // set the button representing the mic to indicate it is ready
    microphoneButton.isSelected = false
  }

   
  
  @IBAction func microphoneButtonPressed(_ sender: Any) {
    // change the button image
    microphoneButton.isSelected = true
    
    // start the voice recognition
    startListening()
    
    // remove any previos results from the screen
    removeSuggestionLabels()
  }
  
  
  
  // MARK: Start and Stop the Voice Recognition

  /// start the voice recognition by opening the connection to the voice api server, and starting up the microphone
  func startListening() {
    // audio settings
    let sampleRate   = microphone!.sampleRate()
    let encoding     = "pcm_f32le"

    // autosuggest settings
    // play with these settings, any of them can ommited using 'nil'
    // the parameters in open() are optional (except samplerate)
    let language:String                      = "en"
    let resultCount:Int?                     = 8
    let focus:CLLocationCoordinate2D?        = nil // CLLocationCoordinate2D(latitude: 51.520847, longitude: -0.195521)
    let focusCount:Int?                      = 3
    let country:String?                      = nil // "GB"
    let circleCenter:CLLocationCoordinate2D? = nil // CLLocationCoordinate2D(latitude: 51.520847, longitude: -0.195521)
    let circleRadius:Double?                 = nil // 1000.00

    voiceApi?.open(sampleRate: sampleRate, encoding: encoding, language: language, resultCount: resultCount, focus: focus, focusCount: focusCount, country: country, circleCenter: circleCenter, cicleRadius: circleRadius)
    microphone?.start()
  }
  
  
  /// stop the voice regognition by stopping the microphone and closing the voice api connection
  func stopListening() {
    microphone?.stop()
    voiceApi?.close()
  }
  
  
  
  // MARK: VoiceAPI Events
  
  
  /// called when the voice api has some three word address suggestions
  ///   - parameter suggestions: array containing address suggestions
  func voiceSuggestionsArrived(suggestions: [VoiceSuggestion]) {
    stopListening()
    microphoneButton.isSelected = false

    addSuggestionLabels(suggestions: suggestions)
  }
  
  
  /// called when the websocket was closed
  ///   - parameter reason: a textual description of why the socket was closed
  private func closed(reason:String) {
    if reason.contains("InvalidKey") {
      errorHappened(message: reason)
    }

    print("Server closed connection: ", reason)
  }

  
  /// called when a communication error happened
  ///   - parameter message: text explaining the nature of the error
  func errorHappened(message: String) {
    print(message)
    microphone?.stop()
    voiceApi?.close()

    DispatchQueue.main.async {
      self.microphoneButton.isSelected = false
      
      let alert = UIAlertController(title: "Error", message: message, preferredStyle: UIAlertController.Style.alert)
      alert.addAction(UIAlertAction(title: "Okay", style: .cancel, handler: { _ in }))
      self.present(alert, animated: true, completion: nil)

    }

  }

  
  
  // MARK: Microphone Events

  
  /// called when audio data comes in; we then send it to the VoiceApi
  ///   - parameter data: the raw audio smaple data as a block of Float values
  func sampleArrivedFromMic(data:UnsafeBufferPointer<Float>) {
    if (data.baseAddress != nil) {
      voiceApi?.send(samples: Data(buffer: data))
    }
  }
  

  // MARK: Interface Stuff
  
  
  class SuggestionLabel: UILabel {
  }
  
  
  /// given an array of suggestions, we throw them up on the scren
  ///   - parameter suggestions: array containing address suggestions
  func addSuggestionLabels(suggestions: [VoiceSuggestion]) {
    
    let heightIncrement:CGFloat = 32.0
    
    var position = microphoneButton.center
    position.y += microphoneButton.frame.size.height

    for suggestion in suggestions {
      let suggestionLabel = SuggestionLabel(frame: CGRect(x: position.x, y: position.y, width: view.frame.size.width * 0.8, height: heightIncrement))
      suggestionLabel.text = flag(suggestion.country ?? "") + " " + (suggestion.words ?? "----.----.----")
      suggestionLabel.center = position
      suggestionLabel.textAlignment = .center
      suggestionLabel.textColor = .white
      suggestionLabel.font = UIFont(name: "Helvetica", size: 24.0)
      suggestionLabel.adjustsFontSizeToFitWidth = true
      suggestionLabel.minimumScaleFactor = 0.5
      view.addSubview(suggestionLabel)

      position.y += heightIncrement
    }
  }
  

  /// remove any suggestions previously put on the scrren.  in this minimal example all UILabels on screen are three word addresses
  func removeSuggestionLabels() {
    for subviews in self.view.subviews as [UIView] {
      if let suggestionLabel = subviews as? SuggestionLabel {
        suggestionLabel.removeFromSuperview()
      }
    }

  }
  
  
  /// given a two letter country code, find the emogi for the flag of that country, this is a quick and dirty way to do this, probably not best for production code
  ///   - parameter country: ISO 3166-1 alpha-2 country code
  func flag(_ country:String) -> String {
    if country.uppercased() == "ZZ" {
      return "🌊"
    }
    
    var s = ""
    for v in country.uppercased().unicodeScalars {
      s.unicodeScalars.append(UnicodeScalar(UInt32(127397) + v.value)!)
    }
    return s
  }
  
  
  /// tidy up the screen if it rotates or does anything shape changey
  override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
    removeSuggestionLabels()
  }
  

  
}

