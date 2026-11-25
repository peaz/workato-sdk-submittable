{
  title: 'Submittable',
  subtitle: 'Read submissions and submitters from Submittable',
  help: lambda do |_input, _picklist_label|
    {
      body: 'Connects to the Submittable API v4. Create an API key in Submittable ' \
            '(Settings > Integrations > API) and paste it below.',
      learn_more_url: 'https://submittable-api.submittable.com/docs/v4/index.html',
      learn_more_text: 'Submittable API documentation'
    }
  end,

  connection: {
    fields: [
      {
        name: 'api_key',
        label: 'API key',
        optional: false,
        control_type: 'password',
        hint: 'Submittable API key provisioned for your organization.'
      }
    ],

    authorization: {
      type: 'custom_auth',
      apply: lambda do |connection|
        headers('Authorization' => "Basic #{"#{connection['api_key']}:".encode_base64}")
      end
    },

    # Trailing slash + paths WITHOUT a leading slash keeps the /v4 prefix.
    base_uri: lambda do |_connection|
      'https://submittable-api.submittable.com/v4/'
    end
  },

  test: lambda do |_connection|
    get('submissions?size=1')
  end,

  methods: {
    # Builds a query string. Array values are sent as repeated keys
    # (Statuses.Include=a&Statuses.Include=b), which is what the API expects.
    build_query: lambda do |params|
      params.compact.map do |key, value|
        values = value.is_a?(Array) ? value : [value]
        values.reject { |v| v.blank? && v != false }.map do |v|
          "#{key}=#{v.to_s.encode_url}"
        end
      end.flatten.join('&')
    end,

    # Turns a comma separated string (multiselect / text toggle) into an array.
    csv_to_array: lambda do |value|
      return nil if value.blank?

      value.to_s.split(',').map(&:strip).reject(&:blank?)
    end,

    # Maps the Search / trigger inputs onto Submittable query parameters.
    # Filters are only honoured on the first request; later pages use only
    # the continuation token.
    submission_query_params: lambda do |input|
      {
        'size' => input['size'],
        'Search' => input['search'],
        'Statuses.Include' => call('csv_to_array', input['statuses_include']),
        'Statuses.Exclude' => call('csv_to_array', input['statuses_exclude']),
        'Projects.Include' => call('csv_to_array', input['project_ids_include']),
        'Projects.Exclude' => call('csv_to_array', input['project_ids_exclude']),
        'Labels.IncludeAny' => call('csv_to_array', input['label_ids_include_any']),
        'ArchivedStatus' => input['archived_status'],
        'DateFrom' => input['date_from'].present? ? input['date_from'].to_time.utc.iso8601 : nil,
        'DateTo' => input['date_to'].present? ? input['date_to'].to_time.utc.iso8601 : nil,
        'SortBy.Field' => input['sort_field'],
        'SortBy.Order' => input['sort_order']
      }
    end
  },

  object_definitions: {
    label: {
      fields: lambda do |_connection, _config_fields, _object_definitions|
        [
          { name: 'labelId', label: 'Label ID' },
          { name: 'name', label: 'Name' },
          { name: 'backgroundColor', label: 'Background color' },
          { name: 'foregroundColor', label: 'Foreground color' }
        ]
      end
    },

    # One row of GET /submissions (list endpoint).
    submission_list_item: {
      fields: lambda do |_connection, _config_fields, _object_definitions|
        [
          { name: 'submissionId', label: 'Submission ID' },
          { name: 'projectId', label: 'Project ID' },
          { name: 'submitterId', label: 'Submitter ID' },
          { name: 'reviewStageId', label: 'Review stage ID' },
          { name: 'submissionStatus', label: 'Submission status' },
          { name: 'isArchived', label: 'Is archived', type: 'boolean' },
          { name: 'isPaid', label: 'Is paid', type: 'boolean' },
          { name: 'labels', label: 'Labels', type: 'array', of: 'string' },
          { name: 'reviewers', label: 'Reviewers', type: 'array', of: 'string' },
          { name: 'submitterFirstName', label: 'Submitter first name' },
          { name: 'submitterLastName', label: 'Submitter last name' },
          { name: 'submitterEmail', label: 'Submitter email', control_type: 'email' },
          { name: 'submitterLastLoginDate', label: 'Submitter last login date', type: 'date_time' },
          { name: 'submissionTitle', label: 'Submission title' },
          { name: 'projectTitle', label: 'Project title' },
          { name: 'submissionDate', label: 'Submission date', type: 'date_time' },
          { name: 'isConcealed', label: 'Is concealed', type: 'boolean' },
          { name: 'isInitialFormEntryEditable', label: 'Is initial form entry editable', type: 'boolean' },
          { name: 'publicOrgId', label: 'Public organization ID' },
          { name: 'publicOrgVersion', label: 'Public organization version', type: 'integer' },
          { name: 'publicOrgName', label: 'Public organization name' },
          { name: 'concealPublicOrgName', label: 'Conceal public organization name', type: 'boolean' }
        ]
      end
    },

    # Result of GET /submissions/{submissionId}.
    submission: {
      fields: lambda do |_connection, _config_fields, object_definitions|
        [
          { name: 'submissionId', label: 'Submission ID' },
          { name: 'projectId', label: 'Project ID' },
          { name: 'submitterId', label: 'Submitter ID' },
          { name: 'submissionStatus', label: 'Submission status' },
          { name: 'isArchivedBySubmitter', label: 'Is archived by submitter', type: 'boolean' },
          { name: 'isArchivedByOrganization', label: 'Is archived by organization', type: 'boolean' },
          { name: 'isPaid', label: 'Is paid', type: 'boolean' },
          {
            name: 'formEntries',
            label: 'Form entries',
            type: 'array',
            of: 'object',
            properties: [
              { name: 'formType', label: 'Form type' },
              {
                name: 'entry',
                label: 'Entry',
                type: 'object',
                properties: [
                  { name: 'entryId', label: 'Entry ID' },
                  { name: 'formId', label: 'Form ID' },
                  { name: 'submissionId', label: 'Submission ID' },
                  { name: 'projectId', label: 'Project ID' },
                  { name: 'status', label: 'Status' },
                  { name: 'completedAt', label: 'Completed at', type: 'date_time' },
                  { name: 'createdBy', label: 'Created by' },
                  { name: 'createdAt', label: 'Created at', type: 'date_time' },
                  { name: 'openedForEditingAt', label: 'Opened for editing at', type: 'date_time' },
                  { name: 'score', label: 'Score', type: 'number' }
                ]
              }
            ]
          },
          { name: 'labels', label: 'Labels', type: 'array', of: 'object',
            properties: object_definitions['label'] },
          { name: 'reviewStageId', label: 'Review stage ID' },
          { name: 'publicOrgId', label: 'Public organization ID' },
          { name: 'publicOrgVersion', label: 'Public organization version', type: 'integer' },
          { name: 'publicOrgName', label: 'Public organization name' },
          { name: 'submissionTitle', label: 'Submission title' }
        ]
      end
    },

    address: {
      fields: lambda do |_connection, _config_fields, _object_definitions|
        [
          { name: 'id', label: 'Address ID', type: 'integer' },
          { name: 'addressTypeId', label: 'Address type ID', type: 'integer' },
          { name: 'address1', label: 'Address line 1' },
          { name: 'address2', label: 'Address line 2' },
          { name: 'city', label: 'City' },
          { name: 'stateId', label: 'State ID' },
          { name: 'zipCode', label: 'Zip code' },
          { name: 'country', label: 'Country' },
          { name: 'phone', label: 'Phone' },
          { name: 'region', label: 'Region' },
          { name: 'countryName', label: 'Country name' },
          { name: 'state', label: 'State' },
          { name: 'stateName', label: 'State name' }
        ]
      end
    },

    # Result of GET /users/submissions/{submissionId}/submitter.
    submitter: {
      fields: lambda do |_connection, _config_fields, object_definitions|
        [
          { name: 'userId', label: 'User ID' },
          { name: 'firstName', label: 'First name' },
          { name: 'lastName', label: 'Last name' },
          { name: 'email', label: 'Email', control_type: 'email' },
          { name: 'lastLoginDate', label: 'Last login date', type: 'date_time' },
          { name: 'address', label: 'Address', type: 'object',
            properties: object_definitions['address'] }
        ]
      end
    },

    # One answer inside an entry's fieldData. The API returns ~35 polymorphic
    # field types discriminated by fieldType; this is the flat union of them.
    # Which properties are populated depends on fieldType.
    field_data_item: {
      fields: lambda do |_connection, _config_fields, _object_definitions|
        [
          { name: 'formFieldId', label: 'Form field ID' },
          { name: 'fieldType', label: 'Field type',
            hint: 'e.g. ShortAnswer, LongAnswer, Name, Address, FileUpload, Table, ...' },
          { name: 'fieldLabel', label: 'Field label',
            hint: 'Question text from the form definition. Only set by Get full submission.' },
          { name: 'optionLabels', label: 'Selected option labels', type: 'array', of: 'string',
            hint: 'Text of the selected options. Only set by Get full submission.' },
          { name: 'displayValue', label: 'Display value',
            hint: 'One readable string for the answer, whatever the field type. Only set by Get full submission.' },
          { name: 'value', label: 'Value',
            hint: 'Answer for simple fields (short/long answer, email, phone, website, number, date, ...).' },
          { name: 'options', label: 'Selected options', type: 'array', of: 'string' },
          { name: 'isAccepted', label: 'Is accepted (disclosure)', type: 'boolean' },
          { name: 'url', label: 'Disclosure URL' },
          { name: 'firstName', label: 'First name' },
          { name: 'lastName', label: 'Last name' },
          { name: 'email', label: 'Email' },
          { name: 'address1', label: 'Address line 1' },
          { name: 'address2', label: 'Address line 2' },
          { name: 'city', label: 'City' },
          { name: 'region', label: 'Region / state' },
          { name: 'postalCode', label: 'Postal code' },
          { name: 'country', label: 'Country' },
          { name: 'latitude', label: 'Latitude' },
          { name: 'longitude', label: 'Longitude' },
          { name: 'files', label: 'Files', type: 'array', of: 'object',
            properties: [
              { name: 'fileId', label: 'File ID' },
              { name: 'fileName', label: 'File name' },
              { name: 'type', label: 'Type' },
              { name: 'getDownloadUrl', label: 'Download URL' },
              { name: 'getThumbnailUrl', label: 'Thumbnail URL' },
              { name: 'getConversionUrl', label: 'Conversion URL' },
              { name: 'downloadUrl', label: 'Download URL (resolved)' },
              { name: 'fileSizeBytes', label: 'File size (bytes)', type: 'integer' },
              { name: 'duration', label: 'Duration', type: 'integer' }
            ] },
          { name: 'table', label: 'Table', type: 'object',
            properties: [
              { name: 'fileName', label: 'File name' },
              { name: 'getDownloadUrl', label: 'Download URL' },
              { name: 'getConversionUrl', label: 'Conversion URL' },
              { name: 'cells', label: 'Cells', type: 'array', of: 'object',
                properties: [
                  { name: 'r', label: 'Row', type: 'integer' },
                  { name: 'c', label: 'Column', type: 'integer' },
                  { name: 'value', label: 'Value' }
                ] }
            ] },
          { name: 'refereeEmail', label: 'Referee email' },
          { name: 'referenceFormEntryId', label: 'Reference form entry ID' },
          { name: 'personalMessage', label: 'Personal message' },
          { name: 'organizationName', label: 'Organization name' },
          { name: 'ein', label: 'EIN' },
          { name: 'state', label: 'State' },
          { name: 'zip', label: 'Zip' },
          { name: 'pub78Verified', label: 'Pub78 verified', type: 'boolean' },
          { name: 'ofacStatus', label: 'OFAC status' },
          { name: 'deductibilityStatus', label: 'Deductibility status' },
          { name: 'foundation509aStatus', label: 'Foundation 509(a) status' },
          { name: 'verificationStatusString', label: 'Verification status' },
          { name: 'verificationReason', label: 'Verification reason' }
        ]
      end
    },

    # The inner `entry` object of an entry. Union across form types
    # (initial, additional, internal, reference, review, eligibility, request).
    entry_body: {
      fields: lambda do |_connection, _config_fields, object_definitions|
        [
          { name: 'entryId', label: 'Entry ID' },
          { name: 'entryVersionId', label: 'Entry version ID' },
          { name: 'submissionId', label: 'Submission ID' },
          { name: 'projectId', label: 'Project ID' },
          { name: 'formId', label: 'Form ID' },
          { name: 'formName', label: 'Form name' },
          { name: 'createdByName', label: 'Created by (name)',
            hint: 'Submitter, staff member or reviewer name. Only set by Get full submission.' },
          { name: 'stageName', label: 'Review stage name' },
          { name: 'status', label: 'Status' },
          { name: 'completedAt', label: 'Completed at', type: 'date_time' },
          { name: 'createdBy', label: 'Created by' },
          { name: 'createdAt', label: 'Created at', type: 'date_time' },
          { name: 'openedForEditingAt', label: 'Opened for editing at', type: 'date_time' },
          { name: 'collaborationSessionId', label: 'Collaboration session ID' },
          { name: 'isOldFormVersion', label: 'Is old form version', type: 'boolean' },
          { name: 'isTransferredSubmission', label: 'Is transferred submission', type: 'boolean' },
          { name: 'lastTransferDate', label: 'Last transfer date', type: 'date_time' },
          { name: 'paymentReceipt', label: 'Payment receipt', type: 'object',
            properties: [{ name: 'total', label: 'Total', type: 'number' }] },
          # review entries
          { name: 'stageId', label: 'Review stage ID' },
          { name: 'reviewerId', label: 'Reviewer ID' },
          { name: 'isAssigned', label: 'Is assigned', type: 'boolean' },
          { name: 'score', label: 'Score', type: 'number' },
          # additional entries
          { name: 'deadline', label: 'Deadline', type: 'date_time' },
          { name: 'isStrictDeadline', label: 'Is strict deadline', type: 'boolean' },
          { name: 'hasBeenOpenedForEditing', label: 'Has been opened for editing', type: 'boolean' },
          # eligibility entries
          { name: 'parentEntryId', label: 'Parent entry ID' },
          { name: 'isEligible', label: 'Is eligible', type: 'boolean' },
          # reference entries
          { name: 'fieldId', label: 'Field ID' },
          { name: 'sendCount', label: 'Send count', type: 'integer' },
          { name: 'refereeEmail', label: 'Referee email' },
          # request entries
          { name: 'requestFormEntryStatus', label: 'Request form entry status' },
          { name: 'fieldData', label: 'Field data (answers)', type: 'array', of: 'object',
            properties: object_definitions['field_data_item'] }
        ]
      end
    },

    # { formType, entry } wrapper returned by the entries endpoints.
    form_entry: {
      fields: lambda do |_connection, _config_fields, object_definitions|
        [
          { name: 'formType', label: 'Form type',
            hint: 'initial, additional, internal, reference, review, eligibility or request' },
          { name: 'entry', label: 'Entry', type: 'object',
            properties: object_definitions['entry_body'] }
        ]
      end
    },

    review_stage: {
      fields: lambda do |_connection, _config_fields, _object_definitions|
        [
          { name: 'reviewStageId', label: 'Review stage ID' },
          { name: 'stageName', label: 'Stage name' },
          { name: 'stageOrder', label: 'Stage order', type: 'integer' },
          { name: 'type', label: 'Type' },
          { name: 'formId', label: 'Form ID' },
          { name: 'reviewerUserIds', label: 'Reviewer user IDs', type: 'array', of: 'string' },
          { name: 'hasCompletedReviews', label: 'Has completed reviews', type: 'boolean' },
          { name: 'isDeleted', label: 'Is deleted', type: 'boolean' },
          { name: 'randomAssignmentCount', label: 'Random assignment count', type: 'integer' },
          { name: 'nextStageOnCompletedReviews', label: 'Next stage on completed reviews' }
        ]
      end
    },

    # GET /projects/{projectId}; the list endpoint returns a subset of these.
    project: {
      fields: lambda do |_connection, _config_fields, object_definitions|
        [
          { name: 'projectId', label: 'Project ID' },
          { name: 'organizationId', label: 'Organization ID' },
          { name: 'name', label: 'Name' },
          { name: 'guidelinesHtml', label: 'Guidelines (HTML)' },
          { name: 'termsOfUse', label: 'Terms of use' },
          { name: 'initialFormId', label: 'Initial form ID' },
          { name: 'internalFormId', label: 'Internal form ID' },
          { name: 'eligibilityFormId', label: 'Eligibility form ID' },
          { name: 'customIneligibleMessage', label: 'Custom ineligible message' },
          { name: 'startsAt', label: 'Starts at', type: 'date_time' },
          { name: 'endsAt', label: 'Ends at', type: 'date_time' },
          { name: 'isHidden', label: 'Is hidden', type: 'boolean' },
          { name: 'isLive', label: 'Is live', type: 'boolean' },
          { name: 'isArchived', label: 'Is archived', type: 'boolean' },
          { name: 'shouldHideBlindFields', label: 'Should hide blind fields', type: 'boolean' },
          { name: 'blindLevel', label: 'Blind level' },
          { name: 'createdByUserId', label: 'Created by user ID' },
          { name: 'createdAt', label: 'Created at', type: 'date_time' },
          { name: 'concealPublicOrgInfo', label: 'Conceal public org info', type: 'boolean' },
          { name: 'requirePublicOrgId', label: 'Require public org ID', type: 'boolean' },
          { name: 'enableCollaborativeDrafts', label: 'Enable collaborative drafts', type: 'boolean' },
          { name: 'requireValidatedEmail', label: 'Require validated email', type: 'boolean' },
          { name: 'discoverTags', label: 'Discover tags', type: 'array', of: 'string' },
          { name: 'defaultNoteVisibility', label: 'Default note visibility' },
          { name: 'emailOnSubmission', label: 'Email on submission', type: 'boolean' },
          { name: 'autoResponseTemplateId', label: 'Auto response template ID' },
          { name: 'successUrl', label: 'Success URL' },
          { name: 'reviewStages', label: 'Review stages', type: 'array', of: 'object',
            properties: object_definitions['review_stage'] },
          { name: 'enforceSubmissionCap', label: 'Enforce submission cap', type: 'boolean' },
          { name: 'numSubmissionsAllowed', label: 'Submissions allowed', type: 'integer' },
          { name: 'totalSubmissionCount', label: 'Total submission count', type: 'integer' },
          { name: 'limitMultipleSubmissions', label: 'Limit multiple submissions', type: 'boolean' },
          { name: 'enableEditReviews', label: 'Enable edit reviews', type: 'boolean' },
          { name: 'enableReimbursements', label: 'Enable reimbursements', type: 'boolean' },
          { name: 'allowedFunds', label: 'Allowed funds', type: 'array', of: 'string' },
          { name: 'budgetCategories', label: 'Budget categories', type: 'array', of: 'string' },
          { name: 'isConcealed', label: 'Is concealed', type: 'boolean' },
          { name: 'isAdvancedConcealed', label: 'Is advanced concealed', type: 'boolean' },
          { name: 'hideConcealedLabels', label: 'Hide concealed labels', type: 'boolean' },
          { name: 'visibleRoles', label: 'Visible roles', type: 'array', of: 'string' },
          { name: 'fundsDistributionAccountId', label: 'Funds distribution account ID' }
        ]
      end
    },

    # GET /forms/{formId} and rows of GET /forms. The `fields`, `blocks` and
    # `branches` definitions are polymorphic and are returned as-is.
    form: {
      fields: lambda do |_connection, _config_fields, _object_definitions|
        [
          { name: 'formType', label: 'Form type' },
          { name: 'formId', label: 'Form ID' },
          { name: 'name', label: 'Name' },
          { name: 'createdBy', label: 'Created by' },
          { name: 'createdAt', label: 'Created at', type: 'date_time' },
          { name: 'updatedBy', label: 'Updated by' },
          { name: 'updatedAt', label: 'Updated at', type: 'date_time' },
          { name: 'isDeleted', label: 'Is deleted', type: 'boolean' },
          { name: 'price', label: 'Price', type: 'number' },
          { name: 'paymentDescription', label: 'Payment description' },
          { name: 'enablePayment', label: 'Enable payment', type: 'boolean' },
          { name: 'currencyCode', label: 'Currency code' }
        ]
      end
    },

    # GET /labels/{labelId} and rows of GET /labels.
    label_detail: {
      fields: lambda do |_connection, _config_fields, _object_definitions|
        [
          { name: 'labelId', label: 'Label ID' },
          { name: 'name', label: 'Name' },
          { name: 'backgroundColor', label: 'Background color' },
          { name: 'foregroundColor', label: 'Foreground color' },
          { name: 'intLabelID', label: 'Legacy label ID', type: 'integer' },
          { name: 'createdOn', label: 'Created on', type: 'date_time' },
          { name: 'createdBy', label: 'Created by' },
          { name: 'active', label: 'Active', type: 'boolean' },
          { name: 'count', label: 'Count', type: 'integer' },
          { name: 'archivedCount', label: 'Archived count', type: 'integer' },
          { name: 'orderVal', label: 'Order', type: 'integer' },
          { name: 'isConcealed', label: 'Is concealed', type: 'boolean' }
        ]
      end
    },

    fund: {
      fields: lambda do |_connection, _config_fields, _object_definitions|
        [
          { name: 'fundId', label: 'Fund ID' },
          { name: 'fundName', label: 'Fund name' },
          { name: 'fundingStatus', label: 'Funding status',
            hint: 'available (balance left to award) or depleted. Calculated by the connector from Available amount; only set by Search funds.' },
          { name: 'totalAmount', label: 'Total amount', type: 'number' },
          { name: 'awardedAmount', label: 'Awarded amount', type: 'number' },
          { name: 'paidAmount', label: 'Paid amount', type: 'number' },
          { name: 'availableAmount', label: 'Available amount', type: 'number' },
          { name: 'description', label: 'Description' },
          { name: 'createdBy', label: 'Created by' },
          { name: 'createdAt', label: 'Created at', type: 'date_time' }
        ]
      end
    },

    transaction: {
      fields: lambda do |_connection, _config_fields, _object_definitions|
        [
          { name: 'transactionId', label: 'Transaction ID' },
          { name: 'amount', label: 'Amount', type: 'number' },
          { name: 'fundId', label: 'Fund ID' },
          { name: 'fundName', label: 'Fund name' },
          { name: 'status', label: 'Status' },
          { name: 'submissionId', label: 'Submission ID' },
          { name: 'createdAt', label: 'Created at', type: 'date_time' },
          { name: 'description', label: 'Description' },
          { name: 'applicantMemo', label: 'Applicant memo' },
          { name: 'awardTransactionId', label: 'Award transaction ID' }
        ]
      end
    },

    history_item: {
      fields: lambda do |_connection, _config_fields, _object_definitions|
        [
          { name: 'historyTypeId', label: 'History type ID', type: 'integer' },
          { name: 'submissionId', label: 'Submission ID' },
          { name: 'submissionName', label: 'Submission name' },
          { name: 'description', label: 'Description' },
          { name: 'note', label: 'Note' },
          { name: 'changeReason', label: 'Change reason' },
          { name: 'changeDescription', label: 'Change description' },
          { name: 'replaceData', label: 'Replace data' },
          { name: 'emailRecipients', label: 'Email recipients' },
          { name: 'activityUserId', label: 'Activity user ID' },
          { name: 'activityUserFirstName', label: 'Activity user first name' },
          { name: 'activityUserLastName', label: 'Activity user last name' },
          { name: 'activityDateUtc', label: 'Activity date', type: 'date_time' },
          { name: 'createdOnUtc', label: 'Created on', type: 'date_time' },
          { name: 'submitterName', label: 'Submitter name' },
          { name: 'bulkActionTaskId', label: 'Bulk action task ID' },
          { name: 'entryVersionId', label: 'Entry version ID' }
        ]
      end
    },

    organization: {
      fields: lambda do |_connection, _config_fields, _object_definitions|
        [
          { name: 'id', label: 'Organization ID' },
          { name: 'legacyId', label: 'Legacy ID' },
          { name: 'name', label: 'Name' },
          { name: 'domain', label: 'Domain' },
          { name: 'websiteUrl', label: 'Website URL' },
          { name: 'timeZone', label: 'Time zone' },
          { name: 'submissionTypeName', label: 'Submission type name' },
          { name: 'projectTypeName', label: 'Project type name' },
          { name: 'email', label: 'Email' },
          { name: 'accountStatusName', label: 'Account status' },
          { name: 'isAccessRestricted', label: 'Is access restricted', type: 'boolean' },
          { name: 'accountTypeId', label: 'Account type ID', type: 'integer' },
          { name: 'feeSchedule', label: 'Fee schedule' },
          { name: 'organizationTypeId', label: 'Organization type ID', type: 'integer' },
          { name: 'transactionLimit', label: 'Transaction limit', type: 'number' },
          { name: 'teamCapacity', label: 'Team capacity', type: 'integer' }
        ]
      end
    },

    # One row returned by the "Find submissions" action.
    submission_match: {
      fields: lambda do |_connection, _config_fields, _object_definitions|
        [
          { name: 'submissionId', label: 'Submission ID' },
          { name: 'submissionTitle', label: 'Submission title' },
          { name: 'submissionStatus', label: 'Submission status' },
          { name: 'projectId', label: 'Project ID' },
          { name: 'projectName', label: 'Project name' },
          { name: 'submissionDate', label: 'Submission date', type: 'date_time',
            hint: 'Only set when found through the submissions search.' },
          { name: 'submitterId', label: 'Submitter ID' },
          { name: 'submitterName', label: 'Submitter name' },
          { name: 'submitterEmail', label: 'Submitter email', control_type: 'email' },
          { name: 'labelNames', label: 'Label names', type: 'array', of: 'string' },
          { name: 'reviewStageId', label: 'Review stage ID' },
          { name: 'isPaid', label: 'Is paid', type: 'boolean' },
          { name: 'fundId', label: 'Fund ID' },
          { name: 'fundName', label: 'Fund name' },
          { name: 'fundAmount', label: 'Amount in this fund', type: 'number',
            hint: 'Sum of transactions on this submission for the fund. Only set when searching by fund.' },
          { name: 'transactionCount', label: 'Transaction count', type: 'integer' }
        ]
      end
    },

    # Everything about one submission, assembled by the "Get full submission" action.
    full_submission: {
      fields: lambda do |_connection, _config_fields, object_definitions|
        object_definitions['submission'].ignored('formEntries') + [
          { name: 'formEntries', label: 'Form entries (with answers)', type: 'array', of: 'object',
            properties: object_definitions['form_entry'] },
          { name: 'submitter', label: 'Submitter', type: 'object',
            properties: object_definitions['submitter'] },
          { name: 'project', label: 'Project', type: 'object',
            properties: object_definitions['project'] },
          { name: 'reviews', label: 'Reviews', type: 'array', of: 'object',
            properties: object_definitions['entry_body'] },
          { name: 'transactions', label: 'Transactions', type: 'array', of: 'object',
            properties: object_definitions['transaction'] },
          { name: 'history', label: 'History', type: 'array', of: 'object',
            properties: object_definitions['history_item'] },
          { name: 'projectName', label: 'Project name' },
          { name: 'submitterName', label: 'Submitter name' },
          { name: 'submitterEmail', label: 'Submitter email', control_type: 'email' },
          { name: 'labelNames', label: 'Label names', type: 'array', of: 'string' },
          { name: 'reviewStageName', label: 'Current review stage' },
          { name: 'transactionsTotal', label: 'Transactions total', type: 'number' },
          { name: 'answers', label: 'All answers (flat list)', type: 'array', of: 'object',
            hint: 'Every answer from every entry and review, one row each. Easy to loop over.',
            properties: [
              { name: 'formType', label: 'Form type' },
              { name: 'formName', label: 'Form name' },
              { name: 'entryId', label: 'Entry ID' },
              { name: 'entryStatus', label: 'Entry status' },
              { name: 'createdByName', label: 'Created by (name)' },
              { name: 'formFieldId', label: 'Form field ID' },
              { name: 'fieldLabel', label: 'Field label' },
              { name: 'fieldType', label: 'Field type' },
              { name: 'displayValue', label: 'Display value' },
              { name: 'optionLabels', label: 'Selected option labels', type: 'array', of: 'string' }
            ] }
        ]
      end
    }
  },

  pick_lists: {
    submission_statuses: lambda do |_connection|
      [
        %w[New new],
        ['In progress', 'in_progress'],
        %w[Accepted accepted],
        %w[Declined declined],
        %w[Withdrawn withdrawn],
        %w[Completed completed],
        %w[Editable editable],
        %w[Viewed viewed],
        %w[Received received],
        %w[Published published]
      ]
    end,

    archived_statuses: lambda do |_connection|
      [
        %w[Archived archived],
        ['Not archived', 'notArchived'],
        %w[Either either]
      ]
    end,

    sort_fields: lambda do |_connection|
      [
        ['Submission ID', 'submissionId'],
        ['Submission title', 'submissionTitle'],
        %w[Date date],
        ['Review stage score', 'reviewStageScore'],
        ['Submitter name', 'submitterName'],
        ['Public organization name', 'publicOrgName'],
        ['Organization name', 'organizationName'],
        ['Project title', 'projectTitle']
      ]
    end,

    fund_statuses: lambda do |_connection|
      [
        ['Available (balance left)', 'available'],
        ['Depleted (no balance left)', 'depleted']
      ]
    end,

    form_types: lambda do |_connection|
      [
        %w[Initial initial],
        %w[Additional additional],
        %w[Internal internal],
        %w[Reference reference],
        %w[Review review],
        %w[Eligibility eligibility],
        %w[Request request]
      ]
    end,

    sort_orders: lambda do |_connection|
      [
        %w[Ascending ascending],
        %w[Descending descending]
      ]
    end
  },

  actions: {
    get_submission: {
      title: 'Get submission',
      subtitle: 'Retrieve a single submission by its ID',
      description: lambda do |_input, _picklist_label|
        "Get <span class='provider'>submission</span> in <span class='provider'>Submittable</span>"
      end,

      input_fields: lambda do |_object_definitions|
        [
          { name: 'submission_id', label: 'Submission ID', type: 'string', optional: false,
            hint: 'Submission GUID, e.g. from the Search submissions action.' }
        ]
      end,

      execute: lambda do |_connection, input|
        get("submissions/#{input['submission_id']}")
      end,

      output_fields: lambda do |object_definitions|
        object_definitions['submission']
      end,

      sample_output: lambda do |_connection, _input|
        {
          'submissionId' => '2f8a6f9e-1c1b-4d58-9b6a-5d0f6c2b7a11',
          'projectId' => '8b1d4a52-3f0e-4c8a-a6f4-0c9d2e7b5e33',
          'submitterId' => 'c4f1a7d9-6b2e-4e0c-8a35-1d7e9b4f2a60',
          'submissionStatus' => 'in_progress',
          'isArchivedBySubmitter' => false,
          'isArchivedByOrganization' => false,
          'isPaid' => false,
          'formEntries' => [
            {
              'formType' => 'initial',
              'entry' => {
                'entryId' => '5e9c2b1a-7d3f-4a86-b0c4-9f1e6a2d8b77',
                'formId' => 'a1b2c3d4-0000-4000-8000-123456789abc',
                'submissionId' => '2f8a6f9e-1c1b-4d58-9b6a-5d0f6c2b7a11',
                'projectId' => '8b1d4a52-3f0e-4c8a-a6f4-0c9d2e7b5e33',
                'status' => 'completed',
                'completedAt' => '2026-01-15T10:30:00Z',
                'createdBy' => 'c4f1a7d9-6b2e-4e0c-8a35-1d7e9b4f2a60',
                'createdAt' => '2026-01-15T10:00:00Z',
                'openedForEditingAt' => nil,
                'score' => nil
              }
            }
          ],
          'labels' => [
            { 'labelId' => 'd0e1f2a3-1111-4222-8333-444455556666', 'name' => 'Priority',
              'backgroundColor' => '#ff0000', 'foregroundColor' => '#ffffff' }
          ],
          'reviewStageId' => '77aa88bb-1234-4abc-9def-001122334455',
          'publicOrgId' => nil,
          'publicOrgVersion' => nil,
          'publicOrgName' => nil,
          'submissionTitle' => 'Spring Grant Application'
        }
      end
    },

    search_submissions: {
      title: 'Search submissions',
      subtitle: 'Retrieve a page of submissions, optionally filtered',
      description: lambda do |_input, _picklist_label|
        "Search <span class='provider'>submissions</span> in <span class='provider'>Submittable</span>"
      end,
      help: 'Filters apply to the first request only. To fetch the next page, pass the ' \
            '"Continuation token" from the previous result; all other filters are ignored then.',

      input_fields: lambda do |_object_definitions|
        [
          { name: 'continuation_token', label: 'Continuation token', sticky: true,
            hint: 'Token from a previous result. When set, all other filters are ignored.' },
          { name: 'size', label: 'Page size', type: 'integer', sticky: true, default: 50,
            hint: 'Number of submissions to return per page.' },
          { name: 'search', label: 'Search text', sticky: true,
            hint: 'Free text search across submissions.' },
          { name: 'statuses_include', label: 'Include statuses', control_type: 'multiselect',
            pick_list: 'submission_statuses', delimiter: ',', sticky: true,
            toggle_hint: 'Select from list',
            toggle_field: { name: 'statuses_include', label: 'Include statuses', type: 'string',
                            control_type: 'text', toggle_hint: 'Use custom value',
                            hint: 'Comma separated statuses, e.g. new,in_progress' } },
          { name: 'statuses_exclude', label: 'Exclude statuses', control_type: 'multiselect',
            pick_list: 'submission_statuses', delimiter: ',',
            toggle_hint: 'Select from list',
            toggle_field: { name: 'statuses_exclude', label: 'Exclude statuses', type: 'string',
                            control_type: 'text', toggle_hint: 'Use custom value',
                            hint: 'Comma separated statuses, e.g. declined,withdrawn' } },
          { name: 'project_ids_include', label: 'Include project IDs',
            hint: 'Comma separated project GUIDs.' },
          { name: 'project_ids_exclude', label: 'Exclude project IDs',
            hint: 'Comma separated project GUIDs.' },
          { name: 'label_ids_include_any', label: 'Include any of these label IDs',
            hint: 'Comma separated label GUIDs.' },
          { name: 'archived_status', label: 'Archived status', control_type: 'select',
            pick_list: 'archived_statuses',
            toggle_hint: 'Select from list',
            toggle_field: { name: 'archived_status', label: 'Archived status', type: 'string',
                            control_type: 'text', toggle_hint: 'Use custom value',
                            hint: 'One of: archived, notArchived, either' } },
          { name: 'date_from', label: 'Submitted from', type: 'date_time', sticky: true,
            hint: 'Only submissions on or after this date.' },
          { name: 'date_to', label: 'Submitted to', type: 'date_time',
            hint: 'Only submissions on or before this date.' },
          { name: 'sort_field', label: 'Sort by', control_type: 'select',
            pick_list: 'sort_fields',
            toggle_hint: 'Select from list',
            toggle_field: { name: 'sort_field', label: 'Sort by', type: 'string',
                            control_type: 'text', toggle_hint: 'Use custom value',
                            hint: 'e.g. date, submissionTitle, submitterName' } },
          { name: 'sort_order', label: 'Sort order', control_type: 'select',
            pick_list: 'sort_orders',
            toggle_hint: 'Select from list',
            toggle_field: { name: 'sort_order', label: 'Sort order', type: 'string',
                            control_type: 'text', toggle_hint: 'Use custom value',
                            hint: 'ascending or descending' } }
        ]
      end,

      execute: lambda do |_connection, input|
        query = if input['continuation_token'].present?
                  call('build_query', { 'continuationToken' => input['continuation_token'] })
                else
                  call('build_query', call('submission_query_params', input))
                end
        path = query.present? ? "submissions?#{query}" : 'submissions'
        response = get(path)

        {
          'items' => response['items'] || [],
          'continuationToken' => response['continuationToken']
        }
      end,

      output_fields: lambda do |object_definitions|
        [
          { name: 'items', label: 'Submissions', type: 'array', of: 'object',
            properties: object_definitions['submission_list_item'] },
          { name: 'continuationToken', label: 'Continuation token',
            hint: 'Pass this to the next call to get the next page. Empty on the last page.' }
        ]
      end,

      sample_output: lambda do |_connection, _input|
        {
          'items' => [
            {
              'submissionId' => '2f8a6f9e-1c1b-4d58-9b6a-5d0f6c2b7a11',
              'projectId' => '8b1d4a52-3f0e-4c8a-a6f4-0c9d2e7b5e33',
              'submitterId' => 'c4f1a7d9-6b2e-4e0c-8a35-1d7e9b4f2a60',
              'reviewStageId' => '77aa88bb-1234-4abc-9def-001122334455',
              'submissionStatus' => 'in_progress',
              'isArchived' => false,
              'isPaid' => false,
              'labels' => ['Priority'],
              'reviewers' => [],
              'submitterFirstName' => 'Jane',
              'submitterLastName' => 'Doe',
              'submitterEmail' => 'jane@example.com',
              'submitterLastLoginDate' => '2026-01-20T08:00:00Z',
              'submissionTitle' => 'Spring Grant Application',
              'projectTitle' => 'Spring Grants',
              'submissionDate' => '2026-01-15T10:30:00Z',
              'isConcealed' => false,
              'isInitialFormEntryEditable' => false,
              'publicOrgId' => nil,
              'publicOrgVersion' => nil,
              'publicOrgName' => nil,
              'concealPublicOrgName' => false
            }
          ],
          'continuationToken' => 'eyJwYWdlIjoyfQ'
        }
      end
    },

    get_submitter: {
      title: 'Get submitter',
      subtitle: "Retrieve the submitter (user) of a submission",
      description: lambda do |_input, _picklist_label|
        "Get <span class='provider'>submitter</span> of a submission in <span class='provider'>Submittable</span>"
      end,

      input_fields: lambda do |_object_definitions|
        [
          { name: 'submission_id', label: 'Submission ID', type: 'string', optional: false,
            hint: 'Submission GUID whose submitter you want to retrieve.' }
        ]
      end,

      execute: lambda do |_connection, input|
        get("users/submissions/#{input['submission_id']}/submitter")
      end,

      output_fields: lambda do |object_definitions|
        object_definitions['submitter']
      end,

      sample_output: lambda do |_connection, _input|
        {
          'userId' => 'c4f1a7d9-6b2e-4e0c-8a35-1d7e9b4f2a60',
          'firstName' => 'Jane',
          'lastName' => 'Doe',
          'email' => 'jane@example.com',
          'lastLoginDate' => '2026-01-20T08:00:00Z',
          'address' => {
            'id' => 1,
            'addressTypeId' => 1,
            'address1' => '123 Main St',
            'address2' => nil,
            'city' => 'Portland',
            'stateId' => 'OR',
            'zipCode' => '97201',
            'country' => 'US',
            'phone' => nil,
            'region' => nil,
            'countryName' => 'United States',
            'state' => 'OR',
            'stateName' => 'Oregon'
          }
        }
      end
    },

    # ---------------------------------------------------------------- composite
    get_full_submission: {
      title: 'Get full submission',
      subtitle: 'Retrieve a submission with its form answers, submitter, project, reviews and more',
      description: lambda do |_input, _picklist_label|
        "Get <span class='provider'>full submission</span> in <span class='provider'>Submittable</span>"
      end,
      help: 'Makes several API calls and merges the results. The submission response only lists ' \
            'entry metadata; this action replaces it with the full entries, including the ' \
            'applicant answers (fieldData), plus readable labels and names. Answers may include sensitive fields such as ' \
            'bank details or SSN/EIN, depending on the forms in the project.',

      input_fields: lambda do |_object_definitions|
        [
          { name: 'submission_id', label: 'Submission ID', type: 'string', optional: false,
            hint: 'Submission GUID.' },
          { name: 'include_submitter', label: 'Include submitter', type: 'boolean',
            control_type: 'checkbox', default: true, sticky: true,
            toggle_hint: 'Select from list',
            toggle_field: { name: 'include_submitter', label: 'Include submitter', type: 'string',
                            control_type: 'text', toggle_hint: 'Use custom value',
                            hint: 'true or false' } },
          { name: 'include_project', label: 'Include project', type: 'boolean',
            control_type: 'checkbox', default: true, sticky: true,
            toggle_hint: 'Select from list',
            toggle_field: { name: 'include_project', label: 'Include project', type: 'string',
                            control_type: 'text', toggle_hint: 'Use custom value',
                            hint: 'true or false' } },
          { name: 'include_reviews', label: 'Include reviews', type: 'boolean',
            control_type: 'checkbox', default: true, sticky: true,
            toggle_hint: 'Select from list',
            toggle_field: { name: 'include_reviews', label: 'Include reviews', type: 'string',
                            control_type: 'text', toggle_hint: 'Use custom value',
                            hint: 'true or false' } },
          { name: 'include_transactions', label: 'Include transactions', type: 'boolean',
            control_type: 'checkbox', default: false, sticky: true,
            hint: 'First page (up to 100) of payments/awards for this submission.',
            toggle_hint: 'Select from list',
            toggle_field: { name: 'include_transactions', label: 'Include transactions',
                            type: 'string', control_type: 'text', toggle_hint: 'Use custom value',
                            hint: 'true or false' } },
          { name: 'include_history', label: 'Include history', type: 'boolean',
            control_type: 'checkbox', default: false, sticky: true,
            hint: 'First page (up to 100) of activity history for this submission.',
            toggle_hint: 'Select from list',
            toggle_field: { name: 'include_history', label: 'Include history', type: 'string',
                            control_type: 'text', toggle_hint: 'Use custom value',
                            hint: 'true or false' } },
          { name: 'include_field_labels', label: 'Add field labels, option labels and form names',
            type: 'boolean', control_type: 'checkbox', default: true, sticky: true,
            hint: 'Looks up each form definition and adds fieldLabel, optionLabels and formName. ' \
                  'Makes one extra API call per distinct form.',
            toggle_hint: 'Select from list',
            toggle_field: { name: 'include_field_labels', label: 'Add field labels, option labels and form names',
                            type: 'string', control_type: 'text', toggle_hint: 'Use custom value',
                            hint: 'true or false' } },
          { name: 'include_name_lookups', label: 'Resolve staff and fund names', type: 'boolean',
            control_type: 'checkbox', default: true, sticky: true,
            hint: 'Adds createdByName to entries and reviews (looks up your team list) and fundName ' \
                  'to transactions. Needs permission to view team members.',
            toggle_hint: 'Select from list',
            toggle_field: { name: 'include_name_lookups', label: 'Resolve staff and fund names',
                            type: 'string', control_type: 'text', toggle_hint: 'Use custom value',
                            hint: 'true or false' } },
          { name: 'include_file_urls', label: 'Include file download URLs', type: 'boolean',
            control_type: 'checkbox', default: false, sticky: true,
            hint: 'Adds a downloadUrl to every uploaded file. Makes one API call per file, ' \
                  'so leave off for submissions with many uploads.',
            toggle_hint: 'Select from list',
            toggle_field: { name: 'include_file_urls', label: 'Include file download URLs',
                            type: 'string', control_type: 'text', toggle_hint: 'Use custom value',
                            hint: 'true or false' } }
        ]
      end,

      execute: lambda do |_connection, input|
        sid = input['submission_id']

        submission = get("submissions/#{sid}")
        entries = get("entries/submissions/#{sid}")
        result = submission.merge('formEntries' => entries['formEntries'] || [])

        if input['include_submitter'].to_s == 'true'
          result['submitter'] = get("users/submissions/#{sid}/submitter")
        end

        if input['include_project'].to_s == 'true' && submission['projectId'].present?
          result['project'] = get("projects/#{submission['projectId']}")
        end

        if input['include_reviews'].to_s == 'true'
          result['reviews'] = get("entries/submissions/#{sid}/reviews")
        end

        if input['include_transactions'].to_s == 'true'
          query = call('build_query', { 'submissionId' => sid, 'size' => 100 })
          result['transactions'] = get("transactions?#{query}")['items'] || []
        end

        if input['include_history'].to_s == 'true'
          query = call('build_query', { 'submissionId' => [sid], 'size' => 100 })
          result['history'] = get("submissions/history?#{query}")['items'] || []
        end

        submitter = result['submitter']
        project = result['project']

        # --- lookups (one API call per distinct form / fund, one for the team) ---
        labels = {}
        option_labels = {}
        form_names = {}
        if input['include_field_labels'].to_s == 'true'
          form_ids = result['formEntries'].map { |form_entry| (form_entry['entry'] || {})['formId'] }
          form_ids += (result['reviews'] || []).map { |review| review['formId'] }
          form_ids.compact.uniq.each do |form_id|
            form = get("forms/#{form_id}")
            form_names[form_id] = form['name']
            (form['fields'] || []).each do |field|
              labels[field['formFieldId']] = field['label']
              (field['options'] || []).each do |option|
                option_labels[option['formOptionId']] = option['label']
              end
            end
          end
        end

        people = {}
        if submitter.present?
          people[submitter['userId']] = [submitter['firstName'], submitter['lastName']].compact.join(' ')
        end
        if input['include_name_lookups'].to_s == 'true'
          (get('organizations/team')['teamMembers'] || []).each do |member|
            name = member['name'] || {}
            full = [name['first'], name['last']].compact.join(' ')
            people[member['userId']] = full.present? ? full : member['email']
          end
        end

        # --- enrich every entry and review (hashes are updated in place) ---
        pairs = result['formEntries'].map { |form_entry| [form_entry['formType'], form_entry['entry']] }
        pairs += (result['reviews'] || []).map { |review| ['review', review] }
        pairs = pairs.select { |pair| pair[1].present? }

        stage_names = {}
        if project.present?
          (project['reviewStages'] || []).each do |stage|
            stage_names[stage['reviewStageId']] = stage['stageName']
          end
        end

        flat_answers = []
        pairs.each do |pair|
          form_type = pair[0]
          entry = pair[1]
          entry['formName'] = form_names[entry['formId']]
          entry['createdByName'] = people[entry['reviewerId'] || entry['createdBy']]
          entry['stageName'] = stage_names[entry['stageId']] if entry['stageId'].present?

          (entry['fieldData'] || []).each do |answer|
            if input['include_file_urls'].to_s == 'true'
              (answer['files'] || []).each do |file|
                file['downloadUrl'] = get("entries/#{entry['entryId']}/files/#{file['fileId']}")['url']
              end
            end

            answer['fieldLabel'] = labels[answer['formFieldId']]
            answer['optionLabels'] = (answer['options'] || []).map { |id| option_labels[id] || id }

            display = if answer['options'].present?
                        answer['optionLabels'].join(', ')
                      elsif answer['files'].present?
                        answer['files'].map { |file| file['fileName'] }.join(', ')
                      elsif answer['table'].present?
                        answer['table']['fileName'].to_s
                      elsif answer['firstName'].present? || answer['lastName'].present?
                        [answer['firstName'], answer['lastName']].compact.join(' ')
                      elsif answer['address1'].present?
                        [answer['address1'], answer['address2'], answer['city'], answer['region'],
                         answer['postalCode'], answer['country']].reject(&:blank?).join(', ')
                      elsif answer.key?('isAccepted')
                        answer['isAccepted'].to_s
                      else
                        answer['value'].to_s
                      end
            answer['displayValue'] = display

            flat_answers << {
              'formType' => form_type,
              'formName' => entry['formName'],
              'entryId' => entry['entryId'],
              'entryStatus' => entry['status'],
              'createdByName' => entry['createdByName'],
              'formFieldId' => answer['formFieldId'],
              'fieldLabel' => answer['fieldLabel'],
              'fieldType' => answer['fieldType'],
              'displayValue' => display,
              'optionLabels' => answer['optionLabels']
            }
          end
        end
        result['answers'] = flat_answers

        # --- top-level conveniences (no extra calls) ---
        result['projectName'] = project['name'] if project.present?
        if submitter.present?
          result['submitterName'] = people[submitter['userId']]
          result['submitterEmail'] = submitter['email']
        end
        result['labelNames'] = (submission['labels'] || []).map { |label| label['name'] }
        result['reviewStageName'] = stage_names[submission['reviewStageId']] if submission['reviewStageId'].present?

        if result['transactions'].present?
          fund_names = {}
          if input['include_name_lookups'].to_s == 'true'
            result['transactions'].map { |txn| txn['fundId'] }.compact.uniq.each do |fund_id|
              fund_names[fund_id] = get("funds/#{fund_id}")['fundName']
            end
          end
          result['transactions'] = result['transactions'].map do |txn|
            txn.merge('fundName' => fund_names[txn['fundId']])
          end
          result['transactionsTotal'] = result['transactions'].map { |txn| txn['amount'].to_f }.sum
        end

        result
      end,

      output_fields: lambda do |object_definitions|
        object_definitions['full_submission']
      end
    },

    # ------------------------------------------------------- submission details
    get_submission_entries: {
      title: 'Get submission entries',
      subtitle: "Retrieve a submission's form entries (e.g. the internal form), including answers",
      description: lambda do |_input, _picklist_label|
        "Get <span class='provider'>entries</span> of a submission in <span class='provider'>Submittable</span>"
      end,
      help: 'Use "Form type" = internal to get the internal form, and "Latest only" to keep just the ' \
            'most recently completed entry of each form type.',

      input_fields: lambda do |_object_definitions|
        [
          { name: 'submission_id', label: 'Submission ID', optional: false },
          { name: 'form_type', label: 'Form type', control_type: 'select', pick_list: 'form_types',
            sticky: true, toggle_hint: 'Select from list',
            hint: 'Leave blank for all form types.',
            toggle_field: { name: 'form_type', label: 'Form type', type: 'string',
                            control_type: 'text', toggle_hint: 'Use custom value',
                            hint: 'initial, additional, internal, reference, review, eligibility or request' } },
          { name: 'latest_only', label: 'Latest only', type: 'boolean', control_type: 'checkbox',
            default: false, sticky: true,
            hint: 'Keep only the most recently completed entry of each form type.',
            toggle_hint: 'Select from list',
            toggle_field: { name: 'latest_only', label: 'Latest only', type: 'string',
                            control_type: 'text', toggle_hint: 'Use custom value',
                            hint: 'true or false' } },
          { name: 'include_field_labels', label: 'Add field labels, option labels and form names',
            type: 'boolean', control_type: 'checkbox', default: true, sticky: true,
            toggle_hint: 'Select from list',
            toggle_field: { name: 'include_field_labels', label: 'Add field labels, option labels and form names',
                            type: 'string', control_type: 'text', toggle_hint: 'Use custom value',
                            hint: 'true or false' } }
        ]
      end,

      execute: lambda do |_connection, input|
        response = get("entries/submissions/#{input['submission_id']}")
        form_entries = response['formEntries'] || []

        if input['form_type'].present?
          form_entries = form_entries.select { |form_entry| form_entry['formType'] == input['form_type'] }
        end

        if input['latest_only'].to_s == 'true'
          form_entries = form_entries.group_by { |form_entry| form_entry['formType'] }.map do |_type, group|
            group.max_by do |form_entry|
              entry = form_entry['entry'] || {}
              (entry['completedAt'] || entry['createdAt']).to_s
            end
          end
        end

        if input['include_field_labels'].to_s == 'true'
          labels = {}
          option_labels = {}
          form_names = {}
          form_entries.map { |form_entry| (form_entry['entry'] || {})['formId'] }.compact.uniq.each do |form_id|
            form = get("forms/#{form_id}")
            form_names[form_id] = form['name']
            (form['fields'] || []).each do |field|
              labels[field['formFieldId']] = field['label']
              (field['options'] || []).each do |option|
                option_labels[option['formOptionId']] = option['label']
              end
            end
          end

          form_entries.each do |form_entry|
            entry = form_entry['entry']
            next if entry.blank?

            entry['formName'] = form_names[entry['formId']]
            (entry['fieldData'] || []).each do |answer|
              answer['fieldLabel'] = labels[answer['formFieldId']]
              answer['optionLabels'] = (answer['options'] || []).map { |id| option_labels[id] || id }
              answer['displayValue'] = if answer['options'].present?
                                         answer['optionLabels'].join(', ')
                                       elsif answer['files'].present?
                                         answer['files'].map { |file| file['fileName'] }.join(', ')
                                       elsif answer['table'].present?
                                         answer['table']['fileName'].to_s
                                       elsif answer['firstName'].present? || answer['lastName'].present?
                                         [answer['firstName'], answer['lastName']].compact.join(' ')
                                       elsif answer['address1'].present?
                                         [answer['address1'], answer['address2'], answer['city'], answer['region'],
                                          answer['postalCode'], answer['country']].reject(&:blank?).join(', ')
                                       elsif answer.key?('isAccepted')
                                         answer['isAccepted'].to_s
                                       else
                                         answer['value'].to_s
                                       end
            end
          end
        end

        { 'formEntries' => form_entries }
      end,

      output_fields: lambda do |object_definitions|
        [{ name: 'formEntries', label: 'Form entries', type: 'array', of: 'object',
           properties: object_definitions['form_entry'] }]
      end
    },

    find_submissions: {
      title: 'Find submissions by submitter / fund',
      subtitle: 'Find submissions for a submitter and/or a fund',
      description: lambda do |_input, _picklist_label|
        "Find <span class='provider'>submissions</span> by submitter / fund in <span class='provider'>Submittable</span>"
      end,
      help: 'Give a submitter (email, name or ID), a project, a fund, or any combination. "Project name" ' \
            'matches the Submittable project name. "Submittable fund" instead matches the Funds module ' \
            'through its transactions. ' \
            'Results are filtered to the submitter. Use the returned Submission ID with ' \
            '"Get submission entries" or "Get full submission".',

      input_fields: lambda do |_object_definitions|
        [
          { name: 'submitter_email', label: 'Submitter email', sticky: true },
          { name: 'submitter_name', label: 'Submitter name', sticky: true,
            hint: 'Matches if the submitter\'s full name contains this text.' },
          { name: 'submitter_id', label: 'Submitter ID', hint: 'User GUID.' },
          { name: 'project_name', label: 'Project name', sticky: true,
            hint: 'Matches projects whose name contains this text, e.g. Spring Grants.' },
          { name: 'fund_name', label: 'Submittable fund name',
            hint: 'Exact name of a fund in the Funds module (not case sensitive). Matches via transactions.' },
          { name: 'fund_id', label: 'Submittable fund ID', hint: 'Takes priority over fund name.' },
          { name: 'size', label: 'Maximum results', type: 'integer', default: 25, sticky: true }
        ]
      end,

      execute: lambda do |_connection, input|
        max_results = input['size'].present? ? input['size'].to_i : 25
        email = input['submitter_email'].to_s.strip.downcase
        name = input['submitter_name'].to_s.strip.downcase
        submitter_id = input['submitter_id'].to_s.strip

        if email.blank? && name.blank? && submitter_id.blank? && input['fund_id'].blank? && input['fund_name'].blank? &&
           input['project_name'].blank?
          error('Provide a submitter (email, name or ID), a project name or a fund.')
        end

        # --- resolve the fund ---
        fund_id = input['fund_id'].to_s.strip
        fund_name = nil
        if fund_id.blank? && input['fund_name'].present?
          wanted = input['fund_name'].to_s.strip.downcase
          token = nil
          10.times do
            path = token.present? ? "funds?#{call('build_query', { 'continuationToken' => token })}" : 'funds'
            page = get(path)
            match = (page['items'] || []).find { |fund| fund['fundName'].to_s.strip.downcase == wanted }
            if match.present?
              fund_id = match['fundId']
              fund_name = match['fundName']
            end
            token = page['continuationToken']
            break if fund_id.present? || token.blank?
          end
          error("No fund named '#{input['fund_name']}' was found.") if fund_id.blank?
        elsif fund_id.present?
          fund_name = get("funds/#{fund_id}")['fundName']
        end

        # --- project filter ---
        project_ids = []
        project_names = {}
        if input['project_name'].present?
          wanted_project = input['project_name'].to_s.strip.downcase
          token = nil
          10.times do
            path = token.present? ? "projects?#{call('build_query', { 'continuationToken' => token })}" : 'projects'
            page = get(path)
            (page['items'] || []).each do |project|
              project_names[project['projectId']] = project['name']
              project_ids << project['projectId'] if project['name'].to_s.downcase.include?(wanted_project)
            end
            token = page['continuationToken']
            break if token.blank?
          end
          error("No project name contains '#{input['project_name']}'.") if project_ids.empty?
        end

        # --- candidate submissions ---
        totals = {}
        counts = {}
        submissions = []
        if fund_id.present?
          submission_ids = []
          token = nil
          10.times do
            query = if token.present?
                      call('build_query', { 'continuationToken' => token })
                    else
                      call('build_query', { 'fundId' => fund_id, 'submitterId' => submitter_id, 'size' => 50 })
                    end
            page = get("transactions?#{query}")
            (page['items'] || []).each do |txn|
              next if txn['submissionId'].blank?
              submission_ids << txn['submissionId']
              totals[txn['submissionId']] = totals[txn['submissionId']].to_f + txn['amount'].to_f
              counts[txn['submissionId']] = counts[txn['submissionId']].to_i + 1
            end
            token = page['continuationToken']
            break if token.blank?
          end
          submission_ids = submission_ids.uniq
          submission_ids.each_slice(100) do |batch|
            submissions += post('submissions/ids', { 'submissionIds' => batch })
          end
        else
          search = email.present? ? email : (name.present? ? name : '')
          token = nil
          5.times do
            query = if token.present?
                      call('build_query', { 'continuationToken' => token })
                    else
                      call('build_query', { 'Search' => search, 'Projects.Include' => project_ids, 'size' => 50 })
                    end
            page = get("submissions?#{query}")
            submissions += (page['items'] || [])
            token = page['continuationToken']
            break if token.blank? || submissions.size >= 250
          end
        end

        # --- submitter details for the candidates ---
        submitters = {}
        submissions.map { |sub| sub['submissionId'] }.compact.each_slice(100) do |batch|
          post('users/submissions/submitters', { 'submissionIds' => batch }).each do |person|
            submitters[person['submissionId']] = person
          end
        end

        matches = []
        submissions.each do |sub|
          person = submitters[sub['submissionId']] || {}
          person_email = (person['email'] || sub['submitterEmail']).to_s
          person_name = [person['firstName'] || sub['submitterFirstName'],
                         person['lastName'] || sub['submitterLastName']].compact.join(' ')
          person_id = (person['userId'] || sub['submitterId']).to_s

          ok = true
          ok = false if project_ids.present? && !project_ids.include?(sub['projectId'])
          ok = false if email.present? && person_email.downcase != email
          ok = false if name.present? && !person_name.downcase.include?(name)
          ok = false if submitter_id.present? && person_id != submitter_id
          next unless ok

          label_names = (sub['labels'] || []).map { |label| label.is_a?(Hash) ? label['name'] : label }
          matches << {
            'submissionId' => sub['submissionId'],
            'submissionTitle' => sub['submissionTitle'],
            'submissionStatus' => sub['submissionStatus'],
            'projectId' => sub['projectId'],
            'projectName' => project_names[sub['projectId']] || sub['projectTitle'],
            'submissionDate' => sub['submissionDate'],
            'submitterId' => person_id,
            'submitterName' => person_name,
            'submitterEmail' => person_email,
            'labelNames' => label_names,
            'reviewStageId' => sub['reviewStageId'],
            'isPaid' => sub['isPaid'],
            'fundId' => (fund_id.present? ? fund_id : nil),
            'fundName' => fund_name,
            'fundAmount' => fund_id.present? ? totals[sub['submissionId']] : nil,
            'transactionCount' => fund_id.present? ? counts[sub['submissionId']] : nil
          }
        end

        { 'count' => matches.size, 'submissions' => matches.first(max_results) }
      end,

      output_fields: lambda do |object_definitions|
        [
          { name: 'count', label: 'Total matches', type: 'integer',
            hint: 'Matches found before applying Maximum results.' },
          { name: 'submissions', label: 'Submissions', type: 'array', of: 'object',
            properties: object_definitions['submission_match'] }
        ]
      end
    },

    get_entry: {
      title: 'Get entry',
      subtitle: 'Retrieve one form entry (with answers) by its ID',
      description: lambda do |_input, _picklist_label|
        "Get <span class='provider'>entry</span> in <span class='provider'>Submittable</span>"
      end,

      input_fields: lambda do |_object_definitions|
        [
          { name: 'entry_id', label: 'Entry ID', optional: false },
          { name: 'prefer_original_version', label: 'Prefer original version', type: 'boolean',
            control_type: 'checkbox', sticky: true,
            hint: 'Return the original answers instead of the latest edited version.',
            toggle_hint: 'Select from list',
            toggle_field: { name: 'prefer_original_version', label: 'Prefer original version',
                            type: 'string', control_type: 'text', toggle_hint: 'Use custom value',
                            hint: 'true or false' } },
          { name: 'include_drafts', label: 'Include drafts', type: 'boolean',
            control_type: 'checkbox', sticky: true,
            toggle_hint: 'Select from list',
            toggle_field: { name: 'include_drafts', label: 'Include drafts', type: 'string',
                            control_type: 'text', toggle_hint: 'Use custom value',
                            hint: 'true or false' } }
        ]
      end,

      execute: lambda do |_connection, input|
        query = call('build_query', {
                       'preferOriginalVersion' => input['prefer_original_version'].present? ? input['prefer_original_version'] : nil,
                       'includeDrafts' => input['include_drafts'].present? ? input['include_drafts'] : nil
                     })
        get(query.present? ? "entries/#{input['entry_id']}?#{query}" : "entries/#{input['entry_id']}")
      end,

      output_fields: lambda do |object_definitions|
        object_definitions['form_entry']
      end
    },

    get_submission_reviews: {
      title: 'Get submission reviews',
      subtitle: 'Retrieve the reviews (review form entries) for a submission',
      description: lambda do |_input, _picklist_label|
        "Get <span class='provider'>reviews</span> of a submission in <span class='provider'>Submittable</span>"
      end,

      input_fields: lambda do |_object_definitions|
        [
          { name: 'submission_id', label: 'Submission ID', optional: false },
          { name: 'review_stage_id', label: 'Review stage ID', sticky: true,
            hint: 'Only return reviews from this stage.' }
        ]
      end,

      execute: lambda do |_connection, input|
        query = call('build_query', { 'reviewStageId' => input['review_stage_id'] })
        path = "entries/submissions/#{input['submission_id']}/reviews"
        { 'reviews' => get(query.present? ? "#{path}?#{query}" : path) }
      end,

      output_fields: lambda do |object_definitions|
        [{ name: 'reviews', label: 'Reviews', type: 'array', of: 'object',
           properties: object_definitions['entry_body'] }]
      end
    },

    search_submission_history: {
      title: 'Search submission history',
      subtitle: 'Retrieve a page of submission activity history',
      description: lambda do |_input, _picklist_label|
        "Search <span class='provider'>submission history</span> in <span class='provider'>Submittable</span>"
      end,

      input_fields: lambda do |_object_definitions|
        [
          { name: 'continuation_token', label: 'Continuation token', sticky: true,
            hint: 'Token from a previous result. When set, all other filters are ignored.' },
          { name: 'size', label: 'Page size', type: 'integer', sticky: true, default: 50,
            hint: 'Number of records to return per page.' },
          { name: 'submission_ids', label: 'Submission IDs', sticky: true,
            hint: 'Comma separated submission GUIDs.' },
          { name: 'user_ids', label: 'User IDs', hint: 'Comma separated user GUIDs.' },
          { name: 'history_type_ids', label: 'History type IDs',
            hint: 'Comma separated integer history type IDs.' },
          { name: 'bulk_action_task_id', label: 'Bulk action task ID' }
        ]
      end,

      execute: lambda do |_connection, input|
        query = if input['continuation_token'].present?
                  call('build_query', { 'continuationToken' => input['continuation_token'] })
                else
                  call('build_query', {
                   'size' => input['size'],
                   'submissionId' => call('csv_to_array', input['submission_ids']),
                   'userId' => call('csv_to_array', input['user_ids']),
                   'historyTypeId' => call('csv_to_array', input['history_type_ids']),
                   'bulkActionTaskId' => input['bulk_action_task_id']
                 })
                end
        path = query.present? ? "submissions/history?#{query}" : 'submissions/history'
        response = get(path)

        {
          'items' => response['items'] || [],
          'continuationToken' => response['continuationToken']
        }
      end,

      output_fields: lambda do |object_definitions|
        [
          { name: 'items', label: 'Items', type: 'array', of: 'object',
            properties: object_definitions['history_item'] },
          { name: 'continuationToken', label: 'Continuation token',
            hint: 'Pass this to the next call to get the next page. Empty on the last page.' }
        ]
      end
    },

    # ------------------------------------------------------------------ projects
    get_project: {
      title: 'Get project',
      subtitle: 'Retrieve a project (including review stages) by ID',
      description: lambda do |_input, _picklist_label|
        "Get <span class='provider'>project</span> in <span class='provider'>Submittable</span>"
      end,

      input_fields: lambda do |_object_definitions|
        [{ name: 'project_id', label: 'Project ID', optional: false }]
      end,

      execute: lambda do |_connection, input|
        get("projects/#{input['project_id']}")
      end,

      output_fields: lambda do |object_definitions|
        object_definitions['project']
      end
    },

    search_projects: {
      title: 'Search projects',
      subtitle: 'Retrieve a page of projects',
      description: lambda do |_input, _picklist_label|
        "Search <span class='provider'>projects</span> in <span class='provider'>Submittable</span>"
      end,

      input_fields: lambda do |_object_definitions|
        [
          { name: 'continuation_token', label: 'Continuation token', sticky: true,
            hint: 'Token from a previous result. When set, all other filters are ignored.' },
          { name: 'size', label: 'Page size', type: 'integer', sticky: true, default: 50,
            hint: 'Number of records to return per page.' }
        ]
      end,

      execute: lambda do |_connection, input|
        query = if input['continuation_token'].present?
                  call('build_query', { 'continuationToken' => input['continuation_token'] })
                else
                  call('build_query', { 'size' => input['size'] })
                end
        path = query.present? ? "projects?#{query}" : 'projects'
        response = get(path)

        {
          'items' => response['items'] || [],
          'continuationToken' => response['continuationToken']
        }
      end,

      output_fields: lambda do |object_definitions|
        [
          { name: 'items', label: 'Items', type: 'array', of: 'object',
            properties: object_definitions['project'] },
          { name: 'continuationToken', label: 'Continuation token',
            hint: 'Pass this to the next call to get the next page. Empty on the last page.' }
        ]
      end
    },

    # --------------------------------------------------------------------- forms
    get_form: {
      title: 'Get form',
      subtitle: 'Retrieve a form definition by ID',
      description: lambda do |_input, _picklist_label|
        "Get <span class='provider'>form</span> in <span class='provider'>Submittable</span>"
      end,

      input_fields: lambda do |_object_definitions|
        [{ name: 'form_id', label: 'Form ID', optional: false }]
      end,

      execute: lambda do |_connection, input|
        get("forms/#{input['form_id']}")
      end,

      output_fields: lambda do |object_definitions|
        object_definitions['form']
      end
    },

    search_forms: {
      title: 'Search forms',
      subtitle: 'Retrieve a page of form definitions',
      description: lambda do |_input, _picklist_label|
        "Search <span class='provider'>forms</span> in <span class='provider'>Submittable</span>"
      end,

      input_fields: lambda do |_object_definitions|
        [
          { name: 'continuation_token', label: 'Continuation token', sticky: true,
            hint: 'Token from a previous result. When set, all other filters are ignored.' },
          { name: 'size', label: 'Page size', type: 'integer', sticky: true, default: 50,
            hint: 'Number of records to return per page.' },
          { name: 'type', label: 'Form type', control_type: 'select', pick_list: 'form_types',
            sticky: true, toggle_hint: 'Select from list',
            toggle_field: { name: 'type', label: 'Form type', type: 'string',
                            control_type: 'text', toggle_hint: 'Use custom value',
                            hint: 'initial, additional, internal, reference, review, eligibility or request' } },
          { name: 'project_id', label: 'Project ID', sticky: true }
        ]
      end,

      execute: lambda do |_connection, input|
        query = if input['continuation_token'].present?
                  call('build_query', { 'continuationToken' => input['continuation_token'] })
                else
                  call('build_query', {
                   'size' => input['size'],
                   'type' => input['type'],
                   'projectId' => input['project_id']
                 })
                end
        path = query.present? ? "forms?#{query}" : 'forms'
        response = get(path)

        {
          'items' => response['items'] || [],
          'continuationToken' => response['continuationToken']
        }
      end,

      output_fields: lambda do |object_definitions|
        [
          { name: 'items', label: 'Items', type: 'array', of: 'object',
            properties: object_definitions['form'] },
          { name: 'continuationToken', label: 'Continuation token',
            hint: 'Pass this to the next call to get the next page. Empty on the last page.' }
        ]
      end
    },

    # -------------------------------------------------------------------- labels
    get_label: {
      title: 'Get label',
      subtitle: 'Retrieve a label by ID',
      description: lambda do |_input, _picklist_label|
        "Get <span class='provider'>label</span> in <span class='provider'>Submittable</span>"
      end,

      input_fields: lambda do |_object_definitions|
        [{ name: 'label_id', label: 'Label ID', optional: false }]
      end,

      execute: lambda do |_connection, input|
        get("labels/#{input['label_id']}")
      end,

      output_fields: lambda do |object_definitions|
        object_definitions['label_detail']
      end
    },

    search_labels: {
      title: 'Search labels',
      subtitle: 'Retrieve a page of labels',
      description: lambda do |_input, _picklist_label|
        "Search <span class='provider'>labels</span> in <span class='provider'>Submittable</span>"
      end,

      input_fields: lambda do |_object_definitions|
        [
          { name: 'continuation_token', label: 'Continuation token', sticky: true,
            hint: 'Token from a previous result. When set, all other filters are ignored.' },
          { name: 'size', label: 'Page size', type: 'integer', sticky: true, default: 50,
            hint: 'Number of records to return per page.' }
        ]
      end,

      execute: lambda do |_connection, input|
        query = if input['continuation_token'].present?
                  call('build_query', { 'continuationToken' => input['continuation_token'] })
                else
                  call('build_query', { 'size' => input['size'] })
                end
        path = query.present? ? "labels?#{query}" : 'labels'
        response = get(path)

        {
          'items' => response['items'] || [],
          'continuationToken' => response['continuationToken']
        }
      end,

      output_fields: lambda do |object_definitions|
        [
          { name: 'items', label: 'Items', type: 'array', of: 'object',
            properties: object_definitions['label_detail'] },
          { name: 'continuationToken', label: 'Continuation token',
            hint: 'Pass this to the next call to get the next page. Empty on the last page.' }
        ]
      end
    },

    # --------------------------------------------------------- funds / payments
    get_fund: {
      title: 'Get fund',
      subtitle: 'Retrieve a fund by ID',
      description: lambda do |_input, _picklist_label|
        "Get <span class='provider'>fund</span> in <span class='provider'>Submittable</span>"
      end,

      input_fields: lambda do |_object_definitions|
        [{ name: 'fund_id', label: 'Fund ID', optional: false }]
      end,

      execute: lambda do |_connection, input|
        get("funds/#{input['fund_id']}")
      end,

      output_fields: lambda do |object_definitions|
        object_definitions['fund']
      end
    },

    search_funds: {
      title: 'Search funds',
      subtitle: 'Retrieve funds, optionally filtered by text, funding status or creation date',
      description: lambda do |_input, _picklist_label|
        "Search <span class='provider'>funds</span> in <span class='provider'>Submittable</span>"
      end,
      help: 'Submittable\'s funds API only supports paging, so the filters below are applied by the ' \
            'connector: it reads pages (up to 10) and keeps the funds that match. With a filter, ' \
            'scanning stops after the page where at least "Page size" matches were found; if the ' \
            '"Continuation token" in the result is not empty, pass it back to keep scanning. ' \
            'Funding status is calculated from Available amount (the API has no status field).',

      input_fields: lambda do |_object_definitions|
        [
          { name: 'continuation_token', label: 'Continuation token', sticky: true,
            hint: 'Token from a previous result, to continue scanning. Filters still apply.' },
          { name: 'size', label: 'Page size', type: 'integer', sticky: true, default: 50,
            hint: 'Funds read per API call. With filters, also the number of matches to look for.' },
          { name: 'query', label: 'Search text', sticky: true,
            hint: 'Keep funds whose name or description contains this text (not case sensitive).' },
          { name: 'status', label: 'Funding status', control_type: 'select', pick_list: 'fund_statuses',
            sticky: true, toggle_hint: 'Select from list',
            toggle_field: { name: 'status', label: 'Funding status', type: 'string',
                            control_type: 'text', toggle_hint: 'Use custom value',
                            hint: 'available or depleted' } },
          { name: 'created_from', label: 'Created from', type: 'date_time',
            hint: 'Only funds created on or after this date.' },
          { name: 'created_to', label: 'Created to', type: 'date_time',
            hint: 'Only funds created on or before this date.' }
        ]
      end,

      execute: lambda do |_connection, input|
        size = input['size'].present? ? input['size'].to_i : 50
        wanted = input['query'].to_s.strip.downcase
        from = input['created_from'].present? ? input['created_from'].to_time.utc : nil
        to = input['created_to'].present? ? input['created_to'].to_time.utc : nil
        filtered = wanted.present? || input['status'].present? || from.present? || to.present?

        token = input['continuation_token']
        matches = []
        scanned = 0
        10.times do
          query = if token.present?
                    call('build_query', { 'continuationToken' => token })
                  else
                    call('build_query', { 'size' => size })
                  end
          page = get("funds?#{query}")
          items = page['items'] || []
          scanned += items.size

          items.each do |fund|
            status = fund['availableAmount'].to_f > 0 ? 'available' : 'depleted'
            created = fund['createdAt'].present? ? fund['createdAt'].to_time.utc : nil

            ok = true
            ok = false if wanted.present? && !"#{fund['fundName']} #{fund['description']}".downcase.include?(wanted)
            ok = false if input['status'].present? && input['status'] != status
            ok = false if from.present? && (created.nil? || created < from)
            ok = false if to.present? && (created.nil? || created > to)
            matches << fund.merge('fundingStatus' => status) if ok
          end

          token = page['continuationToken']
          break if token.blank? || !filtered || matches.size >= size
        end

        {
          'items' => matches,
          'continuationToken' => token,
          'scannedCount' => scanned
        }
      end,

      output_fields: lambda do |object_definitions|
        [
          { name: 'items', label: 'Funds', type: 'array', of: 'object',
            properties: object_definitions['fund'] },
          { name: 'continuationToken', label: 'Continuation token',
            hint: 'Pass this back to keep scanning. Empty when every fund has been read.' },
          { name: 'scannedCount', label: 'Funds scanned', type: 'integer',
            hint: 'How many funds were read from Submittable to produce this result.' }
        ]
      end,

      sample_output: lambda do |_connection, _input|
        {
          'items' => [
            {
              'fundId' => '3f6c1d52-8a0e-4b7a-9c21-5d4e8f0a1b22',
              'fundName' => 'Spring Grants Fund',
              'fundingStatus' => 'available',
              'totalAmount' => 1_000_000.0,
              'awardedAmount' => 600_000.0,
              'paidAmount' => 250_000.0,
              'availableAmount' => 400_000.0,
              'description' => 'Annual open call fund',
              'createdBy' => 'c4f1a7d9-6b2e-4e0c-8a35-1d7e9b4f2a60',
              'createdAt' => '2026-01-15T10:00:00Z'
            }
          ],
          'continuationToken' => nil,
          'scannedCount' => 1
        }
      end
    },

    get_transaction: {
      title: 'Get transaction',
      subtitle: 'Retrieve a transaction by ID',
      description: lambda do |_input, _picklist_label|
        "Get <span class='provider'>transaction</span> in <span class='provider'>Submittable</span>"
      end,

      input_fields: lambda do |_object_definitions|
        [{ name: 'transaction_id', label: 'Transaction ID', optional: false }]
      end,

      execute: lambda do |_connection, input|
        get("transactions/#{input['transaction_id']}")
      end,

      output_fields: lambda do |object_definitions|
        object_definitions['transaction']
      end
    },

    search_transactions: {
      title: 'Search transactions',
      subtitle: 'Retrieve a page of transactions, optionally filtered',
      description: lambda do |_input, _picklist_label|
        "Search <span class='provider'>transactions</span> in <span class='provider'>Submittable</span>"
      end,

      input_fields: lambda do |_object_definitions|
        [
          { name: 'continuation_token', label: 'Continuation token', sticky: true,
            hint: 'Token from a previous result. When set, all other filters are ignored.' },
          { name: 'size', label: 'Page size', type: 'integer', sticky: true, default: 50,
            hint: 'Number of records to return per page.' },
          { name: 'submission_id', label: 'Submission ID', sticky: true },
          { name: 'fund_id', label: 'Fund ID', sticky: true },
          { name: 'status', label: 'Status', sticky: true },
          { name: 'submitter_id', label: 'Submitter ID' },
          { name: 'public_organization_id', label: 'Public organization ID' },
          { name: 'start_date', label: 'Created from', type: 'date_time' },
          { name: 'end_date', label: 'Created to', type: 'date_time' }
        ]
      end,

      execute: lambda do |_connection, input|
        query = if input['continuation_token'].present?
                  call('build_query', { 'continuationToken' => input['continuation_token'] })
                else
                  call('build_query', {
                   'size' => input['size'],
                   'submissionId' => input['submission_id'],
                   'fundId' => input['fund_id'],
                   'status' => input['status'],
                   'submitterId' => input['submitter_id'],
                   'publicOrganizationId' => input['public_organization_id'],
                   'startDate' => input['start_date'].present? ? input['start_date'].to_time.utc.iso8601 : nil,
                   'endDate' => input['end_date'].present? ? input['end_date'].to_time.utc.iso8601 : nil
                 })
                end
        path = query.present? ? "transactions?#{query}" : 'transactions'
        response = get(path)

        {
          'items' => response['items'] || [],
          'continuationToken' => response['continuationToken']
        }
      end,

      output_fields: lambda do |object_definitions|
        [
          { name: 'items', label: 'Items', type: 'array', of: 'object',
            properties: object_definitions['transaction'] },
          { name: 'continuationToken', label: 'Continuation token',
            hint: 'Pass this to the next call to get the next page. Empty on the last page.' }
        ]
      end
    },

    # -------------------------------------------------------------- organization
    get_organization: {
      title: 'Get organization',
      subtitle: 'Retrieve information about your Submittable organization',
      description: lambda do |_input, _picklist_label|
        "Get <span class='provider'>organization</span> in <span class='provider'>Submittable</span>"
      end,

      input_fields: lambda do |_object_definitions|
        []
      end,

      execute: lambda do |_connection, _input|
        get('organizations')
      end,

      output_fields: lambda do |object_definitions|
        object_definitions['organization']
      end
    }
  },

  triggers: {
    new_submission: {
      title: 'New submission',
      subtitle: 'Triggers when a new submission is received in Submittable',
      description: lambda do |_input, _picklist_label|
        "New <span class='provider'>submission</span> in <span class='provider'>Submittable</span>"
      end,
      help: 'Polls Submittable for submissions by submission date (oldest first). ' \
            'The API does not report edits, so this fires once per new submission.',

      input_fields: lambda do |_object_definitions|
        [
          { name: 'since', label: 'When first started, pick up submissions from',
            type: 'timestamp', optional: true, sticky: true,
            hint: 'First run only. Defaults to the time the recipe is started.' },
          { name: 'project_ids_include', label: 'Only these project IDs', optional: true,
            hint: 'Comma separated project GUIDs. Leave blank for all projects.' }
        ]
      end,

      poll: lambda do |_connection, input, closure|
        closure = {} unless closure.present?
        page_size = 100

        query = if closure['token'].present?
                  # Mid-pagination: the token carries the original filters.
                  call('build_query', { 'continuationToken' => closure['token'] })
                else
                  from = (closure['cursor'] || input['since'] || Time.now).to_time.utc.iso8601
                  call('build_query', {
                         'size' => page_size,
                         'DateFrom' => from,
                         'SortBy.Field' => 'date',
                         'SortBy.Order' => 'ascending',
                         'Projects.Include' => call('csv_to_array', input['project_ids_include'])
                       })
                end

        response = get("submissions?#{query}")
        items = response['items'] || []
        token = response['continuationToken']

        closure['cursor'] = items.last['submissionDate'] if items.any?
        closure['token'] = items.any? ? token : nil

        {
          events: items,
          next_poll: closure,
          can_poll_more: items.any? && token.present?
        }
      end,

      dedup: lambda do |record|
        record['submissionId']
      end,

      output_fields: lambda do |object_definitions|
        object_definitions['submission_list_item']
      end,

      sample_output: lambda do |_connection, _input|
        {
          'submissionId' => '2f8a6f9e-1c1b-4d58-9b6a-5d0f6c2b7a11',
          'projectId' => '8b1d4a52-3f0e-4c8a-a6f4-0c9d2e7b5e33',
          'submitterId' => 'c4f1a7d9-6b2e-4e0c-8a35-1d7e9b4f2a60',
          'reviewStageId' => '77aa88bb-1234-4abc-9def-001122334455',
          'submissionStatus' => 'new',
          'isArchived' => false,
          'isPaid' => false,
          'labels' => [],
          'reviewers' => [],
          'submitterFirstName' => 'Jane',
          'submitterLastName' => 'Doe',
          'submitterEmail' => 'jane@example.com',
          'submitterLastLoginDate' => '2026-01-20T08:00:00Z',
          'submissionTitle' => 'Spring Grant Application',
          'projectTitle' => 'Spring Grants',
          'submissionDate' => '2026-01-15T10:30:00Z',
          'isConcealed' => false,
          'isInitialFormEntryEditable' => false,
          'publicOrgId' => nil,
          'publicOrgVersion' => nil,
          'publicOrgName' => nil,
          'concealPublicOrgName' => false
        }
      end
    }
  },

  custom_action: true,
  custom_action_help: {
    learn_more_url: 'https://submittable-api.submittable.com/docs/v4/index.html',
    learn_more_text: 'Submittable API documentation',
    body: '<p>Call any Submittable v4 endpoint. Paths are relative to ' \
          '<b>https://submittable-api.submittable.com/v4/</b>.</p>'
  }
}
