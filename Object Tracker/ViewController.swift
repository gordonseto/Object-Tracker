//
//  ViewController.swift
//  Object Tracker
//
//  Created by Gordon Seto on 2017-07-10.
//  Copyright © 2017 gordonseto. All rights reserved.
//

import UIKit
import AVFoundation
import Vision

class ViewController: UIViewController {
    
    @IBOutlet private weak var cameraView: UIView?
    @IBOutlet private weak var highlightView: UIView? {
        didSet {
            highlightView?.layer.borderColor = UIColor.red.cgColor
            highlightView?.layer.borderWidth = 4
            highlightView?.backgroundColor = .clear
        }
    }
    
    private lazy var cameraLayer: AVCaptureVideoPreviewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
    private lazy var captureSession: AVCaptureSession = {
        let session = AVCaptureSession()
        session.sessionPreset = AVCaptureSession.Preset.photo
        guard let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back), let input = try? AVCaptureDeviceInput(device: backCamera) else { return session }
        session.addInput(input)
        return session
    }()
    
    private let visionSequenceHandler = VNSequenceRequestHandler()
    private var lastObservation: VNDetectedObjectObservation?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        highlightView?.frame = .zero
        view.addSubview(highlightView!)
        
        cameraView?.layer.addSublayer(cameraLayer)
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "MyQueue"))
        captureSession.addOutput(videoOutput)
        captureSession.startRunning()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        cameraLayer.frame = cameraView?.bounds ?? .zero
    }
    
    @IBAction func onViewTapped(_ sender: UITapGestureRecognizer) {
        highlightView?.frame.size = CGSize(width: 120, height: 120)
        highlightView?.center = sender.location(in: view)
        
        let originalRect = highlightView?.frame ?? .zero
        var convertedRect = cameraLayer.metadataOutputRectConverted(fromLayerRect: originalRect)
        convertedRect.origin.y = 1 - convertedRect.origin.y
        
        let newObservation = VNDetectedObjectObservation(boundingBox: convertedRect)
        lastObservation = newObservation
    }
    
    private func handleVisionRequestUpdate(_ request: VNRequest, error: Error?){
        DispatchQueue.main.async {
            guard let newObservation = request.results?.first as? VNDetectedObjectObservation else { return }
            self.lastObservation = newObservation
            
            guard newObservation.confidence >= 0.3 else {
                self.highlightView?.frame = .zero
                return
            }
            
            var transformedRect = newObservation.boundingBox
            transformedRect.origin.y = 1 - transformedRect.origin.y
            let convertedRect = self.cameraLayer.layerRectConverted(fromMetadataOutputRect: transformedRect)
            
            self.highlightView?.frame = convertedRect
        }
    }
    
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer), let lastObservation = lastObservation else { return }
        let request = VNTrackObjectRequest(detectedObjectObservation: lastObservation, completionHandler: handleVisionRequestUpdate)
        request.trackingLevel = .accurate
        
        do {
            try visionSequenceHandler.perform([request], on: pixelBuffer)
        } catch {
            print("Throws: \(error)")
        }
    }
}

