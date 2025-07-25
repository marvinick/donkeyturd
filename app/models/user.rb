class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :omniauthable,
         omniauth_providers: [:google_oauth2]

  has_many :listings, dependent: :destroy
  has_many :blog_posts, dependent: :destroy

  validates :name, presence: true

  def self.from_omniauth(auth)
    where(email: auth.info.email).first_or_create do |user|
      user.email = auth.info.email
      user.name = auth.info.name
      user.provider = auth.provider
      user.uid = auth.uid
      user.password = Devise.friendly_token[0, 20]
    end
  end

  def full_name
    name
  end

  def admin?
    # For now, check if user has admin role or is first user
    # In production, you'd want a proper role system
    return true if self.id == 1  # First user is admin
    return true if self.email.in?(['admin@example.com', 'marvkipi@gmail.com'])  # Add your email here
    false
  end
end
