// snippet.hide
import SnippetsExample

// snippet.show
let _:String = """
The import statements at the top of the file are redacted from \
the rendered Snippet.

// snippet.hide

Snippet markers slice the source code at the token syntax level. \
This means strings resembling Snippet markers inside multiline \
string literals do not need to be escaped. However, there is no \
requirement for slices to contain complete lexical blocks. This is
different from the behavior of constructs like `#if`.

// snippet.show
"""
