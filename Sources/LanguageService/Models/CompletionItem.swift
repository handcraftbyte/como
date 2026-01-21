import Foundation
import AppKit

/// Represents a completion item from the TypeScript language service
struct CompletionItem: Identifiable, Hashable {
    let id = UUID()
    let label: String
    let kind: CompletionKind
    let sortText: String
    let insertText: String
    let isRecommended: Bool

    init(label: String, kind: CompletionKind, sortText: String? = nil, insertText: String? = nil, isRecommended: Bool = false) {
        self.label = label
        self.kind = kind
        self.sortText = sortText ?? label
        self.insertText = insertText ?? label
        self.isRecommended = isRecommended
    }
}

/// Completion item kind matching TypeScript ScriptElementKind
enum CompletionKind: String, CaseIterable {
    case function = "function"
    case method = "method"
    case variable = "var"
    case letVariable = "let"
    case constVariable = "const"
    case localVariable = "local var"
    case property = "property"
    case getter = "getter"
    case setter = "setter"
    case classKind = "class"
    case interface = "interface"
    case type = "type"
    case `enum` = "enum"
    case enumMember = "enum member"
    case module = "module"
    case keyword = "keyword"
    case parameter = "parameter"
    case alias = "alias"
    case primitiveType = "primitive type"
    case unknown = "unknown"

    init(tsKind: String) {
        switch tsKind {
        case "function": self = .function
        case "method": self = .method
        case "var": self = .variable
        case "let": self = .letVariable
        case "const": self = .constVariable
        case "local var": self = .localVariable
        case "property": self = .property
        case "getter": self = .getter
        case "setter": self = .setter
        case "class": self = .classKind
        case "interface": self = .interface
        case "type": self = .type
        case "enum": self = .enum
        case "enum member": self = .enumMember
        case "module": self = .module
        case "keyword": self = .keyword
        case "parameter": self = .parameter
        case "alias": self = .alias
        case "primitive type": self = .primitiveType
        default: self = .unknown
        }
    }

    /// SF Symbol name for this completion kind
    var symbolName: String {
        switch self {
        case .function, .method:
            return "function"
        case .variable, .letVariable, .constVariable, .localVariable, .parameter:
            return "x.squareroot"
        case .property, .getter, .setter:
            return "list.bullet"
        case .classKind:
            return "c.square"
        case .interface:
            return "i.square"
        case .type, .alias, .primitiveType:
            return "t.square"
        case .enum, .enumMember:
            return "e.square"
        case .module:
            return "shippingbox"
        case .keyword:
            return "textformat"
        case .unknown:
            return "questionmark.circle"
        }
    }

    /// Color for this completion kind
    var color: NSColor {
        switch self {
        case .function, .method:
            return .systemPurple
        case .variable, .letVariable, .constVariable, .localVariable, .parameter:
            return .systemBlue
        case .property, .getter, .setter:
            return .systemCyan
        case .classKind:
            return .systemOrange
        case .interface, .type, .alias, .primitiveType:
            return .systemGreen
        case .enum, .enumMember:
            return .systemYellow
        case .module:
            return .systemBrown
        case .keyword:
            return .systemPink
        case .unknown:
            return .secondaryLabelColor
        }
    }
}
