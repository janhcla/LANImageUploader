with open('LANImageUploader/UploadView.swift', 'r') as f:
    content = f.read()

content = content.replace('renameImage(duplicateFile!)', 'if let file = duplicateFile { renameFile(file) }')
content = content.replace('Task { await uploadImage(duplicateFile!, overwrite: true) }', 'if let file = duplicateFile { Task { await uploadFile(file, overwrite: true) } }')

with open('LANImageUploader/UploadView.swift', 'w') as f:
    f.write(content)
