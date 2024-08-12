import Vapor
import SotoS3
import NIO
import Fluent
import Foundation

struct FileUpload: Content {
    let fileName: String
    let bucket: String
    let filePublic: String
    let fileData: Data
}

actor UploadManager: Sendable {
    static let shared = UploadManager()
    private var uploads: [UUID: (parts: [S3.CompletedPart], uploadId: String)] = [:]
    
    func startUpload(fileId: UUID, uploadId: String) {
        uploads[fileId] = (parts: [], uploadId: uploadId)
    }
    
    func addPart(fileId: UUID, part: S3.CompletedPart) {
        uploads[fileId]?.parts.append(part)
    }
    
    func getUploadInfo(fileId: UUID) -> (parts: [S3.CompletedPart], uploadId: String)? {
        return uploads[fileId]
    }
    
    func removeUpload(fileId: UUID) {
        uploads.removeValue(forKey: fileId)
    }
}

struct S3Controller: RouteCollection {
    
    private let fileUploadMiddleware: FileUploadMiddleware
    
    func boot(routes: RoutesBuilder) throws {
        let files = routes.grouped("files")
        let uploadRoute = files.grouped(fileUploadMiddleware)
        files.get(use: listFiles)
        files.get(":id", use: getFile)
        uploadRoute.post(use: uploadFile)
        files.patch(":id", use: updateFile)
        files.delete(":id", use: deleteFile)
        files.delete(use: deleteMultipleFiles)
    }
    
    init() throws {
        self.fileUploadMiddleware = FileUploadMiddleware(allowedExtensions: [
            "jpg", "png", "pdf"
        ], allowedContentTypes: [
            HTTPMediaType.jpeg,
            HTTPMediaType.png,
            HTTPMediaType.pdf
        ])
    }
    
    @Sendable
    func listFiles(req: Request) async throws -> [FileModel] {
        try await FileModel.query(on: req.db).all()
    }
    
    @Sendable
    func getFile(req: Request) async throws -> Response {


        guard let fileId = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        
        guard let file = try await FileModel.find(fileId, on: req.db) else {
            throw Abort(.notFound)
        }
        
        // check if file is public
        if !file.isPublic {
            throw Abort(HTTPResponseStatus(
                statusCode: 403,
                reasonPhrase: "Unauthorized access to file, please contact the file owner."))
        }

        let s3 = req.application.aws.s3
        let request = S3.GetObjectRequest(bucket: file.bucket, key: file.id!.uuidString)
        let result = try await s3.getObject(request)
        let buffer = try await result.body.collect(upTo: .max)
        return Response(status: .ok, body: .init(buffer: buffer))
    }
    
