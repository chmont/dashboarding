I have a Grafana dashboard using Azure Monitor (Azure Resource Graph and Log Analytics) that currently shows alert summary panels such as “Warning Alerts” and “Total Active Alerts,” along with a table of active alerts.

Right now, the dashboard shows counts and basic alert details (severity, alert name, resource, etc.), but it does not clearly explain *why* the alerts are firing. The goal is to improve the dashboard so users can understand the reason behind alerts directly within Grafana, without needing to navigate to the Azure Portal.

I want to enhance the dashboard by:

* Adding more context to alerts (for example: description, monitor condition, signal type)
* Making it clear what “degraded” or “warning” actually means
* Possibly creating a dedicated “Warning Alert Details” panel filtered to Sev2–Sev4 alerts
* Ensuring users can understand what triggered the alert and what is affected

Can you help:

1. Suggest improvements to the current alert table to better show the “why” behind alerts
2. Provide an example Azure Resource Graph query using `AlertsManagementResources` that includes useful context fields
3. Recommend best practices for making Grafana dashboards more actionable (not just informational)

---
