import Fluent
import Vapor

final class FileModel: Model, Content, @unchecked Sendable {
    static let schema = "files"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "file_name")
    var fileName: String
    
    @Field(key: "file_size")
    var fileSize: Int
    
    @Field(key: "file_type")
    var fileType: String
    
    @Field(key: "upload_date")
    var uploadDate: Date
    
    @Field(key: "storage_type")
    var storageType: StorageType
    
    @Field(key: "bucket")
    var bucket: String
    
    @Field(key: "s3_etag")
    var s3ETag: String?
    
    @Field(key: "is_public")
    var isPublic: Bool
    
    @Timestamp(key: "created_at", on: .create)
    var createdAt: Date?
    
    @Timestamp(key: "updated_at", on: .update)
    var updatedAt: Date?
    
    init() { }
    
    init(id: UUID? = nil, fileName: String, fileSize: Int, fileType: String, bucket: String, uploadDate: Date, storageType: StorageType, isPublic: Bool) {
        self.id = id
        self.fileName = fileName
        self.fileSize = fileSize
        self.fileType = fileType
        self.uploadDate = uploadDate
        self.storageType = storageType
        self.bucket = bucket
        self.isPublic = isPublic
    }
}
