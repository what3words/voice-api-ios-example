//
//  Microphone.swift
//  VoiceApiDemo
//
//  Created by Dave Duprey on 22/10/2019.
//  Copyright © 2019 Dave Duprey. All rights reserved.
//

import Foundation
import AVFoundation


/// Manages the device microphone
class Microphone {
  
  /// CoreAudio interface
  var audioEngine = AVAudioEngine()
  /// handle to a microphone
  var mic:          AVAudioInputNode!
  /// callback for when the mic has new audio date
  var sampleArrived: (UnsafeBufferPointer<Float>) -> ()?
  /// keep track as to whether 'mic' has been connected to the audio system
  var audioIsTapped = false
  /// a current amplitude
  var amplitude = 0.0
  /// the maximum amplitude so far
  var maxAmplitude = 0.0
  /// the minimum amplitude so far
  var minAmplitude = 0.0
  
  
  // MARK: Initialization
  
  init() {
    mic = audioEngine.inputNode
    sampleArrived = { _ in }
    
    do {
      try AVAudioSession.sharedInstance().setCategory(.record)
      try AVAudioSession.sharedInstance().setActive(true)
    } catch {
      print("Error using microphone")
    }
  }
  
  
  // MARK: Accessors
  
  /// get the current sample rate from the mic
  func sampleRate() -> Int {
    return Int(mic.inputFormat(forBus: 0).sampleRate)
  }
  
  
  // MARK: Starting and Stopping
  
  /// start the mic recording
  func start() {

    let micFormat = mic.inputFormat(forBus: 0)

    if (micFormat.channelCount == 0){
      NSLog("Not enough available inputs!")
      return
    }

    if (audioIsTapped == false) {
      audioIsTapped = true
      mic.installTap(onBus: 0, bufferSize: 2048, format: micFormat) { (buffer: AVAudioPCMBuffer!, time: AVAudioTime!) in
        self.micReturnedSamples(buffer: buffer, time: time)
      }
    } else {
      print("Warning: microphone was started twice")
    }
    
    do {
      try audioEngine.start()
    } catch {
    }
  }
  
  
  /// stop the mic recording
  func stop() {
    audioEngine.stop()
    audioEngine.reset()
    
    if (audioIsTapped == true) {
      audioIsTapped = false
      mic.removeTap(onBus: 0)
    } else {
      print("Warning: microphone stop() called when mic was off")
    }
  }
  
  
  // MARK: Events
  
  
  /// this is called when there is new audio data from the microphone
  ///   - parameter buffer: the buffer holding the audio data
  ///   - parameter time: the timestamp for the audio buffer
  private func micReturnedSamples(buffer: AVAudioPCMBuffer!, time: AVAudioTime!) {
    let sampleData = UnsafeBufferPointer(start: buffer.floatChannelData![0], count: Int(buffer.frameLength))
    
    // fade the amplitude indicator quickly, but not imediately
    self.amplitude = self.amplitude * 0.3
    
    // remember the max amplitude
    if let m = sampleData.max() {
      self.amplitude = Double(m)
      if m > abs(Float(self.maxAmplitude)) {
        self.maxAmplitude = abs(Double(m))
      }
    }
    
    // remember the min amplitude
    if let m = sampleData.min() {
      if m < abs(Float(self.minAmplitude)) {
        self.minAmplitude = abs(Double(m))
      }
    }
    
    /// send the audio samples on to whomever is interested in it
    self.sampleArrived(sampleData)
  }
  
  
  

}
