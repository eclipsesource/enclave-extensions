# gws filter security concept

What the gws filter lets an agent do with a Google Workspace account, what it
never allows, and what remains possible. Enclave core enforces the policy. Its
threat model, guarantees, and enforcement order are in Enclave's
[request filter security concept](https://github.com/eclipse-enclave/enclave/blob/main/docs/security/request-filters.md).

## Threat model

As in Enclave core: assume the agent is fully compromised, for example by
prompt injection from a mail, document, or event it read. It runs any code in
the container, reads every file and variable there, and sends any HTTPS
request to allowlisted hosts, including with the placeholder token.

Trusted: the host, Enclave, the gateway, and this filter as installed and
reviewed through its capability summary. Out of scope: host compromise,
Google-side bugs, and abuse of a capability within its granted bounds.

The filter's goals:

- The OAuth client secret, refresh token, and access tokens never enter the
  container.
- Only routed operations of enabled capabilities reach Google, with their
  constraints and quotas applied.
- Nothing grants anyone outside the session access to the account's data.

## Request checks

The filter governs `www.googleapis.com`, `gmail.googleapis.com`,
`docs.googleapis.com`, `sheets.googleapis.com`, `slides.googleapis.com`,
`people.googleapis.com`, and `oauth2.googleapis.com`, and confines
`googleapis.com`, so the session reaches no other host below it. The gateway
terminates TLS for each governed host and denies by default. On these hosts it
also denies:

- any `Authorization` other than the placeholder, and the credential carriers
  `x-goog-api-key`, the `x-goog-iam-*` headers, cookies, and the `access_token`,
  `oauth_token`, `key`, and `api_key` parameters, so a token the agent brings
  cannot use the API as a channel out,
- parameter names with characters other than letters, digits, and `._~-`,
  denied by Enclave. This covers Google's system parameters `$key`, `$alt`,
  an alias of `alt` that would bypass the download checks, `$ct`, which
  overrides the request `Content-Type` so Google would parse the body
  differently than the gateway, and `$fields`,
- `upload_id` and `upload_protocol`, since resumable upload sessions
  authenticate by `upload_id` alone,
- the `x-goog-upload-*` and `x-upload-*` headers, which can switch the upload
  protocol so that Google reads a different part of the body than the filter
  checked,
- the field mask in `x-goog-fieldmask`, and `fields` on the routes that count
  message IDs from the response, since a mask without IDs would read a thread
  without counting it.

Bodies are read the way Google reads them. JSON keys in snake_case count as
their lowerCamelCase field, so `writers_can_share` cannot pass a condition on
`writersCanShare`, and duplicate keys are denied. A query parameter or JSON
key matches a route by its exact name or its snake_case alias, such as
`add_parents` for `addParents`. Other spellings of a checked name, such as
`Format`, `for_mat`, or `Trashed`, are denied. A body that a route reads must
be a JSON object with a JSON `Content-Type`, so JSPB
(`application/json+protobuf`), an array encoding that Sheets accepts, is
denied. A multipart upload must have exactly two parts, JSON metadata first,
without transfer encodings, as gws sends it. The recipient check reads the
second part, which Google sends as the message. Form-encoded bodies are
denied.

Routes follow Google's discovery documents. Where a parameter decides what an
operation does, the route lists the allowed values, so a new or unusual value
matches nothing: Gmail `format`, Drive `alt`, `uploadType`, `addParents`,
`trashed`. Gmail routes accept only `users/me`. `oauth2.googleapis.com` has no
routes, so the container cannot mint or inspect tokens. Sharing, Gmail
settings changes, inserts and imports, Gmail watch, batch requests, copies,
`drafts.send`, permanent deletes, and the edits in
[Edits that read or fetch elsewhere](#edits-that-read-or-fetch-elsewhere)
have explicit deny routes. Their denials name the reason, and the policy
summary in the container lists them under `deniedOperations`. Write routes
also list the JSON keys they allow, see [Allowed keys](#allowed-keys).

Content routes count what they reveal. `mail.metadata` counts the distinct
messages whose headers or snippet a response carries: metadata and minimal
reads of messages, threads, and drafts, and each thread of a thread list.
Gmail includes a body snippet in all of them. A Drive `files.list` whose `q`
mentions `fullText`, in any case and spacing, searches file content and needs
`files.read` with `resources: "*"`.

Denials use Google's error envelope with reason `enclaveFilter` and status
`PERMISSION_DENIED`, `RESOURCE_EXHAUSTED` for a quota, or `UNAVAILABLE` with
HTTP 502 when the token cannot be refreshed. Quota denials use 403, never 429,
which clients retry.

## Capabilities

| Capability | The agent can | Bounded by |
|------------|---------------|------------|
| `mail.metadata` | See senders, recipients, subjects, snippets, labels, and history of all mail | `mail.metadata` quota on distinct messages |
| `mail.read` | Read and search all mail, attachments, drafts, and send-as settings | `mail.read` quota on distinct messages |
| `mail.draft` | Create drafts with any content and recipients | Nothing is sent, `mail.drafts` quota |
| `mail.send` | Send new mail from the user's account | `recipients`, also on reply, receipt, and bounce addresses, `mail.sent` quota, `mail.recipients` quota on distinct addresses |
| `profile` | Read the user's display name | |
| `calendar.read` | Read all calendars the user sees, free/busy of colleagues | Nothing |
| `drive.metadata` | List all files and search them by name and metadata, read names, owners, and folders | Nothing |
| `files.read` | Download, export, and read Docs, Sheets, Slides, and search file content | `resources`, `files.read` quota on distinct files. Content search needs `resources: "*"` |
| `files.edit` | Edit Docs, Sheets, and Slides and change Drive metadata of existing files, without pulling in other files or URLs | `resources`, `files.written` quota |
| `files.replace` | Replace the content of existing files by upload. Drive converts uploads to Docs, Sheets, and Slides, past the edit checks | `resources`, `files.written` quota |
| `files.import` | Upload files that Drive converts to Docs, Sheets, or Slides, past the edit checks | `parents`, `files.written` quota |
| `files.create` | Create files, folders, Docs, Sheets, Slides, upload files without conversion | `parents`, `files.written` quota |
| `files.move` | Move files between folders | `resources` and `parents` |
| `files.delete` | Move files to the trash, recoverable for 30 days | `resources` |

## Grades

| Preset | Worst case within its bounds |
|--------|------------------------------|
| `metadata` | Learns who mails whom about what, snippets of 1000 messages, and the structure and names of all files |
| `readonly` | Reads 200 messages, snippets of 1000, 200 files, and all calendars, which may then leave through another channel |
| `drafts` | Plants 50 drafts with harmful content that the user may send unreviewed. Remote images in a draft send read content out when the user opens it |
| `send-eclipsesource` | Sends 20 mails to 50 colleagues in the user's name, phishing or leaking read content internally. Remote images and groups with external members carry content outside |
| `send-any` | Sends 20 mails to 50 addresses anywhere, a direct channel out for everything it read |
| `edit-all` | Rewrites or clears any file the user can edit with 500 write requests, each of which can rewrite a whole file, and creates files anywhere |

User presets narrow `files.*` to specific files or folders, which is the
recommended way to grant writes.

## Never allowed

| Operation | Why |
|-----------|-----|
| Drive permissions, access proposals, file fields that widen access (`writersCanShare`, `inheritedPermissionsDisabled`, `linkShareMetadata`, `downloadRestrictions`, relaxing `copyRequiresWriterPermission`), calendar ACLs | Sharing grants a principal outside the session lasting access to data. One call exposes a whole folder, bypasses every quota, and outlives the session. No constraint the filter can check makes that safe |
| Gmail settings: forwarding, filters, send-as, delegates, IMAP, POP | They route future mail to others, a persistent channel out |
| Inserting or importing messages, label changes, trash | Planted mail looks received, label changes hide mail from the user |
| Watch and push channels for Gmail, Drive, Calendar | Google pushes notifications to an address the caller picks |
| Batch endpoints | One body carries many requests the filter does not inspect |
| Resumable uploads | Content arrives in later requests that authenticate by `upload_id` alone |
| `drive files copy`, Sheets `copyTo` | One call reads a file and writes another, past `files.read` |
| `users.drafts.send` | The draft lives on the server, so its recipients cannot be checked |
| Edits that pull in other files or URLs, except converted uploads under `files.replace` and `files.import` | See [Edits that read or fetch elsewhere](#edits-that-read-or-fetch-elsewhere) |
| Allowing external URL access for a spreadsheet | Google's consent for `IMAGE` and `IMPORT` URL fetches, which cannot be withdrawn, backs up the formula check |
| Bodies that are not JSON objects sent as JSON, such as JSPB | The checks cannot see into them |
| Request kinds and fields the spec does not list | Kinds Google adds later may fetch, read other files, or notify people. They stay denied until reviewed |
| Comments in Docs, Sheets, and Slides | Comments mail the people they mention or assign, past the `mail.send` recipient check |
| Person chips and mentions, accepting, rejecting, or deleting Docs suggestions | Whether they notify people is not verified |
| Permanent delete and `emptyTrash` | Irreversible |
| Shortcuts, Apps Script projects, forms | A shortcut points into files outside the policy, scripts are code, forms collect input from others |
| Other users' mailboxes | Delegated access is not this user's data |

Moves are not part of `edit-all`. Moving a file into a folder shared with
others shares it by inheritance, so `files.move` checks the destination and is
meant for user presets with `within` folders. `parents: "*"` in `files.create`
or `files.move` lets the agent place content in any folder, including shared
ones.

## Edits that read or fetch elsewhere

`files.edit` is bounded by the files it may change. Some edits make Google
read another file or fetch a URL, which reads past the `files.read` checks or
sends data out through Google, whatever the network policy. Deny routes
placed before the edit routes catch them anywhere in a batch request, in
camelCase or snake_case.

| API | Denied | Why |
|-----|--------|-----|
| Docs `batchUpdate` | `insertInlineImage`, `replaceImage`, `insertRichLink` | Google fetches the image URL, a rich link reads the title of the linked file or page |
| Slides `batchUpdate` | `createImage`, `replaceAllShapesWithImage`, `replaceImage`, background pictures | Google fetches the image URL |
| Slides `batchUpdate` | `createSheetsChart`, `replaceAllShapesWithSheetsChart`, `refreshSheetsChart`, `createVideo` | Charts copy or link another spreadsheet, videos embed a Drive file or a YouTube video |
| Sheets values `update`, `append`, `batchUpdate` | Cells calling `IMPORTRANGE`, `IMPORTDATA`, `IMPORTFEED`, `IMPORTHTML`, `IMPORTXML`, `IMAGE`, or any other `IMPORT*` function | `IMPORTRANGE` reads another spreadsheet, the others fetch a URL |
| Sheets `batchUpdate` and `create` | The same functions in cell formulas and strings, validation, filter, and formatting conditions, gradient points, pivot formulas, and pasted data | As above |
| Sheets `batchUpdate` | HTML pastes, `findReplace`, `textToColumns` | Markup, replacements, and splitting can assemble a function name the filter never sees |
| Sheets `batchUpdate` and `create` | `importFunctionsExternalUrlAccessAllowed` | Google fetches URLs for `IMAGE` and the `IMPORT` functions other than `IMPORTRANGE` only once a person allowed it for the spreadsheet |
| Sheets `batchUpdate` and `create` | Data sources (BigQuery, Looker), objects reading from them, file chips | They read data from outside the spreadsheet |

The formula check matches the function names case-insensitively, also inside
other formulas and with whitespace before the parenthesis, whatever the
`valueInputOption`. A cell string counts too, since it becomes a formula once
a user edits the cell. Plain values and other formulas, such as
`=SUM(A1:A3)`, pass.

Drive converts content uploaded to an existing Doc, Sheet, or Slides file,
and to a new file with such a `mimeType`. The filter cannot inspect the
converted content or see the target's type, so every content upload to an
existing file needs `files.replace`, and every converting upload needs
`files.import`. Both lift the checks above, and no shipped preset enables
them.

## Allowed keys

Write routes list the JSON keys they allow. A request with another key
matches no allow route, so kinds and fields that Google adds later are denied
until the spec lists them. The lists follow docs/v1 and slides/v1 revision
20261109 and sheets/v4 revision 20261111.

| Route | Allowed |
|-------|---------|
| Docs `batchUpdate` | Every request kind except images, rich links, person mentions, comments, and suggestions |
| Sheets `batchUpdate` | Every request kind except data sources, `findReplace`, `textToColumns`, and comments. Not `commentsViewMode` |
| Slides `batchUpdate` | Every request kind except images, Sheets charts, videos, and comments. Page backgrounds only as solid fills, slide properties only `isSkipped` |
| Drive `files.update`, also with an upload | `name`, `description`, `starred`, `trashed`, `properties`, `appProperties`, `folderColorRgb`, `contentHints`, `originalFilename`, `modifiedTime`, `viewedByMeTime`, `copyRequiresWriterPermission`, `viewersCanCopyContent` |
| Drive `files.create`, also with an upload | The update fields except `trashed` and the copy restrictions, plus `id`, `mimeType`, `parents`, and `createdTime` |
| Gmail `messages.send` | `raw` and `threadId`, upload metadata only `threadId` |
| Sheets values `update`, `append`, `batchUpdate`, `clear`, `batchClear` | The fields of their request type |
| Sheets `create` | `properties`, `sheets`, `namedRanges`, `developerMetadata`, and every sheet field except `commentAnchors` |
| Docs and Slides `create` | `title`, for Slides also `presentationId` |

The check covers the request kinds of a batch, not the fields below them,
apart from the Slides backgrounds and slide properties. Deny routes catch the
known dangerous fields at any depth.

## Residual risks

- Internal phishing. `send-eclipsesource` sends from the user's real account,
  which colleagues trust. The check covers the recipient domain, not the
  content. Prefer `drafts` and send after review.
- Arbitrary content in allowed files. `files.edit` writes any text, values,
  and plain formulas into the files it may change, including files shared
  outside the organization, and `edit-all` can overwrite or clear every file
  the user can edit. Version history restores content. Trash is not part of
  `edit-all`.
- Exfiltration through other allowlisted hosts. The filter governs its hosts
  only. Anything the agent reads can leave through any other reachable host.
  Quotas bound how much the agent reads, not where it goes. The filter
  confines `googleapis.com`, so other Google APIs, such as Cloud Storage,
  cannot take a token the agent brings. Allowlisted Google domains outside
  it, such as `google.com`, still carry data out, see the README's
  [Open issues](README.md#open-issues).
- Mail side channels. The recipient check covers recipients and the reply,
  receipt, and bounce addresses, not the body. Remote images in HTML mail and
  drafts send data in their URLs when opened. An allowed domain can contain
  groups with external members.
- New fields. A field Google adds inside an allowed request kind passes until
  a deny route names it.
- Exfiltration through granted writes. Send presets mail content out.
  `files.edit` and `files.create` put content where others can read it.
- Fetches the filter cannot see. With `files.replace` or `files.import`,
  formulas and linked images in uploaded content take effect after
  conversion. Formulas already in an allowed file, such as
  `IMPORTDATA(A1)`, fetch whatever the agent writes into the cells they
  read, and custom functions of a script bound to a spreadsheet run their
  own code. The formula check matches the English function names. Google's
  per spreadsheet consent still blocks URL fetches by `IMAGE` and the
  `IMPORT` functions other than `IMPORTRANGE`, unless a person allowed them
  or an admin allowlists URLs.
- Reads through existing links. `IMPORTRANGE` formulas and linked charts that
  are already in an allowed file show data of other files when the file is
  read.
- Metadata. `mail.metadata` exposes subjects, addresses, and body snippets of
  up to 1000 distinct messages per session in the shipped presets.
  `drive.metadata` exposes names, owners, and folders. If the grant also
  carries `drive.readonly`, Drive returns `thumbnailLink`, a rendering of the
  file's first page, for files outside `files.read`.
- No response filtering. Lists return everything Google returns for the
  request.
- Persistence. Drafts and edits can carry instructions for later sessions or
  for people. Read content is untrusted input for every agent.
- Quotas count content reads, not searches. In `readonly`, Gmail and Drive
  content searches reveal whether items contain a term beyond the read quota.
  A new session starts at zero.

## OAuth scopes as a second layer

Each capability declares the narrowest Google scope that covers its
operations. `enclave filters login gws --preset <preset>` requests exactly the
preset's scopes, so Google rejects operations outside them even if a route
were wrong.

| Grant | Google still allows beyond the filter |
|-------|---------------------------------------|
| `metadata` | Metadata only. Gmail rejects search queries and bodies |
| `readonly` | Reading more, such as Gmail settings and Drive comments and permissions. No writes, though Google's discovery document also lists `drive.readonly` for Slides `batchUpdate` |
| `drafts` | Creating drafts. `gmail.drafts.create` cannot send, update, or delete |
| send presets | Sending to anyone. Only the filter limits recipients |
| `edit-all` | Everything in Drive, including sharing, moving, and deleting. Only the filter blocks these |
| `files.edit` alone, as in a user preset for specific files | Editing any Doc, Sheet, Slides file, and Drive metadata the user can edit. No sharing, uploads, or permanent deletes |

A grant covers every preset whose scopes it includes, and Enclave picks the
narrowest covering grant. A broad grant, such as one imported from `gws auth
export`, removes this layer for narrower presets. Keep one grant per preset.

## OAuth app setup

- Use an Internal app in the Workspace organization. Only organization
  accounts can authorize it, and Google requires no verification. Gmail read
  scopes and the Drive read and full scopes are restricted scopes that need
  verification for External apps in production.
- An External app in Testing status gets refresh tokens that expire after 7
  days. Log in again weekly, or use an Internal app.
- The Desktop client secret is not confidential in Google's model for
  installed apps. Enclave still keeps it, and every refresh token, in its
  state directory with mode 0600, never in the container.
- `enclave filters logout gws --all` deletes the grants and revokes them at
  Google. Users can also revoke the app in their Google Account under
  Security, third-party connections.

## Workspace admin considerations

- If the organization restricts API access for internal or unconfigured apps,
  an admin has to allow the project's OAuth client under Security, API
  controls.
- Admins see the app's grants in the OAuth token audit log and can revoke them
  per user. Gmail and Drive audit logs attribute the agent's actions to the
  user and the client ID.
- Organization controls still apply on Google's side: external sharing
  settings, Gmail and Drive DLP rules, and per organizational unit service
  access. Restricting external sharing and external mail limits the
  exfiltration risks above.
