require 'csv'

class Form < ApplicationRecord
  include AASM

  belongs_to :user
  belongs_to :organization

  has_many :form_sections, dependent: :delete_all
  has_many :questions, dependent: :destroy
  has_many :submissions

  has_many :user_roles, dependent: :destroy
  has_many :users, through: :user_roles, primary_key: :form_id

  validates :name, presence: true
  validates_length_of :disclaimer_text, in: 0..500, allow_blank: true
  validates :delivery_method, presence: true
  validates :anticipated_delivery_count, numericality: true, allow_nil: true
  validate :omb_number_with_expiration_date
  validate :target_for_delivery_method
  validate :ensure_modal_text

  before_create :set_uuid
  before_destroy :ensure_no_responses

  scope :non_templates, -> { where(template: false) }
  scope :templates, -> { where(template: true) }

  mount_uploader :logo, LogoUploader

  def target_for_delivery_method
    if self.delivery_method == "custom-button-modal" || self.delivery_method == "inline"
      if self.element_selector == ""
        errors.add(:element_selector, "can't be blank for an inline form")
      end
    end
  end

  def ensure_modal_text
    if self.delivery_method == "modal"
      if self.modal_button_text.empty?
        errors.add(:modal_button_text, "can't be blank for an modal form")
      end
    end
  end

  def ensure_no_responses
    if submissions.count > 0
      errors.add(:response_count_error, "This form cannot be deleted because it has responses")
      throw(:abort)
    end
  end

  after_create :create_first_form_section

  after_commit do |form|
    FormCache.invalidate(form.short_uuid)
  end

  DELIVERY_METHODS = [
    ["touchpoints-hosted-only", "Hosted only on the Touchpoints site"],
    ["modal", "Tab button & modal"],
    ["custom-button-modal", "Custom button & modal"],
    ["inline", "Embedded inline on your site"]
  ]


  def suppress_submit_button
    self.questions.collect(&:question_type).include?("yes_no_buttons") || self.questions.collect(&:question_type).include?("custom_text_display")
  end

  def self.find_by_short_uuid(short_uuid)
    return nil unless short_uuid && short_uuid.length == 8
    where("uuid LIKE ?", "#{short_uuid}%").first
  end

  def self.find_by_legacy_touchpoints_id(id)
    return nil unless id && id.length < 4
    where(legacy_touchpoint_id: id).first
  end

  def self.find_by_legacy_touchpoints_uuid(short_uuid)
    return nil unless short_uuid && short_uuid.length == 8
    where("legacy_touchpoint_uuid LIKE ?", "#{short_uuid}%").first
  end

  def to_param
    short_uuid
  end

  def short_uuid
    uuid[0..7]
  end

  def send_notifications?
    self.notification_emails.present?
  end

  def create_first_form_section
    self.form_sections.create(title: (I18n.t 'form.page_1'), position: 1)
  end

  # def to_param
  #   short_uuid
  # end

  def short_uuid
    uuid[0..7]
  end


  aasm do
    state :in_development, initial: true
    state :ready_to_submit_to_PRA # manual
    state :submitted_to_PRA # manual
    state :PRA_approved # manual - adding OMB Numbers
    state :PRA_denied # manual
    state :live # manual
    state :archived # after End Date, or manual

    event :develop do
      transitions from: [:ready_to_submit_to_PRA, :submitted_to_PRA, :PRA_approved, :PRA_denied, :live, :archived], to: :in_development
    end
    event :ready_to_submit do
      transitions from: [:in_development, :submitted_to_PRA, :PRA_approved, :PRA_denied, :live, :archived], to: :ready_to_submit_to_PRA
    end
    event :submit do
      transitions from: [:in_development, :ready_to_submit_to_PRA, :PRA_approved, :PRA_denied, :live, :archived], to: :submitted_to_PRA
    end
    event :approve do
      transitions from: [:in_development, :ready_to_submit_to_PRA, :submitted_to_PRA, :PRA_denied, :live, :archived], to: :PRA_approved
    end
    event :deny do
      transitions from: [:in_development, :ready_to_submit_to_PRA, :submitted_to_PRA, :PRA_approved, :live, :archived], to: :PRA_denied
    end
    event :publish do
      transitions from: [:in_development, :ready_to_submit_to_PRA, :submitted_to_PRA, :PRA_approved, :PRA_denied, :archived], to: :live
    end
    event :archive do
      transitions from: [:in_development, :ready_to_submit_to_PRA, :submitted_to_PRA, :PRA_approved, :PRA_denied, :live], to: :archived
    end
  end

  def transitionable_states
    self.aasm.states(permitted: true)
  end

  def all_states
    self.aasm.states
  end

  def duplicate!(user:)
    new_form = self.dup
    new_form.name = "Copy of #{self.name}"
    new_form.title = new_form.name
    new_form.survey_form_activations = 0
    new_form.response_count = 0
    new_form.last_response_created_at = nil
    new_form.aasm_state = :in_development
    new_form.uuid = nil
    new_form.legacy_touchpoint_id = nil
    new_form.legacy_touchpoint_uuid = nil
    new_form.template = false
    new_form.user = user
    new_form.save

    # Manually remove the Form Section created with create_first_form_section
    new_form.form_sections.destroy_all

    # Loop Form Sections to create them for new_form
    self.form_sections.each do |section|
      new_form_section = section.dup
      new_form_section.form = new_form
      new_form_section.save

      # Loop Questions to create them for new_form and new_form_sections
      section.questions.each do |question|
        new_question = question.dup
        new_question.form = new_form
        new_question.form_section = new_form_section
        new_question.save

        # Loop Questions to create them for Questions
        question.question_options.each do |option|
          new_question_option = option.dup
          new_question_option.question = new_question
          new_question_option.save
        end
      end
    end

    return new_form
  end

  def check_expired
    if !self.archived? and self.expiration_date.present? and self.expiration_date <= Date.today
      self.id ? self.archive! : self.archive
      Event.log_event(Event.names[:form_archived], "Touchpoint",self.id, "Touchpoint #{self.name} archived on #{Date.today}") if self.id
    end
  end

  def set_uuid
    self.uuid = SecureRandom.uuid  if !self.uuid.present?
  end

  def deployable_form?
    self.live?
  end

  # returns javascript text that can be used standalone
  # or injected into a GTM Container Tag
  def touchpoints_js_string
    ApplicationController.new.render_to_string(partial: "components/widget/fba.js", locals: { touchpoint: self })
  end

  def to_csv(start_date: nil, end_date: nil)
    non_flagged_submissions = self.submissions.non_flagged.where("created_at >= ?", start_date).where("created_at <= ?", end_date).order("created_at")
    return nil unless non_flagged_submissions.present?

    header_attributes = self.hashed_fields_for_export.values
    attributes = self.fields_for_export

    CSV.generate(headers: true) do |csv|
      csv << header_attributes

      non_flagged_submissions.each do |submission|
        csv << attributes.map { |attr| submission.send(attr) }
      end
    end
  end

  def user_role?(user:)
    role = self.user_roles.find_by_user_id(user.id)
    role.present? ? role.role : nil
  end

  # TODO: Refactor into a Report class

  # Generates 1 of 2 exported files for the A11
  # This is a one record metadata file
  def to_a11_header_csv(start_date:, end_date:)
    non_flagged_submissions = self.submissions.non_flagged.where("created_at >= ?", start_date).where("created_at <= ?", end_date)
    return nil unless non_flagged_submissions.present?

    header_attributes = [
      "submission comment",
      "survey_instrument_reference",
      "agency_poc_name",
      "agency_poc_email",
      "department",
      "bureau",
      "service",
      "transaction_point",
      "mode",
      "start_date",
      "end_date",
      "total_volume",
      "survey_opp_volume",
      "response_count",
      "OMB_control_number",
      "federal_register_url"
    ]

    CSV.generate(headers: true) do |csv|
      submission = non_flagged_submissions.first
      csv << header_attributes
      csv << [
        submission.form.data_submission_comment,
        submission.form.survey_instrument_reference,
        submission.form.agency_poc_name,
        submission.form.agency_poc_email,
        submission.form.department,
        submission.form.bureau,
        submission.form.service_name,
        submission.form.name,
        submission.form.medium,
        start_date,
        end_date,
        submission.form.anticipated_delivery_count,
        submission.form.survey_form_activations,
        non_flagged_submissions.length,
        submission.form.omb_approval_number,
        submission.form.federal_register_url,
      ]
    end
  end

  # Generates the 2nd of 2 exported files for the A11
  # This is a 7 record detail file; one for each question
  def to_a11_submissions_csv(start_date:, end_date:)
    non_flagged_submissions = self.submissions.non_flagged.where("created_at >= ?", start_date).where("created_at <= ?", end_date)
    return nil unless non_flagged_submissions.present?

    header_attributes = [
      "standardized_question_number",
      "standardized_question_identifier",
      "customized_question_text",
      "likert_scale_1",
      "likert_scale_2",
      "likert_scale_3",
      "likert_scale_4",
      "likert_scale_5",
      "response_volume",
      "notes",
      "start_date",
      "end_date"
    ]

    @hash = {
      answer_01: Hash.new(0),
      answer_02: Hash.new(0),
      answer_03: Hash.new(0),
      answer_04: Hash.new(0),
      answer_05: Hash.new(0),
      answer_06: Hash.new(0),
      answer_07: Hash.new(0)
    }

    # Aggregate likert scale responses
    non_flagged_submissions.each do |submission|
      @hash.keys.each do |field|
        response = submission.send(field)
        if response.present?
          @hash[field][submission.send(field)] += 1
        end
      end
    end

    # TODO: Needs work
    CSV.generate(headers: true) do |csv|
      csv << header_attributes

      @hash.each_pair do |key, values|
        @question_text = "123"
        if key == :answer_01
          question = questions.where(answer_field: key).first
          response_volume = values.values.collect { |v| v.to_i }.sum
          @question_text = question.text
          standardized_question_number = 1
        elsif key == :answer_02
          question = questions.where(answer_field: key).first
          response_volume = values.values.collect { |v| v.to_i }.sum
          @question_text = question.text
          standardized_question_number = 2
        elsif key == :answer_03
          question = questions.where(answer_field: key).first
          response_volume = values.values.collect { |v| v.to_i }.sum
          @question_text = question.text
          standardized_question_number = 3
        elsif key == :answer_04
          question = questions.where(answer_field: key).first
          response_volume = values.values.collect { |v| v.to_i }.sum
          @question_text = question.text
          standardized_question_number = 4
        elsif key == :answer_05
          question = questions.where(answer_field: key).first
          response_volume = values.values.collect { |v| v.to_i }.sum
          @question_text = question.text
          standardized_question_number = 5
        elsif key == :answer_06
          question = questions.where(answer_field: key).first
          response_volume = values.values.collect { |v| v.to_i }.sum
          @question_text = question.text
          standardized_question_number = 6
        elsif key == :answer_07
          question = questions.where(answer_field: key).first
          response_volume = values.values.collect { |v| v.to_i }.sum
          @question_text = question.text
          standardized_question_number = 7
        end

        csv << [
          standardized_question_number,
          key,
          @question_text,
          values["1"],
          values["2"],
          values["3"],
          values["4"],
          values["5"],
          response_volume,
          "", # Empty field for the user to enter their own notes
          start_date,
          end_date
        ]
      end

    end
  end

  def fields_for_export
    self.hashed_fields_for_export.keys
  end

  # TODO: Move to /models/submission.rb
  def hashed_fields_for_export
    hash = {}

    self.ordered_questions.map { |q| hash[q.answer_field] = q.text }

    hash.merge!({
      location_code: "Location Code",
      user_agent: "User Agent",
      page: "Page",
      referer: "Referrer",
      created_at: "Created At"
    })

    if self.organization.enable_ip_address?
      hash.merge!({
        ip_address: "IP Address"
      })
    end

    hash
  end

  def ordered_questions
    array = []
    self.form_sections.each do |section|
      array.concat(section.questions.ordered.entries)
    end
    array
  end

  def omb_number_with_expiration_date
    if omb_approval_number.present? && !expiration_date.present?
      errors.add(:expiration_date, "required with an OMB Number")
    end
    if expiration_date.present? && !omb_approval_number.present?
      errors.add(:omb_approval_number, "required with an Expiration Date")
    end
  end

  def completion_rate
    if self.survey_form_activations == 0
      "N/A"
    else
      "#{((self.response_count / self.survey_form_activations.to_f) * 100).round(0)}%"
    end
  end

  def average_answer(answer)
    responses = self.submissions.collect(&answer)
    responses = responses.reject { |string| !string.present? }
    responses = responses.map { |string| string.to_i }
    response_total = responses.sum
    average = response_total / response_count.to_f
    {
      response_total: response_total,
      response_count: response_count,
      average: average.round(3)
    }
  end

end
