import CoreImage
import PhotosUI
import SwiftUI

struct Filter: Identifiable {
    var id: String { name }
    let name: String
    let inputKeys: [String]
    let outputKeys: [String]
    let attributes: [String: Any]

    var displayName: String? { attributes[kCIAttributeFilterDisplayName] as? String }
    var referenceDocumentation: URL? { attributes[kCIAttributeReferenceDocumentation] as? URL }
    var availableiOS: Int? { attributes[kCIAttributeFilterAvailable_iOS] as? Int }
    var availableMacOS: Int? { attributes[kCIAttributeFilterAvailable_Mac] as? Int }
    var categories: [String]? { attributes[kCIAttributeFilterCategories] as? [String] } // https://developer.apple.com/documentation/coreimage/cifilter/filter_category_keys

    var inputs: [FilterInput] {
        var results: [FilterInput] = []
        for inputKey in inputKeys {
            let inputAttributes = attributes[inputKey] as! [String: Any]
            let displayName = inputAttributes[kCIAttributeDisplayName] as! String
            let classType = inputAttributes[kCIAttributeClass] as! String
            let description = inputAttributes[kCIAttributeDescription] as? String
            guard let attributeType = FilterInputType(inputAttributes[kCIAttributeType] as? String) else { continue }

            // temporarily limit types
            guard attributeType == .scalar || attributeType == .distance else { continue }

            let values = FilterValues(
                defaultValue: inputAttributes[kCIAttributeDefault] as? Double,
                identityValue: inputAttributes[kCIAttributeIdentity] as? Double,
                minValue: inputAttributes[kCIAttributeMin] as? Double,
                maxValue: inputAttributes[kCIAttributeMax] as? Double,
                sliderMinValue: inputAttributes[kCIAttributeSliderMin] as? Double,
                sliderMaxValue: inputAttributes[kCIAttributeSliderMax] as? Double
            )
            let result = FilterInput(name: inputKey, displayName: displayName, classType: classType, description: description, inputType: attributeType, values: values)
            results.append(result)
        }
        return results
    }

    var isValid: Bool {
        guard inputKeys.contains(kCIInputImageKey) else { return false }
        guard outputKeys.contains(kCIOutputImageKey) else { return false }
        return true
    }
}

struct FilterInput: Identifiable {
    var id: String { displayName }
    let name: String
    let displayName: String
    let classType: String
    let description: String?
    let inputType: FilterInputType
    let values: FilterValues
}

struct FilterValues {
    let defaultValue: Double?
    let identityValue: Double?
    let minValue: Double?
    let maxValue: Double?
    let sliderMinValue: Double?
    let sliderMaxValue: Double?

    var preferredDefaultValue: Double {
        var result = defaultValue
        result = result ?? identityValue
        result = result ?? minValue
        result = result ?? maxValue
        result = result ?? sliderMinValue
        result = result ?? sliderMaxValue
        return result ?? 0
    }

    var preferredSliderMinValue: Double {
        var result = minValue
        result = result ?? sliderMinValue
        return result ?? 0
    }

    var preferredSliderMaxValue: Double {
        var result = maxValue
        result = result ?? sliderMaxValue
        return result ?? 0
    }
}

enum FilterInputType {
    case time
    case scalar
    case distance
    case angle
    case boolean
    case integer
    case count

    init?(_ attributeType: String?) {
        switch attributeType {
        case kCIAttributeTypeTime: self = .time
        case kCIAttributeTypeScalar: self = .scalar
        case kCIAttributeTypeDistance: self = .distance
        case kCIAttributeTypeAngle: self = .angle
        case kCIAttributeTypeBoolean: self = .boolean
        case kCIAttributeTypeInteger: self = .integer
        case kCIAttributeTypeCount: self = .count
        default: return nil
        }
    }

    var cIAttributeType: String {
        switch self {
        case .time: kCIAttributeTypeTime
        case .scalar: kCIAttributeTypeScalar
        case .distance: kCIAttributeTypeDistance
        case .angle: kCIAttributeTypeAngle
        case .boolean: kCIAttributeTypeBoolean
        case .integer: kCIAttributeTypeInteger
        case .count: kCIAttributeTypeCount
        }
    }
}

