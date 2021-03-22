require_relative 'bundle.rb'

class MeasureBundle
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Attributes::Dynamic
  belongs_to :bundle, class_name: 'Bundle'

  field :measure_bundle_hash, type: Hash, default: {}

  delegate :name, to: :measure_resource
  delegate :version, to: :measure_resource

  def measure
    Rails.cache.fetch("#{cache_key}/measure") do
      FHIR::Bundle.new(measure_bundle_hash)
    end
  end

  def effective_period
    measure_resource.effectivePeriod
  end

  def measure_scoring
    measure_resource.scoring.coding[0].code
  end

  private

  def measure_resource
    Rails.cache.fetch("#{cache_key}/measure_resource") do
      measure.entry.find { |e| e.resource.resourceType == 'Measure' }.resource
    end
  end
end

class PatientBundle
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Attributes::Dynamic
  belongs_to :bundle, class_name: 'Bundle'

  field :patient_bundle_hash, type: Hash, default: {}
  field :correlation_id, type: BSON::ObjectId
  field :validation_results, type: Hash, default: {}

  def patient
    Rails.cache.fetch("#{cache_key}/patient") do
      FHIR::Bundle.new(patient_bundle_hash)
    end
  end

  # TODO: rename given_names
  def givenNames
    patient_resource.name[0].given
  end

  # TODO: rename family_name
  def familyName
    patient_resource.name[0].family
  end

  def patient_fhir_id
    patient_resource.id
  end

  # TODO: rename birthdate
  def birthDate
    patient_resource.birthDate
  end

  def gender
    patient_resource.gender
  end

  def validation_errors?
    validation_results.values.any? { |vr| vr['errors'].present? }
  end

  def validate(validator)
    patient.entry.each do |entry|
      resource = entry.resource
      profile_url = resource&.meta&.profile&.first
      validation_results[hexkey_for_entry(entry)] = validator.validate(resource, profile_url)
    end
    save
  end

  def validation_result_for_entry(entry)
    validation_results[hexkey_for_entry(entry)] || { errors: [], warnings: [], information: [] }
  end

  def destroy
    PatientMeasureReport.where(patient_id: id).destroy_all
    delete
  end

  def scoop_and_filter(measure_id)
    patient_measure_report = PatientMeasureReport.where(patient_id: id, measure_id: measure_id).first
    entries_for_measure_report(patient_measure_report)
  end

  private

  def patient_resource
    Rails.cache.fetch("#{cache_key}/patient_resource") do
      patient.entry.find { |e| e.resource.resourceType == 'Patient' }.resource
    end
  end

  def hexkey_for_entry(entry)
    Digest::SHA2.hexdigest("#{entry.resource.resourceType} #{entry.resource.id}")
  end

  def entries_for_measure_report(patient_measure_report)
    evaluated_resources = patient_measure_report&.evaluated_resources
    # find the entries directly referenced in the measure report (as evaluated_resources)
    relevant_entries = retrieve_entries(evaluated_resources)
    # find the entries that are linked to the evaluated_resources
    relevant_entries.concat retrieve_entries(find_linked_entries(relevant_entries) - evaluated_resources)
  end

  def find_linked_entries(relevant_entries)
    linked_entries = []
    # Iterate over relevant_entries
    relevant_entries.each do |entry|
      entry_json = JSON.parse(entry.resource.to_json)
      linked_entries.concat find_all_values_for(entry_json, 'reference')
    end
    linked_entries.uniq
  end

  def find_all_values_for(entry, key, result = [])
    result << entry[key] if entry[key]
    # go through has, store each value for the key
    entry.values.each do |hash_value|
      values = hash_value.is_a?(Array) ? hash_value : [hash_value]
      values.each do |value|
        find_all_values_for(value, key, result) if value.is_a? Hash
      end
    end
    result.compact
  end

  def retrieve_entries(resource_urls)
    patient.entry.select { |e| resource_urls.include?("#{e.resource.resourceType}/#{e.resource.id}") }
  end
end

class BundlePatientBundle < PatientBundle; end
class VendorPatientBundle < PatientBundle; end
