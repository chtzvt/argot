# frozen_string_literal: true

require "test_helper"

class TestArgot < Minitest::Test
  def setup
    @schema = File.read("./test/fixtures/schemas/01.yml")
    @passing_document = File.read("./test/fixtures/documents/01-pass.yml")
    @failing_document = File.read("./test/fixtures/documents/01-fail.yml")
    @malicious_document = File.read("./test/fixtures/documents/01-malicious.yml")
    Argot::Schema.register(:test_schema, @schema)
  end

  def test_schema_registration
    assert Argot::Schema.for(:test_schema).is_a?(Argot::Schema::Ruleset)
  end

  def test_that_loading_a_valid_document_yields_a_result
    rules = Argot::Schema.for(:test_schema)
    document = Argot::Validator.load(rules, @passing_document, symbolize_names: true)

    assert !document.nil?
  end

  def test_that_loading_an_invalid_document_yields_nil
    rules = Argot::Schema.for(:test_schema)
    document = Argot::Validator.load(rules, @failing_document, symbolize_names: true)

    assert document.nil?
  end

  def test_that_loading_an_invalid_document_yields_expected_error_annotations
    rules = Argot::Schema.for(:test_schema)
    handler = Argot::Validator.parse_and_validate(rules, @failing_document)

    assert handler.errors?

    error_messages = ["The value 'Farmr Charlton' is invalid for farmer_name",
      "The value 'goof' is invalid for farmer_level",
      "The value '' is invalid for meats.beef_from_usa.grade",
      "The value '9001' is invalid for good_number",
      "The key 'farm.goat_zone.pasture_uuid' is required, but missing."]

    assert handler.errors.all? { |e| error_messages.include?(e.message) }
  end

  def test_that_loading_a_malicious_document_raises_malicious_input
    rules = Argot::Schema.for(:test_schema)

    assert_raises Argot::MaliciousInput do
      Argot::Validator.load(rules, @malicious_document, symbolize_names: true, ignore_validation_errors: true)
    end
  end

  def test_that_annotations_are_comparable
    loc = {start_line: 1, end_line: 1, start_column: 1, end_column: 1}
    a1 = Argot::Annotation.new(level: Argot::Annotation::NOTICE, location: loc)
    a2 = Argot::Annotation.new(level: Argot::Annotation::WARNING, location: loc)
    a3 = Argot::Annotation.new(level: Argot::Annotation::FAILURE, location: loc)

    assert a3 > a2
    assert a2 > a1
    assert a1 < a3
  end

  def test_that_it_has_a_version_number
    refute_nil ::Argot::VERSION
  end
end
