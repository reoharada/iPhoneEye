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
    
    var captureDevice = AVCaptureDevice.default(for: .video)
    var captureSession = AVCaptureSession()
    var captureDeviceInput: AVCaptureInput!
    var captureVideoDataOutput = AVCaptureVideoDataOutput()
    var previewLayer: AVCaptureVideoPreviewLayer!
    
    let queName = "videoQue"
    
    var coreMLModel: VNCoreMLModel!
    var request: VNCoreMLRequest!
    
    let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))
    var recognitionRequest: SFSpeechAudioBufferRecognitionRequest!
    var recognitionTask: SFSpeechRecognitionTask!
    let audioEngine = AVAudioEngine()
    
    let startText = "起動"
    let stopText = "停止"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initCameraSetting()
        initMLSetting()
        initSpeechRecognizer()
    }
    
    fileprivate func initSpeechRecognizer() {
        SFSpeechRecognizer.requestAuthorization { (status) in
            print(status)
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.record, mode: .measurement, options: .defaultToSpeaker)
        try? audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        self.recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest.shouldReportPartialResults = true
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest, resultHandler: { (result, error) in
            print(error)
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
                    self.resultImageView.image = UIImage(named: prefixData.first!.identifier.components(separatedBy: ",")[0])
                    self.resultImageView.alpha = CGFloat(prefixData.first!.confidence)
                }
            }
        })
    }
    
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixellBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            print("エラー")
            return
        }
        if request != nil {
            try? VNImageRequestHandler(cvPixelBuffer: pixellBuffer, options: [:]).perform([request])
        }
    }
}