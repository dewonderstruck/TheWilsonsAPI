import Vapor
import Fluent

final class FileChunks: Model, Content {
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
    
    init(id: UUID? = nil, chunkNumber: Int, chunkSize: Int, chunkData: Data, fileID: UUID) {
        self.id = id
        self.chunkNumber = chunkNumber
        self.chunkSize = chunkSize
        self.chunkData = chunkData
    }
}