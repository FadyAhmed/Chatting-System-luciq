namespace :chat_worker do
  desc "Start the batch chat message processing worker"
  task start: :environment do
    logger = Logger.new(STDOUT)
    logger.level = Logger::INFO
    logger.formatter = proc do |severity, datetime, progname, msg|
      "[#{datetime}] #{severity}: #{msg}\n"
    end
    
    logger.info "Loading BatchChatWorker in Rails environment..."
    
    Signal.trap('TERM') do
      logger.info "Received TERM signal, shutting down gracefully..."
      exit
    end
    
    Signal.trap('INT') do
      logger.info "Received INT signal, shutting down gracefully..."
      exit
    end

    begin
      worker = BatchChatWorker.new
      worker.run
    rescue => e
      logger.error "Worker failed to start: #{e.message}"
      logger.error e.backtrace.join("\n")
      exit 1
    end
  end
end