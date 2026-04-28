Overview
The goal of this design is to provide a simple and scalable way for users to access client-specific dashboards without needing to understand how Grafana works. The idea is for users to already have specific client folders and dashboards set up as soon as they log in to Grafana.

We will maintain a single set of shared dashboards that act as the source of truth and build client-specific home pages that act as entry points into those dashboards. 

Shared Dashboards (Source of Truth)
A shared folder will contain a subfolder called:

Shared/Client-Homepages/<Client-Name>

This folder will contain the main dashboards used across all clients.

Each of these dashboards includes a Grafana variable named sub. This variable is populated from Azure Monitor by querying available subscriptions.

This allows a single dashboard to display metrics for different clients by switching the subscription value.

Problem Being Solved
Many new users may not be familiar with Grafana and should not be expected to:

navigate folder structures

understand variables

manually switch subscriptions in dashboard settings (confusing)

Save as a copy into specified folder (too many steps)

The solution is to provide a simplified client-specific entry point where users can immediately access the correct dashboards based on a specific client.

Folder Structure


Client Homepages/
  Client-A/
    Home Dashboard
  Client-B/
    Home Dashboard
Each client has its own folder and home dashboard.

Client Home Pages (Portal Dashboards)
Each client will have a dedicated home dashboard that serves as a portal.

These home dashboards will:

contain links to shared dashboards

automatically pass the correct client subscription

allow users to click and view dashboards without additional setup

These dashboards can be assigned as default home pages using Grafana Teams so users land directly on their client portal after login. 

These client homepages will live in a specified client folder. The client folder will be named after the client, and all these folders will live under a folder called Client Homepages. 

Reusable Panel Management
The client homepages will use a library panel to display links.

Benefits:

Links are defined in one place

Updates automatically propagate to all client homepage links.

Adding or removing dashboards only requires a single change.

This significantly reduces maintenance effort. This library panel can only be edited by admin users. If users want to add information this will be done a different panel and there will already be a panel to do so. 

Variable Strategy
Each client home dashboard will include a $sub variable with a default value set to that specific client.

This value will not be manually configured in the UI. Instead, it will be set in the dashboard JSON during deployment. Since there are already a list of clients and their corresponding IDs, this process can be automated. The variable can also be hidden so users do not need to interact with it.

Client Shared dashboards will also have resource group variables. They should already be organized into categories. This is done by a $category variable that is essentially are labels for $resourcegroup to filter when querying from Azures Resource Graph. This allows for users to select which category (Prod, Client-Facing, Non-Client Facing, All) and once selected resource group are filtered, and the resource groups are able to be selected. 

Grafana UIDS
UIDs are the primary way Grafana identifies dashboards and folders behind the scenes. Using consistent and recognizable UIDs solves key challenges around linking, organization, and recovery.

How everything connects:

Client Homepage Dashboard

 contains links to Shared Dashboards (via UID)

uses Library Panel (shared links panel)

 dashboards live inside Folders (also identified by UID) 

Why this matters:

Stable linking

Dashboard links rely on /d/<uid>/...

If the UID changes, links in the shared library panel break

Library panel consistency

The shared panel is reused across all client homepages

It centrally manages links to shared dashboards

Stable UIDs ensure one update works everywhere without fixing broken links

Folder-level organization

Folders also have UIDs used in APIs and provisioning

Consistent folder UIDs help maintain structure during automation and recovery

Recovery and backup

Dashboards are restored using JSON definitions

Matching UIDs allow links, panels, and folder placement to reconnect correctly

Prevents the need to manually rebuild homepage links or relationships

Scalability

As more clients and dashboards are added, predictable UIDs make it easier to trace, manage, and automate resources

In this design, UIDs are not just identifiers. They are the foundation that keeps client homepages, shared dashboards, and the reusable library panel reliably connected.

Link Structure
Links from the home dashboard to shared dashboards will follow a simple format:

/d/<uid>/<dasboard-name>?var-sub=${sub}

Notes:

The UID is the only required identifier

The dashboard name portion is optional and is used for readability

The var-sub=${sub} parameter ensures the correct client context is passed

Automation and API Usage
A template dashboard JSON will be used for all client home pages.

Existing PowerShell and Python scripts can:

modify the JSON

set the correct sub value for each client

deploy dashboards through the Grafana API

Dashboard metadata such as UID and URL can also be retrieved from the Grafana API.

This allows:

automatic generation of links

easy updates to the shared panel

consistent rollout across all clients

Deploying these home dashboards only needs to be done once. Any changes done to panels will be done in the UI. 

In the case where a Dashboard gets deleted

Dashboard Recovery and Backup Strategy
All shared dashboards should be exported as JSON and stored in a repository as the “golden source of truth”.

If a dashboard is accidentally deleted or needs to be restored:

retrieve the dashboard JSON from the repository

resubmit it to Grafana using the existing scripts (readjust if needed) 

obtain the dashboard UID and URL if needed

update any affected links in the shared panel

This ensures dashboards can be quickly restored with minimal disruption and maintains.

Resources
Variables | Grafana documentation 

Grafana-Categorizing Resource Groups - Tech Ops - Confluence 

Manage library panels | Grafana documentation 
