with open('LANImageUploader/UploadView.swift', 'r') as f:
    content = f.read()

content = content.replace('Upload failed: \\\\(error.localizedDescription)', 'Upload failed: \\(error.localizedDescription)')
content = content.replace('let newName = "\\\\(file.name)_\\\\(Int(Date().timeIntervalSince1970))"', 'let newName = "\\(file.name)_\\(Int(Date().timeIntervalSince1970))"')

with open('LANImageUploader/UploadView.swift', 'w') as f:
    f.write(content)

with open('LANImageUploader/AppData.swift', 'r') as f:
    content = f.read()

content = content.replace('let fileName = "\\\\(suggestedPrefix)_\\\\(timestamp).jpg"', 'let fileName = "\\(suggestedPrefix)_\\(timestamp).jpg"')

with open('LANImageUploader/AppData.swift', 'w') as f:
    f.write(content)
