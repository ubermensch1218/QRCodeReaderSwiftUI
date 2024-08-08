//
//  ContentView.swift
//  QRCodeReaderSwiftUI
//
//  Created by Jeongseok Kang on 7/30/24.
//

import SwiftUI
import AVFoundation
/// This method doesn't use the Notification
// MARK: - ContentView

struct ContentView: View {
    @State private var scannedCode: String = "NULL"
    @State private var isPresented: Bool = false
    
    
    var body: some View {
        VStack {
            Text("Scanned Code: \(scannedCode)")
            Button("Scan QR Code") {
                isPresented = true
            }
        }
        .sheet(isPresented: $isPresented) {
            QRCodeReaderView(scannedCode: $scannedCode, isPresented: $isPresented)
        }
    }
}

// MARK: - QRCodeReaderView

struct QRCodeReaderView: View {
    @Binding var scannedCode: String
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            CodeScanner(result: $scannedCode,isPresented : $isPresented)
            
            VStack {
                Spacer()
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white, lineWidth: 4)
                    .frame(width: 250, height: 250)
                Spacer()
            }
        }
        .edgesIgnoringSafeArea(.all)
    }
}
// MARK: - VisionQRReader

class QRCodeScannerViewController: UIViewController {
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    var scannedCode: ((String) -> Void)?
    var dismissAction: (() -> Void)?
    let objectType : [AVMetadataObject.ObjectType] = [ .qr , .ean8, .ean13, .code128]
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCaptureSession()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startCaptureSession()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopCaptureSession()
    }
    private func setupCaptureSession() {
        captureSession = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            return
        }
        
        if (captureSession?.canAddInput(videoInput) ?? false) {
            captureSession?.addInput(videoInput)
        } else {
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
       
        if (captureSession?.canAddOutput(metadataOutput) ?? false) {
            captureSession?.addOutput(metadataOutput)
            
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = objectType
        } else {
            return
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
        previewLayer?.frame = view.bounds
        previewLayer?.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer!)
        
        //captureSession?.startRunning()
    }
    
    private func startCaptureSession() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }
    
    private func stopCaptureSession() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.captureSession?.stopRunning()
        }
    }
}

extension QRCodeScannerViewController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject else { return }
        
        if objectType.contains( metadataObject.type){
            scannedCode?(metadataObject.stringValue ?? "")
            dismissAction?()
        }
    }
}

struct CodeScanner: UIViewControllerRepresentable {
    @Binding var result: String
    @Binding var isPresented: Bool
    
    func makeUIViewController(context: Context) -> QRCodeScannerViewController {
        let controller = QRCodeScannerViewController()
        controller.scannedCode = { code in
            self.result = code
        }
        controller.dismissAction = {
            self.isPresented = false
        }
        return controller
    }
    
    func updateUIViewController(_ uiViewController: QRCodeScannerViewController, context: Context) {
    }
}
// MARK: - QRAVCodeReaderViewController
class QRScannerControllerAV: UIViewController {
    var captureSession = AVCaptureSession()
    var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    var qrCodeFrameView: UIView?
    
    var delegate: AVCaptureMetadataOutputObjectsDelegate?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Get the back-facing camera for capturing videos
        guard let captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("Failed to get the camera device")
            return
        }
        
        let videoInput: AVCaptureDeviceInput
        
        do {
            // Improve focus and exposure
            try captureDevice.lockForConfiguration()
            if captureDevice.isFocusModeSupported(.continuousAutoFocus) {
                captureDevice.focusMode = .continuousAutoFocus
            }
            if captureDevice.isExposureModeSupported(.continuousAutoExposure) {
                captureDevice.exposureMode = .continuousAutoExposure
            }
            // Increase capture quality
            captureDevice.activeFormat = captureDevice.formats.last ?? captureDevice.activeFormat
            captureDevice.unlockForConfiguration()
            
            // Get an instance of the AVCaptureDeviceInput class using the previous device object.
            videoInput = try AVCaptureDeviceInput(device: captureDevice)
            // Set the input device on the capture session.
            captureSession.addInput(videoInput)
            
        } catch {
            // If any error occurs, simply print it out and don't continue any more.
            print(error)
            return
        }
        
        // Initialize a AVCaptureMetadataOutput object and set it as the output device to the capture session.
        let captureMetadataOutput = AVCaptureMetadataOutput()
        captureSession.addOutput(captureMetadataOutput)
        
        // Set delegate and use the default dispatch queue to execute the call back
        captureMetadataOutput.setMetadataObjectsDelegate(delegate, queue: DispatchQueue.main)
        captureMetadataOutput.metadataObjectTypes = [ .qr , .ean8, .ean13]
        
        // Initialize the video preview layer and add it as a sublayer to the viewPreview view's layer.
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        videoPreviewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        videoPreviewLayer?.frame = view.layer.bounds
        view.layer.addSublayer(videoPreviewLayer!)
        
        // Start video capture.
        DispatchQueue.global(qos: .userInteractive).async {
            self.captureSession.startRunning()
        }
        
    }
    func stopScanning() {
        DispatchQueue.global(qos: .userInteractive).async {
            self.captureSession.stopRunning()
        }
    }
    
}
struct QRScannerAV: UIViewControllerRepresentable {
    @Binding var result: String
    @Binding var isPresented: Bool
    
    func makeUIViewController(context: Context) -> QRScannerControllerAV {
        let controller = QRScannerControllerAV()
        controller.delegate = context.coordinator
        return controller
    }
    
    func updateUIViewController(_ uiViewController: QRScannerControllerAV, context: Context) {
    }
    func makeCoordinator() -> Coordinator {
        Coordinator($result, $isPresented)
    }
    class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        
        @Binding var scanResult: String
        @Binding var isPresented: Bool
        var hasScanned = false
        init(_ scanResult: Binding<String>, _ isPresented : Binding<Bool>) {
            self._scanResult = scanResult
            self._isPresented = isPresented
        }
        
        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
            guard !hasScanned else { return }  // Exit if we've already scanned
            // Check if the metadataObjects array is not nil and it contains at least one object.
            if metadataObjects.count == 0 {
                scanResult = "No QR code detected"
                return
            }
            
            // Get the metadata object.
            let codeOfInterest : [AVMetadataObject.ObjectType] = [.qr, .ean8, .ean13]
            
            guard let metadataObj = metadataObjects[0] as? AVMetadataMachineReadableCodeObject,
                  codeOfInterest.contains(metadataObj.type),
                  let result = metadataObj.stringValue else { return
            }
            
            
            scanResult = result
            print(result)
            hasScanned = true
            isPresented = false
            // Stop the scanning session
            if let controller = UIApplication.shared.windows.first?.rootViewController?.children.first as? QRScannerControllerAV {
                controller.stopScanning()
            }
        }
    }
}
