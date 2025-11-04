# app/workers/batch_chat_worker.rb
class BatchChatWorker
  FLUSH_INTERVAL = 5 # seconds

  def initialize
    @logger = Logger.new(STDOUT)
    @logger.level = Logger::INFO
    @logger.formatter = proc do |severity, datetime, progname, msg|
      "[#{datetime}] #{severity}: #{msg}\n"
    end

    load_rails_models
    
    @rabbitmq_conn = establish_rabbitmq_connection
    @redis = establish_redis_connection
    
    @channel = @rabbitmq_conn.create_channel
    @queue = @channel.queue(RABBITMQ_QUEUE, durable: true)

    # In-Memory Buffer and Mutex
    @message_buffer = [] 
    @mutex = Mutex.new

    @running = true

    @logger.info "Worker initialized. Flush interval: #{FLUSH_INTERVAL}s. Queue: #{RABBITMQ_QUEUE}"
  end

  def run
    consumer = consumer_thread
    flusher = flushing_thread

    @logger.info "Worker is running. Press Ctrl+C to exit."
    
    consumer.join
    flusher.join
  rescue Interrupt => e
    shutdown
  end

  def shutdown
    @logger.info "Shutting down worker gracefully..."
    @running = false
    
    flush_remaining_messages
    
    @channel.close if @channel && @channel.open?
    @rabbitmq_conn.close if @rabbitmq_conn && @rabbitmq_conn.open?
    @redis.quit if @redis
    
    @logger.info "Worker shutdown complete."
  end

  private

  def load_rails_models
    if defined?(Rails)
      @logger.info "Rails environment loaded successfully"
    end
  rescue => e
    @logger.error "Failed to load Rails models: #{e.message}"
    raise
  end

  def establish_rabbitmq_connection
    conn = Bunny.new(
      host: RABBITMQ_HOST,
      port: RABBITMQ_PORT,
      automatically_recover: true,
      logger: @logger,
    ).start
    @logger.info "Connected to RabbitMQ at #{RABBITMQ_HOST}:#{RABBITMQ_PORT}"
    conn
  rescue => e
    @logger.error "Failed to connect to RabbitMQ: #{e.message}. Exiting."
    exit(1)
  end

  def establish_redis_connection
    client = Redis.new(url: REDIS_URL)
    client.ping
    @logger.info "Connected to Redis at #{REDIS_URL}"
    client
  rescue => e
    @logger.error "Failed to connect to Redis: #{e.message}. Exiting."
    exit(1)
  end

  def consumer_thread
    Thread.new do
      Thread.current.name = 'ConsumerThread'
      @logger.info "Consumer Thread started. Waiting for messages on #{RABBITMQ_QUEUE}..."
      
      begin
        @queue.subscribe(manual_ack: true) do |delivery_info, _properties, payload|
          break unless @running
          
          begin
            message_data = JSON.parse(payload)
            
            @mutex.synchronize do
              @message_buffer << {
                data: message_data,
                delivery_tag: delivery_info.delivery_tag
              }
              @logger.debug "Buffered message. Current buffer size: #{@message_buffer.size}"
            end
            
          rescue JSON::ParserError => e
            @logger.error "Failed to parse message payload: #{payload}. Error: #{e.message}. Rejecting message."
            @channel.reject(delivery_info.delivery_tag, false)
          rescue => e
            @logger.error "Unexpected error in consumer thread: #{e.message}. Rejecting message."
            @channel.reject(delivery_info.delivery_tag, false)
          end
        end
      rescue => e
        @logger.error "Consumer thread error: #{e.message}" if @running
      end
    end
  end

  def flushing_thread
    Thread.new do
      Thread.current.name = 'FlushingThread'
      @logger.info "Flushing Thread started. Will flush every #{FLUSH_INTERVAL} seconds."
      
      while @running
        sleep(FLUSH_INTERVAL)
        flush_buffer if @running
      end
    end
  end

  def flush_buffer
    batch_to_process = []
    
    @mutex.synchronize do
      batch_to_process = @message_buffer
      @message_buffer = []
    end
    
    if batch_to_process.empty?
      @logger.debug "Buffer empty. Skipping flush."
    else
      @logger.info "Flushing batch of #{batch_to_process.size} messages"
      process_batch(batch_to_process)
    end
  end

  def flush_remaining_messages
    batch_to_process = []
    
    @mutex.synchronize do
      batch_to_process = @message_buffer
      @message_buffer = []
    end
    
    unless batch_to_process.empty?
      @logger.info "Processing remaining #{batch_to_process.size} messages before shutdown"
      process_batch(batch_to_process)
    end
  end

    def process_batch(batch)
    message_data_batch = batch.map { |item| item[:data] }
    delivery_tags = batch.map { |item| item[:delivery_tag] }
    @logger.info "#{message_data_batch}"

    success = false
    begin
      ActiveRecord::Base.transaction do
        # Use Redis for atomic increments
        redis = Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/0'))
        @logger.info "Hii"

        chat_ids = message_data_batch.map { |msg| msg['chat_id'] }.uniq
        
        # Find or create chats
        existing_chats = Chat.where(id: chat_ids).pluck(:id)
        missing_chat_ids = chat_ids - existing_chats
        
        if missing_chat_ids.any?
          @logger.info "Creating #{missing_chat_ids.size} new chats"
          missing_chat_ids.each do |chat_id|
            sample_msg = message_data_batch.find { |msg| msg['chat_id'] == chat_id }
            chats_number = redis.incr("chat:#{chat_id}:chat_counter")
            
            @logger.info "MSG: #{sample_msg}"
            Chat.create!(
              id: chat_id,
              number: chats_number,
              application_id: sample_msg['applicationId'],
              user_id: sample_msg['user_id']
            )
          rescue ActiveRecord::RecordNotUnique
            @logger.debug "Chat #{chat_id} was already created"
          rescue => e
            @logger.error "Failed to create chat #{chat_id}: #{e.message}"
            raise
          end
        end
        
        messages_for_bulk_insert = message_data_batch.map do |msg|
          chat_id = msg['chat_id']
          
          # Atomically increment message number for this chat
          message_number = redis.incr("chat:#{chat_id}:message_counter")
          @logger.info "message_number #{message_number}"
          {
            id: SecureRandom.uuid,
            chat_id: chat_id,
            user_id: msg['user_id'],
            text: msg['content'],
            number: message_number,
            created_at: Time.current,
            updated_at: Time.current
          }
        end

        Message.insert_all(messages_for_bulk_insert)
        success = true
      end
    rescue => e
      @logger.error "Transaction FAILED for batch of #{batch.size}. Error: #{e.message}"
      @logger.error e.backtrace.join("\n")
    end

    # Acknowledge or Reject messages
    if success
      @logger.info "Batch successfully committed. Acknowledging #{delivery_tags.size} messages."
      delivery_tags.each { |tag| @channel.ack(tag) }
    else
      @logger.warn "Batch failed to commit. Rejecting #{delivery_tags.size} messages."
      delivery_tags.each { |tag| @channel.reject(tag, true) }
    end
  end
end

# Configuration constants
RABBITMQ_HOST = ENV.fetch('RABBITMQ_HOST', 'rabbitmq')
RABBITMQ_PORT = ENV.fetch('RABBITMQ_PORT', 5672).to_i
RABBITMQ_QUEUE = 'chats-queue'
REDIS_PORT = ENV.fetch('REDIS_PORT', '6379')
REDIS_HOST = ENV.fetch('REDIS_HOST', 'localhost')
REDIS_URL = "redis://#{REDIS_HOST}:#{REDIS_PORT}/0"