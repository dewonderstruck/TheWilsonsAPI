import Foundation

enum FileError: Error {
    case couldNotSave(reason: String)
}