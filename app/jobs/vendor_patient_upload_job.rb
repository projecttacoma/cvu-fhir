class VendorPatientUploadJob < ApplicationJob
  include Job::Status
  include ::CqmValidators
  include ::Validators

  after_enqueue do |job|
    tracker = job.tracker
    tracker.options['original_filename'] = job.arguments[1]
    tracker.options['vendor_id'] = job.arguments[2]
    tracker.save
  end

  def perform(file, _original_filename, vendor_id, bundle_id)
    tracker.log('Importing')

    vendor_patient_file = File.new(file)

    bundle = Bundle.find(bundle_id)

    patients, failed_files = parse_patients(vendor_patient_file, vendor_id, bundle)

    # do patient calculation against bundle
    unless patients.empty?
      config = Rails.application.config
      validator = HL7Validator.new("http://#{config.hl7_host}:#{config.hl7_port}")
      generate_calculations(patients, bundle, vendor_id)
      patients.each { |patient| patient.validate(validator) }
      # PatientAnalysisJob.perform_later(bundle.id.to_s, vendor_id)
    end

    raise failed_files.to_s unless failed_files.empty?
  end

  def parse_patients(file, vendor_id, bundle)
    artifact = Artifact.new(file: file)
    failed_files = {} # hash (filename -> error array)
    patients = []

    artifact.each do |name, data|
      # Add a patient if it passes CDA validation
      valid, patient_or_errors = add_patient(data, vendor_id, bundle)
      if valid
        patients << patient_or_errors unless patient_or_errors.nil?
      else
        failed_files[name] = patient_or_errors
      end
    end

    [patients, failed_files]
  end

  # Take xml file name, data, error collection hash, return CQM::Patient
  def add_patient(data, vendor_id, bundle)
    [true, VendorPatientBundle.create(patient_bundle_hash: JSON.parse(data), correlation_id: vendor_id, bundle: bundle.id)]

    # time_shifted_patient(doc, vendor_id, bundle)
  end

  # TODO: Bring back time shift?
  # def time_shifted_patient(doc, vendor_id, bundle)
  #   # check for start date
  #   year_validator = MeasurePeriodValidator.new
  #   doc_start = year_validator.measure_period_start(doc)&.value
  #   # doc_end = validator.measure_period_end(doc).value -> should we validate end???
  #   return false, 'Document needs to report the Measurement Start Date' unless doc_start

  #   # import
  #   begin
  #     patient, _warnings, codes = QRDA::Cat1::PatientImporter.instance.parse_cat1(doc)

  #     # use all patient codes to build description map
  #     Cypress::QRDAPostProcessor.build_code_descriptions(codes, patient, bundle)

  #     # shift date
  #     utc_start = DateTime.parse(doc_start).to_time.utc
  #     bundle_utc_start = DateTime.strptime(bundle.measure_period_start.to_s, '%s').utc
  #     # Compare date alone, without time
  #     if utc_start.strftime('%x') != bundle_utc_start.strftime('%x')
  #       time_dif = bundle.measure_period_start - utc_start.to_i
  #       patient.qdmPatient.shift_dates(time_dif)
  #     end

  #     patient.update(_type: CQM::VendorPatient, correlation_id: vendor_id, bundleId: bundle.id)
  #     Cypress::QRDAPostProcessor.replace_negated_codes(patient, bundle)
  #     patient.save
  #     return [true, patient]
  #   rescue => e
  #     return [false, e.to_s]
  #   end
  # end

  def generate_calculations(patients, bundle, vendor_id)
    patient_ids = patients.map { |p| p.id.to_s }
    # TODO: remove hardcoding
    options = { 'includeHighlighting' => true, 'calculateHTML' => true,
                'measurementPeriodStart' => '2019-01-01', 'measurementPeriodEnd' => '2019-12-31' }
    tracker_index = 0
    # cqm-execution-service (using includeClauseResults) can run out of memory when it is run with a lot of patients.
    # 20 patients was selected after monitoring performance when experimenting with varying counts (from 1 to 100)
    # with all of the measures
    patients_per_calculation = 20
    # Total count is the number of patient slices - (total patients / patients_per_calculation) + 1
    # multiplied by the total number of measures.
    # For example, and upload of 115 patients for 5 measures would be 6 patient slices (101 / 20) + 1 = 6
    # multiplied by 5 measures for a total of 30.
    total_count = ((patient_ids.size / patients_per_calculation) + 1) * bundle.fhir_measure_bundles.size
    patient_ids.each_slice(patients_per_calculation) do |patient_ids_slice|
      bundle.fhir_measure_bundles.each do |measure|
        tracker.log("Calculating (#{((tracker_index.to_f / total_count) * 100).to_i}% complete) ")
        SingleMeasureCalculationJob.perform_now(patient_ids_slice, measure.id.to_s, vendor_id, options)
        tracker_index += 1
      end
    end
  end
end
