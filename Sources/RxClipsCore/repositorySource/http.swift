import Foundation

public actor HttpRepositorySource: RepositorySource {
    private let baseUrl: URL
    private let repositoryPath: String

    public init(baseUrl: URL, repositoryPath: String = "") {
        self.baseUrl = baseUrl
        self.repositoryPath = repositoryPath
    }

    public func list(path: String?) async throws -> [RepositoryItem] {
        let url = buildURL(path: path)

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw RepositorySourceError.networkError(URLError(.badServerResponse))
            }

            switch httpResponse.statusCode {
            case 200:
                break
            case 404:
                throw RepositorySourceError.pathNotFound(path ?? "root")
            default:
                throw RepositorySourceError.httpError(httpResponse.statusCode)
            }

            let items = try JSONDecoder().decode([RepositoryItem].self, from: data)
            return items
        } catch let error as RepositorySourceError {
            throw error
        } catch let decodingError as DecodingError {
            throw RepositorySourceError.parseError(decodingError)
        } catch {
            throw RepositorySourceError.networkError(error)
        }
    }

    public func get(path: String) async throws -> Repository {
        let url = buildURL(path: path)

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw RepositorySourceError.networkError(URLError(.badServerResponse))
            }

            switch httpResponse.statusCode {
            case 200:
                break
            case 404:
                throw RepositorySourceError.pathNotFound(path)
            default:
                throw RepositorySourceError.httpError(httpResponse.statusCode)
            }

            let repository = try JSONDecoder().decode(Repository.self, from: data)
            return repository
        } catch let error as RepositorySourceError {
            throw error
        } catch let decodingError as DecodingError {
            throw RepositorySourceError.parseError(decodingError)
        } catch {
            throw RepositorySourceError.networkError(error)
        }
    }

    public func resolve(path: String, file: String) async throws -> String {
        let fullPath = repositoryPath.isEmpty ? path : "\(repositoryPath)/\(path)"
        let url = buildURL(path: fullPath)
        return url.appendingPathComponent(file).absoluteString
    }

    private func buildURL(path: String?) -> URL {
        if let path = path, !path.isEmpty {
            return baseUrl.appendingPathComponent(path)
        } else {
            return baseUrl
        }
    }

}
