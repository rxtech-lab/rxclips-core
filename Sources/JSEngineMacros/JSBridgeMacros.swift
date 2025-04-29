//
//  JSEngineClassMacros.swift
//  JSEngine
//
//  Created by Qiwei Li on 2/17/25.
//
import SwiftSyntax
import SwiftSyntaxMacros

public struct JSBridgeMacro: MemberMacro {
    private static func processNamedParameters(
        _ funcDecl: FunctionDeclSyntax,
        in context: some MacroExpansionContext
    ) -> [DeclSyntax] {
        // Get the function name and parameters
        let functionName = funcDecl.name.text
        let parameters = funcDecl.signature.parameterClause.parameters

        // Skip if there are no parameters
        guard !parameters.isEmpty else {
            return []
        }

        // Check if all parameters already have _ as external names
        let allParametersUnderscored = parameters.allSatisfy { param in
            param.firstName.text == "_"
        }

        // Skip generating wrapper if all parameters are already underscored
        if allParametersUnderscored {
            return []
        }

        // Create parameter list with unnamed external parameters
        let unnamedParameterList = parameters.map { param in
            let internalName = param.secondName?.text ?? param.firstName.text
            return "_ \(internalName): \(param.type)"
        }.joined(separator: ", ")

        // Create the argument list for the function call, preserving external names
        let argumentList = parameters.map { param in
            let internalName = param.secondName?.text ?? param.firstName.text
            let externalName = param.firstName.text
            // If external name is _, skip it in the call
            if externalName == "_" {
                return internalName
            }
            // If there's a second name, use the external name in the call
            if param.secondName != nil {
                return "\(externalName): \(internalName)"
            }
            // Otherwise just use the internal name
            return "\(internalName): \(internalName)"
        }.joined(separator: ", ")

        // Get return type
        let returnType = funcDecl.signature.returnClause?.type
        // Create the wrapper function
        let wrapperFunction = """
            func \(functionName)(\(unnamedParameterList)) -> \(returnType ?? "Void"){
                return \(functionName)(\(argumentList))
            }
            """

        return [DeclSyntax(stringLiteral: wrapperFunction)]
    }

    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let memberBlock: MemberBlockSyntax
        if let classDecl = declaration.as(ClassDeclSyntax.self) {
            memberBlock = classDecl.memberBlock
        } else if let extensionDecl = declaration.as(ExtensionDeclSyntax.self) {
            memberBlock = extensionDecl.memberBlock
        } else {
            context.addDiagnostics(from: MacroError.invalidDeclaration, node: node)
            return []
        }

        var newMembers: [DeclSyntax] = []

        for member in memberBlock.members {
            guard let funcDecl = member.decl.as(FunctionDeclSyntax.self) else {
                continue
            }

            // Only process async functions
            guard funcDecl.signature.effectSpecifiers?.asyncSpecifier != nil else {
                // process named parameters
                let namedParameters = processNamedParameters(funcDecl, in: context)
                newMembers.append(contentsOf: namedParameters)
                continue
            }

            let functionName = funcDecl.name.text

            // Extract parameters
            let parameters = funcDecl.signature.parameterClause.parameters

            // Create unnamed parameter list for the generated function
            let unnamedParameterList = parameters.map { param in
                let internalName = param.secondName?.text ?? param.firstName.text
                return "_ \(internalName): \(param.type)"
            }.joined(separator: ", ")

            let jsParameterList = parameters.map { param in
                let externalName = param.firstName.text
                let internalName = param.secondName?.text ?? param.firstName.text
                return "\(externalName): \(internalName)"
            }.joined(separator: ", ")

            var returnType = funcDecl.signature.returnClause?.type
            returnType?.trailingTrivia = .spaces(0)

            // Add resolve helper
            let resolveHelper = try FunctionDeclSyntax(
                """
                private func resolve\(raw: functionName.capitalized)(with value: \(raw: returnType ?? "Void")) {
                    context.globalObject.setObject(value, forKeyedSubscript: "\(raw: functionName)Result" as NSString)
                    context.evaluateScript("resolve\(raw: functionName.capitalized)(\(raw: functionName)Result);")
                }
                """)

            // Add reject helper
            let rejectHelper = try FunctionDeclSyntax(
                """
                private func reject\(raw: functionName.capitalized)(with error: Error) {
                    context.globalObject.setObject(
                        error.localizedDescription, forKeyedSubscript: "errorMessage" as NSString)
                    context.evaluateScript("reject\(raw: functionName.capitalized)(new Error(errorMessage));")
                }
                """)

            // Add JSValue returning function
            let jsValueFunc = try FunctionDeclSyntax(
                """
                func \(raw: functionName)(\(raw: unnamedParameterList)) -> JSValue {
                    let promise = context.evaluateScript(
                        \"\"\"
                            new Promise((resolve, reject) => {
                                globalThis.resolve\(raw: functionName.capitalized) = resolve;
                                globalThis.reject\(raw: functionName.capitalized) = reject;
                            });
                        \"\"\")!

                    Task {
                        do {
                            let result = try await \(raw: functionName)(\(raw: jsParameterList))
                            resolve\(raw: functionName.capitalized)(with: result)
                        } catch {
                            reject\(raw: functionName.capitalized)(with: error)
                        }
                    }

                    return promise
                }
                """)

            newMembers.append(contentsOf: [
                DeclSyntax(resolveHelper),
                DeclSyntax(rejectHelper),
                DeclSyntax(jsValueFunc),
            ])
        }

        return newMembers
    }
}
