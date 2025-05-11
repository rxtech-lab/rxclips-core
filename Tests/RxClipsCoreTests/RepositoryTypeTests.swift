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

      jobs:
        - name: Simple Strategy
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
    XCTAssert(repository.jobs[0].steps[0].lifecycle?.count == 1)
    XCTAssert(repository.lifecycle?.count == 1)
  }

  func testScriptTypeBash() throws {
    // Test for Bash Script
    let bashYaml = """
      jobs:
        - name: Simple Strategy
          steps:
            - type: bash
              name: Run Bash Command
              command: echo "Hello, World!"
      """
    let decoder = YAMLDecoder()
    let bashRepo = try decoder.decode(Repository.self, from: bashYaml)
    if case .bash(let bashScript) = bashRepo.jobs[0].steps[0].script {
      XCTAssert(bashScript.command == "echo \"Hello, World!\"")
      XCTAssert(bashScript.type == .bash)
    } else {
      XCTFail("Expected a bash script")
    }
  }

  func testScriptTypeJavascript() throws {
    // Test for Javascript
    let javascriptYaml = """
      jobs:
        - name: Simple Strategy
          steps:
            - type: javascript
              name: Run Javascript Command
              file: script.js
      """
    let decoder = YAMLDecoder()
    let javascriptRepo = try decoder.decode(Repository.self, from: javascriptYaml)
    if case .javascript(let javascriptScript) = javascriptRepo.jobs[0].steps[0].script {
      XCTAssert(javascriptScript.file == "script.js")
      XCTAssert(javascriptScript.type == .javascript)
    } else {
      XCTFail("Expected a javascript script")
    }
  }

  func testScriptTypeTemplate() throws {
    // Test for Template
    let templateYaml = """
      jobs:
        - name: Simple Strategy
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
                - file: README.md.tmpl
                  output: README.md
      """
    let decoder = YAMLDecoder()
    let templateRepo = try decoder.decode(Repository.self, from: templateYaml)
    if case .template(let templateScript) = templateRepo.jobs[0].steps[0].script {
      XCTAssert(templateScript.files!.count == 5)
      XCTAssert(templateScript.type == .template)
    } else {
      XCTFail("Expected a template script")
    }
  }
}
