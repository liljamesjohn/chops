import SwiftUI
import SwiftData

struct CollectionListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SkillCollection.sortOrder) private var collections: [SkillCollection]
    @State private var showingNewCollection = false
    @State private var newCollectionName = ""
    @State private var newCollectionIcon = "folder"

    private let availableIcons = [
        "folder", "star", "bookmark", "tag", "tray",
        "archivebox", "doc.text", "gearshape", "wrench",
        "hammer", "paintbrush", "wand.and.stars", "terminal",
        "network", "globe", "bolt", "flame", "leaf"
    ]

    private var trimmedCollectionName: String {
        newCollectionName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        ForEach(collections) { collection in
            Label(collection.name, systemImage: collection.icon)
                .badge(collection.skills.count)
                .tag(SidebarFilter.collection(collection.name))
                .contextMenu {
                    Button("Delete", role: .destructive) {
                        modelContext.delete(collection)
                        try? modelContext.save()
                    }
                }
        }

        Button {
            showingNewCollection = true
        } label: {
            Label("New Collection", systemImage: "plus.circle")
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showingNewCollection) {
            VStack(spacing: 12) {
                TextField("Collection name", text: $newCollectionName)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.done)
                    .onSubmit(createCollection)

                LazyVGrid(columns: Array(repeating: GridItem(.fixed(28)), count: 6), spacing: 8) {
                    ForEach(availableIcons, id: \.self) { icon in
                        Button {
                            newCollectionIcon = icon
                        } label: {
                            Image(systemName: icon)
                                .font(.body)
                                .frame(width: 28, height: 28)
                                .background(
                                    newCollectionIcon == icon ?
                                    Color.accentColor.opacity(0.2) :
                                    Color.clear,
                                    in: RoundedRectangle(cornerRadius: 4)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack {
                    Button("Cancel") { showingNewCollection = false }
                    Spacer()
                    Button("Create", action: createCollection)
                    .disabled(trimmedCollectionName.isEmpty)
                }
            }
            .padding()
            .frame(width: 240)
        }
    }

    private func createCollection() {
        guard !trimmedCollectionName.isEmpty else { return }

        let collection = SkillCollection(
            name: trimmedCollectionName,
            icon: newCollectionIcon,
            sortOrder: collections.count
        )
        modelContext.insert(collection)
        try? modelContext.save()
        newCollectionName = ""
        showingNewCollection = false
    }
}
