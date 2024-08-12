import Vapor
import Fluent

final class FileChunks: Model, Content, @unchecked Sendable {
    init() { }
    
    static let schema = "file_chunk"
    
    @ID(key: .id)
    var id: UUID?
    
    @Field(key: "chunk_number")
    var chunkNumber: Int
    
    @Field(key: "chunk_size")
    var chunkSize: Int
    
    @Field(key: "chunk_data")
    var chunkData: Data

    @Parent(key: "file_id")
    var file: FileModel
    
    init(id: UUID? = nil, chunkNumber: Int, chunkSize: Int, chunkData: Data, fileID: UUID) {
        self.id = id
        self.chunkNumber = chunkNumber
        self.chunkSize = chunkSize
        self.chunkData = chunkData
        self.$file.id = fileID
    }
}
