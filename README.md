<div align="center">
  <img width="256" alt="spmify-logo" src="https://github.com/rogerluan/SPMify/assets/8419048/55fd0aef-5871-4095-b67a-8febdbdf0452">

  <h1>SPMify</h1>
  <p><strong>Transform your <code>Podfile.lock</code> into a <code>Package.swift</code>.</strong></p>
  <a href="https://github.com/rogerluan/SPMify/issues">
    <img alt="Issues" src="https://img.shields.io/github/issues/rogerluan/SPMify?color=#86D492" />
  </a>
  <a href="https://swift.org">
    <img src="https://img.shields.io/badge/Swift-5.8-F05138?logo=swift&logoColor=white" alt="Swift 5.8" />
  </a>
  <a href="https://twitter.com/intent/follow?screen_name=rogerluan_">
    <img src="https://img.shields.io/twitter/follow/rogerluan_?&logo=twitter" alt="Follow on Twitter">
  </a>

  <p align="center">
    <a href="https://github.com/rogerluan/SPMify/issues/new/choose">Report Bug</a>
    ·
    <a href="https://github.com/rogerluan/SPMify/issues/new/choose">Request Feature</a>
  </p>
</div>

This script will help you migrate your iOS project from CocoaPods to SPM by _helping_ you convert your `Podfile.lock` into a `Package.swift`.

Keep in mind that this script will only get you 90% there, the remaining 10% will most likely require some manual massaging, as this script is not bullet proof — there are always private repos, or repos that don't support SPM yet, or other things that get on the way that prevent the final `Package.swift` from fully working out-of-the-box.

## Installation

None.

## Usage

First, navigate to the directory where your `Podfile.lock` is in. Then run:

```sh
ruby <(curl -s https://raw.githubusercontent.com/rogerluan/SPMify/main/spmify.ruby)
```

This will produce the resulting `Package.swift` in the same directory. Now review the `Package.swift` file, and check out the potential TO-DOs that the script left in your file.

# Features

- ✅ It will check whether the presumed GitHub repository has a `Package.swift` file.
- ✅ It will follow branch references when present (some repos only have `Package.swift` in a "spm" branch for instance).
- ✅ It will leave "TO-DO" comments on what needs attention after building your `Package.swift`.
- ✅ It will automatically follow GitHub repo redirects, which catches the edge case where a username, organization or repository was renamed.
- ✅ It will follow the specified pods repo forks, tags, branches, and versions, so your `Package.swift` will be as close as possible to your `Podfile.lock`.

# What it won't do

Unless someone feels like opening a PR to add these features, these are the things it won't do:

- ❌ It doesn't handle CocoaPods sub-directories. E.g. `Firebase/Messaging`, `Firebase/Analytics`, etc.
- ❌ It doesn't handle cases where the SPM repo is different from the CocoaPods repo. E.g.: https://github.com/aws-amplify/aws-sdk-ios
- ❌ It doesn't use any form of authentication with GitHub when checking whether the repo contains `Package.swift`. This means it can't access private repos, and has a limit of 60 requests/hour.
- ❌ It doesn't handle local pods (aka Development Pods).
- ❌ It doesn't handle cases where the pod specific version doesn't support SPM. So after the Package.swift is generated, you'll have to manually check whether the version you're using supports SPM or not, and if it doesn't, you'll have to manually change the version to a one that does support SPM.

# Troubleshooting

## Xcode is throwing `Package manifest at '/Package.swift' cannot be accessed (/Package.swift doesn't exist in file system)`

See: https://stackoverflow.com/a/76250361/4075379

# Contributions

If you spot something wrong, missing, or if you'd like to propose improvements to this project, please open an Issue or a Pull Request with your ideas and I promise to get back to you within 24 hours! 😇

# Contact

Twitter: [@rogerluan_](https://twitter.com/rogerluan_)

Subscribe to my blog: [roger.ml](https://www.roger.ml)
