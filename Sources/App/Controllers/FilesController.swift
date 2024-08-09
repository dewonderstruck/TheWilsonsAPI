import Vapor
import Fluent
import SotoS3

struct FilesController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let files = routes.grouped("files")
        files.get(use: listFiles)
        files.get(":id", use: getFile)
        files.post(use: uploadFile)
        files.post("import", use: importFile)
        files.patch(":id", use: updateFile)
        files.delete(":id", use: deleteFile)
        files.delete(use: deleteMultipleFiles)
    }
    
    @Sendable
    func listFiles(req: Request) async throws -> [FileModel] {
        return try await FileModel.query(on: req.db).all()
    }
    
    @Sendable
    func getFile(req: Request) async throws -> FileModel {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        guard let file = try await FileModel.find(id, on: req.db) else {
            throw Abort(.notFound)
        }
        return file
    }
    
    @Sendable
    func uploadFile(req: Request) async throws -> FileModel {
        let data = try req.content.decode(FileModel.self)
        let file = FileModel(
            fileName: data.fileName,
            fileSize: data.fileSize,
            fileType: data.fileType,
            uploadDate: data.uploadDate,
            storageType: data.storageType,
            isPublic: data.isPublic
        )
        try await file.save(on: req.db)
        return file
    }
    
    @Sendable
    func importFile(req: Request) async throws -> FileModel {
        struct ImportData: Content {
            let url: String
            let data: FileModel
        }
        
        let importData = try req.content.decode(ImportData.self)
        let url = importData.url
        let fileData = importData.data
        
        // Download file from URL and save to S3
        let response = try await req.client.get(URI(string: url))
        guard let body = response.body else {
            throw Abort(.badRequest)
        }
        let buffer = body.getData(at: 0, length: body.readableBytes) ?? Data()
        
        
        let s3 = req.application.s3.client
        let putObjectRequest = S3.PutObjectRequest(
            body: AWSHTTPBody(buffer: buffer),
            bucket: "your-bucket-name",
            key: fileData.fileName
        )
        try await s3.putObject(putObjectRequest)
        
        let file = FileModel(
            fileName: fileData.fileName,
            fileSize: fileData.fileSize,
            fileType: fileData.fileType,
            uploadDate: fileData.uploadDate,
            storageType: .s3,
            isPublic: fileData.isPublic
        )
        try await file.save(on: req.db)
        return file
    }
    
    @Sendable
    func updateFile(req: Request) async throws -> FileModel {
        let updatedData = try req.content.decode(FileModel.self)
        guard let file = try await FileModel.find(updatedData.id, on: req.db) else {
            throw Abort(.notFound)
        }
        file.fileName = updatedData.fileName
        file.fileSize = updatedData.fileSize
        file.fileType = updatedData.fileType
        file.uploadDate = updatedData.uploadDate
        file.storageType = updatedData.storageType
        file.isPublic = updatedData.isPublic
        try await file.save(on: req.db)
        return file
    }
    
    @Sendable
    func deleteFile(req: Request) async throws -> HTTPStatus {
        guard let id = req.parameters.get("id", as: UUID.self) else {
            throw Abort(.badRequest)
        }
        guard let file = try await FileModel.find(id, on: req.db) else {
            throw Abort(.notFound)
        }
        try await file.delete(on: req.db)
        return .noContent
    }
    
    @Sendable
    func deleteMultipleFiles(req: Request) async throws -> HTTPStatus {
        let ids = try req.content.decode([UUID].self)
        let files = try await FileModel.query(on: req.db)
            .filter(\.$id ~~ ids)
            .all()
        for file in files {
            try await file.delete(on: req.db)
        }
        return .noContent
    }
}
