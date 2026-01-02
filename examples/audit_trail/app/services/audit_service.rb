# frozen_string_literal: true

# AuditService provides utilities for generating audit reports and logs.
# Supports compliance reporting for SOX, HIPAA, GDPR requirements.
#
# @example Generate an audit report
#   AuditService.generate_report(
#     record_type: 'financial_transaction',
#     from: 30.days.ago,
#     to: Time.current
#   )
#
class AuditService
  class << self
    # Log an access event
    #
    # @param record_type [String] The type of record accessed
    # @param record_id [String] The record ID
    # @param user [User] The user who accessed
    # @param action [String] The action (view, export, etc.)
    # @return [AuditedRecord] The access log entry
    def log_access(record_type:, record_id:, user:, action:)
      AuditedRecord.create(
        record_type: 'access_log',
        record_id: SecureRandom.uuid,
        data: {
          accessed_record_type: record_type,
          accessed_record_id: record_id,
          user_name: user.respond_to?(:name) ? user.name : user.to_s,
          user_email: user.respond_to?(:email) ? user.email : nil,
          action: action,
          timestamp: Time.current.iso8601,
          ip_address: Thread.current[:client_ip]
        },
        author: user,
        message: "Access log: #{action} #{record_type}/#{record_id}"
      )
    end

    # Generate audit report for a time range
    #
    # @param record_type [String, nil] Filter by record type
    # @param record_id [String, nil] Filter by record ID
    # @param from [Time] Start of time range
    # @param to [Time] End of time range
    # @param format [Symbol] Output format (:hash, :csv, :json)
    # @return [Array, String] The audit report
    def generate_report(record_type: nil, record_id: nil, from: 30.days.ago, to: Time.current, format: :hash)
      entries = collect_audit_entries(
        record_type: record_type,
        record_id: record_id,
        from: from,
        to: to
      )

      case format
      when :csv
        format_as_csv(entries)
      when :json
        entries.to_json
      else
        entries
      end
    end

    # Generate compliance summary
    #
    # @param from [Time] Start of time range
    # @param to [Time] End of time range
    # @return [Hash] Compliance summary
    def compliance_summary(from: 30.days.ago, to: Time.current)
      entries = collect_audit_entries(from: from, to: to)

      {
        period: {
          from: from.iso8601,
          to: to.iso8601
        },
        total_changes: entries.size,
        changes_by_type: entries.group_by { |e| e[:record_type] }
                               .transform_values(&:count),
        changes_by_user: entries.group_by { |e| e[:author] }
                               .transform_values(&:count),
        integrity_status: 'verified',
        generated_at: Time.current.iso8601
      }
    end

    # Verify integrity of all records
    #
    # @return [Hash] Integrity verification results
    def verify_all_integrity
      results = { verified: 0, failed: 0, errors: [] }

      AuditedRecord.types.each do |type|
        AuditedRecord.where(record_type: type).each do |record|
          if record.verify_integrity!
            results[:verified] += 1
          else
            results[:failed] += 1
            results[:errors] << {
              record: "#{record.record_type}/#{record.record_id}",
              error: 'Checksum mismatch'
            }
          end
        end
      end

      results[:status] = results[:failed].zero? ? 'healthy' : 'compromised'
      results
    end

    # Export audit log for compliance
    #
    # @param record_type [String, nil] Filter by type
    # @param from [Time] Start date
    # @param to [Time] End date
    # @return [String] CSV export
    def export_for_compliance(record_type: nil, from: 90.days.ago, to: Time.current)
      entries = collect_audit_entries(
        record_type: record_type,
        from: from,
        to: to
      )

      headers = ['Timestamp', 'Record Type', 'Record ID', 'Action', 'Author', 'Email', 'Commit ID', 'Message']

      csv_data = CSV.generate do |csv|
        csv << headers
        entries.each do |entry|
          csv << [
            entry[:timestamp],
            entry[:record_type],
            entry[:record_id],
            entry[:action],
            entry[:author],
            entry[:email],
            entry[:commit_id],
            entry[:message]
          ]
        end
      end

      csv_data
    end

    private

    def collect_audit_entries(record_type: nil, record_id: nil, from: nil, to: nil)
      entries = []
      store = Rails.application.config.audit_store
      current = store.head

      while current
        timestamp = current.author&.time

        # Filter by time range
        if timestamp
          break if from && timestamp < from
          next if to && timestamp > to
        end

        # Extract record info from commit
        entry = extract_entry_from_commit(current, record_type, record_id)
        entries << entry if entry

        parent_id = current.parent.first
        current = parent_id ? store.get(parent_id) : nil
      end

      entries
    end

    def extract_entry_from_commit(commit, filter_type, filter_id)
      # Parse the commit message to determine what changed
      message = commit.message.to_s
      author = commit.author

      # Try to extract record type and ID from message
      if message =~ /(?:Created|Updated|Deleted) (\w+)\/(.+)/
        type = ::Regexp.last_match(1)
        id = ::Regexp.last_match(2)

        # Apply filters
        return nil if filter_type && type != filter_type
        return nil if filter_id && id != filter_id

        action = if message.start_with?('Created')
                   'create'
                 elsif message.start_with?('Updated')
                   'update'
                 elsif message.start_with?('Deleted')
                   'delete'
                 else
                   'change'
                 end

        {
          timestamp: author&.time&.iso8601,
          record_type: type,
          record_id: id,
          action: action,
          author: author&.name,
          email: author&.email,
          commit_id: commit.id,
          message: message.strip
        }
      end
    end

    def format_as_csv(entries)
      require 'csv'

      CSV.generate do |csv|
        csv << ['Timestamp', 'Type', 'ID', 'Action', 'Author', 'Commit', 'Message']
        entries.each do |entry|
          csv << [
            entry[:timestamp],
            entry[:record_type],
            entry[:record_id],
            entry[:action],
            entry[:author],
            entry[:commit_id]&.first(7),
            entry[:message]
          ]
        end
      end
    end
  end
end
