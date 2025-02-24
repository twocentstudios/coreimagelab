import SwiftUI

struct HelpView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Input Image") {
                    Text("Most Core Image filters take at least one image as the primary input (the exception is Generators). By default, an image of Sendai Station is used, but you can set an image from your library.")
                }
                Section("Background/Target Image") {
                    Text(try! AttributedString(markdown: "**Composite**-type filters (ending in *Compositing* or *BlendMode*) also take a background image as input. Set a background image from your library to use these filters. **Transition**-type filters use target image."))
                }
                Section("Supported Filters") {
                    Text("Filters have a variety of input types. Other than the standard image inputs, Core Image Labo supports numerical inputs via sliders. Filters that have more complicated input types are not supported. However, you can still view unsupported filters by tapping the *Show All* button.")
                }
                Section("Filter Flow") {
                    Text("Filters flow from top to bottom. You can reorder them by tapping the edit button and dragging the handle for a filter.")
                }
                Section("Toggling Filters") {
                    Text("Toggle a filter by tapping its name. Temporarily view the original version of the input image by tapping and holding the image preview.")
                }
                Section("Filter Setup Errors") {
                    Text("Some filter setups will not be executable by Core Image. An error message that indicates the filter where the error occurred will be shown over the image. In some cases, ensure you've set a background image.")
                }
            }
            .listStyle(.plain)
            .navigationTitle("Help")
        }
    }
}

#Preview {
    HelpView()
}
