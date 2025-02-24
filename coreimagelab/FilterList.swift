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

//            if inputAttributes[kCIAttributeType] as? String == kCIAttributeTypeDistance {
//                print(inputAttributes)
//            }

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
    var isEnabled: Bool = true
    var canExpand: Bool { !inputs.isEmpty }
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
    let filters: [Filter.ID: Filter] = .init(uniqueKeysWithValues: allFilters().map { ($0.id, $0) })

    @State var inputImage: UIImage? = nil
    let testImage: UIImage = .init(named: "sendai")!
    var unfilteredImage: UIImage { inputImage ?? testImage }
    @State var inputLibraryItem: PhotosPickerItem? = nil

    @State var inputBackgroundImage: UIImage? = nil
    @State var inputBackgroundLibraryItem: PhotosPickerItem? = nil

    @State var isShowingAdd: Bool = false

    @State var userFilters: [UserFilter] = []
    @State var filteredImage: UIImage? = nil
    @State var isEditing: Bool = false
    @State var isTouchingImage: Bool = false
    @State var useOriginalAspectRatio: Bool = false
    @State var isScalingBackgroundImage: Bool = false
    @State var isProcessing: Bool = false

    @State var expandedFilters: [UserFilter.ID: Bool] = [:]

    @AppStorage("isInputsExpanded") var isInputsExpanded: Bool = true

    let imageProcessor = ImageProcessor()
    let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ZStack {
                    Image(uiImage: unfilteredImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .opacity((isTouchingImage || filteredImage == nil) ? 1.0 : 0.0)
                    if let filteredImage {
                        Image(uiImage: filteredImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .opacity(isTouchingImage ? 0.0 : 1.0)
                    }
                }
                .aspectRatio(useOriginalAspectRatio ? nil : 1.0, contentMode: .fit)
                .containerRelativeFrame(.vertical) { size, _ in size * 0.4 }
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
                        if isInputsExpanded {
                            inputImageSection
                            inputBackgroundImageSection
                        }
                    } header: {
                        Button {
                            isInputsExpanded.toggle()
                        } label: {
                            HStack {
                                Text("Inputs")
                                    .font(.headline)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .rotationEffect(isInputsExpanded ? .zero : .degrees(-90))
                                    .foregroundStyle(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    filtersSection
                }
                .listStyle(.plain)
            }
            .animation(.default, value: isEditing)
            .animation(.bouncy, value: isInputsExpanded)
            .environment(\.editMode, isEditing ? .constant(.active) : .constant(.inactive))
            .task(id: userFilters) { await processImage() }
            .task(id: unfilteredImage) { await processImage() }
            .task(id: inputBackgroundImage) { await processImage() }
            .task(id: isScalingBackgroundImage) { await processImage() }
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
            .task(id: inputBackgroundLibraryItem) {
                if let item = inputBackgroundLibraryItem,
                   let data = try? await item.loadTransferable(type: Data.self)
                {
                    inputBackgroundImage = UIImage(data: data)
                } else {
                    filteredImage = nil
                    inputBackgroundImage = nil
                }
            }
            .sheet(isPresented: $isShowingAdd) {
                AddFilterView { filter in
                    userFilters.append(filter)
                }
            }
        }
    }

    private func processImage() async {
        guard !userFilters.isEmpty else { return }
        isProcessing = true
        do {
            try await Task.sleep(for: .milliseconds(20))
            filteredImage = try await imageProcessor.processImage(
                inputImage: unfilteredImage,
                inputBackgroundImage: inputBackgroundImage,
                filters: userFilters,
                isScalingBackgroundImage: isScalingBackgroundImage,
                ciContext: ciContext
            )
        } catch {
            if !(error is CancellationError) {
                print(error)
            }
        }
        isProcessing = false
    }

    @ViewBuilder var inputImageSection: some View {
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
    }

    @ViewBuilder var inputBackgroundImageSection: some View {
        GroupBox("Background Image") {
            VStack(spacing: 16) {
                HStack {
                    Group {
                        if inputBackgroundLibraryItem == nil || (inputBackgroundLibraryItem != nil && inputBackgroundImage == nil) {
                            PhotosPicker(selection: $inputBackgroundLibraryItem, matching: .images, preferredItemEncoding: .current) {
                                Text(inputBackgroundLibraryItem == nil ? "Select Image From Library" : "Loading Image...")
                            }
                        } else {
                            Button("Remove Image") { inputBackgroundLibraryItem = nil }
                        }
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                Toggle("Scale to Fill Input Image", isOn: $isScalingBackgroundImage)
                    .font(.subheadline)
            }
        }
    }

    @ViewBuilder var filtersSection: some View {
        Section {
            ForEach($userFilters) { $userFilter in
                let isExpanded: Bool = expandedFilters[userFilter.id, default: true]
                VStack(spacing: 10) {
                    HStack {
                        Toggle(userFilter.name, isOn: $userFilter.isEnabled)
                            .toggleStyle(.button)
                        Spacer()
                        if userFilter.canExpand, !isEditing {
                            Button {
                                expandedFilters[userFilter.id] = !isExpanded
                            } label: {
                                Image(systemName: "chevron.down")
                                    .rotationEffect(isExpanded ? .zero : .degrees(-90))
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if isExpanded, userFilter.canExpand, !isEditing {
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
                .animation(.default, value: isExpanded)
                .moveDisabled(!isEditing)
                .deleteDisabled(!isEditing)
            }
            .onMove { from, to in userFilters.move(fromOffsets: from, toOffset: to) }
            .onDelete { indexSet in userFilters.remove(atOffsets: indexSet) }
        } header: {
            HStack {
                Text("Filters")
                ProgressView().opacity(isProcessing ? 1 : 0)
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
            .navigationTitle("All Filters")
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

    func processImage(
        inputImage: UIImage,
        inputBackgroundImage: UIImage?,
        filters: [UserFilter],
        isScalingBackgroundImage: Bool,
        ciContext: CIContext
    ) async throws -> UIImage {
        let ciImage = CIImage(image: inputImage, options: [.applyOrientationProperty: true])!
            .oriented(forExifOrientation: inputImage.imageOrientation.exifOrientation)
        let ciBackgroundImage = inputBackgroundImage.flatMap {
            CIImage(image: $0, options: [.applyOrientationProperty: true])?
                .oriented(forExifOrientation: $0.imageOrientation.exifOrientation)
                .transformed(by: isScalingBackgroundImage
                    ? CGAffineTransform(scaleX: inputImage.size.width / $0.size.width, y: inputImage.size.height / $0.size.height)
                    : .identity
                )
        }
        var resultImage: CIImage = ciImage
        for userFilter in filters {
            guard userFilter.isEnabled else { continue }
            let filter = filterCache[userFilter.id] ?? CIFilter(name: userFilter.name)!
            filterCache[userFilter.id] = filter
            filter.setValue(resultImage, forKey: kCIInputImageKey)
            if filter.inputKeys.contains(kCIInputBackgroundImageKey) {
                if let ciBackgroundImage {
                    filter.setValue(ciBackgroundImage, forKey: kCIInputBackgroundImageKey)
                } else {
                    filter.setValue(nil, forKey: kCIInputBackgroundImageKey)
                }
            }
            for userFilterInput in userFilter.inputs {
                filter.setValue(userFilterInput.value, forKey: userFilterInput.name)
            }
            resultImage = filter.outputImage!
        }
        try Task.checkCancellation()
        let filteredImage = UIImage(cgImage: ciContext.createCGImage(resultImage, from: ciImage.extent, format: ciContext.workingFormat, colorSpace: inputImage.cgImage?.colorSpace, deferred: false)!, scale: inputImage.scale, orientation: inputImage.imageOrientation)
        try Task.checkCancellation()
        return filteredImage
    }
}

#Preview {
    FiltersView()
}

extension UIImage.Orientation {
    var exifOrientation: Int32 {
        switch self {
        case .up: return 1
        case .down: return 3
        case .left: return 8
        case .right: return 6
        case .upMirrored: return 2
        case .downMirrored: return 4
        case .leftMirrored: return 5
        case .rightMirrored: return 7
        @unknown default: return 0
        }
    }
}
