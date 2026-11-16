import PhotosUI
import SwiftUI

/// Square photo of a machine, or a placeholder icon.
struct PhotoThumb: View {
    let image: UIImage?
    var size: CGFloat = 56

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: "dumbbell.fill").font(.system(size: size * 0.35)).foregroundStyle(Theme.muted)
            }
        }
        .frame(width: size, height: size)
        .background(Theme.surface3)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
    }
}

/// Photo full screen, zoomable with two fingers.
struct PhotoViewer: View {
    let image: UIImage
    let title: String
    @Environment(\.dismiss) private var dismiss
    @State private var zoom: CGFloat = 1
    @GestureState private var pinch: CGFloat = 1

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .scaleEffect(min(max(zoom * pinch, 1), 5))
                .gesture(MagnifyGesture()
                    .updating($pinch) { value, state, _ in state = value.magnification }
                    .onEnded { value in zoom = min(max(zoom * value.magnification, 1), 5) })
                .onTapGesture(count: 2) { withAnimation { zoom = zoom > 1 ? 1 : 2.5 } }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack {
                Text(title).font(.system(size: 17, weight: .bold))
                Spacer()
                RoundButton(label: "✕", fontSize: 16, action: { dismiss() })
            }
            .padding(16)
        }
        .foregroundStyle(Theme.ink)
    }
}

/// Buttons to take or choose the single photo of an item.
struct PhotoField: View {
    /// Photo shown now: the saved one or the one just picked.
    let current: UIImage?
    let onPick: (UIImage?) -> Void

    @State private var libraryItem: PhotosPickerItem?
    @State private var showCamera = false

    var body: some View {
        HStack(spacing: 14) {
            PhotoThumb(image: current, size: 84)
            VStack(alignment: .leading, spacing: 8) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button { showCamera = true } label: { Label("Scatta foto", systemImage: "camera") }
                }
                PhotosPicker(selection: $libraryItem, matching: .images) {
                    Label("Scegli dalla libreria", systemImage: "photo.on.rectangle")
                }
                if current != nil {
                    Button(role: .destructive) { onPick(nil) } label: { Label("Rimuovi", systemImage: "trash") }
                }
            }
            .buttonStyle(.borderless)
            .font(.system(size: 15))
        }
        .onChange(of: libraryItem) {
            guard let libraryItem else { return }
            Task {
                if let data = try? await libraryItem.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    onPick(image)
                }
                self.libraryItem = nil
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker { onPick($0) }.ignoresSafeArea()
        }
    }
}

/// The iPhone camera (SwiftUI has no camera view of its own).
private struct CameraPicker: UIViewControllerRepresentable {
    let onPick: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ picker: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage { parent.onPick(image) }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { parent.dismiss() }
    }
}

/// Name and size of a room.
struct RoomEditor: View {
    let gym: GymStore
    @State var room: Room
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Nome") {
                    TextField("Sala pesi", text: $room.name)
                }
                Section {
                    Stepper("Colonne: \(room.columns) (A–\(MapItem.columnName(room.columns)))",
                            value: $room.columns, in: room.minColumns...52)
                    Stepper("Righe: \(room.rows)", value: $room.rows, in: room.minRows...200)
                } header: {
                    Text("Griglia")
                } footer: {
                    Text("Non può diventare più piccola dei macchinari che contiene. Si allarga da sola se metti un macchinario oltre il bordo.")
                }
                if gym.map.rooms.count > 1 {
                    Section {
                        Button("Elimina sala", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .navigationTitle("Sala")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annulla") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") {
                        gym.updateRoom(room)
                        dismiss()
                    }
                    .disabled(room.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .confirmationDialog("Eliminare \(room.name) con tutti i suoi macchinari?", isPresented: $confirmDelete,
                                titleVisibility: .visible) {
                Button("Elimina", role: .destructive) {
                    gym.removeRoom(room.id)
                    dismiss()
                }
            }
        }
    }
}