struct UserFilter: Identifiable, Equatable {
    let id: UUID = .init()
    let name: String
    var inputs: [UserFilterInput] = []
    var isExpanded: Bool = true
    var isEnabled: Bool = true
}

struct UserFilterInput: Identifiable, Equatable {
    var id: String { displayName }
    let name: String
    let displayName: String
    var value: Double
}

extension UserFilter {
    static let mock = UserFilter(
        name: "CIBloom",
        inputs: [
            .init(name: "inputIntensity", displayName: "Intensity", value: 0.5),
        ]
    )
}

func allFilters() -> [Filter] {
    var filters: [Filter] = []
    let filterNames = CIFilter.filterNames(inCategory: kCICategoryBuiltIn) as [String]
    for filterName in filterNames {
        let ciFilter = CIFilter(name: filterName)!
        let filter = Filter(name: filterName, inputKeys: ciFilter.inputKeys, outputKeys: ciFilter.outputKeys, attributes: ciFilter.attributes)
        if filter.isValid {
            filters.append(filter)
        }
    }
    return filters
}

struct FiltersView: View {
    @State var inputImage: UIImage? = nil
    let testImage: UIImage = .init(named: "sendai")!
    var unfilteredImage: UIImage { inputImage ?? testImage }
    @State var inputLibraryItem: PhotosPickerItem? = nil

    let filters: [Filter.ID: Filter] = .init(uniqueKeysWithValues: allFilters().map { ($0.id, $0) })
    @State var isShowingAdd: Bool = false
    @State var userFilters: [UserFilter] = [.mock]
    @State var filteredImage: UIImage? = nil
    @State var isEditing: Bool = false
    @State var isTouchingImage: Bool = false
    @State var useOriginalAspectRatio: Bool = false
    let imageProcessor = ImageProcessor()

    let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ZStack {
                    Image(uiImage: unfilteredImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                    if let filteredImage {
                        Image(uiImage: filteredImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .opacity(isTouchingImage ? 0.0 : 1.0)
                    }
                }
                .aspectRatio(useOriginalAspectRatio ? nil : 1.0, contentMode: .fit)
                .containerRelativeFrame(.vertical) { size, axis in size * 0.4 }
                .clipped()
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isTouchingImage = true
                        }
                        .onEnded { value in
                            isTouchingImage = false
                        }
                )

