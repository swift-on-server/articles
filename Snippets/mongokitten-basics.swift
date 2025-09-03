import Foundation
import MongoKitten

// snippet.connection
let db = try await MongoDatabase.connect(
    to: "mongodb://localhost:27017/social_network"
)
print("Connected to MongoDB!")
// snippet.end

// snippet.models
struct Post: Codable {
    let _id: ObjectId
    let author: String
    let content: String
    let createdAt: Date

    init(author: String, content: String) {
        self._id = ObjectId()
        self.author = author
        self.content = content
        self.createdAt = Date()
    }
}
// snippet.end

// snippet.insert
func createPost(author: String, content: String) async throws {
    // 1. Create the post
    let post = Post(author: author, content: content)

    // 2. Get the posts collection
    let posts = db["posts"]

    // 3. Insert the post
    try await posts.insertEncoded(post)
}
// snippet.end

// snippet.find-all
// 1. Find all posts
let allPosts = try await db["posts"]
    .find()
    .decode(Post.self)
    .drain()
// snippet.end

// snippet.find-by-author
// 2. Find posts by a specific author
let authorPosts = try await db["posts"]
    .find("author" == "swift_developer")
    .decode(Post.self)
    .drain()
// snippet.end

// snippet.find-recent
// 3. Find recent posts, sorted by creation date
let recentPosts = try await db["posts"]
    .find()
    .sort(["createdAt": .descending])
    .limit(10)
    .decode(Post.self)
    .drain()
// snippet.end

// snippet.bson
struct Person: Codable {
    let name: String
    let age: Int
    let tags: [String]
    let active: Bool
}

// Creating a BSON Document manually
let document: Document = [
    "name": "Swift Developer",
    "age": 25,
    "tags": ["swift", "mongodb", "backend"] as Document,
    "active": true,
]

// Converting between BSON and Codable
let bsonDocument = try BSONEncoder().encode(document)
let decodedPerson = try BSONDecoder().decode(Person.self, from: bsonDocument)
// snippet.end
