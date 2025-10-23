# App Tracker

An application version tracker that uses [Evergreen](https://stealthpuppy.com/evergreen) to query for application version updates and store the result in JSON format.

A workflow is run every 12-hours to retrieve available updates and commit changes to this repository, which then generates the App Tracker site.

[![update-apps](https://github.com/aaronparker/apptracker/actions/workflows/update-apps.yml/badge.svg?branch=main&event=schedule)](https://github.com/aaronparker/apptracker/actions/workflows/update-apps.yml)