                List {
                    Section {
                        GroupBox("Input Image") {
                            VStack(spacing: 16) {
                                HStack {
                                    Group {
                                        if inputLibraryItem == nil || (inputLibraryItem != nil && inputImage == nil) {
                                            PhotosPicker(selection: $inputLibraryItem, matching: .images, preferredItemEncoding: .current) {
                                                Text(inputLibraryItem == nil ? "Select Image From Library" : "Loading Image...")
                                            }
                                        } else {
                                            Button("Remove Image") { inputLibraryItem = nil }
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                }
                                .task(id: inputLibraryItem) {
                                    if let item = inputLibraryItem,
                                       let data = try? await item.loadTransferable(type: Data.self)
                                    {
                                        inputImage = UIImage(data: data)
                                    } else {
                                        filteredImage = nil
                                        inputImage = nil
                                    }
                                }

                                HStack {
                                    Text("Viewer Aspect Ratio")
                                        .font(.subheadline)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Picker("Viewer Aspect Ratio", selection: $useOriginalAspectRatio) {
                                        Text("Original").tag(true)
                                        Text("Square").tag(false)
                                    }
                                    .pickerStyle(.segmented)
                                }
                            }
                        }
                    } header: {
                        Text("Inputs")
                            .font(.headline)
                    }
                    filtersSection
                }
                .listStyle(.plain)
            }
            .environment(\.editMode, isEditing ? .constant(.active) : .constant(.inactive))
            .task(id: userFilters) { await processImage() }
            .task(id: unfilteredImage) { await processImage() }
            .sheet(isPresented: $isShowingAdd) {
                AddFilterView { filter in
                    userFilters.append(filter)
                }
            }
        }
    }

    private func processImage() async {
        guard !userFilters.isEmpty else { return }
        do {
            try await Task.sleep(for: .milliseconds(100))
            filteredImage = await imageProcessor.processImage(inputImage: unfilteredImage, filters: userFilters, ciContext: ciContext)
        } catch {}
    }

    @ViewBuilder var filtersSection: some View {
        Section {
            ForEach($userFilters) { $userFilter in
                VStack(spacing: 10) {
                    HStack {
                        Toggle(userFilter.name, isOn: $userFilter.isEnabled)
                            .toggleStyle(.button)
                        Spacer()
                        if !isEditing {
                            Button {
                                userFilter.isExpanded.toggle()
                            } label: {
                                Image(systemName: userFilter.isExpanded ? "chevron.down" : "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if userFilter.isExpanded, !isEditing {
                        ForEach($userFilter.inputs) { $input in
                            GroupBox {
                                let filter = filters[userFilter.name]!
                                if let matchingInput = filter.inputs.first(where: { $0.name == input.name }) {
                                    let values = matchingInput.values
                                    let sliderMin = values.preferredSliderMinValue
                                    let sliderMax = values.preferredSliderMaxValue
                                    HStack {
                                        Slider(value: $input.value, in: sliderMin ... sliderMax) {
                                            Text(input.name)
                                        } minimumValueLabel: {
                                            Text(sliderMin, format: .number.precision(.significantDigits(2)))
                                        } maximumValueLabel: {
                                            Text(sliderMax, format: .number.precision(.significantDigits(2)))
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(input.name)
                                    Spacer()
                                    Text(input.value, format: .number.precision(.significantDigits(4)))
                                }
                            }
                        }
                    }
                }
                .moveDisabled(!isEditing)
                .deleteDisabled(!isEditing)
            }
            .onMove { from, to in userFilters.move(fromOffsets: from, toOffset: to) }
            .onDelete { indexSet in userFilters.remove(atOffsets: indexSet) }
        } header: {
            HStack {
                Text("Filters")
                Spacer()
                Toggle("Edit", isOn: $isEditing)
                    .toggleStyle(.button)
                Button("Add", systemImage: "plus") {
                    isShowingAdd = true
                }
                .labelStyle(.iconOnly)
                .disabled(isEditing)
            }
            .font(.headline)
        }
    }
}

struct AddFilterView: View {
    @Environment(\.dismiss) private var dismiss
    var action: ((UserFilter) -> Void)?

    var body: some View {
        NavigationStack {
            List(allFilters()) { filter in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(filter.name)
                        Text(filter.inputs.map(\.displayName).joined(separator: "・"))
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Button("Add", systemImage: "plus") {
                        let inputs: [UserFilterInput] = filter.inputs.map { (input: FilterInput) in
                            UserFilterInput(name: input.name, displayName: input.displayName, value: input.values.preferredDefaultValue)
                        }
                        let userFilter = UserFilter(
                            name: filter.name,
                            inputs: inputs
                        )
                        action?(userFilter)
                        dismiss()
                    }
                    .labelStyle(.iconOnly)
                }
            }
            .listStyle(.plain)
            .navigationTitle("All Scalar Filters")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done", systemImage: "xmark") {
                        dismiss()
                    }
                }
            }
        }
    }
}

actor ImageProcessor {
    private var filterCache: [UserFilter.ID: CIFilter] = [:]

    func processImage(inputImage: UIImage, filters: [UserFilter], ciContext: CIContext) async -> UIImage {
        let ciImage = CIImage(cgImage: inputImage.cgImage!)
        var resultImage: CIImage = ciImage
        for userFilter in filters {
            guard userFilter.isEnabled else { continue }
            let filter = filterCache[userFilter.id] ?? CIFilter(name: userFilter.name)!
            filterCache[userFilter.id] = filter
            filter.setValue(resultImage, forKey: kCIInputImageKey)
            for userFilterInput in userFilter.inputs {
                filter.setValue(userFilterInput.value, forKey: userFilterInput.name)
            }
            resultImage = filter.outputImage!
        }
        let filteredImage = UIImage(cgImage: ciContext.createCGImage(resultImage, from: ciImage.extent)!, scale: inputImage.scale, orientation: inputImage.imageOrientation)
        return filteredImage
    }
}

#Preview {
    FiltersView()
}
