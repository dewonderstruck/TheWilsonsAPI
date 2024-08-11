import Vapor
import SotoS3
import NIO
import Fluent
import Foundation

struct FileUpload: Content {
    let fileName: String
    let fileData: Data
}

actor UploadManager: Sendable {
    static let shared = UploadManager()
    private var uploads: [String: (parts: [S3.CompletedPart], uploadId: String)] = [:]
    
    func startUpload(fileName: String, uploadId: String) {
        uploads[fileName] = (parts: [], uploadId: uploadId)
    }
    
    func addPart(fileName: String, part: S3.CompletedPart) {
        uploads[fileName]?.parts.append(part)
    }
    
    func getUploadInfo(fileName: String) -> (parts: [S3.CompletedPart], uploadId: String)? {
        return uploads[fileName]
    }
    
    func removeUpload(fileName: String) {
        uploads.removeValue(forKey: fileName)
    }
}

struct S3Controller: RouteCollection {
    
    private let fileUploadMiddleware: FileUploadMiddleware
    
    func boot(routes: RoutesBuilder) throws {
        
        let routes = routes.grouped("api", "s3")
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
    func listFiles(req: Request) async throws -> [String] {
        let s3 = req.application.aws.s3
        let request = S3.ListObjectsV2Request(bucket: "MyBucket")
        let result = try await s3.listObjectsV2(request)
        return result.contents?.compactMap { $0.key } ?? []
    }
    
    @Sendable
    func getFile(req: Request) async throws -> Response {
        guard let fileId = req.parameters.get("id") else {
            throw Abort(.badRequest)
        }
        let s3 = req.application.aws.s3
        let request = S3.GetObjectRequest(bucket: "MyBucket", key: fileId)
        let result = try await s3.getObject(request)
        let buffer = try await result.body.collect(upTo: .max)
        return Response(status: .ok, body: .init(buffer: buffer))
    }
    
    @Sendable
    func uploadFile(req: Request) async throws -> Response {
        let upload = try req.content.decode(FileUpload.self)
        let s3 = req.application.aws.s3
        
        // Start a new multipart upload
        let createRequest = S3.CreateMultipartUploadRequest(bucket: "MyBucket", key: upload.fileName)
        let createResponse = try await s3.createMultipartUpload(createRequest)
        guard let uploadId = createResponse.uploadId else {
            throw Abort(.internalServerError, reason: "Failed to start multipart upload")
        }
        
        await UploadManager.shared.startUpload(fileName: upload.fileName, uploadId: uploadId)
        
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
                bucket: "MyBucket",
                key: upload.fileName,
                partNumber: chunkNumber + 1,
                uploadId: uploadId
            )
            let uploadPartResponse = try await s3.uploadPart(uploadPartRequest)
            
            guard let eTag = uploadPartResponse.eTag else {
                throw Abort(.internalServerError, reason: "Failed to upload chunk")
            }
            
            await UploadManager.shared.addPart(fileName: upload.fileName, part: .init(eTag: eTag, partNumber: chunkNumber + 1))
            
            let progress = Double(chunkNumber + 1) / Double(totalChunks)
            print("Upload progress: \(progress * 100)%")
        }
        
        // Complete the multipart upload
        guard let uploadInfo = await UploadManager.shared.getUploadInfo(fileName: upload.fileName) else {
            throw Abort(.internalServerError, reason: "Upload info not found")
        }
        
        let completeRequest = S3.CompleteMultipartUploadRequest(
            bucket: "MyBucket",
            key: upload.fileName,
            multipartUpload: .init(parts: uploadInfo.parts),
            uploadId: uploadId
        )
        let completeResponse = try await s3.completeMultipartUpload(completeRequest)
        
        await UploadManager.shared.removeUpload(fileName: upload.fileName)
        
