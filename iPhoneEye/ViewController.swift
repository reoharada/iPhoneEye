//
//  ViewController.swift
//  iPhoneEye
//
//  Created by REO HARADA on 2019/12/14.
//  Copyright © 2019 reo harada. All rights reserved.
//

import UIKit

import UIKit
import AVFoundation
import Vision
import CoreML
import Speech

class ViewController: UIViewController {
    
    @IBOutlet weak var resultLabel: UILabel!
    @IBOutlet weak var resultImageView: UIImageView!
    @IBOutlet weak var cameraView: UIView!
    @IBOutlet weak var recognizeLabel: UILabel!
    @IBOutlet weak var speechLabel: UILabel!
    
    var beforeObserveThing = ""
    let humanStr = "人間"
    let observeTimeInterval = TimeInterval(5)
    var enableObserve = true
    var enableHumanObserve = true
    var timerA: Timer!
    var timerB: Timer!
    var speechExcludeStr = "白い車"
    let scale = CGFloat(400)
    
    /**** カメラ ****/
    var captureDevice = AVCaptureDevice.default(for: .video)
    var captureSession = AVCaptureSession()
    var captureDeviceInput: AVCaptureInput!
    var captureVideoDataOutput = AVCaptureVideoDataOutput()
    var previewLayer: AVCaptureVideoPreviewLayer!
    let queName = "videoQue"
    /**** カメラ ****/
    
    /**** 画像認識 ****/
    var audioSession: AVAudioSession? = AVAudioSession.sharedInstance()
    var coreMLModel: VNCoreMLModel!
    var request: VNCoreMLRequest!
    /**** 画像認識 ****/
    
    /**** 音声認識 ****/
    let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))
    var recognitionRequest: SFSpeechAudioBufferRecognitionRequest!
    var recognitionTask: SFSpeechRecognitionTask!
    let audioEngine = AVAudioEngine()
    
    let startText = "起動"
    let stopText = "停止"
    /**** 音声認識 ****/
    
    /**** 発声 ****/
    let synthesizer = AVSpeechSynthesizer()
    let appStartVoice = "スタートするときは起動といってください"
    /**** 発声 ****/
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initCameraSetting()
        initMLSetting()
        initSpeechRecognizer()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        synthesizer.speechWithJP(appStartVoice)
    }
    
    func startTimerA() {
        enableObserve = false
        timerA = Timer.scheduledTimer(withTimeInterval: observeTimeInterval, repeats: false, block: { (ti) in
            self.enableObserve = true
        })
    }
    
    func startTimerB() {
        enableHumanObserve = false
        timerB = Timer.scheduledTimer(withTimeInterval: observeTimeInterval+1, repeats: false, block: { (ti) in
            self.enableHumanObserve = true
        })
    }

    
    fileprivate func initSpeechRecognizer() {
        SFSpeechRecognizer.requestAuthorization { (status) in
            print(status)
        }
        
        try? audioSession?.setCategory(.playAndRecord, mode: .measurement, options: .defaultToSpeaker)
        try? audioSession?.setActive(true, options: .notifyOthersOnDeactivation)
        
        self.recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest.shouldReportPartialResults = true
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest, resultHandler: { (result, error) in
            //print(error)
            if let result = result {
                if let str = result.bestTranscription.segments.last?.substring {
                    self.recognizeLabel.text = str
                    if str.contains(self.startText) {
                        self.captureSession.startRunning()
                    }
                    if str.contains(self.stopText) {
                        self.captureSession.stopRunning()
                    }
                }
            }
        })
        
        let recordingFormat = audioEngine.inputNode.outputFormat(forBus: 0)
        audioEngine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        try? audioEngine.start()
    }
    
    fileprivate func initCameraSetting() {
        captureSession.sessionPreset = .photo
        if captureDevice != nil {
            captureDeviceInput = try? AVCaptureDeviceInput(device: captureDevice!)
            if !captureSession.canAddInput(captureDeviceInput) {
                print("エラー")
                return
            }
        }
        guard (captureDeviceInput != nil) else {
            print("エラー")
            return
        }
        captureSession.addInput(captureDeviceInput)
        captureVideoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: queName))
        
        guard captureSession.canAddOutput(captureVideoDataOutput) else {
            print("エラー")
            return
        }
        
        captureSession.addOutput(captureVideoDataOutput)
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = cameraView.bounds
        cameraView.layer.insertSublayer(previewLayer, at: 0)
    }
    
    fileprivate func initMLSetting() {
        coreMLModel = try? VNCoreMLModel(for: ImageClassifier().model)
//        coreMLModel = try? VNCoreMLModel(for: Resnet50().model)
        request = VNCoreMLRequest(model: coreMLModel, completionHandler: { (req, error) in
            if error != nil {
                print(error)
                return
            }
            guard let result = req.results as? [VNClassificationObservation] else { return }
            DispatchQueue.main.async {
                let prefixData = result.prefix(3)
                let mappedData = prefixData.compactMap {"\(Int($0.confidence*100))% \($0.identifier.components(separatedBy: ",")[0])"}
                self.resultLabel.text = mappedData.joined(separator: ",")
                if prefixData.count > 0 {
                    let dataName = prefixData.first!.identifier.components(separatedBy: ",")[0]
                    self.resultImageView.image = UIImage(named: dataName)
                    self.resultImageView.alpha = CGFloat(prefixData.first!.confidence)
                    if self.beforeObserveThing != dataName && self.enableObserve && dataName != self.speechExcludeStr {
                        self.startTimerA()
                        let speechText = "1メートル先に"+dataName
                        self.speechLabel.text = speechText
                        self.synthesizer.speechWithJP(speechText)
                        self.beforeObserveThing = dataName
                    }
                }
            }
        })
    }
    
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        DispatchQueue.main.async {
            print(self.beforeObserveThing)
            guard let pixellBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                print("エラー")
                return
            }
            // クロップ処理
            let ciImage = CIImage(cvPixelBuffer: pixellBuffer)
            let context = CIContext(options: nil)
            if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
                let w = cgImage.width, h = cgImage.height
                let rect = CGRect(x: (CGFloat(w)-self.scale)/2, y: (CGFloat(h)-self.scale)/2, width: self.scale, height: self.scale)
                if let imageRef = cgImage.cropping(to: rect) {
                    let cropImage = UIImage(cgImage: imageRef)
                    self.resultImageView.image = cropImage
                }
                // 画像認識
                let uiImage = UIImage(cgImage: cgImage)
                if self.request != nil {
                    if let pixelBuffer = uiImage.pixelBuffer() {
                        try? VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:]).perform([self.request])
                    }
                }
            }
            // クロップ処理
            // 人間認識
            let humanNumber = iPhoneEyeCIDetector.shareInstance.findHuman(ciImage)
            if humanNumber > 0 {
                if self.beforeObserveThing != self.humanStr && self.enableHumanObserve {
                    self.startTimerB()
                    self.beforeObserveThing = self.humanStr
                    let speechText = "前方に\(humanNumber)人の人間がいます"
                    self.synthesizer.speechWithJP(speechText)
                    self.speechLabel.text = speechText
                }
            }
        }
    }
    
}

