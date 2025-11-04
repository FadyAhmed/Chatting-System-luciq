class Application < ApplicationRecord
    has_many :chats

    before_create :generate_token
    before_create :generate_uuid

    # validates :name, presence: true
    # validates :token, presence: true, uniqueness: true

    private

    def generate_token
        self.token = SecureRandom.uuid
    end

    private

    def generate_uuid
        self.id ||= SecureRandom.uuid
    end
end
