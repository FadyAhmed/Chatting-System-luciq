class User < ApplicationRecord
  has_many :chats, dependent: :destroy
  has_many :messages, dependent: :destroy

  before_validation :generate_id, on: :create
  before_create :generate_uuid

  validates :name, presence: true
  validates :email, presence: true, uniqueness: true

  private

  def generate_id
    self.id ||= SecureRandom.uuid
  end

  private

  def generate_uuid
      self.id ||= SecureRandom.uuid
  end
end
