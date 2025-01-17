require 'csv'

class Event < ApplicationRecord
  # Event::Generic is used to log generic types of events, such as sign in attempts
  class Generic
    # `1` is used as an id for Generic events
  end

  # Extend this list with all First Class event types to be logged TP-
  @@names = {
    organization_manager_changed: 'organization_manager_changed', # Legacy event
    user_deactivated: 'user_deactivated',
    user_deleted: 'user_deleted',
    user_update: 'user_update',
    user_authentication_attempt: 'user_authentication_attempt',
    user_authentication_successful: 'user_authentication_successful',
    user_authentication_failure: 'user_authentication_failure',
    user_send_invitation: 'user_send_invitation',

    touchpoint_archived: 'touchpoint_archived',
    touchpoint_form_submitted: 'touchpoint_form_submitted',
    touchpoint_published: 'touchpoint_published',

    form_archived: 'form_archived',
    form_submitted: 'form_submitted',
    form_published: 'form_published',
    form_copied: 'form_copied',
    form_deleted: 'form_deleted',

    response_flagged: 'response_flagged',
    response_unflagged: 'response_unflagged',
    response_deleted: 'response_deleted'
  }

  def self.log_event(ename, otype, oid, desc, uid = nil)
    e = self.new
    e.name = ename
    e.object_type = otype
    e.object_id = oid
    e.description = desc
    e.user_id = uid
    e.save
  end

  def self.names
    @@names
  end

  def self.valid_events
    @@names.values
  end

  def self.to_csv
    attributes = [
      :name,
      :object_type,
      :object_id,
      :description,
      :user_id,
      :created_at,
      :updated_at
    ]

    CSV.generate(headers: true) do |csv|
      csv << attributes

      Event.all.each do |event|
        csv << attributes.map { |attr| event.send(attr) }
      end
    end
  end
end
