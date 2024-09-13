# Getting started with SwiftPM Snippets

[SwiftPM Snippets](https://github.com/apple/swift-evolution/blob/main/proposals/0356-swift-snippets.md) are one of the most powerful features of the [Swift Package Manager](https://github.com/apple/swift-package-manager), and yet two years after their introduction few developers know they exist. This tutorial will explain some of the advantages of using SwiftPM Snippets and show you how to add Snippets to a Swift package.

In this tutorial, we will use the Apple [DocC](https://github.com/apple/swift-docc) tool to preview and iterate on Snippets locally. The DocC tool itself does not support rendering clickable references within Snippets, however the finished SwiftPM project containing Snippets can be published to a platform like [Swiftinit](https://swiftinit.org) where the Snippets will be rendered with clickable references, allowing readers to interact with the symbols contained within them and navigate to supplemental documentation.


## What are Swift Snippets?

Swift Snippets were invented in 2022 by [Ashley Garland](https://github.com/bitjammer) and first shipped in Swift 5.7. [Originally conceived](https://forums.swift.org/t/se-0356-swift-snippets/57097) as a way to validate example programs by compiling them, developers have since found a variety of additional applications for them, ranging from testing to documentation to even full-blown prototyping of multi-module setups.

Despite their immense potential, very little documentation exists on how to use Swift Snippets, and awareness of the feature remains [surprisingly low](https://github.com/search?q=%40Snippet+language%3Aswift&type=code).

> The outlook for this feature is pessimistic considering the low adoption rate. This might change if Apple invests in better documentation and adopts Snippets in their own repositories.
>
> — [A critical look at Swift Snippets](https://blog.eidinger.info/a-critical-look-at-swift-snippets-swift-57) by Marco Eidinger


>   Warning:
>   There is a known [Xcode bug](http://ww.openradar.appspot.com/FB13482049) that prevents Snippets from being shown in the Xcode editor.


## Why use Swift Snippets?

Swift Snippets are incredibly versatile. Some common applications include:

-   **Scratch modules**. Snippets are effectively single-file Swift modules, and can be used to quickly prototype code or sketch patterns without the overhead of declaring a proper library target in the package manifest. Snippets are especially useful when the code being prototyped depends on other modules, as Snippets have the ability to `import` modules from the current package.

-   **Reproductions**. Snippets can be used to reproduce bugs in a minimal environment, with little to no setup required. Although you could also compile your own playgrounds manually with `swiftc -parse-as-library`, it is much easier to run Snippets because they are automatically discovered by the `swift run` command.

    Snippets are especially useful for reproducing compiler bugs. Some developers find it helpful to keep a `.gitignore`’d `Snippets/Crashes` directory in their local environment specifically for collecting compiler crashes.

-   **Examples**. Snippets can be used to provide runnable examples that ship with your package. This allows you to avoid cluttering the package manifest with example targets, and helps you organize your examples in a self-documenting manner.

-   **Documentation**. Snippets can be embedded in Markdown documentation and displayed in DocC. This allows you to include live code examples in your documentation that are guaranteed to compile and run.

    Snippets can be sliced and embedded as individual code fragments, allowing you to write tutorials that discuss each section of an example program in detail.

    Some documentation engines such as Unidoc can render Snippets in the browser with linked identifiers, allowing readers to interact with the symbols in the code.


## Adding Snippets to a Swift package

For this tutorial, we will create a package named `snippets-example`.

```bash
$ mkdir snippets-example
$ cd $_
$ swift package init --name 'Swift Snippets'
```

This should initialize a new Swift package with a `Package.swift` resembling the following.

@Code(name: "Package.swift", file: Manifest.1.swift)

Rename the library target to `SnippetsExample`.

@Code(name: "Package.swift", file: Manifest.2.swift)

Make sure the `Sources/SnippetsExample` directory contains at least one Swift file. For this tutorial, we will add an empty file named `anchor.swift`.

Next, create a new directory named `Snippets` at the top level of the package.

```bash
$ mkdir Snippets
```

>   Note: Despite the specification of [SE-0356](https://github.com/apple/swift-evolution/blob/main/proposals/0356-swift-snippets.md#overriding-the-location-of-snippets), it is not possible to name the directory anything other than `Snippets`.

Inside the `Snippets` directory, create a new Swift file named `SnippetsExample_I.swift`.

@Snippet(id: "SnippetsExample_I")

The directory structure should now look like this:

```
📂 swift-snippets
├── 📂 Snippets
│   └── 📄 SnippetsExample_I.swift
├── 📂 Sources
│   └── 📂 SnippetsExample
│       └── 📄 anchor.swift
├── 📄 Package.swift
└── 📄 .gitignore
```

The Swift package now contains the Snippet file and is ready to be built.​


## Running Snippets

The `swift build` command will automatically discover and compile all Snippets in a package.

Snippets are just modules with discovery enabled, which means you can also build a single Snippet with the `--target` flag.

```bash
$ swift build --target SnippetsExample_I
```

You can run a Snippet with the `swift run` command.

```bash
$ swift run SnippetsExample_I
```

```text
Building for debugging...
[5/5] Linking SnippetsExample_I
Build complete! (0.97s)
Hi Barbie!
```

You could also run a Snippet with release optimizations, just like any other executable target.

```bash
$ swift run -c release SnippetsExample_I
```

```text
Building for production...
[17/17] Linking SnippetsExample_I
Build complete! (9.73s)
Hi Barbie!
```

>   Note:
>   If the Snippet name contains special characters, you should pass the file name as-is to the `--target` flag. For example, to run a Snippet named `Foo bar.swift`, you would use `swift run 'Foo bar'` and not `Foo_bar`.


## Embedding Snippets in documentation

Most modern documentation engines support embedding Snippets in Markdown documentation via the `@Snippet` block directive.

Let’s create a documentation bundle for the `SnippetsExample` target.

```bash
$ mkdir -p Sources/SnippetsExample/docs.docc
```

>   Tip:
>   You can name the documentation bundle anything you like, as long as it has a `.docc` extension. The name comes from the DocC tool, but most other documentation engines will recognize it too.

Create a markdown article named `My article.md` in the `docs.docc` directory.

@Code(name: "My article.md", file: "My article (2).md.txt")

In the example above, we have specified the Snippet to include by `path` identity.

Despite its naming, the `path` syntax is not a file path. The first component is the name of the package **as specified by the ``PackageDescription/Package/name`` field in the manifest**. The second component is always the string `Snippets`. The third component is the Snippet ID, which is the name of the Snippet file without the `.swift` extension.

If the Snippet ID contains special characters, you should pass the ID as-is, without replacing any characters.

Some documentation engines such as [Unidoc](https://github.com/tayloraswift/swift-unidoc) support referencing Snippets by `id`.

@Code(name: "My article.md", file: "My article (1).md.txt")

>   Important:
>   DocC does not currently support referencing Snippets by ID. Instead, you must use the fully-qualified `path` syntax to reference a Snippet.

You should now have a project layout that looks like this:

```
📂 swift-snippets
├── 📂 Snippets
│   └── 📄 SnippetsExample_I.swift
├── 📂 Sources
│   └── 📂 SnippetsExample
│       ├── 📂 docs.docc
│       │   └── 📄 My article.md
│       └── 📄 anchor.swift
├── 📄 Package.swift
└── 📄 .gitignore
```


### Previewing Snippets with DocC

Many developers find [DocC](https://github.com/apple/swift-docc) helpful for previewing documentation locally. To use DocC, add the [swift-docc-plugin](https://github.com/apple/swift-docc-plugin) to the package manifest.

@Code(name: Package.swift, file: Manifest.3.swift)

Please note that while it is possible to build DocC documentation using Xcode, Snippets will not render, due to [FB13482049](http://ww.openradar.appspot.com/FB13482049).

You can then launch DocC with the `preview-documentation` package subcommand:

```bash
$ swift package --disable-sandbox preview-documentation --target SnippetsExample
```

You can find the rendered article at [`http://localhost:8080/documentation/snippetsexample/my-article`](http://localhost:8080/documentation/snippetsexample/my-article).

>   Warning:
>   At the time of writing, there is a [known bug](https://github.com/apple/swift-docc/issues/944) causing DocC preview to crash if the target name contains special characters.


## Using Snippet captions

If a Snippet begins with contiguous line comments, those comments will be parsed as Markdown and treated as a Snippet caption. Try adding the following code to a Snippet named `SnippetsExample_II.swift`.

@Code(name: "SnippetsExample_II.swift", file: SnippetsExample_II.swift)

When embedded, it should look like this:

---

@Snippet(id: SnippetsExample_II)

>   Note:
>   Snippet captions cannot embed other Snippets.


## Redacting parts of a Snippet

You can redact portions of a Snippet using **slice directives**. A slice directive is a line comment token that starts with `snippet` followed by a dot and an identifier. The following identifiers have special meanings:

| Identifier        | Behavior                                   |
| ----------------- | ------------------------------------------ |
| `snippet.hide`    | Hides the content following the directive. |
| `snippet.end`     | Hides the content following the directive. |
| `snippet.show`    | Shows the content following the directive. |


Below is an example of a Snippet that uses redactions to hide the `import` statements.

@Code(name: SnippetsExample_III.swift, file: SnippetsExample_III.swift)

When embedded, it should look like this:

---

@Snippet(id: SnippetsExample_III)


>   Warning:
>   At the time of writing, there is a [known bug](https://github.com/apple/swift-docc/issues/946) preventing DocC from slicing Snippets that contain multi-line string literals correctly.


### Slice indentation

The indentation of the first `snippet.show` determines specifies the maximum amount of indentation to remove from the Snippet. In the example below, four spaces of indentation will be removed from the rendered Snippet. Note that the `snippet.end` token is required in order to prevent the Snippet from including the final brace, which would have prevented the indentation from being removed.

@Code(name: SnippetsExample_IV.swift, file: SnippetsExample_IV.swift)

When embedded, it should look like this:

---

@Snippet(id: SnippetsExample_IV)


## Using named slices

You can also use **named slices** to create Snippets with multiple embeddable sections. It’s a good idea to give slices uppercase names to distinguish them from special slice directives.

Below is an example of a Snippet with a caption and three named slices.

@Code(name: SnippetsExample_V.swift, file: SnippetsExample_V.swift)

Here’s how you might embed the slices in a Markdown article.

@Code(name: "My article.md", file: "My article (3).md.txt")

And here’s how the embedded slices should look.

---

@Snippet(id: SnippetsExample_V, slice: DECLARATION)
@Snippet(id: SnippetsExample_V, slice: BODY)
@Snippet(id: SnippetsExample_V, slice: EXIT)


## Where to go from here

DocC cannot read the metadata emitted by the Swift compiler that associates the tokens in a Snippet with their definitions, nor can it link to symbols that originate from a package’s dependencies.

However, other documentation engines such as [Unidoc](https://github.com/tayloraswift/swift-unidoc) do support rendering Snippets with linked identifiers, and you can easily leverage this feature by publishing your documentation to a platform like [Swiftinit](https://swiftinit.org/help/self-serve). Because the Swift compiler already checks that the Snippets are valid and buildable, most DocC documentation can be uploaded to Swiftinit as-is without additional iteration.

Third-party websites (such as Swift on Server itself) can also leverage this feature through the [Swiftinit API](https://swiftinit.org/help/exporting-articles).
