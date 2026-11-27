//
//  PhotoDetailView.swift
//  EchoesInTime
//

import SwiftData
import SwiftUI

struct PhotoDetailView: View {
    let photo: CachedPhoto
    let token: String
    let localId: String

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var location = ""
    @State private var peopleText = ""
    @State private var dateTaken = Date()
    @State private var isSaving = false
    @State private var isDeleting = false
    @State private var showDeleteConfirmation = false
    @State private var errorMessage: String?

    private var hasChanges: Bool {
        let currentPeople = peopleText
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return location != photo.location
            || currentPeople != photo.people
            || dateTaken != photo.dateTaken
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let uiImage = LocalImageCache.loadImage(filename: photo.localImageFilename) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemBackground))
                            .aspectRatio(4 / 3, contentMode: .fit)
                        ProgressView()
                    }
                }

                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Location")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Location", text: $location)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("People")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("People (comma separated)", text: $peopleText)
                            .textFieldStyle(.roundedBorder)
                    }

                    DatePicker("Date Taken", selection: $dateTaken, displayedComponents: [.date, .hourAndMinute])
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }

                Text("Uploaded: \(photo.dateUploaded.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .navigationTitle("Edit Memory")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    Task { await saveChanges() }
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text("Save")
                    }
                }
                .disabled(!hasChanges || isSaving || isDeleting)
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Delete Memory", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(isSaving || isDeleting)
            .padding()
        }
        .confirmationDialog("Delete this memory?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                Task { await deletePhoto() }
            }
        } message: {
            Text("This will remove the photo from all devices.")
        }
        .onAppear {
            location = photo.location
            peopleText = photo.people.joined(separator: ", ")
            dateTaken = photo.dateTaken
        }
    }

    private func saveChanges() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }

        let newPeople = peopleText
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        photo.location = location
        photo.people = newPeople
        photo.dateTaken = dateTaken
        photo.needsSync = true
        photo.localModifiedAt = Date()

        try? modelContext.save()

        await SyncCoordinator.shared.pushChanges(
            userId: localId,
            idToken: token,
            in: modelContext
        )
    }

    private func deletePhoto() async {
        isDeleting = true

        photo.isSoftDeleted = true
        photo.needsSync = true
        photo.localModifiedAt = Date()

        try? modelContext.save()

        await SyncCoordinator.shared.pushChanges(
            userId: localId,
            idToken: token,
            in: modelContext
        )

        LocalImageCache.deleteImage(filename: photo.localImageFilename)
        dismiss()
    }
}
