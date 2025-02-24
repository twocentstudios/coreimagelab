import PhotosUI
import SwiftUI

struct FiltersView: View {
    let filters: [Filter.ID: Filter] = .init(uniqueKeysWithValues: allFilters().map { ($0.id, $0) })

    @State var inputImage: UIImage? = nil
    let testImage: UIImage = .init(named: "sendai")!
    var unfilteredImage: UIImage { inputImage ?? testImage }
    @State var inputLibraryItem: PhotosPickerItem? = nil

    @State var inputBackgroundImage: UIImage? = nil
    @State var inputBackgroundLibraryItem: PhotosPickerItem? = nil

    @State var isShowingAddScreen: Bool = false
    @State var isShowingHelpScreen: Bool = false
    @State var isShowingAboutScreen: Bool = false
    @State var isShowingTipScreen: Bool = false

    @State var userFilters: [UserFilter] = []
    @State var filteredImage: UIImage? = nil
    @State var isEditing: Bool = false
    @State var isTouchingImage: Bool = false
    @State var useOriginalAspectRatio: Bool = false
    @State var isScalingBackgroundImage: Bool = false
    @State var isProcessing: Bool = false
    @State var processingErrorMessage: String?

    @State var expandedFilters: [UserFilter.ID: Bool] = [:]

    @AppStorage("isAboutExpanded") var isAboutExpanded: Bool = true
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
                .overlay {
                    if let processingErrorMessage {
                        VStack(spacing: 10) {
                            Image(systemName: "exclamationmark.octagon")
                                .font(.largeTitle)
                            Text(processingErrorMessage)
                        }
                        .padding()
                        .foregroundColor(.red)
                        .background(Material.regular, in: RoundedRectangle(cornerRadius: 10))
                        .padding()
                    }
                }
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
                    aboutSection
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
                                Text("Image Inputs")
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
            .animation(.default, value: isInputsExpanded)
            .animation(.default, value: isAboutExpanded)
            .animation(.default, value: userFilters.map(\.id))
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
            .sheet(isPresented: $isShowingAddScreen) {
                AddFilterView(
                    filters: filters,
                    action: { filter in
                        userFilters.append(filter)
                    }
                )
            }
            .sheet(isPresented: $isShowingHelpScreen) {
                Text("Help")
            }
            .sheet(isPresented: $isShowingAboutScreen) {
                Text("About")
            }
            .sheet(isPresented: $isShowingTipScreen) {
                Text("Tip")
            }
        }
    }

    private func processImage() async {
        guard !userFilters.isEmpty else {
            filteredImage = nil
            return
        }
        isProcessing = true
        processingErrorMessage = nil
        do {
            try await Task.sleep(for: .milliseconds(20))
            filteredImage = try await imageProcessor.processImage(
                inputImage: unfilteredImage,
                inputBackgroundImage: inputBackgroundImage,
                filters: userFilters,
                isScalingBackgroundImage: isScalingBackgroundImage,
                ciContext: ciContext
            )
        } catch let ImageProcessor.ProcessingError.missingOutputImage(filterName) {
            processingErrorMessage = "Processing failed at filter \"\(filterName)\"."
            filteredImage = nil
        } catch {}
        isProcessing = false
    }

    @ViewBuilder var aboutSection: some View {
        Section {
            if isAboutExpanded {
                HStack {
                    Button {
                        isShowingHelpScreen = true
                    } label: {
                        Label("Help", systemImage: "questionmark.circle")
                    }
                    .buttonStyle(.bordered)
                    Button {
                        isShowingAboutScreen = true
                    } label: {
                        Label("About", systemImage: "info.circle")
                    }
                    .buttonStyle(.bordered)
                    Button {
                        isShowingTipScreen = true
                    } label: {
                        Label("Tip $5", systemImage: "dollarsign.circle")
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)
                .listRowSeparator(.hidden)
            }
        } header: {
            Button {
                isAboutExpanded.toggle()
            } label: {
                HStack {
                    Text("Core Image Labo")
                        .font(.headline)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .rotationEffect(isAboutExpanded ? .zero : .degrees(-90))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
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
        GroupBox("Background/Target Image") {
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
                            .layoutPriority(1)
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            userFilters.removeAll(where: { $0.id == userFilter.id })
                        }
                        .foregroundStyle(.red)
                        .labelStyle(.iconOnly)
                        .buttonStyle(.plain)
                        if userFilter.canExpand, !isEditing {
                            Button {
                                expandedFilters[userFilter.id] = !isExpanded
                            } label: {
                                Image(systemName: "chevron.down")
                                    .rotationEffect(isExpanded ? .zero : .degrees(-90))
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                    .contentShape(Rectangle())
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
            }
            .onMove { from, to in userFilters.move(fromOffsets: from, toOffset: to) }
            if userFilters.isEmpty {
                VStack(spacing: 0) {
                    Text("No Filters")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Add Filter", systemImage: "plus.circle") {
                        isShowingAddScreen = true
                    }
                    .buttonStyle(.bordered)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .listRowSeparator(.hidden)
            }
        } header: {
            HStack {
                Text("Filters")
                ProgressView().opacity(isProcessing ? 1 : 0)
                Spacer()
                Toggle("Edit", isOn: $isEditing)
                    .toggleStyle(.button)
                Button("Add", systemImage: "plus") {
                    isShowingAddScreen = true
                }
                .labelStyle(.iconOnly)
                .disabled(isEditing)
            }
            .font(.headline)
        }
    }
}

#Preview {
    FiltersView()
}
