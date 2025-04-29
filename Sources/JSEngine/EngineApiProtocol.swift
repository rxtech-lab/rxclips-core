import Foundation
import JavaScriptCore

@objc public protocol APIProtocol {
    func initializeJSExport(context: JSContext)
    var context: JSContext! { get }
}
