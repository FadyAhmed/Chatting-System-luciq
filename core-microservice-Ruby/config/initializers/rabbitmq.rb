RABBITMQ_CONFIG = {
  host: ENV["RABBITMQ_HOST"] || "rabbitmq", # rubocop:disable Style/StringLiterals,Style/StringLiterals
  port: ENV["RABBITMQ_PORT"]|| 5672, # rubocop:disable Style/StringLiterals
  username: ENV["RABBITMQ_USERNAME"] || "guest", # rubocop:disable Style/StringLiterals
  password: ENV["RABBITMQ_PASSWORD"] || "guest", # rubocop:disable Style/StringLiterals,Style/StringLiterals
  vhost: ENV["RABBITMQ_VHOST"] ||"/" # "/"bocop:disable Style/StringLiterals,Layout/SpaceInsideReferenceBrackets,Style/StringLiterals,Style/StringLiterals
}.freeze # rubocop:disable Layout/SpaceInsideHashLiteralBraces
