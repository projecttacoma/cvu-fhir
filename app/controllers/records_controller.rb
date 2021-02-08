class RecordsController < ApplicationController
  include RecordsHelper
  before_action :set_record_source, only: %i[index show]

  respond_to :js, only: [:index]

  def index
    unless Bundle.default
      @patients = []
      @measures = []
      add_breadcrumb 'Master Patient List', :records

      return
    end

    return redirect_to bundle_records_path(Bundle.default) unless params[:bundle_id] || params[:vendor_id]

    # create json with the display_name and url for each measure
    @measure_dropdown = measures_for_source
    if @vendor
      @patients = @vendor.fhir_patient_bundles.where(bundle: @bundle.id)
    else
      @patients = @source.fhir_patient_bundles.order_by(first: 'asc')
      @mpl_bundle = Bundle.find(params[:mpl_bundle_id]) if params[:mpl_bundle_id]
    end
  end

  def show
    @record = @source.fhir_patient_bundles.find(params[:id])
    # TODO: Filter results by patient and measures.
    patient_measure_reports = PatientMeasureReport.where(patient_id: @record.id)
    @results = patient_measure_reports.map(&:measure_report)
    @measures = MeasureBundle.find(patient_measure_reports.map(&:measure_id))
    @relevant_entries = if params[:measure_id]
                          patient_measure_report = patient_measure_reports.select { |pmr| pmr.measure_id.to_s == params[:measure_id] }.first
                          @record.relevant_entries_for_measure_report(patient_measure_report)
                        else
                          @record.patient.entry
                        end
    # @measures = (@vendor ? @bundle : @source).measures.where(:_id.in => @results.map(&:measure_id))
    # @hqmf_id = params[:hqmf_id]
    # @continuous_measures = @measures.where(measure_scoring: 'CONTINUOUS_VARIABLE').sort_by { |m| [m.cms_int] }
    # @proportion_measures = @measures.where(measure_scoring: 'PROPORTION').sort_by { |m| [m.cms_int] }
    # @result_measures = @measures.where(hqmf_set_id: { '$in': APP_CONSTANTS['result_measures'].map(&:hqmf_set_id) }).sort_by { |m| [m.cms_int] }
    expires_in 1.week, public: true
    add_breadcrumb 'Patient: ' + @record.givenNames.join(' ') + ' ' + @record.familyName, :record_path
  end

  # TODO: This will need to be update for FHIR Patient
  # def by_measure
  #   @patients = @vendor.patients.includes(:calculation_results).where(bundleId: @bundle.id.to_s) if @vendor
  #   @patients ||= @source.patients.includes(:calculation_results)

  #   if params[:measure_id]
  #     measures = @vendor ? @bundle.measures : @source.measures
  #     @measure = measures.find_by(hqmf_id: params[:measure_id])
  #     @population_set_hash = params[:population_set_hash] || @measure.population_sets_and_stratifications_for_measure.first
  #     expires_in 1.week, public: true
  #   end
  # end

  def download_mpl
    if BSON::ObjectId.legal?(params[:format])
      bundle = Bundle.find(BSON::ObjectId.from_string(params[:format]))

      if bundle.mpl_status != :ready
        flash[:info] = 'This bundle is currently preparing for download.'
        redirect_to :back
      else
        file = File.new(bundle.mpl_path)
        expires_in 1.month, public: true
        send_data file.read, type: 'application/zip', disposition: 'attachment', filename: "bundle_#{bundle.version}_mpl.zip"
      end
    else
      render body: nil, status: :bad_request
    end
  end

  private

  # note: case vendor will also have a bundle id
  def set_record_source
    if params[:vendor_id]
      set_record_source_vendor
    else
      set_record_source_bundle
    end
  end

  # sets the record source to bundle for the master patient list
  def set_record_source_bundle
    # TODO: figure out what scenarios lead to no params[:bundle_id] here
    @source = @bundle = params[:bundle_id] ? Bundle.available.find(params[:bundle_id]) : Bundle.default
    return unless @bundle

    add_breadcrumb 'Master Patient List', bundle_records_path(@bundle)
    @title = 'Master Patient List'
  end

  def set_record_source_vendor
    @bundle = params[:bundle_id] ? Bundle.available.find(params[:bundle_id]) : Bundle.default
    @vendor = Vendor.find(params[:vendor_id])
    @source = @vendor
    breadcrumbs_for_vendor_path
    @title = "#{@vendor.name} Uploaded Patients"
  end

  def breadcrumbs_for_vendor_path
    add_breadcrumb 'Dashboard', :vendors_path
    add_breadcrumb 'Vendor: ' + @vendor.name, vendor_path(@vendor)
    add_breadcrumb 'Patient List', vendor_records_path(vendor_id: @vendor.id, bundle_id: @bundle&.id)
  end

  def measures_for_source
    Rails.cache.fetch("#{@source.cache_key}/measure_dropdown") do
      if @vendor
        @bundle.fhir_measure_bundles.order_by(name: 1).map do |m|
          { label: m.name,
            value: by_measure_vendor_records_path(@vendor, measure_id: m.id, bundle_id: @bundle.id) }
        end
      else
        @source.fhir_measure_bundles.order_by(name: 1).map do |m|
          { label: m.name,
            value: by_measure_bundle_records_path(@bundle, measure_id: m.id) }
        end
      end.to_json.html_safe
    end
  end
end
