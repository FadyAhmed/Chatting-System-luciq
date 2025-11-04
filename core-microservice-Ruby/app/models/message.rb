class Message < ApplicationRecord
  belongs_to :chat
  belongs_to :user

  # before_validation :generate_uuid, on: :create
  # before_create :assign_message_number

  validates :number, uniqueness: { scope: :chat_id }
  validates :content, presence: true

  # private

  # def generate_uuid
  #   self.id ||= SecureRandom.uuid
  # end

  # def assign_message_number
  #   # Get the last message number for this chat and increment
  #   last_message = Message.where(chat_id: chat_id).order(number: :desc).first
  #   self.number = last_message ? last_message.number + 1 : 1
  # end
end
