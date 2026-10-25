import AVFoundation
import CoreImage
import CoreMedia
import CoreVideo

final class StudioRecorder: @unchecked Sendable {
    private let queue = DispatchQueue(label: "estudio.recorder")
    private let lock = NSLock()
    private let context: CIContext
    private var wantsRecording = false
    private var writer: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var adaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var started = false
    private var sessionStart = CMTime.invalid
    private var stopping = false
    private var outputURL: URL?

    var onFinished: ((Result<URL, Error>) -> Void)?
    var onFailure: ((Error) -> Void)?

    init(context: CIContext) {
        self.context = context
    }

    func start() {
        lock.lock()
        wantsRecording = true
        lock.unlock()
    }

    func stop() {
        lock.lock()
        wantsRecording = false
        lock.unlock()
        queue.async { [weak self] in self?.finishWriting() }
    }

    func appendVideo(_ image: CIImage, timestamp: CMTime) {
        lock.lock()
        let active = wantsRecording
        lock.unlock()
        guard active else { return }
        queue.async { [weak self] in
            self?.processVideo(image, timestamp: timestamp)
        }
    }

    func appendAudio(_ sampleBuffer: CMSampleBuffer) {
        lock.lock()
        let active = wantsRecording
        lock.unlock()
        guard active else { return }
        queue.async { [weak self] in
            self?.processAudio(sampleBuffer)
        }
    }

    private func processVideo(_ image: CIImage, timestamp: CMTime) {
        if stopping { return }
        do {
            if writer == nil { try makeWriter(for: image) }
            guard let writer, let videoInput, let adaptor else { return }
            if !started {
                guard writer.startWriting() else { throw writer.error ?? StudioError.recorderNotReady }
                writer.startSession(atSourceTime: timestamp)
                sessionStart = timestamp
                started = true
            }
            guard videoInput.isReadyForMoreMediaData else { return }
            var pixelBuffer: CVPixelBuffer?
            let result = CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &pixelBuffer)
            guard result == kCVReturnSuccess, let pixelBuffer else { throw StudioError.invalidVideoFrame }
            context.render(image, to: pixelBuffer, bounds: image.extent, colorSpace: CGColorSpaceCreateDeviceRGB())
            if !adaptor.append(pixelBuffer, withPresentationTime: timestamp) {
                throw writer.error ?? StudioError.recorderNotReady
            }
        } catch {
            fail(error)
        }
    }

    private func processAudio(_ sampleBuffer: CMSampleBuffer) {
        guard started, !stopping, let writer, let audioInput, audioInput.isReadyForMoreMediaData else { return }
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        guard timestamp.isValid, sessionStart.isValid, timestamp >= sessionStart else { return }
        if !audioInput.append(sampleBuffer), let error = writer.error { fail(error) }
    }

    private func makeWriter(for image: CIImage) throws {
        let directory = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Estudio Cámara", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let url = directory.appendingPathComponent("Grabación_\(formatter.string(from: Date())).mov")
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }

        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let width = Int(image.extent.width)
        let height = Int(image.extent.height)
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: max(width * height * 6, 4_000_000),
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput.expectsMediaDataInRealTime = true
        guard writer.canAdd(videoInput) else { throw StudioError.recorderNotReady }
        writer.add(videoInput)

        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 128_000
        ]
        let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        audioInput.expectsMediaDataInRealTime = true
        let canRecordAudio = writer.canAdd(audioInput)
        if canRecordAudio { writer.add(audioInput) }

        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]
        adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoInput, sourcePixelBufferAttributes: attributes)
        self.writer = writer
        self.videoInput = videoInput
        self.audioInput = canRecordAudio ? audioInput : nil
        self.outputURL = url
    }

    private func finishWriting() {
        lock.lock()
        wantsRecording = false
        lock.unlock()
        guard let writer, !stopping else { return }
        stopping = true
        videoInput?.markAsFinished()
        audioInput?.markAsFinished()
        let url = outputURL
        writer.finishWriting { [weak self] in
            guard let self else { return }
            if writer.status == .completed, let url {
                self.onFinished?(.success(url))
            } else {
                self.onFinished?(.failure(writer.error ?? StudioError.recorderNotReady))
            }
            self.reset()
        }
    }

    private func fail(_ error: Error) {
        lock.lock()
        wantsRecording = false
        lock.unlock()
        writer?.cancelWriting()
        reset()
        onFailure?(error)
    }

    private func reset() {
        writer = nil
        videoInput = nil
        audioInput = nil
        adaptor = nil
        started = false
        sessionStart = .invalid
        stopping = false
        outputURL = nil
    }
}
