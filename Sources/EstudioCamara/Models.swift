import AVFoundation
import CoreImage
import SwiftUI

struct CaptureDeviceItem: Identifiable, Hashable {
    let id: String
    let name: String
    let device: AVCaptureDevice

    static func == (lhs: CaptureDeviceItem, rhs: CaptureDeviceItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

enum BackgroundKind: Equatable {
    case original
    case blur
    case color(NSColor)
    case image(URL)

    static func == (lhs: BackgroundKind, rhs: BackgroundKind) -> Bool {
        switch (lhs, rhs) {
        case (.original, .original), (.blur, .blur): return true
        case let (.color(a), .color(b)): return a == b
        case let (.image(a), .image(b)): return a == b
        default: return false
        }
    }
}

struct BackgroundOption: Identifiable {
    let id: String
    let name: String
    let kind: BackgroundKind
    let swatch: NSImage?
}

enum VideoAspectRatio: String, CaseIterable, Identifiable {
    case landscape = "16:9"
    case portrait = "9:16"
    case square = "1:1"
    case social = "4:5"

    var id: String { rawValue }
    var ratio: CGFloat { outputSize.width / outputSize.height }
    var title: String {
        switch self {
        case .landscape: return "Horizontal"
        case .portrait: return "Vertical"
        case .square: return "Cuadrado"
        case .social: return "Retrato"
        }
    }
    var outputSize: CGSize {
        switch self {
        case .landscape: return CGSize(width: 1920, height: 1080)
        case .portrait: return CGSize(width: 1080, height: 1920)
        case .square: return CGSize(width: 1080, height: 1080)
        case .social: return CGSize(width: 1080, height: 1350)
        }
    }
    var resolutionLabel: String {
        "\(Int(outputSize.width)) × \(Int(outputSize.height))"
    }
}

enum BackgroundFitMode: String, CaseIterable, Identifiable {
    case fit = "Ajustar"
    case fill = "Llenar"

    var id: String { rawValue }
}

struct RenderSettings {
    var kind: BackgroundKind = .original
    var backgroundImage: CIImage?
    var aspectRatio: VideoAspectRatio = .landscape
    var backgroundFit: BackgroundFitMode = .fit
}

final class RenderSettingsStore: @unchecked Sendable {
    private let lock = NSLock()
    private var settings = RenderSettings()

    func update(_ settings: RenderSettings) {
        lock.lock()
        self.settings = settings
        lock.unlock()
    }

    func current() -> RenderSettings {
        lock.lock()
        defer { lock.unlock() }
        return settings
    }
}

enum StudioError: LocalizedError {
    case cameraUnavailable
    case microphoneUnavailable
    case permissionDenied
    case invalidVideoFrame
    case recorderNotReady

    var errorDescription: String? {
        switch self {
        case .cameraUnavailable: return "No se encontró una cámara disponible."
        case .microphoneUnavailable: return "No se encontró un micrófono disponible."
        case .permissionDenied: return "Activa los permisos de cámara y micrófono en Ajustes del Sistema › Privacidad y seguridad."
        case .invalidVideoFrame: return "No se pudo procesar la imagen de la cámara."
        case .recorderNotReady: return "La grabación todavía no está lista. Inténtalo de nuevo."
        }
    }
}

enum AppColors {
    static let window = Color(red: 0.055, green: 0.063, blue: 0.082)
    static let panel = Color(red: 0.086, green: 0.094, blue: 0.12)
    static let raised = Color(red: 0.12, green: 0.13, blue: 0.16)
    static let line = Color.white.opacity(0.09)
    static let accent = Color(red: 0.42, green: 0.52, blue: 1.0)
    static let recording = Color(red: 1.0, green: 0.28, blue: 0.34)
}
