require "mothership/help"

Mothership::Help.groups(
  [:start, "Getting Started"],
  [:apps, "Applications",
    [:manage, "Management"],
    [:info, "Information"]],
  [:services, "Services",
    [:manage, "Management"]],
  [:organizations, "Organizations"],
  [:spaces, "Spaces"],
  [:routes, "Routes"],
  [:domains, "Domains"],
  [:admin, "Administration",
    [:user, "User Management"]])
