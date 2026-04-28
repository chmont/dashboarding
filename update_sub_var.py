"""
update_sub_var.py
-----------------
Prepares a CLIENT dashboard JSON for upload to Grafana.

This script is ONLY used for client-folder dashboards. Shared
dashboards are uploaded exactly as-is with no modifications.

WHAT IT CHANGES:
  1. uid      -> removed entirely (Grafana assigns a fresh UID)
  2. id       -> null (tells the API "this is a new dashboard")
  3. version  -> 0 (reset version counter)
  4. Template variable named 'sub' (Azure subscription selector):
       current.text   -> client name (display label)
       current.value  -> subscription ID (query value)
       hide           -> 2 (hidden; user cannot change it)
       query.subscription -> subscription ID
       query.grafanaTemplateVariableFn.subscription -> subscription ID

WHAT IT DOES NOT CHANGE:
  - title        (uses whatever is in the source JSON)
  - description  (uses whatever is in the source JSON)
  - any other top-level field

REQUIRED ENV VARS:
  Client_Name     - e.g. "Acme Corp"
  Subscription    - Azure subscription ID
  Source_Path     - full path to the input JSON
  Output_Path     - full path to write the customized JSON

USAGE:
  send-dashboard.ps1 sets the env vars and invokes this script.
  You generally don't run it directly.
"""

import json
import os
import sys


# ---------------------------------------------------------------------
# Read and validate required env vars
# ---------------------------------------------------------------------
CLIENT_NAME     = os.environ.get("Client_Name", "").strip()
SUBSCRIPTION_ID = os.environ.get("Subscription", "").strip()
SOURCE_PATH     = os.environ.get("Source_Path", "").strip()
OUTPUT_PATH     = os.environ.get("Output_Path", "").strip()

missing = []
if not CLIENT_NAME:     missing.append("Client_Name")
if not SUBSCRIPTION_ID: missing.append("Subscription")
if not SOURCE_PATH:     missing.append("Source_Path")
if not OUTPUT_PATH:     missing.append("Output_Path")

if missing:
    print(f"ERROR: Missing environment variables: {', '.join(missing)}")
    sys.exit(1)


# Template variable visibility: 0 = visible, 1 = label only, 2 = hidden
HIDE_SUB_VARIABLE = 2


# ---------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------
def load_template(path: str) -> dict:
    """Read the template JSON from disk into a Python dict."""
    if not os.path.isfile(path):
        print(f"ERROR: Template not found: {path}")
        sys.exit(1)

    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def reset_dashboard_identity(dashboard: dict) -> None:
    """
    Remove or null out identity fields so Grafana treats this as a
    new dashboard when uploaded.

      uid      -> removed (Grafana will assign a fresh UID)
      id       -> null    (API sees this as a new dashboard)
      version  -> 0       (no prior history)
    """
    dashboard["id"]      = None
    dashboard["version"] = 0
    dashboard.pop("uid", None)


def update_subscription_variable(dashboard: dict) -> None:
    """
    Find the template variable named 'sub' and point it at this
    client's Azure subscription.

    Also hides the variable so end users can't switch subscriptions.
    """
    template_list = dashboard.get("templating", {}).get("list", [])

    sub_var = None
    for var in template_list:
        if var.get("name") == "sub":
            sub_var = var
            break

    if sub_var is None:
        print("ERROR: Template variable 'sub' not found in dashboard JSON.")
        sys.exit(1)

    # What Grafana shows as the selected value on load
    sub_var["current"] = {
        "text":  CLIENT_NAME,
        "value": SUBSCRIPTION_ID,
    }

    # Hide the dropdown
    sub_var["hide"] = HIDE_SUB_VARIABLE

    # Lock the query block to this subscription
    query = sub_var.get("query")
    if isinstance(query, dict):
        query["subscription"] = SUBSCRIPTION_ID

        # Some templates carry a nested grafanaTemplateVariableFn
        # that also has a subscription field - update it if present
        fn = query.get("grafanaTemplateVariableFn")
        if isinstance(fn, dict) and "subscription" in fn:
            fn["subscription"] = SUBSCRIPTION_ID


def save_dashboard(dashboard: dict, path: str) -> None:
    """Write JSON to disk, creating directories as needed."""
    output_dir = os.path.dirname(path)
    if output_dir and not os.path.isdir(output_dir):
        os.makedirs(output_dir, exist_ok=True)

    with open(path, "w", encoding="utf-8") as f:
        json.dump(dashboard, f, indent=2, ensure_ascii=False)


# ---------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------
def main():
    print(f"Loading template: {SOURCE_PATH}")
    dashboard = load_template(SOURCE_PATH)

    # The title stays exactly as it is in the JSON - we only log it
    # so the user can confirm what's going up.
    title_in_json = dashboard.get("title", "<no title in JSON>")
    print(f"  Title from JSON (unchanged): {title_in_json}")

    reset_dashboard_identity(dashboard)
    update_subscription_variable(dashboard)

    save_dashboard(dashboard, OUTPUT_PATH)

    print("Client-ready copy saved:")
    print(f"  Subscription:  {CLIENT_NAME} ({SUBSCRIPTION_ID})")
    print(f"  Hidden:        yes (hide={HIDE_SUB_VARIABLE})")
    print(f"  Output:        {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
