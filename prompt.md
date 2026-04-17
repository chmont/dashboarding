Here is a detailed README-style workflow spec you can reuse later as a prompt.

# Grafana Client Dashboard Script Workflow

## Overview

This workflow is for managing Grafana client folders and dashboards through scripts.

The system supports five separate actions:

1. Create Folder
2. Send Dashboard
3. Onboard New Subscription
4. Delete Dashboard
5. Delete Folder

A top-level run script will act as the entry point. The user chooses which action to run. If the user does not select a valid option, then nothing runs.

This design is script-first. Pipelines may be added later, but the current goal is to make the scripts structured, predictable, and easy to maintain.

---

# Core Concepts

## Dashboard Types

There are two dashboard types:

### Shared Dashboard

Shared dashboards are centrally managed dashboards.
They are reused across clients and are considered stable source dashboards.

Rules for shared dashboards:

* The UID must stay the same
* The script must not replace or remove the UID
* The script may update the default subscription name or subscription ID in the JSON if needed
* Shared dashboards are not treated like client-specific copies

### Homepage Dashboard

Homepage dashboards are client-specific dashboards used as landing pages or portals.

Rules for homepage dashboards:

* The UID does not matter long-term
* If a new homepage is submitted, the old one may be deleted or replaced
* The script should replace or remove the UID so Grafana can assign a new one if appropriate
* The script should update:

  * subscription name
  * subscription ID
  * any client-specific metadata such as title and description

---

## Folder Structure

The scripts should assume a structure like this:

* templates/shared/
* templates/client-dash/
* dashboards/output/

Example dashboard templates may include:

* Client-Overview
* Client-Performance
* Client-Home

The template path used depends on whether the dashboard is:

* shared
* homepage/client-specific

---

## Required Environment / Config Inputs

Base config values may include:

* `Grafana_Url`
* `Token`
* `Client_Name`
* `Subscription`
* `Dashboards_Dir`
* `Dashboard_Key`

Additional flags or inputs should specify:

* operation type
* dashboard type
* whether deletion is for a folder or dashboard

---

# Top-Level Run Script

## Purpose

The run script is the main entry point. It should ask the user what they want to do, and then route to the correct script or workflow.

## Allowed Actions

The run script should support these five actions:

1. Create Folder
2. Send Dashboard
3. Onboard New Subscription
4. Delete Dashboard
5. Delete Folder

## Behavior

### Valid selection

If the user chooses a valid action, the run script should:

* gather only the inputs needed for that action
* call the correct script
* stop after that action completes

### Invalid selection

If the user enters:

* nothing
* an unsupported option
* an invalid value

then:

* no script should run
* the run script should exit cleanly

## Design rule

The run script should act as a dispatcher only.
It should not contain all business logic itself.
Each action should have its own dedicated script and rules.

---

# Workflow 1: Create Folder

## Purpose

Create a new client folder in Grafana.

This action only creates the folder.
It does not send any dashboards.

## Inputs

Required:

* Grafana URL
* API token
* client name

Optional if needed:

* parent folder path
* folder naming convention

## Flow

1. Read config and environment variables
2. Validate required values are present
3. Resolve the target folder name from the client name
4. Check whether the folder already exists
5. If the folder already exists:

   * stop
   * print that no new folder was created
6. If the folder does not exist:

   * call the Grafana API to create it
7. Print the result

   * folder created successfully
   * or exact failure reason

## Rules

* Must not create duplicate folders
* Must use consistent naming conventions
* Must not send dashboards as part of this action

## Expected outcome

A client folder exists and is ready to receive dashboards.

---

# Workflow 2: Send Dashboard

## Purpose

Send a dashboard into Grafana using a JSON template.

This action is for one dashboard at a time.

## Inputs

Required:

* Grafana URL
* API token
* client name
* subscription name or ID
* dashboard key
* dashboards directory
* dashboard type

Dashboard type must be one of:

* shared
* homepage

## Flow

1. Read config and environment variables
2. Validate required values
3. Validate dashboard type
4. Determine the correct template path based on dashboard type

   * shared dashboards use the shared template path
   * homepage dashboards use the client-specific or homepage template path
5. Resolve the specific template file from the dashboard key

   * example:

     * overview
     * performance
     * home
6. Load the template JSON
7. Modify the JSON according to dashboard rules
8. Write the modified JSON to an output file if needed
9. Send the dashboard to Grafana through the API
10. Print the result, including dashboard title, UID if relevant, and URL if available

## Rules for Shared Dashboards

If dashboard type is shared:

* keep the existing UID
* do not remove or replace the UID
* update only the default subscription name or subscription ID if needed
* treat the dashboard as a controlled reusable dashboard

## Rules for Homepage Dashboards

If dashboard type is homepage:

* replace or remove the UID
* set `id` to null if needed for import
* reset version if needed
* update client-specific metadata

  * title
  * description
* update:

  * subscription name
  * subscription ID
* treat the dashboard as a client-specific dashboard

## Expected outcome

A single dashboard is created or updated in Grafana according to its type-specific rules.

---

# Workflow 3: Onboard New Subscription

## Purpose

Perform the full initial setup for a new client subscription.

This is a bundled workflow that combines multiple actions.

## Inputs

Required:

* Grafana URL
* API token
* client name
* subscription name or ID
* dashboards directory
* required dashboard keys

Optional:

* which dashboards to include during onboarding

## Flow

1. Read config and environment variables
2. Validate required values
3. Create the client folder
4. Confirm folder creation succeeded
5. Send the required dashboards for the new client

   * typically homepage first
   * then any required client dashboards
