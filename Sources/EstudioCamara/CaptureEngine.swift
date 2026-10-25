import AVFoundation
import CoreImage
import CoreMedia
import CoreVideo

final class CaptureEngine: NSObject, @unchecked Sendable {
    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "estudio.capture.session")
    private let videoQueue = DispatchQueue(label: "estudio.capture.video")
    private let audioQueue = DispatchQueue(label: "estudio.capture.audio")
    private let videoOutput = AVCaptureVideoDataOutput()
    private let audioOutput = AVCaptureAudioDataOutput()
    private let ciContext = CIContext(options: [.cacheIntermediates: false])
    private let settings = RenderSettingsStore()
    private lazy var processor = BackgroundProcessor(settings: settings, context: ciContext)
    private lazy var recorder = StudioRecorder(context: ciContext)

    var onPreview: ((CGImage) -> Void)?
    var onRecordingFinished: ((Result<URL, Error>) -> Void)?
    var onRecordingFailure: ((Error) -> Void)?

    override init() {
        super.init()
        recorder.onFailure = { [weak self] error in
            self?.onRecordingFailure?(error)
        }
        recorder.onFinished = { [weak self] result in
            self?.onRecordingFinished?(result)
        }
    }

    func updateRenderSettings(kind: BackgroundKind, imageURL: URL?, aspectRatio: VideoAspectRatio, backgroundFit: BackgroundFitMode) {
        settings.update(RenderSettings(
            kind: kind,
            backgroundImage: imageURL.flatMap { CIImage(contentsOf: $0, options: [.applyOrientationProperty: true]) },
            aspectRatio: aspectRatio,
            backgroundFit: backgroundFit
        ))
    }

    static func devices(for mediaType: AVMediaType) -> [CaptureDeviceItem] {
        let types: [AVCaptureDevice.DeviceType] = mediaType == .video
            ? [.builtInWideAngleCamera, .continuityCamera, .external]
            : [.microphone, .external]
        let discovery = AVCaptureDevice.DiscoverySession(deviceTypes: types, mediaType: mediaType, position: .unspecified)
        return discovery.devices.map { CaptureDeviceItem(id: $0.uniqueID, name: $0.localizedName, device: $0) }
    }

    static func requestAccess() async -> Bool {
        let video = await requestAccess(for: .video)
        let audio = await requestAccess(for: .audio)
        return video && audio
    }

    private static func requestAccess(for mediaType: AVMediaType) async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: mediaType) {
        case .authorized: return true
        case .notDetermined: return await AVCaptureDevice.requestAccess(for: mediaType)
        default: return false
        }
    }

    func configure(cameraID: String, microphoneID: String) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.session.beginConfiguration()
            self.session.inputs.forEach(self.session.removeInput)
            self.session.outputs.forEach(self.session.removeOutput)
            self.session.sessionPreset = .high

            do {
                guard let camera = AVCaptureDevice(uniqueID: cameraID) else { throw StudioError.cameraUnavailable }
                let cameraInput = try AVCaptureDeviceInput(device: camera)
                guard self.session.canAddInput(cameraInput) else { throw StudioError.cameraUnavailable }
                self.session.addInput(cameraInput)

                if let microphone = AVCaptureDevice(uniqueID: microphoneID) {
                    let audioInput = try AVCaptureDeviceInput(device: microphone)
                    if self.session.canAddInput(audioInput) { self.session.addInput(audioInput) }
                }

                self.videoOutput.alwaysDiscardsLateVideoFrames = true
                self.videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
                self.videoOutput.setSampleBufferDelegate(self, queue: self.videoQueue)
                guard self.session.canAddOutput(self.videoOutput) else { throw StudioError.invalidVideoFrame }
                self.session.addOutput(self.videoOutput)

                self.audioOutput.setSampleBufferDelegate(self, queue: self.audioQueue)
                if self.session.canAddOutput(self.audioOutput) { self.session.addOutput(self.audioOutput) }

                self.session.commitConfiguration()
                if !self.session.isRunning { self.session.startRunning() }
            } catch {
                self.session.commitConfiguration()
                DispatchQueue.main.async { self.onRecordingFailure?(error) }
            }
        }
    }

    func startRecording() {
        recorder.start()
    }

    func stopRecording() {
        recorder.stop()
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }
}

extension CaptureEngine: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard CMSampleBufferDataIsReady(sampleBuffer) else { return }
        if output == videoOutput {
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
            let source = CIImage(cvPixelBuffer: pixelBuffer)
            let rendered = processor.render(source, pixelBuffer: pixelBuffer)
            if let image = ciContext.createCGImage(rendered, from: rendered.extent) {
                onPreview?(image)
            }
            recorder.appendVideo(rendered, timestamp: CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
        } else if output == audioOutput {
            recorder.appendAudio(sampleBuffer)
        }
    }
}
