##Chatting App

# After Cloning the application run The Application
```bash
docker-compose up --build -d
```
---
## Chat Server Architecture Documentation
High-Level Architectural Overview
Architectural Summary: Key Project Points

This document summarizes the current architecture, established workflow, and strategic roadmap for the real-time messaging platform.

I. Core Architecture & Established Strengths

High Concurrency & Efficiency: The core messaging logic is implemented in Go, specifically chosen for its efficient handling of a large volume of concurrent WebSocket connections via goroutines.

Data Integrity & Persistence (Single Point of Trust): Ruby-based APIs and migrations manage the primary database, ensuring transactional integrity and making the Ruby application the sole trusted authority for data changes.

Race Condition Mitigation: All critical database updates (such as subscription changes or message history) are processed through Message Queues (MQ). This pattern buffers updates and performs synchronized database writes in chunks, preventing direct redundant database hits and mitigating race conditions.

Optimized Indexing (Redis): Redis is utilized for high-speed indexing, maintaining both the standard index (User to Chats) and the inverse index (Chat to Subscribers) to ensure fast lookup and message distribution.

II. Current Operational Workflow

The platform follows a structured, multi-step process for initial setup and messaging:

Application Creation: A new application is created via the main API, generating a unique application token for security and authorization.

Chat Creation: A new chat instance is explicitly created within the scope of the application.

Subscription: Users are subscribed to a specific chat, enabling multi-user communication.

Initial Message Handshake: Messages are sent to the platform, including an array of current subscribers.

Real-Time Delivery: The Go WebSocket handlers distribute the message in real-time to all clients listed in the message's subscriber array.

III. Strategic Enhancements and Development Roadmap
Search Functionality: Integrate ElasticSearch to implement robust, full-text search API for messages and comprehensive user history retrieval. (Planned)

Authentication Service: Develop dedicated Authentication microservice to handle user identity management, OAuth flows, and granular authorization controls. (In Progress)

Implicit Chat Creation: Streamline chat instantiation: users can send messages with new chat IDs, triggering automatic implicit chat record creation in database. (Implemented)

History Retrieval: Implement functionality to fetch complete chat history for users who were offline during original message delivery, ensuring message persistence. (Planned)

Read Performance Caching: Utilize Redis to cache recent messages for every chat participant, accelerating history lookups and significantly reducing database load. (In Progress)

Code Structure Optimization: Implement comprehensive enhancements to code structure, modularity, and separation of concerns for improved long-term maintainability and scalability. (Ongoing)