6. Apply type-specific rules to each dashboard
7. Print the final result of onboarding

## Rules

* Onboarding is a bundled process
* It may call the create-folder workflow internally
* It may call the send-dashboard workflow internally
* It should stop cleanly if a required step fails
* It should not continue blindly after a failed folder creation or failed dashboard send

## Expected outcome

A new client subscription is fully set up with:

* a client folder
* required dashboards deployed

---

# Workflow 4: Delete Dashboard

## Purpose

Delete one specific dashboard from Grafana.

This action targets a single dashboard only.

## Inputs

Required:

* Grafana URL
* API token
* client name if needed
* dashboard key or dashboard identifier
* dashboard type if needed

Optional:

* exact dashboard UID if already known

## Flow

1. Read config and environment variables
2. Validate required inputs
3. Resolve the target dashboard

   * by UID if already known
   * or by dashboard key and client naming convention
4. Verify that the dashboard exists
5. Display what will be deleted

   * title
   * UID
   * folder if useful
6. Ask the user for confirmation
7. Accept confirmation values case-insensitively

   * yes
   * y
   * no
   * n
8. If input is invalid:

   * keep prompting until valid input is entered
9. If confirmed:

   * delete the dashboard
10. If denied:

* cancel the action

11. Print the result

## Rules

* Must never delete without explicit confirmation
* Must support case-insensitive confirmation input
* Must loop until valid confirmation input is given
* Shared dashboards and homepage dashboards may be resolved differently, but the delete action itself targets only one dashboard

## Expected outcome

One dashboard is either:

* deleted after confirmation
* or left untouched if the user cancels

---

# Workflow 5: Delete Folder

## Purpose

Delete an entire client folder safely.

This action should remove the folder and the dashboards inside it.

## Inputs

Required:

* Grafana URL
* API token
* client name

Optional:

* folder UID if already known

## Flow

1. Read config and environment variables
2. Validate required values
3. Resolve the target folder from the client name
4. Verify that the folder exists
5. List dashboards currently inside that folder
6. Display what will be deleted

   * folder name
   * number of dashboards
   * optionally dashboard titles
7. Ask the user for confirmation
8. Accept confirmation values case-insensitively

   * yes
   * y
   * no
   * n
9. If input is invalid:

   * keep prompting until valid input is entered
10. If confirmed:

* delete all dashboards inside the folder first
* then delete the folder itself

11. If denied:

* cancel the action

12. Print the result

## Rules

* Must not delete a folder without explicit confirmation
* Must verify the folder exists before attempting deletion
* Should delete child dashboards before deleting the folder
* Must stop cleanly if the folder does not exist

## Expected outcome

The selected client folder and its dashboards are removed only after user confirmation.

---

# Action Selection Rules for the Run Script

## Menu options

The run script should expose these exact user-facing actions:

* Create Folder
* Send Dashboard
* Onboard New Subscription
* Delete Dashboard
* Delete Folder

## Dispatch behavior

### Create Folder

Calls only the folder creation logic

### Send Dashboard

Calls only dashboard submission logic

### Onboard New Subscription

Calls the full onboarding flow

### Delete Dashboard

Calls only single-dashboard deletion logic

### Delete Folder

Calls only folder deletion logic

### No valid choice

If the user does not choose a valid action:

* do not run any script
* exit cleanly

---

# Dashboard Template Handling Rules

## Shared templates

Shared templates live in a shared template path.
These are used when the dashboard type is shared.

Behavior:

* preserve UID
* update only allowed fields
* do not treat as a new client copy

## Homepage templates

Homepage templates live in a homepage or client-dash template path.

Behavior:

* create a client-specific version
* replace or remove UID
* update client-specific metadata
* update subscription values

---

# Subscription Variable Rules

When JSON is modified, the `sub` variable should be updated according to dashboard type and purpose.

Typical changes may include:

* current text
* current value
* subscription ID
* hidden state
* query subscription references

The script should apply these consistently so dashboards open with the intended client context.

---

# Safety and Validation Rules

These rules apply across all workflows:

## Validation

Every script should validate:

* required environment variables
* required user inputs
* target resource existence before modifying or deleting

## Confirmation

Delete actions must always require confirmation.

## No-op behavior

If the user does not choose a valid action in the run script:

* nothing should run

## Clear output

Every script should print:

* what it is doing
* what resource it found
* whether it succeeded or failed
* why it failed if applicable

## Separation of concerns

Each workflow should be its own script or function.
The run script should only route actions.

---

# Recommended Mental Model

Think of the system like this:

## Create Folder

Prepare a place for client content

## Send Dashboard

Submit one dashboard according to its type rules

## Onboard New Subscription

Run the full setup for a new client

## Delete Dashboard

Remove one dashboard safely

## Delete Folder

Remove an entire client area safely

---

# Summary

This system should behave like a controlled script runner for Grafana administration.

The user selects one of five actions:

* Create Folder
* Send Dashboard
* Onboard New Subscription
* Delete Dashboard
* Delete Folder

Each action has its own workflow and validation rules.

The most important distinction is between dashboard types:

* **Shared dashboards**

  * keep UID
  * update only allowed subscription-related values

* **Homepage dashboards**

  * replace or remove UID
  * update subscription values and client-specific metadata

Delete actions must always require confirmation.
The run script must do nothing if the user does not make a valid choice.

This provides a clear foundation for later script refactoring and eventual pipeline adoption.
