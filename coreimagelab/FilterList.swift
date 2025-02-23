import CoreImage
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

    var scalarInputs: [FilterInput] {
        var results: [FilterInput] = []
        for inputKey in inputKeys {
            let inputAttributes = attributes[inputKey] as! [String: Any]
            let displayName = inputAttributes[kCIAttributeDisplayName] as! String
            let classType = inputAttributes[kCIAttributeClass] as! String
            let description = inputAttributes[kCIAttributeDescription] as? String

            guard inputAttributes[kCIAttributeType] as? String == kCIAttributeTypeScalar else { continue }
            let inputScalar = FilterInputScalar(
                defaultValue: inputAttributes[kCIAttributeDefault] as? Double,
                identityValue: inputAttributes[kCIAttributeIdentity] as? Double,
                minValue: inputAttributes[kCIAttributeMin] as? Double,
                maxValue: inputAttributes[kCIAttributeMin] as? Double,
                sliderMinValue: inputAttributes[kCIAttributeSliderMin] as? Double,
                sliderMaxValue: inputAttributes[kCIAttributeSliderMax] as? Double
            )
            let result = FilterInput(name: inputKey, displayName: displayName, classType: classType, description: description, inputType: .scalar(inputScalar))
            results.append(result)
        }
        return results
    }

    var isValid: Bool {
        guard inputKeys.contains(kCIInputImageKey) else { return false }
        guard outputKeys.contains(kCIOutputImageKey) else { return false }
        guard !scalarInputs.isEmpty else { return false }
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
}

struct FilterInputScalar {
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
}

enum FilterInputType {
    case time
    case scalar(FilterInputScalar)
    case distance
    case angle
    case boolean
    case integer
    case count

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
    let initialImage: UIImage = .init(named: "sendai")!
    let filters: [Filter.ID: Filter] = .init(uniqueKeysWithValues: allFilters().map { ($0.id, $0) })
    @State var isShowingAdd: Bool = false
    @State var userFilters: [UserFilter] = [.mock]
    @State var filteredImage: UIImage? = nil
    @State var isEditing: Bool = false
    @State var isTouchingImage: Bool = false
    @State var aspectRatio: CGFloat? = nil
    let imageProcessor = ImageProcessor()

    let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    var body: some View {
        NavigationStack {
            VStack {
                ZStack {
                    Image(uiImage: initialImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                    Image(uiImage: filteredImage ?? initialImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .opacity(isTouchingImage ? 0.0 : 1.0)
                }
                .aspectRatio(aspectRatio, contentMode: .fill)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isTouchingImage = true
                        }
                        .onEnded { value in
                            if abs(value.velocity.height) > 300 {
                                if aspectRatio == nil {
                                    aspectRatio = 1.0
                                } else {
                                    aspectRatio = nil
                                }
                            }
                            isTouchingImage = false
                        }
                )

                HStack {
                    Text("Active Filters")
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
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .onChange(of: isEditing) { oldValue, newValue in
                }
                List {
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
                                    GroupBox(input.name) {
                                        let filter = filters[userFilter.name]!
                                        if let matchingScalarInput = filter.scalarInputs.first(where: { $0.name == input.name }),
                                           case let .scalar(scalarInput) = matchingScalarInput.inputType,
                                           let sliderMin = scalarInput.sliderMinValue,
                                           let sliderMax = scalarInput.sliderMaxValue
                                        {
                                            HStack {
                                                Slider(value: $input.value, in: sliderMin ... sliderMax)
                                                Text(input.value, format: .number.precision(.significantDigits(2)))
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .moveDisabled(!isEditing)
                    }
                    .onMove { from, to in userFilters.move(fromOffsets: from, toOffset: to) }
                    .onDelete { indexSet in userFilters.remove(atOffsets: indexSet) }
                }
                .listStyle(.plain)
            }
            .environment(\.editMode, isEditing ? .constant(.active) : .constant(.inactive))
            .task(id: userFilters) {
                guard !userFilters.isEmpty else { return }
                do {
                    try await Task.sleep(for: .milliseconds(100))
                    filteredImage = await imageProcessor.processImage(inputImage: initialImage, filters: userFilters, ciContext: ciContext)
                } catch {}
            }
            .sheet(isPresented: $isShowingAdd) {
                AddFilterView { filter in
                    userFilters.append(filter)
                }
            }
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
                        Text(filter.scalarInputs.map(\.displayName).joined(separator: "・"))
                            .foregroundStyle(.secondary)
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Button("Add", systemImage: "plus") {
                        let inputs: [UserFilterInput] = filter.scalarInputs.map { (input: FilterInput) in
                            guard case let .scalar(scalarInput) = input.inputType else { fatalError("only scalar inputs supported") }
                            return UserFilterInput(name: input.name, displayName: input.displayName, value: scalarInput.preferredDefaultValue)
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
        var inputImage: CIImage = ciImage
        for userFilter in filters {
            guard userFilter.isEnabled else { continue }
            let filter = filterCache[userFilter.id] ?? CIFilter(name: userFilter.name)!
            filterCache[userFilter.id] = filter
            filter.setValue(inputImage, forKey: kCIInputImageKey)
            for userFilterInput in userFilter.inputs {
                filter.setValue(userFilterInput.value, forKey: userFilterInput.name)
            }
            inputImage = filter.outputImage!
        }
        let filteredImage = UIImage(cgImage: ciContext.createCGImage(inputImage, from: ciImage.extent)!)
        return filteredImage
    }
}

#Preview {
    FiltersView()
}
