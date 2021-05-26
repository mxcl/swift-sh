# `swift sh` ![badge-platforms] ![badge-languages] [![Build Status](https://travis-ci.com/mxcl/swift-sh.svg)](https://travis-ci.com/mxcl/swift-sh)

Writing Swift scripts is *easy*:

```sh
$ cat <<EOF > script
#!/usr/bin/swift
print("Hi!")
EOF
$ chmod u+x script
$ ./script
Hi!
```

Sadly, to use third-party dependencies we have to migrate our script to a swift
package and use `swift build`, a relatively heavy solution when all we wanted
was to whip up a quick script. `swift-sh` gives us the best of both worlds:

```sh
$ cat <<EOF > script
#!/usr/bin/swift sh
import PromiseKit  // @mxcl ~> 6.5
print(Promise.value("Hi!"))
EOF
$ chmod u+x script
$ ./script
Promise("Hi!")
```

In case it’s not clear, `swift-sh` reads the comment after the `import` and
uses this information to fetch your dependencies.

---

Let’s work through an example: if you had a *single file* called `foo.swift`
and you wanted to import [mxcl/PromiseKit](https://github.com/mxcl/PromiseKit):

```swift
#!/usr/bin/swift sh

import Foundation
import PromiseKit  // @mxcl ~> 6.5

firstly {
    after(.seconds(2))
}.then {
    after(.milliseconds(500))
}.done {
    print("notice: two and a half seconds elapsed")
    exit(0)
}

RunLoop.main.run()
```

You could run it with:

```
$ swift sh foo.swift
```

Or to make it more “scripty”, first make it executable:

```
$ chmod u+x foo.swift
$ mv foo.swift foo    # optional step!
```

And then run it directly:

```
$ ./foo
```

# Sponsorship

If your company depends on `swift-sh` please consider sponsoring the project.
Otherwise it is hard for me to justify maintaining it.

# Installation

```
brew install swift-sh
```

Or you can build manually using `swift build`.

Installation results in a single executable called `swift-sh`, the `swift`
executable will call this (provided it is in your `PATH`) when you type:
`swift sh`.

We actively support both Linux and Mac and will support Windows as soon as it is
possible to do so.

# Usage

Add the *shebang* as the first line in your script: `#!/usr/bin/swift sh`.

Your dependencies are determined via your `import` lines:

```swift
#!/usr/bin/swift sh
import AppUpdater    // @mxcl
// ^^ https://github.com/mxcl/AppUpdater, latest version

import PromiseKit    // @mxcl ~> 6.5
// ^^ mxcl/PromiseKit, version 6.5.0 or higher up to but not including 7.0.0 or higher

import Chalk         // @mxcl == 0.3.1
// ^^ mxcl/Chalk, only version 0.3.1

import LegibleError  // @mxcl == b4de8c12
// ^^ mxcl/LegibleError, the precise commit `b4de8c12`

import Path          // mxcl/Path.swift ~> 0.16
// ^^ for when the module-name and repo-name are not identical

import BumbleButt    // https://example.com/bb.git ~> 9
// ^^ non-GitHub URLs are fine

import CommonTaDa    // git@github.com:mxcl/tada.git ~> 1
// ^^ ssh URLs are fine

import TaDa          // ssh://git@github.com:mxcl/tada.git ~> 1
// ^^ this style of ssh URL is also fine

import Foo  // ./my/project
import Bar  // ../my/other/project
import Baz  // ~/my/other/other/project
import Fuz  // /I/have/many/projects
// ^^ local dependencies must expose library products in their `Package.swift`
// careful: `foo/bar` will be treated as a GitHub dependency; prefix with `./`
// local dependencies do *not* need to be versioned


import Floibles  // @mxcl ~> 1.0.0-alpha.1
import Bloibles  // @mxcl == 1.0.0-alpha.1
// ^^ alphas/betas will only be fetched if you specify them explicitly like so
// this is per Semantic Versioning guidelines
```

`swift-sh` reads the comments after your imports and fetches the requested
SwiftPM dependencies.

It is not necessary to add a comment specification for transitive dependencies.

# Editing in Xcode

The following will generate an Xcode project (not in the working directory, we
keep it out the way in our cache directory) and open it, edits are saved to your
script file.

```
$ swift sh edit ./myScript
```

# Examples

* [Tweet deleter](https://gist.github.com/mxcl/002c3514d50b73287c89268c45662394)
* [PostgreSQL Check](https://gist.github.com/joscdk/c4b89add26509c6dfabf84974e62543d)

# Converting your script to a package

Simple scripts can quickly become bigger projects that would benefit from being
packages that you build with SwiftPM. To help you migrate your project we
provide `swift sh eject`, for example:

    $ swift sh eject foo.swift

creates a Swift package in `./Foo`, from now on use `swift build` in the
`Foo` directory. Your script is now `./Foo/Sources/main.swift`.

# Use in CI

If you want to make scripts available to people using CI; use `stdin`:

    brew install mxcl/made/swift-sh
    swift sh <(curl http://example.com/yourscript) arg1 arg2

# Internal Details

`swift sh` creates a Swift `Package.swift` configured to fetch your dependencies
and build a single executable for your script in `~/Library/Developer/swift-sh.cache`†,
the script is then executed via `swift run`.

† We use the FreeDesktop specified cache location on Linux.

# Swift Versions

`swfit-sh` v2 requires Swift 5.1. We had to drop support for Swift v4.2
because maintenance was just too tricky.

`swift-sh` uses the active tools version, (ie: `xcode-select`) or whichever
Swift is first in the `PATH` on Linux. It writes a manifest for the package
it will `swift build` with that tools-version. Thus Xcode 11.0 builds with Swift 5.1.
Dependencies build with the Swift versions they declare support for, provided
the active toolchain can do that (eg. Xcode 11.0 supports Swift 4.2 and above)

To declare a support for specific Swift versions in your script itself, use
`#if swift` or `#if compiler` directives.

# Alternatives

* [Beak](https://github.com/yonaskolb/Beak)
* [Marathon](https://github.com/JohnSundell/Marathon)

---

# Troubleshooting

### `error: unable to invoke subcommand: /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift-sh`

If you got here via Google, you have a script that uses this tool, if you now
install `swift-sh`, you will be able to run your script:

    brew install mxcl/made/swift-sh

Or see the [above installation instructions](#Installation).

[badge-platforms]: https://img.shields.io/badge/platforms-macOS%20%7C%20Linux-lightgrey.svg
[badge-languages]: https://img.shields.io/badge/swift-5.1%20%7C%205.2%20%7C%205.3%20%7C%205.4-orange.svg
