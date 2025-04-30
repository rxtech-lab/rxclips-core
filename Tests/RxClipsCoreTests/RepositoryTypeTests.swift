import XCTest
import Yams

@testable import RxClipsCore

class RepositoryTypeTests: XCTestCase {
    func testDecode() throws {
        let yaml = """
            # yaml-language-server: $schema=https://rx-snippet-repo-spec-visulization.vercel.app/api/spec/repository?content-type=json
            name: Simple Strategy
            description: A simple strategy for Argo Trading
            category: Simple

            globalConfig:
              templatePath: ./

            permissions:
              - writeFile
            lifecycle:
              - on: afterStep
                type: bash
                command:
                  go get github.com/rxtech-lab/argo-trading@latest && go mod download &&
                  go mod tidy
            steps:
              - type: template
                name: Simple Strategy
                files:
                  - file: go.mod.tmpl
                    output: go.mod
                  - output: strategy.go
                    file: strategy.go.tmpl
                  - file: gitignore.tmpl
                    output: .gitignore
                  - file: malefile.tmpl
                    output: Makefile
                lifecycle:
                  - on: afterStep
                    type: bash
                    command:
                      go get github.com/rxtech-lab/argo-trading@latest && go mod download &&
                      go mod tidy
                form:
                  type: object
                  required:
                    - packageName
                    - strategyName
                  properties:
                    packageName:
                      type: string
                    strategyName:
                      type: string
                      minLength: 1
            """
        let decoder = YAMLDecoder()
        let repository = try decoder.decode(Repository.self, from: yaml)
        XCTAssert(repository.steps![0].lifecycle?.count == 1)
        XCTAssert(repository.lifecycle?.count == 1)
    }
}
