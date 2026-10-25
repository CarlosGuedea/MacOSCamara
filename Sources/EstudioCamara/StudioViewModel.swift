import AVFoundation
import CoreImage
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class StudioViewModel: ObservableObject {
    @Published var cameras: [CaptureDeviceItem] = []
    @Published var microphones: [CaptureDeviceItem] = []
    @Published var selectedCameraID = ""
    @Published var selectedMicrophoneID = ""
    @Published var previewImage: CGImage?
    @Published var backgroundKind: BackgroundKind = .original
    @Published var backgroundFit: BackgroundFitMode = .fit
    @Published var aspectRatio: VideoAspectRatio = .landscape
    @Published var isPreviewMirrored = true
    @Published var isRecording = false
    @Published var isFinalizing = false
    @Published var elapsedTime = "00:00"
    @Published var errorMessage: String?
    @Published var lastRecordingURL: URL?
    @Published var showSavedMessage = false

    let colorOptions: [(String, NSColor)] = [
        ("Grafito", NSColor(calibratedRed: 0.10, green: 0.12, blue: 0.17, alpha: 1)),
        ("Azul", NSColor(calibratedRed: 0.12, green: 0.28, blue: 0.68, alpha: 1)),
        ("Verde", NSColor(calibratedRed: 0.08, green: 0.42, blue: 0.28, alpha: 1)),
        ("Arena", NSColor(calibratedRed: 0.72, green: 0.62, blue: 0.48, alpha: 1))
    ]

    private let engine = CaptureEngine()
    private var timerTask: Task<Void, Never>?
    private var startedAt: Date?

    var canRecord: Bool {
        !selectedCameraID.isEmpty && !selectedMicrophoneID.isEmpty && !isFinalizing && previewImage != nil
    }

    init() {
        engine.onPreview = { [weak self] image in
            Task { @MainActor in self?.previewImage = image }
        }
        engine.onRecordingFinished = { [weak self] result in
            Task { @MainActor in
                self?.isFinalizing = false
                switch result {
                case let .success(url):
                    self?.lastRecordingURL = url
                    self?.showSavedMessage = true
                case let .failure(error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
        engine.onRecordingFailure = { [weak self] error in
            Task { @MainActor in
                self?.isRecording = false
                self?.isFinalizing = false
                self?.stopTimer()
                self?.errorMessage = error.localizedDescription
            }
        }
    }

    func start() async {
        refreshDevices()
        guard await CaptureEngine.requestAccess() else {
            errorMessage = StudioError.permissionDenied.localizedDescription
            return
        }
        errorMessage = nil
        refreshDevices()
        configureCapture()
    }

    func refreshDevices() {
        cameras = CaptureEngine.devices(for: .video)
        microphones = CaptureEngine.devices(for: .audio)
        if !cameras.contains(where: { $0.id == selectedCameraID }) {
            selectedCameraID = cameras.first?.id ?? ""
        }
        if !microphones.contains(where: { $0.id == selectedMicrophoneID }) {
            selectedMicrophoneID = microphones.first?.id ?? ""
        }
    }

    func configureCapture() {
        guard !selectedCameraID.isEmpty, !selectedMicrophoneID.isEmpty else {
            errorMessage = cameras.isEmpty ? StudioError.cameraUnavailable.localizedDescription : StudioError.microphoneUnavailable.localizedDescription
            return
        }
        errorMessage = nil
        engine.configure(cameraID: selectedCameraID, microphoneID: selectedMicrophoneID)
    }

    func selectBackground(_ kind: BackgroundKind) {
        backgroundKind = kind
        updateRenderSettings()
    }

    func selectAspectRatio(_ ratio: VideoAspectRatio) {
        guard !isRecording else { return }
        aspectRatio = ratio
        updateRenderSettings()
    }

    func selectBackgroundFit(_ mode: BackgroundFitMode) {
        backgroundFit = mode
        updateRenderSettings()
    }

    private func updateRenderSettings() {
        engine.updateRenderSettings(
            kind: backgroundKind,
            imageURL: backgroundKind.imageURL,
            aspectRatio: aspectRatio,
            backgroundFit: backgroundFit
        )
    }

    func chooseBackgroundImage() {
        let panel = NSOpenPanel()
        panel.title = "Elegir fondo"
        panel.prompt = "Usar imagen"
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        selectBackground(.image(url))
    }

    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }

    private func startRecording() {
        guard canRecord else { return }
        errorMessage = nil
        showSavedMessage = false
        engine.startRecording()
        isRecording = true
        startedAt = Date()
        elapsedTime = "00:00"
        startTimer()
    }

    private func stopRecording() {
        isRecording = false
        isFinalizing = true
        engine.stopRecording()
        stopTimer()
    }

    func revealRecording() {
        guard let lastRecordingURL else { return }
        NSWorkspace.shared.activateFileViewerSelecting([lastRecordingURL])
    }

    func openPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") else { return }
        NSWorkspace.shared.open(url)
    }

    private func startTimer() {
        stopTimer()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard let self, let startedAt = self.startedAt else { return }
                    let seconds = max(0, Int(Date().timeIntervalSince(startedAt)))
                    self.elapsedTime = String(format: "%02d:%02d", seconds / 60, seconds % 60)
                }
            }
        }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }
}

private extension BackgroundKind {
    var imageURL: URL? {
        if case let .image(url) = self { return url }
        return nil
    }
}