        return Response(status: .ok, body: .init(string: "File uploaded successfully. ETag: \(completeResponse.eTag ?? "N/A")"))
    }
    
    @Sendable
    func uploadFileMultipart(req: Request) async throws -> Response {
        var file = try req.content.decode(File.self)
        let s3 = req.application.aws.s3
        let request = S3.CreateMultipartUploadRequest(bucket: "MyBucket", key: file.filename)
        let multipartUploadResponse = try await s3.createMultipartUpload(request)
        
        var parts: [S3.CompletedPart] = []
        var uploadPartRequests: [S3.UploadPartRequest] = []
        var partNumber = 1
        
        while !(file.data.readableBytes == 0) {
            let partData = file.data.readSlice(length: min(5 * 1024 * 1024, file.data.readableBytes))!
            let uploadPartRequest = S3.UploadPartRequest(
                body: .init(buffer: partData), bucket: "MyBucket",
                key: file.filename,
                partNumber: partNumber,
                uploadId: multipartUploadResponse.uploadId!
            )
            let uploadPartResponse = try await s3.uploadPart(uploadPartRequest)
            parts.append(S3.CompletedPart(eTag: uploadPartResponse.eTag!, partNumber: partNumber))
            uploadPartRequests.append(uploadPartRequest)
            partNumber += 1
        }
        
        let completeMultipartUploadRequest = S3.CompleteMultipartUploadRequest(
            bucket: "MyBucket",
            key: file.filename,
            multipartUpload: S3.CompletedMultipartUpload(parts: parts),
            uploadId: multipartUploadResponse.uploadId!
        )
        let completeMultipartUploadResponse = try await s3.completeMultipartUpload(completeMultipartUploadRequest)
        
        return Response(status: .ok, body: .init(string: "File uploaded successfully. ETag: \(completeMultipartUploadResponse.eTag ?? "N/A")"))
    }
    
    @Sendable
    func getPresignedUrl(req: Request) async throws -> Response {
        guard let fileId = req.parameters.get("id") else {
            throw Abort(.badRequest)
        }
        let s3 = req.application.aws.s3
        let request = S3.GetObjectRequest(bucket: "MyBucket", key: fileId)
        let url = URL(string: "https://\(request.bucket).s3.us-east-1.amazonaws.com/\(request.key)")!
        let presignedURLRequest = try await s3.signURL(url: url, httpMethod: .GET, expires: .hours(1))
        return Response(status: .ok, body: .init(string: presignedURLRequest.absoluteString))
    }
    
    @Sendable
    func updateFile(req: Request) async throws -> Response {
        guard let fileId = req.parameters.get("id") else {
            throw Abort(.badRequest)
        }
        let updateInfo = try req.content.decode(FileUpdateInfo.self)
        let s3 = req.application.aws.s3
        let request = S3.CopyObjectRequest(
            bucket: "MyBucket",
            copySource: "/MyBucket/\(fileId)",
            key: fileId,
            metadata: updateInfo.metadata,
            metadataDirective: .replace
        )
        let _ = try await s3.copyObject(request)
        return Response(status: .ok, body: .init(string: "File updated successfully"))
    }
    
    @Sendable
    func deleteFile(req: Request) async throws -> Response {
        guard let fileId = req.parameters.get("id") else {
            throw Abort(.badRequest)
        }
        let s3 = req.application.aws.s3
        let request = S3.DeleteObjectRequest(bucket: "MyBucket", key: fileId)
        let _ = try await s3.deleteObject(request)
        return Response(status: .ok, body: .init(string: "File deleted successfully"))
    }
    
    @Sendable
    func deleteMultipleFiles(req: Request) async throws -> Response {
        let filesToDelete = try req.content.decode([String].self)
        let s3 = req.application.aws.s3
        let objects = filesToDelete.map { S3.ObjectIdentifier(key: $0) }
        let request = S3.DeleteObjectsRequest(bucket: "MyBucket", delete: S3.Delete(objects: objects))
        let result = try await s3.deleteObjects(request)
        let deletedCount = result.deleted?.count ?? 0
        return Response(status: .ok, body: .init(string: "Deleted \(deletedCount) files successfully"))
    }
}

struct FileUpdateInfo: Content {
    let metadata: [String: String]
}
