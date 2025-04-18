# Swift on server articles

Articles for the [swiftonserver.com](https://swiftonserver.com/) site.

## Writing Articles

To write an article for the site, you'll need to write it in markdown in the DocC documentation of the `Articles` module: https://github.com/swift-on-server/articles/tree/main/Sources/Articles/Documentation.docc/2024

The folders are structured by `<year>/<article-slug>`. If you're just starting with an article, the slug doesn't matter too much. It'll be tweaked before publication.

Inside each article folder, you should put a markdown file with the same name. E.g. `whats-new-in-hummingbird/whats-new-in-hummingbird.md`.

This is _mostly_ a regular markdown file representing your article, with two notable exceptions.

### Symbol Links

Our rendering engine, [swiftinit](https://swiftinit.org), can link DocC symbol links to any dependency of our project. As such, all mentions of types or functions should use two backticks rather than one.

```
``ByteBuffer``
```

You can also render functions and properties that are members of types.

```
``TaskGroup.addTask(priority:operation:)``
```

### Swift Snippets

Rather than writing sample code in markdown code blocks, our site uses Swift Snippets to display Swift code.

A Swift Snippet is a Swift source file that is compiled and can use all of the project's dependencies. The main benefit of Snippets is that that because they're compiled, any build of the Articles folder guarantees that the samples are valid and compile with the latest Swift release.

Users can copy & paste source code without worry of it breaking. And when the project's dependencies change major release, CI knows if all articles are up-to-date and work.

Because Swift Snippets are compiled, users can download the articles repository to run the snippet's code in Xcode or VSCode.

Finally, _because_ Swift snippets are compiled, the SwiftOnServer.com website can leverage [swiftinit](https://swiftinit.org) to integrate the linked source code into their documentation engine. This allows us to provide enriched metadata for the code that is displayed.

As of writing, that includes linking types, functions and properties to their corresponding documentation through an anchor, as well as on-hover tooltips.

If a tutorial uses one snippet, you can create a snippet with the tutorial's slug in the [Snippets folder](https://github.com/swift-on-server/articles/tree/main/Snippets).

If a tutorial uses multiple snippets, you can create a folder with your tutorial's slug instead, and put any snippets needed inside that folder.

#### Using Snippets

DocC uses the following format to locate a snippet:

```
@Snippet(
    path: "articles/Snippets/2025/introduction-to-jwts-in-swift/jwt-kit"
)
```

- `articles` is mandatory, and refers to the current Swift package by package name.
- The next part is the location where we store our snippet. It is mandatory to start the location with `Snippets`.
- `jwt-kit` refers to the actual snippet file. Do not use the `.swift` extension here.

If you _don't_ want to render certain example code in the tutorial, you can mark the start of hidden lines of code as such:

```swift
// snippet.hide
```

Then re-enable rendering as such:

```swift
// snippet.show
```

[Example of hiding and showing](https://github.com/swift-on-server/articles/blob/main/Snippets/ahc_json.swift#L1-L10)

You can also add a label (other than hide/show/end) to a snippet:

```swift
// snippet.LABEL
```

And you can end that labeled block as such:

```swift
// snippet.end
```

[Example of labels](https://github.com/swift-on-server/articles/blob/main/Snippets/building-swiftnio-clients-01.swift#L1-L6)

You can refer to a labeled block (called a "slice") in your tutorial's code:

```
@Snippet(
    path: "articles/Snippets/2025/introduction-to-jwts-in-swift/jwt-kit", slice: "key_collection_add_hmac"
)
```

### Planning an Article (recommended)

The recommended way to start an article is to create an _outline_ first. It's basically a bullet-point list of chapters (h1, h2, h3).

I recommend adding a one-word tag per bullet-point. Some recommendations for tags:

- intro
- theory (used when you need to front-load information)
- practice (when people get to dive into code)
- conclusion (recap; what did you learn?)

Here's an example outline:

```md
## Getting Started with Hummingbird 2

- What is Hummingbird? [intro]
- Adding the Dependency [practice]
- Hummingbird and Service Lifecycle [theory]
- Creating a Web Server [practice]
- Running Your App [practice]
- What are Routes? [theory]
- Adding a Route [practice]
- Responding to Requests [practice]
- Where to go from here? [conclusion]
```

As a general guideline, I recommend showing only one theory block at a time, separated by practice. However, some articles are theoretical in nature.

Practical blocks should preferably end with a moment of reflection, where the user can check if their code is working as expected. This can be a screenshot of a webbrowser or code block displaying the expected terminal output of the tutorial.

### Writing the Sample Code

I normally start with sample code first, as programmers naturally gravitate towards code that they want to explain or discuss.

Ideally you should keep the sample code constrained within snippets. As snippets are single Swift files, it pushes you to keep the topics simple to keep track of.

However, Swift Snippets don't have a line limit. So feel free to add a lot of (hidden) code in one snippet file.

### Writing the Tutorial

If you've written the sample code, you can copy the outline and code snippets in your editor. Since we're using DocC, you can use the DocC plugin or the Xcode "Build Documentation" tool to view your changes. SwiftInit also has a preview tool that you can use.

My recommendation is not to be very critical on the first draft. Write what you want and what you think, and clean it up from there. Every time you read your article, you'll find new things that are missing, not explained, in the wrong order or simply too difficult to follow.

### Polishing

Once your story makes sense, you can create a draft PR, tagging [Joannis](https://github.com/joannis) and [Tibor](https://github.com/tib).

We'll try to pay attention to the following, providing suggestions to your code and text as we run into them. We generally tend to edit a lot of small phrases, to help the reader. Please don't be intimiated when we do so.

Most of our checks can be done yourself. Our edits focus primarily on the following:

#### Flesch Kincaid Readability Score

We run a readability test over the text, mainly using the free [Hemingway Editor](https://hemingwayapp.com/). This shows us where complex words are used, that have a simpler alternative, in addition to highlighting the complexity of your article.

Almost every article written is expected to start out with a poor score. However, they can be almost trivially tweaked with the suggestions provided by the editor.

#### Word Choices

We try to avoid words like "you", "I" or "we", and focus on an authorative voice. We believe that the articles we write are scrutinised more than enough to warrant being authoritative in our field.

#### Passive Voice

As part of being authoriative, we also strive to remove any and all use of [passive voice](https://www.grammarly.com/blog/passive-voice/).

#### Length of Sections

We try to keep the article in digestable chunks, which includes the length of sample code blocks.
