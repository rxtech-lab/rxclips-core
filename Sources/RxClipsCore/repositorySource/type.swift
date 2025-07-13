import Foundation

/// A repository item that represents either a file or folder in the repository structure.
public struct RepositoryItem: Codable {
    /// The type of repository item.
    public enum ItemType: String, Codable {
        /// The item is a template file that can be executed or processed.
        case file
        /// The item is a folder containing other repository items.
        case folder
    }

    /// The display name of the repository item.
    public let name: String

    /// A human-readable description of the repository item's purpose or content.
    public let description: String

    /// The full path to the repository item within the repository structure.
    public let path: String

    /// The category or classification of the repository item.
    public let category: String

    /// The type of repository item (file or folder).
    public let type: ItemType

    /// Creates a new repository item.
    ///
    /// - Parameters:
    ///   - name: The display name of the repository item.
    ///   - description: A human-readable description of the repository item's purpose or content.
    ///   - path: The full path to the repository item within the repository structure.
    ///   - category: The category or classification of the repository item.
    ///   - type: The type of repository item. Defaults to `.file` if not specified.
    public init(
        name: String, description: String, path: String, category: String, type: ItemType = .file
    ) {
        self.name = name
        self.description = description
        self.path = path
        self.category = category
        self.type = type
    }

    /// Creates a new repository item from a decoder.
    ///
    /// - Parameter decoder: The decoder to read data from.
    /// - Throws: An error if the required fields are missing or invalid.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        path = try container.decode(String.self, forKey: .path)
        category = try container.decode(String.self, forKey: .category)
        // Default to .file if type is not specified in JSON
        type = try container.decodeIfPresent(ItemType.self, forKey: .type) ?? .file
    }
}

/// Errors that can occur when working with repository sources.
public enum RepositorySourceError: Error {
    /// The requested path was not found in the repository.
    case pathNotFound(String)
    /// The repository source is unreachable or inaccessible.
    case unreachable(URL)
    /// An invalid URL was provided.
    case invalidURL(String)
    /// A network error occurred while accessing the repository.
    case networkError(Error)
    /// The response data could not be parsed.
    case parseError(Error)
    /// The HTTP response contained an unexpected status code.
    case httpError(Int)
}

/// A protocol that defines the interface for accessing repository content.
///
/// Repository sources provide access to structured collections of templates, scripts,
/// and other resources organized in a hierarchical folder structure.
public protocol RepositorySource {
    /// Lists all items in the repository at the specified path.
    ///
    /// - Parameter path: The path within the repository to list items from.
    ///   If `nil`, lists items from the root of the repository.
    /// - Returns: An array of ``RepositoryItem`` objects representing the items
    ///   found at the specified path.
    /// - Throws: An error if the path is invalid or the repository cannot be accessed.
    func list(path: String?) async throws -> [RepositoryItem]

    /// Retrieves the complete repository content for the specified path.
    ///
    /// - Parameter path: The path to the repository item to retrieve.
    /// - Returns: A ``Repository`` object containing the content at the specified path.
    /// - Throws: An error if the path is invalid, the item doesn't exist,
    ///   or the repository cannot be accessed.
    func get(path: String) async throws -> Repository

    /// Resolves a file path to a full file path.
    ///
    /// - Parameters:
    ///   - path: The path to the repository item to resolve. For example, "/simple"
    ///   - file: The file to resolve. For example, "script.tmpl"
    /// - Returns: The full file path. For example, "{basePath}/simple/script.tmpl"
    func resolve(path: String, file: String) async throws -> String
}
