##Chatting App

# After Cloning the application run The Application
```bash
docker-compose build --no-cache && docker-compose up -d
```
---
## Chat Server Architecture Documentation
High-Level Architectural Overview
I. Implemented Core Functionality
Core Messaging Logic: The fundamental logic for real-time messaging is complete and operational, supporting both direct user-to-user communication and group chat functionality.

Concurrency Management: The system efficiently handles concurrent operations through Go's native goroutines and synchronized data structures, ensuring high-performance message delivery.

Race Condition Mitigation: Comprehensive mutex protection and atomic operations prevent data inconsistencies across shared resources including user connections and session management.

II. Technology Stack Rationale
Concurrency Handling: Go was strategically selected for its exceptional capability in managing massive numbers of concurrent WebSocket connections, leveraging lightweight goroutines and efficient I/O multiplexing.

Data Integrity and State Management: Ruby serves as the foundation for all database migrations and primary APIs, functioning as the Single Point of Truth (SPOT) for application state and maintaining strict transactional integrity.

Performance and Consistency: The architecture eliminates direct, redundant database hits and prevents potential race conditions through Message Queues (MQ). Consumers systematically process messages in controlled batches, updating the database in synchronized chunks to ensure data consistency.

III. Current Operational Workflow (Sequential Process)
Application Provisioning: Create a new application instance and receive its unique authentication token for API interactions.

Application Definition: Define the new application with descriptive metadata including title, description, and configuration parameters.

Chat Instantiation: Initialize a new chat conversation within the specified application context, generating unique chat identifiers.

Subscription Management: Establish subscriptions to link users to specific chats, enabling multi-user participation and permission-based access control.

Message Delivery: Transmit messages with targeted subscriber arrays, ensuring every designated recipient receives the message via their active WebSocket connection with real-time delivery confirmation.

IV. Strategic Enhancements and Development Roadmap
Search Functionality: Integrate ElasticSearch to implement robust, full-text search API for messages and comprehensive user history retrieval. (Planned)

Authentication Service: Develop dedicated Authentication microservice to handle user identity management, OAuth flows, and granular authorization controls. (In Progress)

Implicit Chat Creation: Streamline chat instantiation: users can send messages with new chat IDs, triggering automatic implicit chat record creation in database. (Implemented)

History Retrieval: Implement functionality to fetch complete chat history for users who were offline during original message delivery, ensuring message persistence. (Planned)

Read Performance Caching: Utilize Redis to cache recent messages for every chat participant, accelerating history lookups and significantly reducing database load. (In Progress)

Code Structure Optimization: Implement comprehensive enhancements to code structure, modularity, and separation of concerns for improved long-term maintainability and scalability. (Ongoing)
