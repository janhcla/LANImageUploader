import Foundation
import OSLog

private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "CompanionUploader")

enum UploadError: Error {
    case invalidURL
    case requestFailed(Error)
    case serverError(statusCode: Int)
    case invalidResponse
}

struct CompanionUploader {

    func uploadImage(imageData: Data, filename: String, to baseURL: String, with apiKey: String) async throws {
        guard let url = URL(string: baseURL)?.appendingPathComponent("upload") else {
            throw UploadError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let httpBody = createMultipartBody(
            boundary: boundary,
            filename: filename,
            imageData: imageData
        )

        request.httpBody = httpBody

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw UploadError.invalidResponse
            }

            logger.info("Upload response status code: \(httpResponse.statusCode)")

            if !(200...299).contains(httpResponse.statusCode) {
                if let responseBody = String(data: data, encoding: .utf8) {
                    logger.error("Server error response: \(responseBody)")
                }
                throw UploadError.serverError(statusCode: httpResponse.statusCode)
            }

            logger.info("Image successfully uploaded.")

        } catch {
            logger.error("Upload request failed: \(error.localizedDescription)")
            throw UploadError.requestFailed(error)
        }
    }

    private func createMultipartBody(boundary: String, filename: String, imageData: Data) -> Data {
        var body = Data()

        // Add image data part
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
        body.append("Content-Type: image/jpeg\r\n\r\n")
        body.append(imageData)
        body.append("\r\n")

        // Add filename part
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"filename\"\r\n\r\n")
        body.append(filename)
        body.append("\r\n")

        body.append("--\(boundary)--\r\n")

        return body
    }
}

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}
