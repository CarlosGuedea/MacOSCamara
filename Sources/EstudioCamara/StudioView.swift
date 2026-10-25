import SwiftUI

struct StudioView: View {
    @EnvironmentObject private var model: StudioViewModel

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(AppColors.line)
            HStack(spacing: 0) {
                previewSection
                Divider().overlay(AppColors.line)
                controls
            }
        }
        .background(AppColors.window)
        .preferredColorScheme(.dark)
        .alert("Grabación guardada", isPresented: $model.showSavedMessage) {
            Button("Mostrar en Finder") { model.revealRecording() }
            Button("Aceptar", role: .cancel) { }
        } message: {
            Text("Tu video está listo en Películas › Estudio Cámara.")
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 9).fill(AppColors.accent.gradient)
                Image(systemName: "camera.aperture")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 34, height: 34)
            VStack(alignment: .leading, spacing: 1) {
                Text("Estudio Cámara").font(.headline)
                Text("Graba. Cambia el fondo. Comparte.").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if model.isRecording {
                Label("GRABANDO \(model.elapsedTime)", systemImage: "record.circle")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.recording)
                    .padding(.horizontal, 10).padding(.vertical, 6)
                    .background(AppColors.recording.opacity(0.12), in: Capsule())
            } else {
                Label("Listo para grabar", systemImage: "checkmark.circle.fill")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 22)
        .frame(height: 68)
        .background(AppColors.panel)
    }

    private var previewSection: some View {
        VStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 18).fill(.black)
                if let image = model.previewImage {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(x: model.isPreviewMirrored ? -1 : 1, y: 1)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                } else {
                    VStack(spacing: 14) {
                        Image(systemName: "camera.metering.center.weighted")
                            .font(.system(size: 42, weight: .light))
                            .foregroundStyle(.secondary)
                        Text(model.errorMessage == nil ? "Preparando tu cámara…" : "La cámara no está disponible")
                            .font(.headline)
                        if let error = model.errorMessage {
                            Text(error).font(.callout).foregroundStyle(.secondary)
                                .multilineTextAlignment(.center).frame(maxWidth: 400)
                            Button("Abrir ajustes de privacidad") { model.openPrivacySettings() }
                                .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(30)
                }
            }
            .aspectRatio(model.aspectRatio.ratio, contentMode: .fit)
            .overlay(alignment: .bottomLeading) {
                if model.previewImage != nil {
                    Label(backgroundLabel, systemImage: "person.crop.rectangle")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 10).padding(.vertical, 7)
                        .background(.black.opacity(0.55), in: Capsule())
                        .padding(14)
                }
            }

            HStack(spacing: 16) {
                Button { model.isPreviewMirrored.toggle() } label: {
                    Label("Espejo", systemImage: "arrow.left.and.right.righttriangle.left.righttriangle.right")
                }
                .buttonStyle(.bordered)
                .tint(model.isPreviewMirrored ? AppColors.accent : .secondary)
                .disabled(model.isRecording)

                Button { model.toggleRecording() } label: {
                    HStack(spacing: 9) {
                        Image(systemName: model.isRecording ? "stop.fill" : "record.circle")
                        Text(model.isRecording ? "Detener" : (model.isFinalizing ? "Guardando…" : "Grabar"))
                    }
                    .font(.headline)
                    .frame(minWidth: 120)
                }
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
                .tint(model.isRecording ? AppColors.recording : AppColors.accent)
                .disabled(!model.canRecord && !model.isRecording)
                .keyboardShortcut(.space, modifiers: [])

                VStack(alignment: .leading, spacing: 2) {
                    Text(model.isRecording ? model.elapsedTime : "00:00")
                        .font(.system(.title3, design: .monospaced).weight(.medium))
                    Text("MOV · H.264 + AAC").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var controls: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 14) {
                    sectionTitle("Formato", icon: "rectangle.ratio.3.to.4")
                    Picker("Relación de tamaño", selection: $model.aspectRatio) {
                        ForEach(VideoAspectRatio.allCases) { ratio in
                            Text(ratio.rawValue).tag(ratio)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .disabled(model.isRecording)
                    .onChange(of: model.aspectRatio) { _, ratio in model.selectAspectRatio(ratio) }
                    HStack {
                        Text(model.aspectRatio.title).font(.caption.weight(.medium))
                        Spacer()
                        Text(model.aspectRatio.resolutionLabel)
                            .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                    Text(model.aspectRatio == .portrait ? "Ideal para TikTok, Reels y Shorts." : "El encuadre se recorta al centro para llenar el formato.")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Divider().overlay(AppColors.line)

                VStack(alignment: .leading, spacing: 14) {
                    sectionTitle("Fuentes", icon: "slider.horizontal.3")
                    devicePicker(title: "Cámara", icon: "camera.fill", selection: $model.selectedCameraID, devices: model.cameras)
                    devicePicker(title: "Micrófono", icon: "mic.fill", selection: $model.selectedMicrophoneID, devices: model.microphones)
                    HStack {
                        Text(model.isRecording ? "Detén la grabación para cambiar las fuentes." : "El audio quedará integrado en el video.")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button { model.refreshDevices() } label: { Image(systemName: "arrow.clockwise") }
                            .buttonStyle(.plain).foregroundStyle(.secondary)
                            .help("Actualizar dispositivos")
                            .disabled(model.isRecording)
                    }
                }

                Divider().overlay(AppColors.line)

                VStack(alignment: .leading, spacing: 14) {
                    sectionTitle("Fondo", icon: "person.and.background.dotted")
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        backgroundCard(title: "Original", systemImage: "camera", kind: .original)
                        backgroundCard(title: "Desenfocado", systemImage: "aqi.medium", kind: .blur)
                    }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
                        ForEach(model.colorOptions, id: \.0) { option in
                            Button { model.selectBackground(.color(option.1)) } label: {
                                VStack(spacing: 7) {
                                    Circle().fill(Color(nsColor: option.1))
                                        .frame(width: 32, height: 32)
                                        .overlay(Circle().stroke(.white.opacity(model.backgroundKind == .color(option.1) ? 0.9 : 0.15), lineWidth: 2))
                                    Text(option.0).font(.caption2)
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Button { model.chooseBackgroundImage() } label: {
                        Label("Elegir imagen de fondo…", systemImage: "photo.on.rectangle.angled")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    if case let .image(url) = model.backgroundKind {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(AppColors.accent)
                            Text(url.lastPathComponent).lineLimit(1).truncationMode(.middle)
                            Spacer()
                        }
                        .font(.caption).foregroundStyle(.secondary)
                        Picker("Ajuste de imagen", selection: $model.backgroundFit) {
                            ForEach(BackgroundFitMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .onChange(of: model.backgroundFit) { _, mode in model.selectBackgroundFit(mode) }
                        Text(model.backgroundFit == .fit ? "Ajustar muestra la imagen completa y rellena los bordes con desenfoque." : "Llenar cubre toda la escena; puede recortar la imagen.")
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text("La sustitución usa detección de personas en tiempo real. Para un mejor resultado, usa luz frontal y evita fondos muy recargados.")
                        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                }

                if let error = model.errorMessage, model.previewImage != nil {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption).foregroundStyle(.orange)
                }
            }
            .padding(22)
        }
        .frame(width: 320)
        .background(AppColors.panel)
    }

    private func sectionTitle(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon).font(.headline)
    }

    private func devicePicker(title: String, icon: String, selection: Binding<String>, devices: [CaptureDeviceItem]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: icon).font(.caption).foregroundStyle(.secondary)
            Picker(title, selection: selection) {
                ForEach(devices) { device in Text(device.name).tag(device.id) }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .disabled(model.isRecording)
            .onChange(of: selection.wrappedValue) { _, _ in model.configureCapture() }
        }
    }

    private func backgroundCard(title: String, systemImage: String, kind: BackgroundKind) -> some View {
        let selected = model.backgroundKind == kind
        return Button { model.selectBackground(kind) } label: {
            VStack(spacing: 10) {
                Image(systemName: systemImage).font(.title2)
                Text(title).font(.caption.weight(.medium))
            }
            .foregroundStyle(selected ? .white : .secondary)
            .frame(maxWidth: .infinity, minHeight: 74)
            .background(selected ? AppColors.accent.opacity(0.22) : AppColors.raised, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(selected ? AppColors.accent : AppColors.line, lineWidth: selected ? 2 : 1))
        }
        .buttonStyle(.plain)
    }

    private var backgroundLabel: String {
        switch model.backgroundKind {
        case .original: return "Fondo original"
        case .blur: return "Fondo desenfocado"
        case .color: return "Color sólido"
        case .image: return "Imagen personalizada"
        }
    }
}
