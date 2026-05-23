with open('LANImageUploader/GalleryView.swift', 'r') as f:
    content = f.read()

# Make sure UIKit is imported
if 'import UIKit' not in content:
    content = content.replace('import SwiftUI', 'import SwiftUI\nimport UIKit')

with open('LANImageUploader/GalleryView.swift', 'w') as f:
    f.write(content)
