# GitStore Audit Trail Example

A Rails 8 application demonstrating versioned data storage with complete audit capabilities powered by GitStore.

## Features

- **Immutable audit trail** - Every change is a Git commit that can't be tampered with
- **Point-in-time reconstruction** - Reconstruct data state at any moment in history
- **Complete provenance** - Track who changed what, when, and why
- **Compliance ready** - Perfect for SOX, HIPAA, GDPR audit requirements
- **Cryptographic integrity** - Git SHA ensures data hasn't been altered

## Quick Start

```bash
# Create a new Rails 8 application
rails new audit_app --database=sqlite3 --css=tailwind

# Add git_store to Gemfile
echo "gem 'git_store', path: '../../../'" >> Gemfile

# Install dependencies
bundle install

# Copy the example files
cp -r app/* audit_app/app/
cp -r config/* audit_app/config/

# Initialize the audit repository
mkdir -p audit_app/audit_repo
cd audit_app/audit_repo && git init

# Run the application
cd audit_app && rails server
```

## Use Cases

### 1. Financial Transaction Auditing

```ruby
# Record a financial transaction with full audit trail
AuditedRecord.create(
  type: 'financial_transaction',
  id: 'txn_12345',
  data: {
    amount: 1000.00,
    currency: 'USD',
    from_account: 'ACC001',
    to_account: 'ACC002',
    description: 'Wire transfer'
  },
  author: current_user,
  message: 'Initiated wire transfer'
)

# Later, if we need to prove the transaction existed at a specific time
record = AuditedRecord.find('financial_transaction', 'txn_12345')
proof = record.existence_proof
# => { commit_id: 'abc123...', timestamp: '2024-01-15T10:30:00Z', ... }
```

### 2. Medical Record Management (HIPAA Compliance)

```ruby
# Store patient data with audit trail
AuditedRecord.create(
  type: 'patient_record',
  id: 'patient_001',
  data: {
    name: 'John Doe',
    dob: '1990-01-15',
    diagnoses: ['Type 2 Diabetes'],
    medications: ['Metformin 500mg']
  },
  author: current_user,
  message: 'Initial patient registration'
)

# Track who accessed the record
AuditService.log_access(
  record_type: 'patient_record',
  record_id: 'patient_001',
  user: current_user,
  action: 'view'
)

# Generate HIPAA audit report
report = AuditService.generate_report(
  record_type: 'patient_record',
  record_id: 'patient_001',
  from: 30.days.ago,
  to: Time.current
)
```

### 3. Document Version Control

```ruby
# Store a legal document
AuditedRecord.create(
  type: 'legal_document',
  id: 'contract_2024_001',
  data: {
    title: 'Service Agreement',
    version: '1.0',
    content: contract_text,
    parties: ['Company A', 'Company B']
  },
  author: current_user,
  message: 'Initial draft of service agreement'
)

# Get the complete revision history
record = AuditedRecord.find('legal_document', 'contract_2024_001')
record.revisions.each do |revision|
  puts "Version at #{revision.timestamp}: #{revision.message}"
  puts "Changed by: #{revision.author}"
end
```

## Compliance Features

### Tamper-Evident Storage

Every record is stored with a cryptographic hash (Git SHA). Any modification to historical data would change the hash, making tampering detectable.

```ruby
# Verify data integrity
record = AuditedRecord.find('financial_transaction', 'txn_12345')
record.verify_integrity!
# => true (data hasn't been tampered with)
```

### Point-in-Time Queries

Reconstruct the exact state of data at any historical moment:

```ruby
# What did this record look like last week?
record = AuditedRecord.find('patient_record', 'patient_001')
historical_state = record.state_at(1.week.ago)
```

### Audit Log Generation

```ruby
# Generate comprehensive audit log
log = AuditService.generate_log(
  from: 1.month.ago,
  to: Time.current,
  record_types: ['financial_transaction', 'patient_record'],
  format: :csv
)
```

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | /records | List all audited records |
| GET | /records/:type/:id | Get a specific record |
| POST | /records | Create a new record |
| PATCH | /records/:type/:id | Update a record |
| GET | /records/:type/:id/history | Full revision history |
| GET | /records/:type/:id/state_at | State at a point in time |
| GET | /records/:type/:id/proof | Existence proof for compliance |
| GET | /audit_logs | Search audit logs |
| GET | /audit_logs/report | Generate audit report |

## Security Considerations

1. **Repository Protection** - The audit repository should be protected with restricted access
2. **Backup Strategy** - Regular backups of the Git repository ensure durability
3. **Key Management** - Consider signing commits for additional integrity
4. **Access Logging** - All API access should be logged separately
