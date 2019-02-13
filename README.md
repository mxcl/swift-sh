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

# Installation

```
brew install mxcl/made/swift-sh
```

Or with [Mint](https://github.com/yonaskolb/Mint):

```
mint install mxcl/swift-sh
```

Or you can build manually using `swift build`.

Installation results in a single executable called `swift-sh`, the `swift`
executable will call this (provided it is in your `PATH`) when you type:
`swift sh`.

We actively support both Linux and Mac and will support Windows as soon as it is
possible to do so.

# Support mxcl

Hi, I’m Max Howell and I have written a lot of open source software, and
probably you already use some of it (Homebrew anyone?). Please help me so I
can continue to make tools and software you need and love. I appreciate it x.

<a href="https://www.patreon.com/mxcl">
	<img src="https://c5.patreon.com/external/logo/become_a_patron_button@2x.png" width="160">
</a>

[Other donation/tipping options](http://mxcl.github.io/donate/)

# Usage

Add the *shebang* as the first line in your script: `#!/usr/bin/swift sh`.

Your dependencies are determined via your `import` lines:

```swift
#!/usr/bin/swift sh
import PromiseKit  // @mxcl ~> 6.5
import Foo         // @bar == 6.5
import Baz         // @bar == b4de8c
import Floobles    // mxcl/Flub == master
import BumbleButt  // https://example.com/bb.git ~> 9
```

`swift-sh` reads the comments after your imports and fetches the requested
SwiftPM dependencies.

The above will fetch:

* https://github.com/mxcl/PromiseKit, the highest available version that is
    greater than or equal to 6.5.0 but less than 7.0.0
* https://github.com/bar/Foo version precisely 6.5.0
* https://github.com/bar/Baz, with the specific Git SHA `b4de8c`
* https://github.com/mxcl/Flub, master branch
* https://example.com/bb.git, highest available version `9.0.0..<10.0.0`

It is not necessary to add a comment specification for transitive dependencies.

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
    swift sh <(curl http://example.com/yourscript)

# Internal Details

`swift sh` creates a Swift `Package.swift` configured to fetch your dependencies
and build a single executable for your script in `~/Library/Developer/swift-sh.cache`†,
the script is then executed via `swift run`.

† We use the FreeDesktop specified cache location on Linux.

# TODO

* More types of version specifications
* Removing SwiftPM output unless there are errors
* Optimizing the cache (creating a library structure more like `gem` or `pip`
    would)
* Error out if the import specification is invalid, currently we silently ignore
    such lines

# Limitations

Our logic for determining package modules is insufficient. It works for most
packages, but will fail for packages with multiple modules. I’ll fix this once
I need to, but feel free to PR it. Doing this properly is probably easiest if
we depend on SwiftPM itself and use its machinery to get module information.

Alternatively we could require all imports that a script depends on to be
specified in the form that we already do. Or we could assume all imports that
are not Apple imports to be dependencies for the generated `Package.swift`. Or
we could manage the build ourselves which isn’t too hard and would be the
solution that simplifies our system the most.

If you have two scripts with the same name we will (currently) always need to 
rebuild whenever you rotate between them. 

# Alternatives

* [Beak](https://github.com/yonaskolb/Beak)
* [Marathon](https://github.com/JohnSundell/Marathon)

### Get push notifications for new releases

https://codebasesaga.com/canopy/

---

# Troubleshooting

### `error: unable to invoke subcommand: /Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift-sh`

If you got here via Google, you have a script that uses this tool, if you now
install `swift-sh`, you will be able to run your script:

    brew install mxcl/made/swift-sh

Or see the [above installation instructions](#Installation).

[badge-platforms]: https://img.shields.io/badge/platforms-macOS%20%7C%20Linux-lightgrey.svg
[badge-languages]: https://img.shields.io/badge/swift-4.2%20%7C%205.0-orange.svg