extension AVSpeechSynthesizer {
    func speechWithJP(_ text: String) {
        if !self.continueSpeaking() {
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = AVSpeechSynthesisVoice(language: "ja-JP")
            self.speak(utterance)
        }
    }
}

extension UIImage {
    func resize(to newSize: CGSize) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(CGSize(width: newSize.width, height: newSize.height), true, 1.0)
        self.draw(in: CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return resizedImage
    }
 
    func pixelBuffer() -> CVPixelBuffer? {
        let width = self.size.width
        let height = self.size.height
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
                     kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                         Int(width),
                                         Int(height),
                                         kCVPixelFormatType_32ARGB,
                                         attrs,
                                         &pixelBuffer)
 
        guard let resultPixelBuffer = pixelBuffer, status == kCVReturnSuccess else {
            return nil
        }
 
        CVPixelBufferLockBaseAddress(resultPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        let pixelData = CVPixelBufferGetBaseAddress(resultPixelBuffer)
 
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(data: pixelData,
                                      width: Int(width),
                                      height: Int(height),
                                      bitsPerComponent: 8,
                                      bytesPerRow: CVPixelBufferGetBytesPerRow(resultPixelBuffer),
                                      space: rgbColorSpace,
                                      bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else {
                                        return nil
        }
 
        context.translateBy(x: 0, y: height)
        context.scaleBy(x: 1.0, y: -1.0)
 
        UIGraphicsPushContext(context)
        self.draw(in: CGRect(x: 0, y: 0, width: width, height: height))
        UIGraphicsPopContext()
        CVPixelBufferUnlockBaseAddress(resultPixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
 
        return resultPixelBuffer
    }
}
