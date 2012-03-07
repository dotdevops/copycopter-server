require 'extensions/string'

class Project < ActiveRecord::Base
  # Associatons
  has_many :blurbs
  belongs_to :draft_cache, :class_name => 'TextCache', :dependent => :destroy
  has_many :locales, :dependent => :delete_all
  has_many :localizations, :through => :blurbs
  belongs_to :published_cache, :class_name => 'TextCache',
    :dependent => :destroy

  # Validations
  validates_presence_of :api_key
  validates_uniqueness_of :api_key

  # Callbacks
  before_validation :generate_api_key, :on => :create
  before_create :create_caches
  after_create :create_english_locale
  after_destroy :delete_localizations_and_blurbs

  def self.archived
    where :archived => true
  end

  def self.active
    where :archived => false
  end

  def active?
    !archived
  end

  def self.by_name
    order 'projects.name'
  end

  def create_defaults(hash)
    DefaultCreator.new(self, hash).create
  end

  def default_locale
    locales.first_enabled
  end

  def deploy!
    localizations.publish
    schedule_cache_update
  end

  def draft_json
    draft_cache.data
  end

  def etag
    [updated_at.to_i.to_s, updated_at.usec.to_s].join
  end

  def locale(locale_id = nil)
    if locale_id
      locales.find locale_id
    else
      default_locale
    end
  end

  def lock_key_for_creating_defaults
    "project-#{id}-create-defaults"
  end

  def published_json
    published_cache.data
  end

  def self.regenerate_caches
    find_each do |project|
      project.update_caches
    end
  end

  def schedule_cache_update
    JOB_QUEUE.enqueue ProjectCacheJob.new(id)
  end

  def update_caches
    draft_cache.update_attributes! :data => generate_json(:draft_content)
    published_cache.update_attributes! :data => generate_json(:published_content)
    touch
  end

  private

  def create_caches
    self.draft_cache = TextCache.create!(:data => "{}")
    self.published_cache = TextCache.create!(:data => "{}")
  end

  def create_english_locale
    locales.create! :key => 'en'
  end

  def delete_localizations_and_blurbs
    transaction do
      blurb_ids = Blurb.select('id').where(:project_id => self.id).map(&:id)
      Localization.where(:blurb_id => blurb_ids).delete_all
      Blurb.where(:project_id => self.id).delete_all
    end
  end

  def generate_api_key
    self.api_key = Digest::MD5.hexdigest("#{name}#{Time.now.to_f}")
  end

  def generate_json(content)
    Yajl::Encoder.encode blurbs.to_hash(content)
  end
end