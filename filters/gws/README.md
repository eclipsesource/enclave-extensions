# gws

Request filter for the Google Workspace APIs that the
[gws CLI](https://github.com/googleworkspace/cli) uses: Gmail, Calendar, Drive,
Docs, Sheets, and Slides. The OAuth credential stays on the host. Enclave's
gateway forwards a request only if the preset chosen at session start allows
it, checks recipients and file locations, and caps reads and sends per session.

Pair it with the [gws feature](../../features/gws/README.md), which installs
`gws`. The security concept is in [SECURITY.md](SECURITY.md).

## Owner

Stefan Dirix ([sdirix@eclipsesource.com](mailto:sdirix@eclipsesource.com))

## How it is used

Give the agent mail, calendar, and document access at a chosen level: read
only, draft replies for review, send within the company, or edit documents.
Pick the level per session with `--filters gws:<preset>`.

## State

🟡 Occasionally used, may receive updates. Experimental. Needs an Enclave
version with request filters.

## Requirements

- Docker or Podman backend, restricted network mode, and the gateway. Enclave
  refuses to start a session with a filter otherwise.
- An Enclave version whose filter specs support `jsonAllowedKeys` and
  `rfc822: destinations`. Older versions reject the spec.
- A Google Workspace account and a Google Cloud project in its organization.

## Install

```bash
enclave filters add eclipsesource/enclave-extensions --name gws
enclave features add eclipsesource/enclave-extensions --name gws
```

## Google Cloud setup

Once per organization or user:

1. Create or pick a Google Cloud project in your Workspace organization.
2. Enable the Gmail, Google Drive, Google Calendar, Google Docs, Google Sheets,
   Google Slides, and People APIs:

   ```bash
   gcloud services enable gmail.googleapis.com drive.googleapis.com \
     calendar-json.googleapis.com docs.googleapis.com sheets.googleapis.com \
     slides.googleapis.com people.googleapis.com --project <project>
   ```

3. In Google Auth Platform (the OAuth consent screen), set the audience to
   Internal. Only users of your organization can authorize it, it needs no
   verification, and its refresh tokens do not expire after 7 days.
4. Under Clients, create an OAuth client of type Desktop app and download its
   JSON.

Then log in on the host:

```bash
enclave filters login gws --client-secret ~/Downloads/client_secret_<id>.json
```

This stores the client and opens the browser for the default preset's scopes.
Later logins reuse the stored client. Delete the downloaded JSON afterwards.
Client and grants live in Enclave's state directory
(`~/.local/state/enclave/filters/gws/` on Linux) with mode 0600.

## Usage

```bash
enclave --features +gws --filters gws                      # preset readonly
enclave --features +gws --filters gws:drafts
enclave filters show gws --preset drafts                   # merged preset, scopes, grant status
enclave filters login gws --preset drafts                  # grant for that preset
enclave filters grants gws
enclave filters logout gws --grant drafts
```

Inside the session, `ENCLAVE_ACTIVE_FILTERS` lists the active filters as
`name:preset`, and `$ENCLAVE_FILTER_SUMMARY_DIR/gws.json`
(`/opt/enclave/filters/gws.json`) holds the policy summary: enabled
capabilities, constraint values, quotas, and `deniedOperations`. The
`gws-filter` skill of the gws feature tells the agent to read them.

Each preset needs a grant that covers its scopes. Enclave picks the covering
grant with the fewest scopes, so one grant per preset you use keeps each
session's token as narrow as its preset. A broader grant also covers narrower
presets.

A grant from gws itself works too, with the scopes gws requested:

```bash
gws auth export --unmasked > authorized_user.json   # on a host with gws
enclave filters login gws --import authorized_user.json
```

## Presets

| Preset | Extends | Adds | Quotas per session | Scopes |
|--------|---------|------|--------------------|--------|
| `metadata` | | `mail.metadata`, `drive.metadata` | `mail.metadata` 1000 | `gmail.metadata`, `drive.metadata.readonly` |
| `readonly` (default) | `metadata` | `mail.read`, `calendar.read`, `files.read` | plus `mail.read` 200, `files.read` 200 | `gmail.readonly`, `calendar.readonly`, `drive.readonly` |
| `drafts` | `readonly` | `mail.draft`, `profile` | plus `mail.drafts` 50 | plus `gmail.drafts.create`, `userinfo.profile` |
| `send-eclipsesource` | `drafts` | `mail.send` to `@eclipsesource.com` | plus `mail.sent` 20, `mail.recipients` 50 | plus `gmail.send` |
| `send-any` | `drafts` | `mail.send` to anyone | plus `mail.sent` 20, `mail.recipients` 50 | plus `gmail.send` |
| `edit-all` | `readonly` | `files.edit` and `files.create`, everywhere | plus `files.written` 500 | `gmail.readonly`, `calendar.readonly`, `drive` |

`send-eclipsesource` checks every `To`, `Cc`, `Bcc`, and `Resent-*` address
and the addresses that receive replies, receipts, and bounces: `Reply-To`,
`Mail-Reply-To`, `Mail-Followup-To`, `Disposition-Notification-To`,
`Return-Receipt-To`, and `Errors-To`. `edit-all` does not move or trash files
and does not replace or convert uploaded content. Enable `files.move`,
`files.delete`, `files.replace`, or `files.import` in a user preset.
`mail.metadata` counts each message whose headers or snippet a response
carries, since Gmail includes a body snippet in metadata reads and thread
lists. `mail.recipients` counts distinct checked addresses across all sent
messages.

## gws commands per preset

| Command | Allowed in |
|---------|------------|
| `gws schema`, discovery | Every preset |
| `gmail users messages list` and `threads list` without `q`, `messages get`, `threads get`, and `drafts get` with `format` `metadata` or `minimal`, `labels`, `history`, `getProfile` | Every preset |
| `drive files list` without `fullText` in `q`, `drive files get` without `alt=media`, `drive about get` | Every preset |
| `gmail +triage`, `gmail +read`, any search with `q`, full messages, threads, attachments, drafts | `readonly` and up |
| `calendar +agenda`, `calendar events list`, `workflow +meeting-prep`, `workflow +weekly-digest` | `readonly` and up |
| `sheets +read`, `drive files get` with `alt=media`, `drive files export`, Docs, Sheets, Slides `get` | `readonly` and up |
| `drive files list` with `fullText` in `q` | `readonly` and up, not with a `files.read` list of files or folders |
| `gmail +send`, `+reply`, `+reply-all`, `+forward` with `--draft` | `drafts`, both send presets |
| `gmail +send`, `+reply`, `+reply-all`, `+forward` | `send-eclipsesource` (recipients checked), `send-any` |
| `docs +write`, `sheets +append`, `drive files update` without upload, Docs, Sheets, Slides `batchUpdate` | `edit-all` |
| `drive +upload` and `drive files create` without conversion, `drive files generateIds`, Docs, Sheets, Slides `create` | `edit-all` |
| `drive files update` with `addParents` or `removeParents`, or `trashed: true` | User presets with `files.move` or `files.delete` |
| `drive files update` with an upload | User presets with `files.replace` |
| `drive +upload` and `drive files create` with a Docs, Sheets, or Slides `mimeType` | User presets with `files.import` |

Denied in every preset: `gmail +watch`, `gmail users drafts send`, draft updates
and deletes, label changes (including marking as read and archiving), trashing
mail, inserting or importing mail, every Gmail settings change,
`calendar +insert` and every calendar write, `drive permissions`,
`drive files copy`, `drive files delete`, `drive files emptyTrash`, comments,
revisions, watch channels, `chat +send`, `events +subscribe`, `events +renew`,
`script +push`, `modelarmor` helpers, `workflow +email-to-task`,
`workflow +file-announce`, the Tasks part of `workflow +standup-report`, and
every API not listed above. Edits are denied when they pull in another file
or a URL, or may notify people: images, rich links, Sheets charts, videos,
comments, and person chips and mentions in Docs, Sheets, and Slides, Docs
suggestions, Sheets cells and rules that call `IMPORTRANGE`, `IMPORTDATA`,
`IMPORTFEED`, `IMPORTHTML`, `IMPORTXML`, or `IMAGE`, data sources, file
chips, HTML pastes, find and replace, text to columns, and allowing external
URL access for a spreadsheet. The most dangerous of these have explicit deny
routes, so their denial names the reason and the summary lists them under
`deniedOperations`. These checks do not apply to uploads that Drive converts,
see `files.replace` and `files.import`.

Write routes allow only listed JSON keys: the request kinds of Docs, Sheets,
and Slides `batchUpdate`, the File fields of Drive updates and creates, and
the fields of Gmail sends, Sheets value writes, and Docs, Sheets, and Slides
creates. [SECURITY.md](SECURITY.md#allowed-keys) lists them. Kinds and
fields that Google adds later are denied until the spec lists them. Bodies
the filter reads must be JSON objects sent as JSON, so JSPB
(`application/json+protobuf`) is denied.

## Capabilities

| Capability | Operations | Scope | Constraint | Counter |
|------------|------------|-------|------------|---------|
| `discovery` | Discovery documents, always on, sent without credential | | | |
| `mail.metadata` | Profile, labels, history, lists without `q`, messages, threads, and drafts in `metadata` or `minimal` format | `gmail.metadata` | | `mail.metadata`, distinct messages |
| `mail.read` | Searches, full and raw messages, threads, drafts, attachments, send-as addresses | `gmail.readonly` | | `mail.read`, distinct messages. Thread searches count `mail.metadata` |
| `mail.draft` | Create drafts | `gmail.drafts.create` | | `mail.drafts`, drafts |
| `mail.send` | Send new messages | `gmail.send` | `recipients` | `mail.sent`, messages. `mail.recipients`, distinct addresses |
| `profile` | Your display name from People | `userinfo.profile` | | |
| `calendar.read` | Calendar list, calendars, events, settings, colors, free/busy | `calendar.readonly` | | |
| `drive.metadata` | File lists, searches by name and metadata, file metadata, shared drives, about | `drive.metadata.readonly` | | |
| `files.read` | Drive downloads and exports, Docs, Sheets, Slides reads, content searches (`fullText`) | `drive.readonly` | `resources`, default `"*"` | `files.read`, distinct files |
| `files.edit` | Drive metadata updates, Docs, Sheets, Slides edits that pull in no other file or URL | `drive.metadata`, `documents`, `spreadsheets`, `presentations` | `resources` | `files.written`, requests |
| `files.replace` | Drive content updates by upload. Drive converts uploads to Docs, Sheets, and Slides, past the edit checks | `drive` | `resources` | `files.written`, requests |
| `files.import` | Drive uploads converted to Docs, Sheets, or Slides, past the edit checks | `drive` | `parents` | `files.written`, requests |
| `files.create` | Drive creates, uploads without conversion, ID generation, Docs, Sheets, Slides creates | `drive` | `parents` | `files.written`, requests |
| `files.move` | Drive updates with `addParents` or `removeParents` | `drive` | `resources`, `parents` | `files.written`, requests |
| `files.delete` | Move to trash | `drive` | `resources` | `files.written`, requests |

Constraint values:

| Kind | Value |
|------|-------|
| `recipients` | `"*"` or a list of `user@domain`, `@domain`, `@*.domain` |
| `resources`, `parents` | `"*"` or `{ ids: [...], within: [...] }` |

`ids` lists files or folders by ID. `within` lists folders or shared drives.
A file passes if it or one of its ancestors, up to 32 levels, is listed.
Docs, Sheets, and Slides creates and `generateIds` have no parent folder, so
they need `parents: "*"`. A content search (`fullText`) matches files
anywhere, so it needs `resources: "*"` in `files.read`. The spec marks these
five routes with `wildcardOnly`.

`files.written` counts requests, not changes. One `batchUpdate` can rewrite a
whole file.

## User presets

User presets live in `~/.config/enclave/filters/gws/presets/<name>.yaml` on
Linux, under Enclave's config directory. They can extend shipped presets, and
one with a shipped preset's name replaces it. Projects cannot define presets.

Specific documents, for example a report and its data sheet:

```yaml
description: Read mail. Read and edit the Q3 report and its data.
extends: readonly
allow:
  files.read: { resources: { ids: ["1AbC...reportDocId", "1XyZ...dataSheetId"] } }
  files.edit: { resources: { ids: ["1AbC...reportDocId", "1XyZ...dataSheetId"] } }
quotas:
  files.read: 20
```

`files.edit` needs no `drive` scope, so the grant for this preset cannot share
or permanently delete files at Google either.

One folder, with everything below it:

```yaml
description: Work inside the Project X folder only.
extends: readonly
deny: [drive.metadata]           # hide the names of all other files
allow:
  files.read: { resources: { within: ["1FoLd...projectXId"] } }
  files.edit: { resources: { within: ["1FoLd...projectXId"] } }
  files.create: { parents: { within: ["1FoLd...projectXId"] } }
  files.move: { resources: { within: ["1FoLd...projectXId"] }, parents: { within: ["1FoLd...projectXId"] } }
  files.delete: { resources: { within: ["1FoLd...projectXId"] } }
```

Without `drive.metadata` the agent cannot list or search Drive, so give it the
IDs it needs. Docs, Sheets, and Slides creates are denied here, since they land
in My Drive. Create those files with `drive files create` and a `parents`
folder instead.

Run it with `enclave --features +gws --filters gws:project-x` after logging in
with `enclave filters login gws --preset project-x`.

### Finding IDs

| Item | URL | ID |
|------|-----|----|
| Document | `https://docs.google.com/document/d/<id>/edit` | `<id>` |
| Spreadsheet | `https://docs.google.com/spreadsheets/d/<id>/edit#gid=0` | `<id>`, not the `gid` |
| Presentation | `https://docs.google.com/presentation/d/<id>/edit` | `<id>` |
| Drive file | `https://drive.google.com/file/d/<id>/view` | `<id>` |
| Folder or shared drive | `https://drive.google.com/drive/folders/<id>` | `<id>` |

Or search in a session with `drive.metadata`:

```bash
gws drive files list --params '{"q": "name contains '\''Report'\''", "fields": "files(id,name,mimeType)"}'
```

## Limitations

- Bodies the filter inspects are capped: Drive multipart uploads and updates at
  64 MiB, Gmail sends at 40 MiB, other JSON bodies at 10 MiB. Resumable
  uploads are not supported. gws uses multipart uploads, so larger files fail.
- Multipart uploads must look like gws sends them: exactly two parts, JSON
  metadata first, no transfer encoding.
- `threads list`, `threads get`, and `drafts get` with `fields` are denied,
  since a field mask could hide the IDs the `mail.read` and `mail.metadata`
  quotas count.
- Edits cannot insert images, rich links, Sheets charts, videos, comments, or
  person chips and mentions, or accept, reject, or delete Docs suggestions.
  Sheets edits cannot use data sources, file chips, HTML pastes, find and
  replace, or text to columns. Add those by hand.
- Request kinds and fields newer than the discovery revisions the spec
  follows are denied until the spec lists them.
- Drive updates cannot change sharing settings, `mimeType`, `parents` in the
  body, `contentRestrictions`, or `shortcutDetails`. Drive creates cannot set
  sharing settings or `contentRestrictions`.
- Request bodies the filter reads must be JSON objects with a JSON
  `Content-Type`. JSPB is denied.
- The filter confines `googleapis.com`: sessions with it cannot reach other
  `googleapis.com` hosts, such as the Gemini API that the theia, pi, and
  opencode allowlists include. Session start names the allowlisted ones it
  blocks.
- Replacing file content by upload needs `files.replace`, and uploads that
  Drive converts need `files.import`. No shipped preset enables them, since
  converted content skips the edit checks.
- The Sheets formula check denies any text that looks like a call of an
  `IMPORT*` function or `IMAGE`, also in plain values such as
  `Imports (2025)`.
- `gmail +triage` always sends a search query and needs `readonly`. In
  `metadata`, list by label with `labelIds`.
- Drafts can be created but not updated, deleted, or sent through the API.
  Send them from Gmail, or send directly with a send preset.
- A Drive create with an explicit `mimeType` other than folder, Docs, Sheets,
  or Slides is denied. Omit `mimeType` for regular files.
- Listing shared drives needs `drive.readonly` at Google, so it fails with a
  `metadata` grant alone.
- A shortcut in an allowed folder does not make its target allowed.
- Quotas count per session and reset with a new session.
- Tokens that Google rotates during a session are kept in memory only.

## Open issues

Gaps the filter cannot close by itself.

- **Other Google domains.** Allowlists with `google.com`, such as those of
  theia, pi, and opencode, reach Google services there, a channel out like
  any other allowlisted host.
- **Fields inside allowed request kinds.** `jsonAllowedKeys` checks the
  request kinds of a batch, not the fields below them. Deny routes name the
  known fields that fetch a URL, read another file, or may notify people,
  such as `stretchedPictureFill`, `richLinkProperties`, and
  `personProperties`. A field Google adds inside an allowed kind passes until
  a deny route names it. Listing every field would copy the discovery schemas
  into the spec. Diff each new discovery revision against the spec.
- **Function names.** The formula check matches English function names.
  Whether the Sheets API accepts localized names, for example in a German
  locale spreadsheet, is not verified. Google still blocks URL fetches by
  `IMAGE` and the `IMPORT` functions until a person allows them per
  spreadsheet, which the filter keeps the agent from doing, unless an admin
  allowlists URLs. That setting does not cover `IMPORTRANGE`.
- **Mail content.** Remote images in HTML bodies send data in their URLs when
  someone opens the mail or draft. An allowed domain can have groups with
  external members. Message bodies cannot be checked.
- **Notifications.** Whether person chips, mentions, and accepting or
  rejecting Docs suggestions notify people is not verified. They are denied
  until it is.
- **Converted uploads.** Drive converts content uploaded to a Doc, Sheet, or
  Slides file, and routes cannot see the target's type, so every content
  upload sits in `files.replace`. That Drive converts on update comes from a
  third-party report, not Google's documentation. A route condition on the
  target's `mimeType` in core would let `files.edit` keep uploads to other
  files.
- **Scopes.** `files.create`, `files.move`, `files.delete`, `files.replace`,
  and `files.import` need `drive`, which can share and delete at Google, so
  `edit-all` keeps it. `mail.read` keeps `gmail.readonly`, since
  `sendAs.list` needs it. The granular `gmail.messages.readonly` and
  `gmail.drafts.readonly` scopes are not tested together with
  `gmail.metadata`, which restricts a token's other Gmail scopes.
