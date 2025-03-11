# RegExp
[![check](https://github.com/yj-qin/regexp/actions/workflows/check.yml/badge.svg)](https://github.com/yj-qin/regexp/actions/workflows/check.yml)

A regular expression module based on a backtracking engine. Due to backtracking during matching, some regular expressions will run for a long time under specific inputs, also known as catastrophic backtracking.
The design of the bytecode and interpreter was heavily inspired by the .NET regular expression library.

## Usage

```
let regexp = @regexp.compile!("^(?<addr>[a-zA-Z0-9._%+-]+)@(?<host>[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,})$")
let match_result = regexp.matches("12345@test.com")
println(match_result.success()) // true
println(match_result.captures()) // ["12345@test.com", "12345", "test.com"]
println(match_result.named_captures()) // {"addr": "12345", "host": "test.com"}
```

## Features

### Character classes

- [x] Character range
- [x] Escapes (e.g. `\d`, `\D`, `\s`, `\S`, `\w`, `\W`)

### Assertions

- [x] Begin of input
- [x] End of input
- [ ] Word boundary
- [ ] Lookaround

### Groups

- [x] Capturing group
- [x] Non-capturing group
- [x] Named capturing group

### Backreferences

- [ ] Group backreference
- [ ] Named backreference

### Quantifiers

- [x] Zero or more (\*)
- [x] Zero or one (?)
- [x] One or more (+)
- [x] Range ({n}, {n,}, {n, m})
- [x] Non-greedy

### Encodings

- [ ] Unicode
