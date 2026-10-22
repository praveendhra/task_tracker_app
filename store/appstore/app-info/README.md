App-level fields (name, subtitle, privacy URL, categories) set once in
App Store Connect → App Information. fastlane deliver fails to update these on
a brand-new app ("No data"), so the workflow only uploads version metadata,
screenshots and the age rating.
