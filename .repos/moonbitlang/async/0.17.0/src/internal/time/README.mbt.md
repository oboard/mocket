# internal/time

Internal wall-clock helpers used by the async runtime.

## Overview

`@internal/time` provides a single function, `ms_since_epoch`, used by timers
and scheduling code. It exposes the platform wall clock in milliseconds. The
value can jump forwards or backwards if the system clock is adjusted, so it is
suited for elapsed-time measurement (by subtraction), not for strict monotonic
ordering.

## API

`ms_since_epoch() -> Int64`

Return the current wall-clock time in milliseconds.

## Platform Behavior

- Unix/macOS: `gettimeofday()` (Unix epoch)
- Windows: `GetSystemTimeAsFileTime()` (FILETIME epoch, 1601)
- JavaScript: `Date.getTime()` (Unix epoch)

## Examples

```mbt check
///|
test "read timestamp" {
  let _ : Int64 = @time.ms_since_epoch()
}
```

```mbt check
///|
test "derive a deadline" {
  let now = @time.ms_since_epoch()
  let deadline = now + 500
  guard deadline >= now else { fail("overflow") }
}
```

## Notes

- If you need an API with stable absolute meaning, use higher-level functions
  such as `@async.now` and treat the value as opaque for ordering only.
