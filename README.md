# Submittable Connector for Workato

A custom [Workato](https://www.workato.com/) connector for the [Submittable API v4](https://submittable-api.submittable.com/docs/v4/index.html). It lets recipes read submissions, submitters, form answers, reviews, projects, funds and transactions from Submittable, and trigger on new submissions.

The connector is a single Workato SDK source file: [submittable_connector.rb](submittable_connector.rb).

## Installation

1. In Workato, go to **Tools > Platform tools > Connector SDK** and choose **Create connector > Via code**.
2. Paste the contents of [submittable_connector.rb](submittable_connector.rb) into the **Source code** tab.
3. Optionally upload [submittable-logo.jpeg](submittable-logo.jpeg) as the connector logo.
4. Save, then use **Test code** or release the connector to use it in recipes.

## Authentication

The connector uses a Submittable API key.

1. In Submittable, create a key under **Settings > Integrations > API**.
2. In the Workato connection, paste it into **API key**.

The key is sent as HTTP Basic auth (key as the username, blank password) to `https://submittable-api.submittable.com/v4/`. The connection test calls `GET submissions?size=1`.

## Actions

| Action | Description |
| --- | --- |
| Get submission | Retrieve a single submission by ID. |
| Search submissions | Page through submissions with filters (text, statuses, projects, labels, archived status, date range, sorting). |
| Get submitter | Retrieve the submitter of a submission. |
| **Get full submission** | Composite action. Merges the submission, full form entries with answers, submitter, project, reviews, transactions and history into one record, with readable field labels, option labels, staff and fund names, and a flat `answers` list that is easy to loop over. |
| Get submission entries | Retrieve a submission's form entries, optionally filtered by form type (e.g. `internal`) and limited to the latest entry per type. |
| Find submissions by submitter / fund | Find submissions by submitter (email, name or ID), by project name, or by Submittable fund (via transactions). |
| Get entry | Retrieve one form entry, with answers, by ID. |
| Get submission reviews | Retrieve the review entries for a submission. |
| Search submission history | Page through submission activity history. |
| Get project / Search projects | Retrieve projects, including review stages. |
| Get form / Search forms | Retrieve form definitions. |
| Get label / Search labels | Retrieve labels. |
| Get fund / Search funds | Retrieve funds. Search can filter by text, funding status (available/depleted) and creation date. |
| Get transaction / Search transactions | Retrieve payments and awards. |
| Get organization | Retrieve information about your Submittable organization. |

The connector also supports Workato's custom action, so any other v4 endpoint can be called with the same connection.

### Triggers

| Trigger | Description |
| --- | --- |
| New submission | Polls for new submissions by submission date, oldest first. It follows continuation tokens within a poll and de-duplicates by submission ID. |

## Notes

- **Pagination:** search actions return `items` and a `continuationToken`. Pass the token to the next call to fetch the next page. Filters apply to the first request only; when a token is set, other filters are ignored.
- **Query format:** multi-value filters are sent as repeated keys (e.g. `Statuses.Include=a&Statuses.Include=b`). In the recipe editor, enter them as comma-separated values or pick from the list.
- **API call volume:** *Get full submission* and *Get submission entries* make several calls. Form definitions are looked up once per distinct form. File download URLs cost one call per file, so they are off by default.
- **Sensitive data:** answers can include bank details or SSN/EIN, depending on your project forms. Restrict recipe access accordingly.
- **Permissions:** resolving staff names needs permission to view team members in Submittable.

## Development

The Ruby version is pinned in [.ruby-version](.ruby-version) (3.3.14). To run or test locally, use the [Workato SDK gem](https://github.com/workato/workato-connector-sdk):

```sh
gem install workato-connector-sdk
workato exec test --connector=submittable_connector.rb --connection=<your-connection-name>
```

## Links

- [Submittable API v4 docs](https://submittable-api.submittable.com/docs/v4/index.html)
- [Workato Connector SDK docs](https://docs.workato.com/developing-connectors/sdk.html)
