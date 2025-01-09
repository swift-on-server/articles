# Real-time MongoDB Updates over WebSockets

Learn how to create a real-time feed of MongoDB changes using ChangeStreams and WebSockets. This tutorial demonstrates how to stream database changes to connected clients using MongoKitten and Hummingbird.

## Overview

In this tutorial, you'll learn how to:
- Create a real-time post feed using MongoDB ChangeStreams
- Set up a WebSocket server with Hummingbird
- Implement a REST endpoint for creating posts
- Broadcast changes to WebSocket clients
- Handle WebSocket connections safely using Swift concurrency

### Prerequisites

This tutorial builds upon concepts from:
- <doc:getting-started-with-mongokitten>
- <doc:websockets-tutorial-using-swift-and-hummingbird>

Make sure you have MongoDB running locally before starting.

## The Connection Manager

The ``ConnectionManager`` handles WebSocket connections and MongoDB change notifications:

@Snippet(path: "site/Snippets/realtime-mongodb-app", slice: "connection-manager")

1. The manager is an actor to ensure thread-safe access to connections
2. It maintains a dictionary of active WebSocket connections
3. The `broadcast` method sends updates to all connected clients
4. `withRegisteredClient` safely manages client lifecycle using structured concurrency

The use of `withRegisteredClient` ensures that the WebSocket connection is properly cleaned up when the connection is closed. This pattern is very scalable.

> Tip: Watch [Franz' Busch talk](https://www.youtube.com/watch?v=JmrnE7HUaDE) on this topic for a deeper dive into this pattern.

### Watching for Changes

Now that the ``ConnectionManager`` is implemented, we can watch for changes in the MongoDB database. For this, we'll tie the ``ConnectionManager`` to the application lifecycle using the ``Service`` protocol.

@Snippet(path: "site/Snippets/realtime-mongodb-app", slice: "watch-changes")

1. Get a reference to the posts collection
2. Create a change stream watching for post changes
3. Loop over each change
4. If the change is an insert, take the decoded post
5. Encode the post as JSON
6. Broadcast the post to all connected clients

This flow is very scalable, as only one ChangeStream is created and maintained per Hummingbird instance. At the same time, the use of structured concurrency ensures that the ChangeStream is properly cleaned up when the application shuts down.

## Setting Up the Application

Let's create the main application entry point:

@Snippet(path: "site/Snippets/realtime-mongodb-app", slice: "main")

1. Connect to MongoDB
2. Create the connection manager
3. Setup the HTTP router with a POST endpoint for creating posts
4. Configure WebSocket support using HTTP/1.1 upgrade
5. Add the connection manager as a service
6. Run the application

### Adding Routes

@Snippet(path: "site/Snippets/realtime-mongodb-app", slice: "routes")

This snippet adds a POST route to the application that creates a new post in the database. That process then triggers the change streams, which broadcast to all connected clients.

## Testing the Setup

1. Start the server:

```bash
swift run
```

You can also copy the code from this tutorial's snippet into your project and run it.

2. Connect to the WebSocket endpoint:

```
ws://localhost:8080
```

3. Create a new post using curl:

```bash
curl -X POST http://localhost:8080/posts \
  -H "Content-Type: application/json" \
  -d '{"author":"Joannis Orlandos","content":"Hello, real-time world!"}'
```

You should see the new post appear immediately in your WebSocket client!

## Next Steps

You've learned how to create a real-time feed of MongoDB changes using ChangeStreams and WebSockets! Here's what you can explore next:

- Add authentication for both HTTP and WebSocket endpoints
- Implement filters for specific types of changes
- Add support for updates and deletions
- Implement message acknowledgment
- Add retry mechanisms for failed broadcasts

### Resources

- [MongoDB ChangeStreams Documentation](https://www.mongodb.com/docs/manual/changeStreams/)
- [Hummingbird WebSocket Documentation](https://github.com/hummingbird-project/hummingbird-websocket)
- [MongoKitten Documentation](https://github.com/orlandos-nl/MongoKitten)

@Comment {
    Primary Keyword: mongodb changestream swift
    Secondary Keywords: 
    - swift websocket mongodb
    - real-time mongodb updates
    - mongodb swift streaming
    - swift websocket server
    - mongodb changestream tutorial
} 