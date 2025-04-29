//
//  JSEngineMicro.swift
//  JSEngine
//
//  Created by Qiwei Li on 2/17/25.
//

@attached(member, names: arbitrary)
public macro JSBridgeProtocol() =
    #externalMacro(module: "JSEngineMacros", type: "JSBridgeProtocolMacro")

@attached(member, names: arbitrary)
public macro JSBridge() = #externalMacro(module: "JSEngineMacros", type: "JSBridgeMacro")
