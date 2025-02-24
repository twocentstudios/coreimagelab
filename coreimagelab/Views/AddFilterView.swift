import SwiftUI

struct AddFilterView: View {
    let filters: [Filter.ID: Filter]

    @State var isShowingUnsupportedFilters: Bool = false

    @Environment(\.dismiss) private var dismiss
    var action: ((UserFilter) -> Void)?

    var sortedFilters: [(String, [Filter])] {
        var result: [String: [Filter]] = [:]
        for filter in filters.values {
            if !isShowingUnsupportedFilters, !filter.isSupported { continue }
            guard let representativeCategory = filter.categories?.first(where: { Filter.supportedCategories.contains($0) }) else {
                print("Category not found", filter.name)
                continue
            }
            result[representativeCategory] = (result[representativeCategory] ?? []) + [filter]
        }
        return result.sorted { $0.key < $1.key }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(sortedFilters, id: \.0) {
                    category,
                        filters in
                    Section(category) {
                        ForEach(filters) { filter in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(filter.name)
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 4) {
                                            ForEach(filter.inputs) { input in
                                                let isSupported = input.isSupported
                                                Text(input.displayName)
                                                    .foregroundStyle(isSupported ? Color.secondary : Color.red)
                                                    .font(.caption)
                                                Divider().containerRelativeFrame(.vertical) { size, _ in size * 0.6 }
                                            }
                                        }
                                    }
                                    .scrollClipDisabled(true)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                Button("Add", systemImage: "plus") {
                                    let inputs: [UserFilterInput] = filter.inputs
                                        .filter { !$0.isGlobalInput }
                                        .map { (input: FilterInput) in
                                            UserFilterInput(name: input.name, displayName: input.displayName, value: input.values.preferredDefaultValue)
                                        }
                                    let userFilter = UserFilter(
                                        name: filter.name,
                                        inputs: inputs
                                    )
                                    action?(userFilter)
                                    dismiss()
                                }
                                .foregroundStyle(.secondary)
                                .labelStyle(.iconOnly)
                                .opacity(filter.isSupported ? 1.0 : 0)
                                .disabled(!filter.isSupported)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle(isShowingUnsupportedFilters ? "All Filters" : "Supported Filters")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done", systemImage: "xmark") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .automatic) {
                    Toggle("Show All", isOn: $isShowingUnsupportedFilters)
                        .padding(.trailing)
                }
            }
        }
    }
}
