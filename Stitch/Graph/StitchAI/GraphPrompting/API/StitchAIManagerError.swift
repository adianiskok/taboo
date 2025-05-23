//
//  StitchAIManagerError.swift
//  Stitch
//
//  Created by Elliot Boschwitz on 2/12/25.
//

import SwiftUI
import StitchSchemaKit

enum StitchAIManagerError: Error {
    case documentNotFound(OpenAIRequest)
    case requestInProgress(OpenAIRequest)
    case maxRetriesError(Int, String)
    case invalidURL(OpenAIRequest)
    case jsonEncodingError(OpenAIRequest, Error)
    case multipleTimeoutErrors(OpenAIRequest, String)
    case requestCancelled(OpenAIRequest)
    case internetConnectionFailed(OpenAIRequest)
    case typeCasting
    case stepActionDecoding(String)
    case stepDecoding(StepType, Step)
    case emptySuccessfulResponse
    case nodeNameParsing(String)
    case nodeTypeParsing(String)
    case other(OpenAIRequest, Error)
    case contentDataDecodingError(String, String)
    case portValueDecodingError(String)
    case decodeObjectFromString(String, String)
    case structuredOutputsNotFound
    case apiResponseError
    case portTypeDecodingError(String)
    case actionValidationError(String)
}

extension StitchAIManagerError: CustomStringConvertible {
    var description: String {
        switch self {
        case .documentNotFound:
            return ""
        case .requestInProgress:
            return "A request is already in progress. Skipping this request."
        case .maxRetriesError(let maxRetries, let errorDescription):
            return "Request failed after \(maxRetries) attempts. Last error:\n\(errorDescription)"
        case .invalidURL:
            return "Invalid URL"
        case .jsonEncodingError(_, let error):
            return "Error encoding JSON: \(error.localizedDescription)"
        case .multipleTimeoutErrors(_, let errorDescription):
            return "Stitch AI failed on multiple requests. Last captured error:\n\(errorDescription)"
        case .internetConnectionFailed:
            return "No internet connection. Please try again when your connection is restored."
        case .other(_, let error):
            return "OpenAI Request error: \(error.localizedDescription)"
        case .requestCancelled(_):
            return ""
        case .typeCasting:
            return "Unable to cast type for object."
        case .stepActionDecoding(let string):
            return "Unable to parse action step type from: \(string)"
        case .stepDecoding(let stepType, let step):
            return "Unable to decode: \(stepType) with step payload:\n\(step)"
        case .emptySuccessfulResponse:
            return "StitchAI JSON parsing failed: No choices available"
        case .nodeNameParsing(let string):
            return "Could not parse node name: \(string)"
        case .nodeTypeParsing(let string):
            return "Could not parse node type: \(string)"
        case .contentDataDecodingError(let contentData, let errorResponse):
            return "Unable to parse step actions from: \(contentData) with error: \(errorResponse)"
        case .portValueDecodingError(let errorResponse):
            return "Unable to decode PortValue with error: \(errorResponse)"
        case .decodeObjectFromString(let stringObject, let errorResponse):
            return "Unable to decode object from string: \(stringObject)\nError: \(errorResponse)"
        case .structuredOutputsNotFound:
            return "Structured outputs file wasn't found."
        case .apiResponseError:
            return "API returned non-successful status code."
        case .portTypeDecodingError(let port):
            return "Could not decode node's port from: \(port)"
        case .actionValidationError(let string):
            return "Action validation error: \(string)"
        }
    }
}

extension StitchAIManagerError {
    var shouldDisplayModal: Bool {
        switch self {
        case .requestCancelled:
            return false
            
        default:
            return true
        }
    }
}
