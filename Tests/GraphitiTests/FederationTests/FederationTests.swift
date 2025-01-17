import Foundation
import Graphiti
import GraphQL
import NIO
import XCTest

final class FederationTests: XCTestCase {
    private var group: MultiThreadedEventLoopGroup!
    private var api: ProductAPI!

    override func setUpWithError() throws {
        let schema = try SchemaBuilder(ProductResolver.self, ProductContext.self)
            .use(partials: [ProductSchema()])
            .setFederatedSDL(to: loadSDL())
            .build()
        self.group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        self.api = try ProductAPI(resolver: ProductResolver(sdl: loadSDL()), schema: schema)
    }

    override func tearDownWithError() throws {
        try group.syncShutdownGracefully()
        group = nil
        api = nil
    }
    
    // Test Queries from https://github.com/apollographql/apollo-federation-subgraph-compatibility/blob/main/COMPATIBILITY.md

    func testServiceQuery() throws {
        try XCTAssertEqual(execute(request: query("service")), GraphQLResult(data: [
            "_service": [
                "sdl": Map(stringLiteral: loadSDL())
            ]
        ]))
    }

    func testEntityKey() throws {
        let representations: [String : Map] = [
            "representations" : [
                [ "__typename": "User", "email": "support@apollographql.com" ]
            ]
        ]

        try XCTAssertEqual(execute(request: query("entities"), variables: representations), GraphQLResult(data: [
            "_entities": [
                [
                    "email": "support@apollographql.com",
                    "name": "Jane Smith",
                    "totalProductsCreated": 1337,
                    "yearsOfEmployment": 10,
                    "averageProductsCreatedPerYear": 133,
                ]
            ]
        ]))
    }

    func testEntityMultipleKey() throws {
        let representations: [String : Map] = [
            "representations" : [
                [ "__typename": "DeprecatedProduct", "sku": "apollo-federation-v1", "package": "@apollo/federation-v1" ]
            ]
        ]

        try XCTAssertEqual(execute(request: query("entities"), variables: representations), GraphQLResult(data: [
            "_entities": [
                [
                    "sku": "apollo-federation-v1",
                    "package": "@apollo/federation-v1",
                    "reason": "Migrate to Federation V2",
                    "createdBy": [
                        "email": "support@apollographql.com",
                        "name": "Jane Smith",
                        "totalProductsCreated": 1337,
                        "yearsOfEmployment": 10,
                        "averageProductsCreatedPerYear": 133,
                    ]
                ]
            ]
        ]))
    }

    func testEntityCompositeKey() throws {
        let representations: [String : Map] = [
            "representations" : [
                [ "__typename": "ProductResearch", "study": [ "caseNumber": "1234" ] ]
            ]
        ]

        try XCTAssertEqual(execute(request: query("entities"), variables: representations), GraphQLResult(data: [
            "_entities": [
                [
                    "study": [
                        "caseNumber": "1234",
                        "description": "Federation Study"
                    ],
                    "outcome": nil
                ]
            ]
        ]))
    }

    func testEntityMultipleKeys() throws {
        let representations: [String : Map] = [
            "representations" : [
                [ "__typename": "Product", "id": "apollo-federation" ],
                [ "__typename": "Product", "sku": "federation", "package": "@apollo/federation" ],
                [ "__typename": "Product", "sku": "studio", "variation": [ "id": "platform" ] ],
            ]
        ]

        try XCTAssertEqual(execute(request: query("entities"), variables: representations), GraphQLResult(data: [
            "_entities": [
                [
                    "id": "apollo-federation",
                    "sku": "federation",
                    "package": "@apollo/federation",
                    "variation": [
                        "id": "OSS"
                    ],
                    "dimensions": [
                        "size": "small",
                        "unit": "kg",
                        "weight": 1
                    ],
                    "createdBy": [
                        "email": "support@apollographql.com",
                        "name": "Jane Smith",
                        "totalProductsCreated": 1337,
                        "yearsOfEmployment":10,
                        "averageProductsCreatedPerYear":133,
                    ],
                    "notes": nil,
                    "research": [
                        [
                            "outcome": nil,
                            "study": [
                                "caseNumber": "1234",
                                "description": "Federation Study"
                            ]
                        ]
                    ]
                ],
                [
                    "id": "apollo-federation",
                    "sku": "federation",
                    "package": "@apollo/federation",
                    "variation": [
                        "id": "OSS"
                    ],
                    "dimensions": [
                        "size": "small",
                        "unit": "kg",
                        "weight": 1
                    ],
                    "createdBy": [
                        "email": "support@apollographql.com",
                        "name": "Jane Smith",
                        "totalProductsCreated": 1337,
                        "yearsOfEmployment":10,
                        "averageProductsCreatedPerYear":133,
                    ],
                    "notes": nil,
                    "research": [
                        [
                            "outcome": nil,
                            "study": [
                                "caseNumber": "1234",
                                "description": "Federation Study"
                            ]
                        ]
                    ]
                ],
                [
                    "id": "apollo-studio",
                    "sku": "studio",
                    "package": "",
                    "variation": [
                        "id": "platform"
                    ],
                    "dimensions": [
                        "size": "small",
                        "unit": "kg",
                        "weight": 1
                    ],
                    "createdBy": [
                        "email": "support@apollographql.com",
                        "name": "Jane Smith",
                        "totalProductsCreated": 1337,
                        "yearsOfEmployment":10,
                        "averageProductsCreatedPerYear":133,
                    ],
                    "notes": nil,
                    "research": [
                        [
                            "outcome": nil,
                            "study": [
                                "caseNumber": "1235",
                                "description": "Studio Study"
                            ]
                        ]
                    ]
                ]
            ]
        ]))
    }
}

// MARK: - Helpers
extension FederationTests {
    enum FederationTestsError: Error {
        case couldNotLoadFile
    }

    func loadSDL() throws -> String {
        guard let url = Bundle.module.url(forResource: "product", withExtension: "graphqls", subdirectory: "GraphQL") else {
            throw FederationTestsError.couldNotLoadFile
        }
        return try String(contentsOf: url)
    }

    func query(_ name: String) throws -> String {
        guard let url = Bundle.module.url(forResource: name, withExtension: "graphql", subdirectory: "GraphQL") else {
            throw FederationTestsError.couldNotLoadFile
        }
        return try String(contentsOf: url)
    }

    func execute(request: String, variables: [String: Map] = [:]) throws -> GraphQLResult {
        try api.execute(request: request, context: ProductContext(), on: group, variables: variables).wait()
    }
}
