# Google Cloud Platform setup

An application calls the Google Application Script in order to post-process generated lesson materials. Instructions below contains all the necessary steps need to set up the integration.

All environment variables and user names provided here have been set up to automate deployment on [Cloud66](https://www.cloud66.com) service stacks. If you plan to use another service provider please change all the variables accordingly.

1. [Set up](#set-up)
2. [How to update Google Application Script](#how-to-update-google-application-script)

## Set up

### Update host application's routes

In order to intercept OAuth callback host application's routes should be updated.
In the sample bellow the Engine is mounted to `/lcms` and this prefix is used in the interceptor.
You can replace it with whatever prefix has been used in your own project.
```ruby
# config/routes.rb

mount Lcms::Engine::Engine, at: '/lcms'

# OAuth2 redirect interceptor
get 'oauth2callback', to: redirect(path: '/lcms/oauth2callback')
```

### Login to google

All google docs will be saved under this account. Also, this Google Account should have access to all source documents which will be imported into the system.

### Create project

Name it whatever you like, i.e. LCMS-dev at [google cloud](https://console.cloud.google.com)

### Enable Google API

Enable Google Drive API, Google Apps Script Execution API for that [project](https://console.cloud.google.com/apis/library)

### Set up google auth

#### Credentials

Create credentials:
  - type oAuth Client ID
  - Application type: Web Application,
  - Application Name: up to you, i.e. lcms-cli-dev

Download credentials JSON file.

###### Local development

Copy downloaded JSON file to `config/google/client_secret.json`

###### Server

Make sure you're executing commands under _cloud66-user_
```bash
$ sudo -i -u cloud66-user
```

Make sure that the following directory exists on a server and is symlinked correctly
```bash
$ mkdir -p "$STACK_BASE/shared/google"
$ chown cloud66-user:cloud66-user "$STACK_BASE/shared/google"
$ ln -nsf "$STACK_BASE/shared/google" "$STACK_PATH/config/google"
```

Copy downloaded JSON file and set appropriate ownership and access rights for it (where `cloud66-user` is a system username under which web application is running)

```bash
$ cp client_secret.json $STACK_BASE/shared/google/
$ cd $STACK_BASE/shared/google
$ sudo chown cloud66-user:cloud66-user client_secret.json
$ sudo chmod 755 client_secret.json
```

#### Application token

If you generate token on a remote server, then make sure you're executing commands under _cloud66-user_

```bash
$ sudo -i -u cloud66-user
```

Run rake task providing the domain name which is registered as _Authorized redirect URIs_ in Google OAuth client.
You will be asked to go by link, give app permissions and paste code into the terminal

```bash
$ bundle exec rake google:setup_auth["https://example.com"]
```

This will create `config/google/app_token.yaml` (which points to the shared directory via symlink). Change the ownership of the `app_token.yaml` otherwise it will not be accessible for the application:

```bash
$ cd $STACK_BASE/shared/google
$ chown cloud66-user:app_writers app_token.yaml
$ sudo chmod g+w app_token.yaml
```

#### Add Google App script

- go to https://www.google.com/script/start/
- copy-paste content of `config/scripts/Code.gs` there and save
- at top menu Resources->Cloud Platform Project set project from step 2 (you need to paste *project number*)
- at top menu Publish->Deploy As API Executable set version v1, access Only myself
- save Current API ID somewhere (wil be used for _GOOGLE_APPLICATION_SCRIPT_ID_), click Close on that annoying window (update will not close it)
- choose any function and run it, it'll request permissions - grant them (there will be security warnings, just ignore them)

### Create special folder in Google Drive

All materials will be saved there. Give view only to all by link, keep folder id (last part of url) for _GOOGLE_APPLICATION_FOLDER_ID_,
copy to the root of the this folder these documents and keep their IDs for (_GOOGLE_APPLICATION_TEMPLATE_LANSCAPE_, _GOOGLE_APPLICATION_TEMPLATE_PORTRAIT_):
- [LANDSCAPE](https://docs.google.com/document/d/1pXQDNKYOJYT6OTPnp8gsTWAydg5B9GTRibaWspmX4oE)
- [PORTRAIT](https://docs.google.com/document/d/1ijuZhGQXkPBxcZT4DRyNVY-qmI0xyVvSzVFqckOpsCc)

### Update corresponding env-file in the project
```
GOOGLE_APPLICATION_FOLDER_ID=
GOOGLE_APPLICATION_SCRIPT_ID=
GOOGLE_APPLICATION_TEMPLATE_PORTRAIT=
GOOGLE_APPLICATION_TEMPLATE_LANSCAPE=
```

## How to update Google Application Script

1. Proceed to Google Drive for an account which has been used to create the Google Application Script (see _Add script_ section in [Set up](#set-up))

2. Update script content

3. Re-publish the script:

- `Publish->Deploy As API Executable`
- Set new version
- `Update` & `Close`
- Choose any function and run it, it'll request permissions - grant them (there will be security warnings, just ignore them)

> **Saving the script is not enough.** `scripts.run` executes the version pinned
> to the API Executable deployment, so an edit that is only saved in the editor
> never reaches the app — step 3 is mandatory. To iterate without bumping a
> version on QA/staging, set `GOOGLE_APPLICATION_SCRIPT_DEV_MODE=true`, which
> runs the most recently saved (HEAD) version instead.

### Checking which version is actually running

`postProcessing` returns `{version, brandmark, pageNumber}` and
`Google::ScriptService` writes it to the Rails log after every export:

```
Google Apps Script postProcessing <doc id>: version="2026-09-21" brandmark="inserted OK" pageNumber="inserted OK"
```

`version` is `SCRIPT_VERSION` from the **deployed** script, not from
`config/scripts/Code.gs` in the repo. If the two disagree — or the line is
missing / `version=nil` — the deployment is stale and needs step 3 above, and no
amount of editing the repo copy will change the generated document. Bump
`SCRIPT_VERSION` whenever you redeploy.

`brandmark` and `pageNumber` carry each insert's outcome. These inserts fail
soft, so that one broken insert cannot abort a whole export — which is exactly
why a failure is otherwise invisible and shows up only as a missing logo or a
footer still reading `{page_number}`.

`pageNumber` is one of:

| Value | Meaning |
| --- | --- |
| `inserted in place` | The intended layout — the number sits where the template put `{page_number}`. |
| `inserted as own line — container TABLE_CELL would not take one` | The placeholder is inside the footer table, which cannot hold a page number, so it went on a right-aligned line of its own below the breadcrumb. To get the intended layout, rebuild that footer line in the template as a paragraph with a right-aligned tab stop instead of a table row. |
| `skipped — {page_number} not found in footer` | The template footer has no placeholder. |
| `inserted … (unstyled: …)` | The number is there and live, but could not be restyled — cosmetic only. |
| `insert failed (container …, N paragraphs, M tables): …` | Neither placement worked; the footer keeps the literal marker. The message carries the container type, the footer's shape and the exception text from each attempt. |
