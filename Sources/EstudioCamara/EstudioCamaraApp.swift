import SwiftUI

@main
struct EstudioCamaraApp: App {
    @StateObject private var model = StudioViewModel()

    var body: some Scene {
        WindowGroup("Estudio Cámara") {
            StudioView()
                .environmentObject(model)
                .frame(minWidth: 1040, minHeight: 700)
                .background(AppColors.window)
                .task { await model.start() }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandMenu("Grabación") {
                Button(model.isRecording ? "Detener grabación" : "Iniciar grabación") {
                    model.toggleRecording()
                }
                .keyboardShortcut("r", modifiers: [.command])
                .disabled(!model.canRecord)

                Button(model.isPreviewMirrored ? "Desactivar espejo" : "Vista en espejo") {
                    model.isPreviewMirrored.toggle()
                }
                .keyboardShortcut("m", modifiers: [.command, .shift])
            }
        }
    }
}
