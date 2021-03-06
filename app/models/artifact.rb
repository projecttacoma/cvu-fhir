class Artifact
  include Enumerable
  include Mongoid::Document
  include Mongoid::Timestamps

  MIME_FILE_TYPES = { 'application/zip' => :zip, 'multipart/mixed' => :zip, 'application/x-zip-compressed' => :zip,
                      'application/x-compressed' => :zip, 'multipart/x-zip' => :zip, 'application/xml' => :xml,
                      'text/xml' => :xml, 'text/json' => :json, 'application/json' => :json }.freeze

  mount_uploader :file, DocumentUploader

  field :content_type, type: String
  field :file_size, type: Integer

  validate :correct_file_type

  before_save :update_asset_attributes

  def correct_file_type
    return unless file_changed?

    content_extension = file.content_type ? MIME_FILE_TYPES[file.content_type] : nil
    errors.add(:file, 'File upload extension should be .zip') unless content_extension == :zip
  end

  def archive?
    MIME_FILE_TYPES[content_type] == :zip || File.extname(file.uploaded_filename) == '.zip'
  end

  def file_names
    file_names = []
    if archive?
      Zip::ZipFile.open(file.path) do |zipfile|
        file_names = zipfile.entries.collect(&:name)
      end
    else
      file_names = [file.uploaded_filename]
    end
    file_names
  end

  def file_count
    count = 0
    if archive?
      Zip::ZipFile.open(file.path) do |zipfile|
        count = zipfile.entries.count
      end
    else
      count = 1
    end
    count
  end

  def get_file(name)
    data = nil
    if archive?
      data =  get_archived_file(name)
    elsif file.uploaded_filename == name
      data = file.read
    end
    data
  end

  def get_archived_file(name)
    data = nil
    encoding = name.encoding
    Zip::ZipFile.open(file.path) do |zipfile|
      data = zipfile.read(name.force_encoding('ASCII-8BIT'))
    end
    name.force_encoding(encoding)
    data
  end

  # Enumerable mixin implementation requirement
  def each
    if archive?
      Zip::ZipFile.open(file.path) do |zipfile|
        zipfile.glob('*.json', File::FNM_CASEFOLD | ::File::FNM_PATHNAME | ::File::FNM_DOTMATCH).each do |entry|
          data = zipfile.read(entry.name)
          yield(entry.name, data)
        end
      end
    else
      yield(file.uploaded_filename, file.read)
    end
  end

  private

  def update_asset_attributes
    return if file.blank? || !file_changed?

    self.content_type = file.file.content_type
    self.file_size = file.file.size
  end
end
