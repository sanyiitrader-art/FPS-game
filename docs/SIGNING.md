# Signing

Android only installs apps that are signed. Signing also decides whether a new APK can be
installed over an old one: the signature must be the same.

## Right now: automatic test signing

- The workflow creates a throwaway test key with the standard test password (`android`).
- It is **not** a production key. It protects nothing and is never committed to the
  repository (`*.keystore` is in `.gitignore`, and the validator fails the build if a key
  is found).
- The key is kept in the GitHub Actions cache so later builds use the same signature.
  New APKs then install over old ones.
- GitHub removes caches that were not used for about a week. If that happens, the next
  build creates a new key. Android refuses to update an app signed with a different key.
  **Fix:** uninstall the old Quiet Front, then install the new APK. Your saved settings
  are removed with the old app.
- Every build prints the key fingerprint in its run summary. If the fingerprint is the
  same as last time, the new APK installs over the old one.
- Even the "release" APKs from the workflow are signed with this test key. They use the
  faster release engine template, but they are test builds.

You do not need to do anything, and there are no secrets to enter.

## There is no in-app update system

Installing a new version is always done by installing a new APK by hand.

## At release time (decision for you, later)

When the game is ready to share outside your own test group, you need one permanent key
that you keep forever. If you lose it, nobody can update the app. I will ask for your
decision then. The realistic options are:

1. **Key stored in GitHub Secrets (recommended for sideloading).** You create the key
   once (I will give exact steps that work from a browser and the workflow itself), store
   it encoded as a secret, and the workflow signs every release with it. You also keep an
   offline copy.
2. **Google Play App Signing.** If you publish on Google Play, Google manages the final
   signing key and you only keep an upload key. Needs a Google Play developer account
   and an Android App Bundle build, which this project can be switched to.
3. **Keep using test signing.** Fine for a closed group of friends who accept that
   updates may need an uninstall now and then. Not suitable for a public release.

Until you choose, nothing is created and nothing secret is stored.