require_relative 'fhirbundle.rb'

class Bundle
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Attributes::Dynamic
  store_in collection: 'bundles'

  field :title, type: String
  field :name, type: String
  field :version, type: String
  field :license, type: String
  field :extensions, type: Array
  field :measures, type: Array
  field :effective_date
  field :measure_period_start
  field :records, type: Array
  field :active, type: Boolean
  field :deprecated, type: Boolean, default: false
  field :done_importing, type: Boolean, default: false

  validates_presence_of :version

  has_many :fhir_measure_bundles, class_name: 'MeasureBundle'
  has_many :fhir_patient_bundles, class_name: 'BundlePatientBundle'

  scope :active, -> { where(active: true) }
  scope :available, -> { where(:deprecated.ne => true) }

  def results
    PatientMeasureReport.where(correlation_id: id.to_s)
  end

  def title
    return super unless deprecated?

    self[:title] + ' (Deprecated)'
  end

  def deprecate
    PatientMeasureReport.where(patient_id: { '$in': PatientBundle.where(bundle_id: id.to_s).pluck(:id) }).destroy_all
    FileUtils.rm(mpl_path) if File.exist?(mpl_path)
    update(deprecated: true, active: false)
  end

  def destroy
    PatientMeasureReport.where(patient_id: { '$in': PatientBundle.where(bundle_id: id.to_s).pluck(:id) }).destroy_all
    FileUtils.rm(mpl_path) if File.exist?(mpl_path)
    MeasureBundle.where(bundle_id: id.to_s).destroy_all
    PatientBundle.where(bundle_id: id.to_s).destroy_all
    super
  end

  def default_negation_codes
    ApplicationController.helpers.config_for_version(version).default_negation_codes
  end

  # start data offset is the time in seconds to move data forward the number of year specified in config file
  def start_date_offset
    offset_years = ApplicationController.helpers.config_for_version(version).start_date_offset
    (Time.at(measure_period_start).in_time_zone + offset_years.year).to_i - measure_period_start
  end

  def qrda_version
    ApplicationController.helpers.config_for_version(version).qrda_version
  end

  def qrda3_version
    ApplicationController.helpers.config_for_version(version).qrda3_version
  end

  def cms_schematron
    ApplicationController.helpers.config_for_version(version).schematron
  end

  def modified_population_labels
    ApplicationController.helpers.config_for_version(version).modified_population_labels
  end

  def mpl_path
    Rails.root.join('tmp', 'cache', "bundle_#{id}_mpl.zip")
  end

  def mpl_status
    if File.exist?(mpl_path)
      :ready
    elsif MplDownloadCreateJob.trackers.where(:options => { bundle_id: id.to_s }, :status.in => %i[queued working]).count.positive?
      :building
    else
      :unbuilt
    end
  end

  # TODO: Bring this back
  def mpl_prepare
    if mpl_status == :unbuilt
      # MplDownloadCreateJob.perform_later(id.to_s)
      :building
    else
      mpl_status
    end
  end

  def major_version
    version.split('.')[0]
  end

  def update_default
    unless version == Settings.current.default_bundle
      Bundle.where(active: true).each { |b| b.update(active: false) }
      update(active: true)
      Bundle.find_by(id: id).active = true
      Settings.current.update(default_bundle: version)
    end
  end

  def self.default
    find_by(active: true)
  rescue
    most_recent
  end

  def self.most_recent
    where(version: pluck(:version).max_by { |v| v.split('.').map(&:to_i) }).first
  end

  def self.latest_bundle_id
    desc(:exported).first.try(:_id)
  end

  def self.first
    raise 'Do not use Bundle.first as there may be multiple bundles and order is not guaranteed.'
  end
end
