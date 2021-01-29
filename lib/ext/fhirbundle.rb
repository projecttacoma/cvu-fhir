require_relative 'bundle.rb'


class MeasureBundle
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Attributes::Dynamic
  belongs_to :bundle, class_name: 'Bundle'

  field :measure_bundle_hash, type: Hash, default: {}

  def measure
    FHIR::Bundle.new(measure_bundle_hash)
  end

  def effectivePeriod
    measureResource.effectivePeriod
  end

  def name
    measureResource.name
  end

  def version
    measureResource.version
  end

private
  def measureResource
    # find actual patient resource (TODO: cache?)
    measure.entry.find{|e| e.resource.resourceType == "Measure"}.resource
  end

end

class PatientBundle
  include Mongoid::Document
  include Mongoid::Timestamps
  include Mongoid::Attributes::Dynamic
  belongs_to :bundle, class_name: 'Bundle'

  field :patient_bundle_hash, type: Hash, default: {}

  def cqm_patient
    CQMPatient.new(self)
  end

  def patient_resource_id
    patient_bundle_hash.entry.find{|e| e.resource.resourceType == "Patient"}.resource.id
  end
end
