# Grafana Dashboard Sharing Approach

## Overview

This document outlines a proposed approach for sharing dashboards internally in Grafana while minimizing duplication and maintaining consistency across teams.

The goal is to maintain a single high quality dashboard as a base, while allowing teams to create their own copies that automatically stay up to date through the use of library panels.

---

## Proposed Solution

### Base Dashboard

Maintain one primary dashboard located in a shared folder. This dashboard acts as the source of truth for layout, panel structure, and queries.

### Use of Library Panels

Each panel within the base dashboard is saved as a library panel. This ensures that all panel logic is centrally managed.

When changes are made to a library panel, those changes automatically propagate to every dashboard that uses that panel.

### Team Workflow

Instead of directly using the shared dashboard, users will:

* Open the base dashboard
* Use "Save as copy"
* Place the copied dashboard into their own folder
* Set the appropriate client or subscription variable

This allows each team to have their own dashboard instance while still benefiting from shared panel updates.

---

## Folder Structure

Library panels are organized into folders based on their type and usage.

Example structure:

* Shared/Root Folder

  * Overview

    * Panels
        * stats
        * table
        * time series
    * Dashboard

* Performance

  * Same subfolder structure as Overview

This structure allows panels to be logically grouped and easily discoverable.

---

## Benefits of This Approach

* Teams can manage their own dashboards independently
* No need to manually update panels across dashboards
* Centralized control of queries and panel logic
* Reduced duplication of panel configuration

Changes made to a library panel are automatically reflected in all dashboards that use it, including copied dashboards.

---

## Save as Copy Method

This approach relies on the "Save as copy" functionality as part of the workflow.

In this method:

* A user creates a copy of the base dashboard
* Adjusts variables such as client or subscription
* Stores the dashboard in their own folder

### Advantages

* Allows per-team customization
* Keeps dashboards organized by team or client
* Works within Grafana’s existing permission model

### Tradeoffs

* Multiple dashboard instances will exist
* Some Layout changes to the base dashboard do not propagate automatically

---

## Limitations of the Library Panel Approach

While library panels ensure panel consistency, there are still limitations:

* Dashboards themselves are not reusable as a shared object
* Structural changes (such as adding new panels) must be manually applied to copied dashboards

### What Changes Actually Propagate

From testing, not all changes propagate consistently across dashboards, and the Grafana documentation is not explicit about what is included.

Confirmed to propagate:

* Query changes
* Some visual settings such as background color
* Panel description

Observed not to propagate:

* Panel title does not update across dashboards

This suggests that some presentation properties may remain local to each dashboard rather than being fully controlled by the library panel.

### Key Tradeoff

* Panel logic and certain visual settings are centralized and propagate
* Dashboard structure and some presentation details must be managed manually

---

## Challenges with Dashboard Sharing in Grafana

Grafana does not currently provide a simple way to share a dashboard internally across teams with minimal setup.

Key challenges include:

* No native support for reusable dashboards similar to library panels
* No way to mount a single dashboard into multiple folders
* Requires either duplication or URL based variable handling

---

## Automation
Currently working automating creating folders and uploading dashboards to Grafana via Grafanas API using powershell scripts. The issue is that I need to modify the dashboard "template" to change the default variable as the specified client and its subscription id. We also need to hide the sub variable so the users can not toggle betweebn subscriptions. 
The work flow will be:

```
set-env -> config params -> create folder -> Update template -> send dasboard
```


Requires a service token with at least editor priviiges but I recomend only giving these to users with admin privilges. 

This can help improve automation without canceling 

---

## Summary

The proposed solution focuses on:

* Maintaining a single base dashboard
* Using library panels for shared logic and consistency
* Allowing teams to create their own copies using "Save as copy"

This approach balances flexibility and maintainability by combining shared panel logic with independent dashboard ownership.

While it does not fully solve dashboard level reuse, it provides a practical and scalable workflow within Grafana’s current limitations.
