import CoreImage
import UIKit.UIImage
import CoreTransferable

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

    var isSupported: Bool {
        guard inputKeys.contains(kCIInputImageKey) else { return false }
        guard outputKeys.contains(kCIOutputImageKey) else { return false }
        guard inputs.map(\.isSupported).allSatisfy(\.self) else { return false }
        return true
    }
}

extension Filter {
    static let supportedCategories: Set<String> = [kCICategoryDistortionEffect, kCICategoryGeometryAdjustment, kCICategoryCompositeOperation, kCICategoryHalftoneEffect, kCICategoryColorAdjustment, kCICategoryColorEffect, kCICategoryTransition, kCICategoryTileEffect, kCICategoryGenerator, kCICategoryReduction, kCICategoryGradient, kCICategoryStylize, kCICategorySharpen, kCICategoryBlur, kCICategoryFilterGenerator]
}

struct FilterInput: Identifiable {
    var id: String { displayName }
    let name: String
    let displayName: String
    let classType: String
    let description: String?
    let inputType: FilterInputType
    let values: FilterValues

    var isGlobalInput: Bool {
        name == kCIInputImageKey || name == kCIInputBackgroundImageKey || name == kCIInputTargetImageKey
    }

    var isSupported: Bool {
        FilterInputType.supported.contains(inputType) || isGlobalInput
    }
}

extension FilterInputType {
    static let supported: Set<FilterInputType> = [.scalar, .distance, .time, .integer, .angle]
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
    case position
    case offset
    case position3
    case rectangle
    case opaqueColor
    case color
    case gradient
    case image
    case transform

    init?(_ attributeType: String?) {
        switch attributeType {
        case kCIAttributeTypeTime: self = .time
        case kCIAttributeTypeScalar: self = .scalar
        case kCIAttributeTypeDistance: self = .distance
        case kCIAttributeTypeAngle: self = .angle
        case kCIAttributeTypeBoolean: self = .boolean
        case kCIAttributeTypeInteger: self = .integer
        case kCIAttributeTypeCount: self = .count
        case kCIAttributeTypePosition: self = .position
        case kCIAttributeTypeOffset: self = .offset
        case kCIAttributeTypePosition3: self = .position3
        case kCIAttributeTypeRectangle: self = .rectangle
        case kCIAttributeTypeOpaqueColor: self = .opaqueColor
        case kCIAttributeTypeColor: self = .color
        case kCIAttributeTypeGradient: self = .gradient
        case kCIAttributeTypeImage: self = .image
        case kCIAttributeTypeTransform: self = .transform
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
        case .position: kCIAttributeTypePosition
        case .offset: kCIAttributeTypeOffset
        case .position3: kCIAttributeTypePosition3
        case .rectangle: kCIAttributeTypeRectangle
        case .opaqueColor: kCIAttributeTypeOpaqueColor
        case .color: kCIAttributeTypeColor
        case .gradient: kCIAttributeTypeGradient
        case .image: kCIAttributeTypeImage
        case .transform: kCIAttributeTypeTransform
        }
    }
}

struct UserFilter: Identifiable, Equatable, Codable {
    var id: UUID = .init()
    let name: String
    var inputs: [UserFilterInput] = []
    var isEnabled: Bool = true
    var canExpand: Bool { !inputs.isEmpty }
}

struct UserFilterInput: Identifiable, Equatable, Codable {
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
            .init(name: "inputRadius", displayName: "Radius", value: 10.0),
        ]
    )
}

func allFilters() -> [Filter] {
    var filters: [Filter] = []
    let filterNames = CIFilter.filterNames(inCategory: kCICategoryBuiltIn) as [String]
    for filterName in filterNames {
        let ciFilter = CIFilter(name: filterName)!
        let filter = Filter(name: filterName, inputKeys: ciFilter.inputKeys, outputKeys: ciFilter.outputKeys, attributes: ciFilter.attributes)
        filters.append(filter)
//        if filter.categories?.contains(kCICategoryTransition) == true {
//            print(filter.attributes)
//        }
    }
    return filters
}

actor ImageProcessor {
    enum ProcessingError: Error {
        case missingOutputImage(String) // filter name
    }
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
            if filter.inputKeys.contains(kCIInputImageKey) {
                filter.setValue(resultImage, forKey: kCIInputImageKey)
            }
            if filter.inputKeys.contains(kCIInputBackgroundImageKey) {
                if let ciBackgroundImage {
                    filter.setValue(ciBackgroundImage, forKey: kCIInputBackgroundImageKey)
                } else {
                    filter.setValue(nil, forKey: kCIInputBackgroundImageKey)
                }
            } else if filter.inputKeys.contains(kCIInputTargetImageKey) {
                if let ciBackgroundImage {
                    filter.setValue(ciBackgroundImage, forKey: kCIInputTargetImageKey)
                } else {
                    filter.setValue(nil, forKey: kCIInputTargetImageKey)
                }
            }
            for userFilterInput in userFilter.inputs {
                filter.setValue(userFilterInput.value, forKey: userFilterInput.name)
            }
            guard let outputImage = filter.outputImage else { throw ProcessingError.missingOutputImage(filter.name) }
            resultImage = outputImage
        }
        try Task.checkCancellation()
        let filteredImage = UIImage(cgImage: ciContext.createCGImage(resultImage, from: ciImage.extent, format: ciContext.workingFormat, colorSpace: inputImage.cgImage?.colorSpace, deferred: false)!, scale: inputImage.scale, orientation: inputImage.imageOrientation)
        try Task.checkCancellation()
        return filteredImage
    }
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

struct ImageExport: Transferable {
    let image: UIImage

    public static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { export in
            if let pngData = export.image.pngData() {
                return pngData
            } else {
                throw ConversionError.failedToConvertToPNG
            }
        }
    }

    enum ConversionError: Error {
        case failedToConvertToPNG
    }
}

struct FilterExport: Codable, Transferable {
    let userFilters: [UserFilter]
    
    static let encoder: JSONEncoder = {
        var encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        return encoder
    }()

    public static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(for: FilterExport.self, contentType: .json, encoder: encoder, decoder: JSONDecoder())
            .suggestedFileName("\(UUID().uuidString.prefix(4))")
    }

    enum ConversionError: Error {
        case failedToConvertToPNG
    }
}
