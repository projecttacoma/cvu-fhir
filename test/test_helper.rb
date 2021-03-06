require 'simplecov'

# Mongo::Logger.logger.level = Logger::WARN
ENV['RAILS_ENV'] ||= 'test'
ENV['IGNORE_ROLES'] ||= 'false'
require File.expand_path('../config/environment', __dir__)
require 'rails/test_help'

require 'minitest/spec'
require 'minitest/autorun'
require 'minitest/reporters'
require 'mocha/minitest'

Minitest::Reporters.use! [Minitest::Reporters::SpecReporter.new]
# comment the previous line and uncomment the next one for test-by-test details
# Minitest::Reporters.use! [Minitest::Reporters::SpecReporter.new]

include Warden::Test::Helpers
Warden.test_mode!

Mongoid.logger.level = Logger::INFO

class ActiveSupport::TestCase
  def teardown
    drop_database
    # Not clearing the rails settings cache means that settings are left in an inconsistent state
    # when the database is dropped.
    Rails.cache.delete('settings')
  end

  def create_rack_test_file(filename, type)
    Rack::Test::UploadedFile.new(File.new(Rails.root.join(filename)), type)
  end

  def drop_database
    # purge the database instead of dropping it
    # because dropping it literally deletes the file
    # which then has to be recreated (which is slow)
    Mongoid::Config.purge!
    # Clear the mongo javascript functions between tests as well
    Mongoid.default_client['system.js'].delete_many({})
  end

  def drop_collection(collection)
    Mongoid.default_client[collection].drop
  end

  def arrays_equivalent(a1, a2)
    return true if a1 == a2
    return false unless a1 && a2 # either one is nil

    a1.count == a2.count && (a1 - a2).empty? && (a2 - a1).empty?
  end

  def get_document(input)
    content_str = case input
                  when File
                    input.read
                  when Nokogiri::XML::Document
                    return input
                  else
                    input
                  end

    document = Nokogiri::XML(content_str, &:strict)
    document.root.add_namespace_definition('cda', 'urn:hl7-org:v3')
    document.root.add_namespace_definition('sdtc', 'urn:hl7-org:sdtc')
    document
  end

  def value_or_bson(v)
    if v.is_a? Hash
      if v['$oid']
        BSON::ObjectId.from_string(v['$oid'])
      else
        map_bson_ids(v)
      end
    else
      v
    end
  end

  def map_array(arr)
    ret = []
    arr.each do |v|
      ret << value_or_bson(v)
    end
    ret
  end

  def map_bson_ids(json)
    json.each_pair do |k, v|
      if v.is_a? Hash
        json[k] = value_or_bson(v)
      elsif v.is_a? Array
        json[k] = map_array(v)
      elsif %w[create_at updated_at].include?(k)
        json[k] = Time.parse(v).in_time_zone
      end
    end
    json
  end

  def collection_fixtures(*collections)
    collections.each do |collection|
      Mongoid.default_client[collection].drop
      Dir.glob(Rails.root.join('test', 'fixtures', collection, '*.json')).each do |json_fixture_file|
        fixture_json = JSON.parse(File.read(json_fixture_file), max_nesting: 250)
        map_bson_ids(fixture_json)
        Mongoid.default_client[collection].insert_one(fixture_json)
      end
    end
  end

  def qdm_patient_for_attribute(dt, ta, src_qdm_patient)
    dt.reason = nil if ta[7] && dt.respond_to?(:reason)
    reset_datatype_fields(dt, ta)

    single_dt_qdm_patient = src_qdm_patient.clone
    single_dt_qdm_patient.dataElements << dt
    single_dt_qdm_patient
  end

  def reset_datatype_fields(dt, ta)
    dt.prescriberId = QDM::Identifier.new(namingSystem: '1.2.3.4', value: '1234') if dt.respond_to?(:prescriberId)
    dt.dispenserId = QDM::Identifier.new(namingSystem: '1.2.3.4', value: '1234') if dt.respond_to?(:dispenserId)

    dt.relevantDatetime = nil if dt.respond_to?(:relevantDatetime) && dt.respond_to?(:relevantPeriod) && ta[2] == 'relevantPeriod'
    dt.relevantPeriod = nil if dt.respond_to?(:relevantDatetime) && dt.respond_to?(:relevantPeriod) && ta[2] == 'relevantDatetime'
  end

  class ActionController::TestCase
    include Devise::Test::ControllerHelpers
    ADMIN = '4def93dd4f85cf8968000010'.freeze
    ATL = '4def93dd4f85cf8968000001'.freeze
    OWNER = '4def93dd4f85cf8968000002'.freeze
    USER = '4def93dd4f85cf8968000002'.freeze
    VENDOR = '4def93dd4f85cf8968000003'.freeze
    OTHER_VENDOR = '4def93dd4f85cf8968000004'.freeze

    EHR1 = '4f57a8791d41c851eb000002'.freeze
    EHR2 = '4f636aba1d41c851eb00048c'.freeze

    def add_user_to_vendor(user, vendor)
      test_params = { user: { email: user.email },
                      role: 'vendor',
                      assignments: { '1001' => { vendor_id: vendor.id.to_s,
                                                 role: 'vendor' } } }
      user.assign_roles_and_email(test_params)
      user.save
    end

    def for_each_logged_in_user(user_ids, &_block)
      User.find([user_ids]).each do |user|
        # this needs to be here to deal with the controller caching the CanCan ability
        # for the first user it sees during a test.  This is only a prblem during testing
        # using this method because in production a new controller is created for every request
        # During test a new controller is created per test, as this method makes multiple calls
        # with different logged in users we need to ensure that each has a fresh controller to
        # execute against to prevent CanCan Ability caching
        @controller = @controller.class.new
        @user = user
        sign_in user
        yield
        sign_out user
      end
    end
  end

  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  # fixtures :all

  # Add more helper methods to be used by all tests here...
end
