import Vapor
import SotoS3
import NIO
import Fluent
import Foundation

struct S3Controller: RouteCollection {
    
    private let fileUploadMiddleware: FileUploadMiddleware
    
    func boot(routes: RoutesBuilder) throws {
        
        let routes = routes.grouped("api", "s3")
        let files = routes.grouped("files")
        let uploadRoute = files.grouped(fileUploadMiddleware)
        files.get(use: listFiles)
        files.get(":id", use: getFile)
        uploadRoute.post(use: uploadFileMultipart)
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
        
        let file = try req.content.decode(File.self)
        
        let fileID = UUID().uuidString
        
        let s3 = req.application.aws.s3
        
        var newContentType = file.contentType?.description ?? "application/octet-stream" // Default content type
        
        var buffer: ByteBuffer
        
        // Assuming `file.data` is raw binary
        let fileData = Data(buffer: file.data)
        let encodedData = fileData.base64EncodedString()
        
        // Decode the data back to verify if it’s correctly encoded
        guard let decodedData = Data(base64Encoded: encodedData) else {
            throw Abort(.badRequest, reason: "Invalid base64 data")
        }
        
        buffer = ByteBufferAllocator().buffer(capacity: decodedData.count)
        buffer.writeBytes(fileData)
        
        // Log the buffer size to debug invalid length
        print("Buffer size: \(buffer.readableBytes)")
        
        let request = S3.CreateMultipartUploadRequest(bucket: "MyBucket", key: file.filename)
        let response = try await s3.multipartUpload(request, buffer: buffer) { progress in
            print("Upload progress: \(progress)")
        }
        return Response(status: .ok, body: .init(string: "File uploaded successfully. ETag: \(response.eTag ?? "N/A")"))
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
