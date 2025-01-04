import Fluent

public struct SeedDefaultCategories: AsyncMigration {
    public init() {}
    
    public func prepare(on database: Database) async throws {
        // Gender categories
        let menswear = try await createCategory(
            id: "category-menswear",
            name: "Menswear",
            slug: "menswear",
            description: "Bespoke suits and clothing for men",
            type: "gender",
            displayOrder: 1,
            on: database
        )
        
        // Style categories under Menswear
        try await createCategory(
            id: "category-suits",
            name: "Suits",
            slug: "suits",
            description: "Classic and modern suit styles",
            parentId: menswear.id,
            type: "style",
            displayOrder: 1,
            metadata: [
                "defaultFit": "regular",
                "recommendedMeasurements": "chest,waist,shoulders,length"
            ],
            on: database
        )
        
        try await createCategory(
            id: "category-tuxedos",
            name: "Tuxedos",
            slug: "tuxedos",
            description: "Formal evening wear and tuxedos",
            parentId: menswear.id,
            type: "style",
            displayOrder: 2,
            metadata: [
                "defaultFit": "slim",
                "recommendedMeasurements": "chest,waist,shoulders,length"
            ],
            on: database
        )
        
        // Occasion categories
        try await createCategory(
            id: "category-wedding",
            name: "Wedding",
            slug: "wedding",
            description: "Wedding and ceremonial suits",
            type: "occasion",
            displayOrder: 1,
            metadata: [
                "consultationRequired": "true",
                "appointmentDuration": "60"
            ],
            on: database
        )
        
        try await createCategory(
            id: "category-business",
            name: "Business",
            slug: "business",
            description: "Professional business attire",
            type: "occasion",
            displayOrder: 2,
            metadata: [
                "consultationRequired": "false",
                "appointmentDuration": "45"
            ],
            on: database
        )
        
        try await createCategory(
            id: "category-casual",
            name: "Casual",
            slug: "casual",
            description: "Smart casual and everyday wear",
            type: "occasion",
            displayOrder: 3,
            metadata: [
                "consultationRequired": "false",
                "appointmentDuration": "30"
            ],
            on: database
        )
    }
    
    private func createCategory(
        id: String,
        name: String,
        slug: String,
        description: String,
        parentId: String? = nil,
        type: String,
        displayOrder: Int,
        metadata: [String: String] = [:],
        on database: Database
    ) async throws -> Category {
        let category = Category(
            id: id,
            name: name,
            slug: slug,
            description: description,
            parentId: parentId,
            metadata: metadata,
            displayOrder: displayOrder,
            type: type
        )
        try await category.save(on: database)
        return category
    }
    
    public func revert(on database: Database) async throws {
        try await Category.query(on: database).delete()
    }
} 