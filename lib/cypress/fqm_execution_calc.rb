module Cypress
  class FqmExecutionCalc
    attr_accessor :patients, :measures, :options

    # patients: An array of patient_bundles
    # measures: An array of measure_bundles
    # correlation_id: An Id that can be used to group calculations
    # options to pass into calculateMeasureReports service e.g., ({ 'includeHighlighting' => true, 'calculateHTML' => true })
    def initialize(patient_bundles, measure_bundles, correlation_id, options)
      @measures = measure_bundles
      @patients = patient_bundles
      @correlation_id = correlation_id
      @options = options
      @fqm_patient_mapping = patients.map { |patient| [patient.patient_fhir_id, patient.id] }.to_h
    end

    def execute(save = true)
      results = @measures.map do |measure|
        request_for(measure, save)
      end.flatten
      results
    end

    def request_for(measure, _save = true)
      post_data = { patients: @patients.map(&:patient_bundle_hash), measure: measure.measure_bundle_hash, options: @options }
      post_data = post_data.to_json(methods: %i[_type])
      begin
        response = RestClient::Request.execute(method: :post, url: self.class.create_connection_string, timeout: 120,
                                               payload: post_data, headers: { content_type: 'application/json' })
      rescue => e
        raise e.to_s || 'Calculation failed without an error message'
      end
      results = JSON.parse(response)

      patient_result_hash = {}
      results.each do |result|
        patient_id = result.subject.reference.split('Patient/')[1]
        pmr = PatientMeasureReport.create(measure_report_hash: result, patient_id: @fqm_patient_mapping[patient_id], measure_id: measure.id)
        patient_result_hash[patient_id] = pmr.measure_report
      end
      patient_result_hash.values
    end

    def self.create_connection_string
      config = Rails.application.config
      "http://#{config.fqm_host}:#{config.fqm_port}/calculateMeasureReports"
    end

    private

    def timeout
      @options[:timeout] || 60
    end
  end
end
