//
//  FileUploadMiddleware.swift
//  TheWilsonsAPI
//
//  Created by Vamsi Madduluri on 10/08/24.
//

import Vapor

struct FileUploadMiddleware: AsyncMiddleware {
    
    let allowedExtensions: Set<String>
    let allowedContentTypes: Set<HTTPMediaType>
    
    func respond(to request: Request, chainingTo next: AsyncResponder) async throws -> Response {
        // Assuming the file is coming in a multipart form request
        if let file = try? request.content.decode(File.self) {
            // Check extension
            if let fileExtension = file.filename.split(separator: ".").last?.lowercased(),
               !allowedExtensions.contains(String(fileExtension)) {
                throw Abort(.badRequest, reason: "File extension not allowed.")
            }
            
            // Get the content type
            guard let contentType = request.headers.contentType else {
                throw Abort(.unsupportedMediaType, reason: "No content type found.")
            }
            
            // Check if the content type is allowed
            if !allowedContentTypes.contains(where: { $0 == contentType }) {
                throw Abort(.unsupportedMediaType, reason: "File content type not allowed.")
            }
            
        }
        
        // Await the response from the next middleware in the chain
        return try await next.respond(to: request)
    }
}