    @Sendable
    func uploadFile(req: Request) async throws -> Response {
        let upload = try req.content.decode(FileUpload.self)
        
        let fileModel = FileModel(
            fileName: upload.fileName,
            fileSize: upload.fileData.count,
            fileType: upload.fileName.fileExtension ?? "unknown",
            bucket: upload.bucket, uploadDate: Date(),
            storageType: .s3, isPublic: Bool(upload.filePublic) ?? false
        )
        
        try await fileModel.save(on: req.db)
        
        let s3 = req.application.aws.s3
        let createRequest = S3.CreateMultipartUploadRequest(bucket: upload.bucket, key: fileModel.id!.uuidString)
        let createResponse = try await s3.createMultipartUpload(createRequest)
        guard let uploadId = createResponse.uploadId else {
            throw Abort(.internalServerError, reason: "Failed to start multipart upload")
        }
        
        await UploadManager.shared.startUpload(fileId: fileModel.id!, uploadId: uploadId)
        
        // Define chunk size (5MB)
        let chunkSize = 5 * 1024 * 1024
        let totalChunks = Int(ceil(Double(upload.fileData.count) / Double(chunkSize)))
        
        for chunkNumber in 0..<totalChunks {
            let start = chunkNumber * chunkSize
            let end = min(start + chunkSize, upload.fileData.count)
            let chunkData = upload.fileData[start..<end]
            
            let body = AWSHTTPBody(bytes: [UInt8](chunkData))
            let uploadPartRequest = S3.UploadPartRequest(
                body: body,
                bucket: upload.bucket,
                key: fileModel.id!.uuidString,
                partNumber: chunkNumber + 1,
                uploadId: uploadId
            )
            let uploadPartResponse = try await s3.uploadPart(uploadPartRequest)
            
            guard let eTag = uploadPartResponse.eTag else {
                throw Abort(.internalServerError, reason: "Failed to upload chunk")
            }
            
            await UploadManager.shared.addPart(fileId: fileModel.id!, part: .init(eTag: eTag, partNumber: chunkNumber + 1))
        }
        
        guard let uploadInfo = await UploadManager.shared.getUploadInfo(fileId: fileModel.id!) else {
            throw Abort(.internalServerError, reason: "Upload info not found")
        }
        
        let completeRequest = S3.CompleteMultipartUploadRequest(
            bucket: upload.bucket,
            key: fileModel.id!.uuidString,
            multipartUpload: .init(parts: uploadInfo.parts),
            uploadId: uploadId
        )
        
        let completeResponse = try await s3.completeMultipartUpload(completeRequest)
        
        await UploadManager.shared.removeUpload(fileId: fileModel.id!)
        
        fileModel.s3ETag = completeResponse.eTag
        try await fileModel.save(on: req.db)
        
        return Response(status: .ok, body: .init(string: "File uploaded successfully. ID: \(fileModel.id?.uuidString ?? "N/A")"))
    }
    
    @Sendable
    func updateFile(req: Request) async throws -> Response {
        guard let fileId = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        
        guard let file = try await FileModel.find(fileId, on: req.db) else {
            throw Abort(.notFound)
        }
        
        let updateInfo = try req.content.decode(FileUpdateInfo.self)
        
        file.fileName = updateInfo.fileName ?? file.fileName
        file.isPublic = updateInfo.isPublic ?? file.isPublic
        
        try await file.save(on: req.db)
        
        let s3 = req.application.aws.s3
        let request = S3.CopyObjectRequest(
            bucket: file.bucket,
            copySource: "/\(file.bucket)/\(file.id!.uuidString)",
            key: file.id!.uuidString,
            metadata: ["fileName": file.fileName, "isPublic": "\(file.isPublic)"],
            metadataDirective: .replace
        )
        let _ = try await s3.copyObject(request)
        
        return Response(status: .ok, body: .init(string: "File updated successfully"))
    }
    
    @Sendable
    func deleteFile(req: Request) async throws -> Response {
        guard let fileId = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        
        guard let file = try await FileModel.find(fileId, on: req.db) else {
            throw Abort(.notFound)
        }
        
        let s3 = req.application.aws.s3
        let request = S3.DeleteObjectRequest(bucket: file.bucket, key: file.id!.uuidString)
        let _ = try await s3.deleteObject(request)
        
        try await file.delete(on: req.db)
        
        return Response(status: .ok, body: .init(string: "File deleted successfully"))
    }
    
    @Sendable
    func deleteMultipleFiles(req: Request) async throws -> Response {
        let fileIdsToDelete = try req.content.decode([UUID].self)
        
        let s3 = req.application.aws.s3
        
        for fileId in fileIdsToDelete {
            if let file = try await FileModel.find(fileId, on: req.db) {
                let request = S3.DeleteObjectRequest(bucket: file.bucket, key: file.id!.uuidString)
                let _ = try await s3.deleteObject(request)
                try await file.delete(on: req.db)
            }
        }
        
        return Response(status: .ok, body: .init(string: "Deleted \(fileIdsToDelete.count) files successfully"))
    }
}

struct FileUpdateInfo: Content {
    let fileName: String?
    let isPublic: Bool?
}

extension String {
    var fileExtension: String? {
        return self.components(separatedBy: ".").last
    }
}
