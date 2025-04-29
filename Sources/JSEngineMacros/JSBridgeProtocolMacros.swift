//
//  JSEngineMicros.swift
//  JSEngine
//
//  Created by Qiwei Li on 2/17/25.
//
import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxMacros

public struct JSBridgeProtocolMacro: MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclGroupSyntax,
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let protocolDecl = declaration.as(ProtocolDeclSyntax.self) else {
            context.diagnose(
                Diagnostic(
                    node: node,
                    message: MacroExpansionErrorMessage(
                        "JSEngineProtocolMacro must be applied to a protocol"
                    )
                )
            )
            return []
        }

        var newMembers: [DeclSyntax] = []

        for member in protocolDecl.memberBlock.members {
            guard let funcDecl = member.decl.as(FunctionDeclSyntax.self) else {
                continue
            }

            // Only process functions that are async
            if funcDecl.signature.effectSpecifiers?.asyncSpecifier == nil {
                // For non-async functions, check if all parameters have external name "_"
                let allParamsUnderscored = funcDecl.signature.parameterClause.parameters.allSatisfy
                {
                    param in
                    param.firstName.text == "_"
                }

                // Skip if all parameters are already underscored
                if allParamsUnderscored {
                    continue
                }

                // For non-async functions, only generate if there are parameters
                if funcDecl.signature.parameterClause.parameters.isEmpty {
                    continue
                }

                // Convert named parameters to unnamed parameters for the original function
                var signature = funcDecl.signature
                let newParameters = signature.parameterClause.parameters.map { param in
                    var newParam = param
                    if param.firstName.text != "_" {
                        newParam.firstName = .wildcardToken()
                    }
                    return newParam
                }

                signature.parameterClause = FunctionParameterClauseSyntax(
                    parameters: FunctionParameterListSyntax(newParameters)
                )

                let newFunc = FunctionDeclSyntax(
                    leadingTrivia: funcDecl.leadingTrivia,
                    name: funcDecl.name,
                    signature: signature,
                    trailingTrivia: funcDecl.trailingTrivia
                )

                newMembers.append(DeclSyntax(newFunc))
                continue
            }

            // Process async functions (generate JSValue version)
            var signature = funcDecl.signature

            // Convert named parameters to unnamed parameters
            let newParameters = signature.parameterClause.parameters.map { param in
                var newParam = param
                if param.firstName.text != "_" {
                    newParam.firstName = .wildcardToken()
                }
                return newParam
            }

            signature.parameterClause = FunctionParameterClauseSyntax(
                parameters: FunctionParameterListSyntax(newParameters)
            )

            signature.returnClause = ReturnClauseSyntax(
                type: TypeSyntax(
                    "JSValue"
                )
            )
            signature.effectSpecifiers = nil

            let newFunc = FunctionDeclSyntax(
                leadingTrivia: funcDecl.leadingTrivia,
                name: funcDecl.name,
                signature: signature,
                trailingTrivia: funcDecl.trailingTrivia
            )

            newMembers.append(DeclSyntax(newFunc))
        }

        return newMembers
    }
}
