# The values of an Entry are as follows:
# - "dumb" (as in simple) but sturdy
# - an Entry should denote something that has *happened*, i.e.  if the
#   occurred_at date is in the future, then maybe you want a diff object?
# - entries can be edited by the user, but if inserted by a robot should be
#   treated as immutable, or as close as it is sensible.
class Entry < ApplicationRecord
  has_many_attached :files

  scope :visible, -> { where(hide: false) }
  scope :for_notebook, -> (notebook) { where(notebook: notebook.to_s) }
  scope :hitherto, -> { where("occurred_at <= ? ", Time.now.end_of_day) }
  # probably ought to add a calendar entry type of object
  scope :upcoming, -> { where("occurred_at > ? ", Time.now) }

  has_many :replies, class_name: "Entry", foreign_key: :in_reply_to, primary_key: :identifier
  belongs_to :parent, class_name: "Entry", foreign_key: :in_reply_to, primary_key: :identifier, optional: true

  before_create :set_identifier
  after_save :process_tags

  # TODO: issue here is i want a uniq id that
  # while not impervious is pretty resistant
  # to random collisions. but at time of writing
  # using occurred_at won't always have sub second
  # resolution, making this not work super well
  def set_identifier
    self.identifier ||= occurred_at.strftime("%Y-%m-%d-%H%M%S%L")
  end

  def process_tags
    EntryTagger.new(self).process!
  end

  def calendar?
    kind == "calendar"
  end

  def bookmark?
    kind == "pinboard"
  end

  def fold?
    self.body.size > 500
  end

  def reply?
    in_reply_to.presence
  end

  # this is actually pretty complicated to do properly?
  # https://github.com/middleman/middleman/blob/master/middleman-core/lib/middleman-core/util/data.rb
  # https://github.com/middleman/middleman/blob/master/middleman-core/lib/middleman-core/core_extensions/front_matter.rb
  # https://github.com/middleman/middleman/blob/5fd6a1efcb7a5f1cb6b3dbe3c930fddc91b3e626/middleman-core/lib/middleman-core/util/binary.rb#L357
  #
  # meh handle later
  # https://stackoverflow.com/questions/36948807/edit-yaml-frontmatter-in-markdown-file
  def frontmatter_attributes
    self.attributes.slice("id",
                          "occurred_at",
                          "created_at",
                          "updated_at")
  end

  def to_param
    identifier
  end

  def export_attributes
    attributes.except("id")
  end

  def to_yaml
    export_attributes.to_yaml
  end

  def to_folder_path(dirname)
    File.join(dirname,
              notebook,
              occurred_at.strftime("%Y/%m/%d"),
              identifier)
  end

  def to_filename
    "#{identifier}.yaml"
  end

  def truncated_description
    (subject || body).truncate(30)
  end
end
