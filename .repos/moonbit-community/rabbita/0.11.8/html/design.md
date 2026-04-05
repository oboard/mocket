# Why HTML EDSL

Here are some design choices:

- Guide Users with Type Definitions

  This package defines specific types for arguments instead of relying on a potentially confusing `String` type. These types serve as documentation, helping users understand how to correctly provide arguments.

- Seamless HTML EDSL

  Instead of relying on a precompiler to process JSX-like syntax, this EDSL allows users to leverage the full power of Moonbit's syntax and toolchain. 
    
  You can embed expressions in views without needing escape characters like `property={expression}` or `:property=expression`. For cases where the property name matches the variable name, you can use the convenient name-punning syntax, such as `property?` or `property~`.

  In this early stage, we need to focus on improving the functionality of Rabbit-TEA. Language extensions like JSX may be considered after the 1.0 release.

- Keep it simple

  No compile-time code translation or runtime reflection magic.
