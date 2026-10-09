import Foundation

public enum SourceLanguage: String, CaseIterable, Sendable {
    case java
    case python

    public static func detect(path: String) -> SourceLanguage? {
        switch (path as NSString).pathExtension.lowercased() {
        case "java": return .java
        case "py", "pyi": return .python
        default: return nil
        }
    }
}
