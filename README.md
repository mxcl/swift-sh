# `swift sh`

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

However, often we need dependencies, this is… impossible. But not anymore:

```sh
$ cat <<EOF > script
#!/usr/bin/swift sh
import PromiseKit  // @mxcl ~> 6.5
print(Promise.value("Hi!"))
EOF
$ chmod u+x script
$ ./script
Promise(value: "Hi!")
```

In case it’s not clear, `swift-sh` reads the comment after the `import` and
uses this information to fetch your dependencies.

---

Let’s work through an example. If you had a *single* file called `foo.swift`
that needed a dependency, [mxcl/PromiseKit](https://github.com/mxcl/PromiseKit):

```swift
#!/usr/bin/swift sh

import PromiseKit  // @mxcl ~> 6.5

firstly {
    URLSession.shared.dataTask(.promise, with: url)
}.then {
    after(.seconds(2))
}.done {
    print("Scripts with package dependencies!")
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
```

And then run it directly:

```
./foo.swift
```

# Installation

```
brew install mxcl/made/swift-sh
```

You could also install with [Mint](https://github.com/yonaskolb/Mint):

```
mint install mxcl/swift-sh
```

Or you can build manually using `swift build`.

Installation results in a single executable called `swift-sh`, the `swift`
executable will call this (provided it is in your `PATH`) when you type:
`swift sh`.

# Support mxcl

Hi, I’m Max Howell and I have written a lot of open source software, and
probably you already use some of it (Homebrew anyone?). Please help me so I
can continue to make tools and software you need and love. I appreciate it x.

[Donate to my Patreon](https://patreon.com/mxcl).

# Usage

The shebang is crucial, it must be `#!/usr/bin/swift sh` or
`#!/usr/bin/env swift sh`.

Your dependencies are determined via your `import` lines:

```swift
#!/usr/bin/swift sh
import PromiseKit  // @mxcl ~> 6.5
import Foo         // @bar == 6.5
import Baz         // @bar == b4de8c
```

`swift-sh` reads the comments after your imports and fetches the relevant
dependency from GitHub.

The above will fetch https://github.com/mxcl/PromiseKit, anything greater than
version 6.5 but less than version 7.0. Then bar/Foo version precisely 6.5. Then
bar/Baz, with a specific Git SHA.

# Internal Details

`swift sh` creates a Swift package that generates a single executable for your
script in `~/Library/Caches/Shwifty`, the script is then executed via
`swift run`.

# Stuff We Would/Plan-to Implement

* Full URLs for non GitHub packages
* Specifications for GitHub packages where the import name is not the same as the repository name
* More types of version specifications
* Removing SwiftPM output unless there are errors
* Optimizing the cache

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
