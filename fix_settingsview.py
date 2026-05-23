import re

with open('LANImageUploader/SettingsView.swift', 'r') as f:
    content = f.read()

new_sections = """            Section("Gallery") {
                Picker("Default Handling", selection: $appData.defaultGalleryOutputMode) {
                    ForEach(GalleryOutputMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
            }

            Section("PDF Output") {
                Picker("Page Size", selection: $appData.pdfPageSize) {
                    Text("A4").tag(PDFPageSize.a4)
                    Text("Letter").tag(PDFPageSize.letter)
                }
                Picker("Image Layout", selection: $appData.pdfImageLayout) {
                    Text("Fit Whole Image").tag(PDFImageLayout.fit)
                    Text("Fill Page").tag(PDFImageLayout.fill)
                }
                Toggle("Include Page Numbers", isOn: $appData.pdfIncludePageNumbers)

                VStack(alignment: .leading) {
                    Text("Image Quality: \\(Int(appData.pdfJPEGQuality * 100))%")
                    Slider(value: $appData.pdfJPEGQuality, in: 0.1...1.0, step: 0.05)
                }
            }

            Section("Image Handling") {
                Picker("Max Image Size", selection: $appData.imageMaxPixelDimension) {
                    Text("2048 px").tag(Double(2048))
                    Text("2500 px").tag(Double(2500))
                    Text("3000 px").tag(Double(3000))
                    Text("Original").tag(Double.greatestFiniteMagnitude)
                }
                Toggle("Strip Image Metadata Before Upload", isOn: $appData.stripImageMetadata)
            }

            ocrSection"""

# In SettingsView.swift, `ocrSection` is used in `completeSetupView` around line 351
# We want to replace the usage of `ocrSection` inside `completeSetupView` with our new block
content = content.replace("            ocrSection\n            Section {", new_sections + "\n            Section {")

with open('LANImageUploader/SettingsView.swift', 'w') as f:
    f.write(content)
