import Vapor 
import Fluent 

struct DashboardResponse: Content {
    let totalProducts: Int
    let totalOrders: Int
    let totalCustomers: Int
    let totalTransactions: Int
    let totalSettlements: Int
}

struct DashboardController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let v1 = routes.grouped("v1")
        let dashboardRoutes = v1.grouped("dashboard")
        dashboardRoutes.get(use: index)
    }

    // Get analytical data of total products, total orders, total customers, transactions, and settelments amount
    @Sendable
    func index(req: Request) async throws -> DashboardResponse {
        let totalProducts = try await Product.query(on: req.db).count()
        let totalOrders = try await Order.query(on: req.db).count()
        let totalCustomers = try await User.query(on: req.db).filter(\.$accountType == .customer).count()
        let totalTransactions = try await Transaction.query(on: req.db).count()
        let totalSettelments = try await Settlement.query(on: req.db).count()

        let response = DashboardResponse(
            totalProducts: totalProducts,
            totalOrders: totalOrders,
            totalCustomers: totalCustomers,
            totalTransactions: totalTransactions,
            totalSettlements: totalSettelments
        )

        return response
    }
}
