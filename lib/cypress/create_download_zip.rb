module Cypress
  class CreateDownloadZip
    def self.create_validation_report_zip(_vendor, options)
      file = Tempfile.new("combined-report-#{Time.now.to_i}")
      Zip::ZipOutputStream.open(file.path) do |z|
        add_file_to_zip(z, 'product_report.html', options[:report_content])

        # TODO: Do we do anything by patient?
        # vendor.fhir_patient_bundles.each do |p|
        #   folder_name = "#{m._type.underscore.dasherize}s/#{m.cms_id}#{filter_folder}"

        #   add_file_to_zip(z, "#{folder_name}/records/#{m.cms_id}_#{m.id}.qrda.zip", m.patient_archive.read) unless m.is_a?(CMSProgramTest)
        # end
      end
      file
    end

    def self.add_file_to_zip(z, file_name, file_content)
      z.put_next_entry(file_name)
      z << file_content
    end
  end
end
