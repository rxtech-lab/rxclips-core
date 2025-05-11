import Foundation
import Stencil

enum TemplateError: Error {
    case fileNotFound(String)
    case invalidUrl(String)
    case invalidTemplate(String)
}

actor TemplateEngine: EngineProtocol {
    public func run(script: Script.TemplateScript, cwd: URL, baseURL: URL, formData: [String: Any])
        async throws
        -> any AsyncSequence<
            ExecuteResult, Error
        >
    {
        return AsyncThrowingStream { continuation in
            Task {
                do {
                    var completedFiles = 0
                    for file in script.files ?? [] {
                        let templateFile = try await loadTemplate(baseURL: baseURL, file: file.file)
                        let template = Template(templateString: templateFile)
                        let rendered = try template.render(formData)

                        let outputPath = getOutputPath(file: file.output, cwd: cwd)
                        try writeOutput(output: rendered, path: outputPath)
                        completedFiles += 1
                        continuation.yield(
                            .template(
                                .init(
                                    scriptId: script.id, filePath: outputPath,
                                    percentage: Double(completedFiles)
                                        / Double(script.files?.count ?? 1))))
                    }

                } catch (let error) {
                    continuation.finish(throwing: error)
                }
                continuation.finish()
            }
        }
    }

    /// Load a template from local path or remote url
    internal func loadTemplate(baseURL: URL, file: String) async throws -> String {
        let url = baseURL.appendingPathComponent(file)
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let string = String(data: data, encoding: .utf8) else {
            throw TemplateError.invalidTemplate(file)
        }
        return string
    }

    /// join the cwd and file path
    /// for example file is ./output.txt and cwd is /tmp
    /// the output path will be /tmp/output.txt
    internal func getOutputPath(file: String, cwd: URL) -> String {
        let outputURL = cwd.appendingPathComponent(file)
        return outputURL.standardized.path
    }

    internal func writeOutput(output: String, path: String) throws {
        // create the directory if it doesn't exist
        let directory = URL(fileURLWithPath: path).deletingLastPathComponent()
        // check if the directory exists
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(
                at: directory, withIntermediateDirectories: true, attributes: nil)
        }
        // write the output to the file
        try output.write(toFile: path, atomically: true, encoding: .utf8)
    }
}
