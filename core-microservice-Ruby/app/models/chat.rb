class Chat < ApplicationRecord
  belongs_to :application
  belongs_to :user
  has_many :messages, dependent: :destroy

  before_validation :generate_id, on: :create
  before_create :generate_uuid, :assign_chat_number

  validates :number, presence: true, uniqueness: { scope: :application_id }
  validates :messages_count, numericality: { greater_than_or_equal_to: 0 }

  private

  def generate_id
    self.id ||= SecureRandom.uuid
  end

  private

  def generate_uuid
      self.id ||= SecureRandom.uuid
  end

  def assign_chat_number
    # Get the next chat number for this application
    last_chat = Chat.where(application_id: application_id).order(number: :desc).first
    self.number = last_chat ? last_chat.number + 1 : 1
  end
end
