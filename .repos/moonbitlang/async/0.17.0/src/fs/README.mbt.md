# File System API (`@moonbitlang/async/fs`)

Asynchronous file system operations for MoonBit. This package provides comprehensive APIs for working with files, directories, and file metadata.

## Table of Contents

- [File Operations](#file-operations)
  - [Opening and Creating Files](#opening-and-creating-files)
  - [Reading Files](#reading-files)
  - [Writing Files](#writing-files)
  - [File Seeking](#file-seeking)
- [Directory Operations](#directory-operations)
  - [Creating Directories](#creating-directories)
  - [Reading Directories](#reading-directories)
  - [Walking Directory Trees](#walking-directory-trees)
  - [Removing Directories](#removing-directories)
- [File Metadata](#file-metadata)
  - [File Kind](#file-kind)
  - [Timestamps](#timestamps)
  - [File Permissions](#file-permissions)
- [Path Operations](#path-operations)
- [Types Reference](#types-reference)

## File Operations

### Opening and Creating Files

The `open` function provides flexible file opening with various modes and options:

```moonbit check
///|
#cfg(target="native")
async test "open file for reading" {
  let test_file = "_build/test_open_read.txt"
  @fs.write_file(test_file, b"Hello, MoonBit!", create=0o644)
  let file = @fs.open(test_file, mode=ReadOnly)
  defer file.close()
  let content = file.read_all().text()
  @fs.remove(test_file)
  inspect(content, content="Hello, MoonBit!")
}

///|
#cfg(target="native")
async test "open file for writing" {
  let test_file = "_build/test_open_write.txt"
  let file = @fs.open(test_file, mode=WriteOnly, create=0o644, truncate=true)
  defer file.close()
  file.write(b"Hello, World!")
  @fs.remove(test_file)
}

///|
#cfg(target="native")
async test "open with append mode" {
  let test_file = "_build/test_append.txt"
  // Create initial file
  @fs.write_file(test_file, b"First line\n", create=0o644)

  // Append to existing file
  let file = @fs.open(test_file, mode=WriteOnly, append=true)
  file.write(b"Second line\n")
  file.close()
  let content = @fs.read_file(test_file).text()
  @fs.remove(test_file)
  inspect(content, content="First line\nSecond line\n")
}
```

The `create` function is a convenience wrapper for creating new files:

```moonbit check
///|
#cfg(target="native")
async test "create new file" {
  let test_file = "_build/test_create.txt"
  let file = @fs.create(test_file, permission=0o644)
  file.write(b"New file content")
  file.close()
  let exists = @fs.exists(test_file)
  @fs.remove(test_file)
  inspect(exists, content="true")
}
```

### Reading Files

Read entire files or read data in chunks:

```moonbit check
///|
#cfg(target="native")
async test "read_file - read entire file" {
  let test_file = "_build/test_read_file.txt"
  @fs.write_file(test_file, b"Hello, MoonBit!", create=0o644)
  let content = @fs.read_file(test_file)
  @fs.remove(test_file)
  inspect(content.text(), content="Hello, MoonBit!")
}

///|
#cfg(target="native")
async test "read in chunks using File" {
  let test_file = "_build/test_chunk_read.txt"
  @fs.write_file(test_file, b"0123456789", create=0o644)
  let file = @fs.open(test_file, mode=ReadOnly)
  defer file.close()
  let buf = FixedArray::make(5, b'0')
  let n = file.read(buf)
  @fs.remove(test_file)
  inspect(n, content="5")
  inspect(@utf8.decode(buf.unsafe_reinterpret_as_bytes()), content="01234")
}

///|
#cfg(target="native")
async test "read_all from file" {
  let test_file = "_build/test_read_all.txt"
  @fs.write_file(test_file, b"Complete content", create=0o644)
  let file = @fs.open(test_file, mode=ReadOnly)
  let data = file.read_all()
  file.close()
  @fs.remove(test_file)
  inspect(data.text(), content="Complete content")
}

///|
#cfg(target="native")
async test "read_exactly specific bytes" {
  let test_file = "_build/test_read_exact.txt"
  @fs.write_file(test_file, b"1234567890", create=0o644)
  let file = @fs.open(test_file, mode=ReadOnly)
  let bytes = file.read_exactly(5)
  file.close()
  @fs.remove(test_file)
  inspect(@utf8.decode(bytes), content="12345")
}
```

### Writing Files

Write data to files using various methods:

```moonbit check
///|
#cfg(target="native")
async test "write_file - write entire file" {
  let test_file = "_build/test_write.txt"
  @fs.write_file(test_file, b"File content", create=0o644)
  let content = @fs.read_file(test_file).text()
  @fs.remove(test_file)
  inspect(content, content="File content")
}

///|
#cfg(target="native")
async test "write with sync modes" {
  let test_file = "_build/test_sync.txt"
  // Write with data sync
  @fs.write_file(test_file, b"Synced data", sync=Data, create=0o644)
  let content = @fs.read_file(test_file).text()
  @fs.remove(test_file)
  inspect(content, content="Synced data")
}

///|
#cfg(target="native")
async test "write using File methods" {
  let test_file = "_build/test_file_write.txt"
  let file = @fs.create(test_file, permission=0o644)
  file.write(b"Line 1\n")
  file.write(b"Line 2\n")
  file.close()
  let content = @fs.read_file(test_file).text()
  @fs.remove(test_file)
  inspect(content, content="Line 1\nLine 2\n")
}

///|
#cfg(target="native")
async test "write_once for single write operation" {
  let test_file = "_build/test_write_once.txt"
  let file = @fs.create(test_file, permission=0o644)
  let data : Bytes = b"Single write"
  let written = file.write_once(data, offset=0, len=data.length())
  file.close()
  @fs.remove(test_file)
  inspect(written, content="12")
}
```

### Random access on files

Read and write file from specified position:

```moonbit check
///|
#cfg(target="native")
async test "read at specific position" {
  let test_file = "_build/read_at_test.txt"
  @fs.write_file(test_file, b"0123456789", create=0o644)
  {
    let file = @fs.open(test_file, mode=ReadOnly)
    defer file.close()

    // read 3 bytes at position 5
    json_inspect(file.read_exactly_at(3, position=5), content="567")

    // use `read_at` to handle EOF robustly
    let buf = FixedArray::make(10, b'\x00')
    let n = file.read_at(buf, position=5)
    inspect(n, content="5")
    json_inspect(buf.unsafe_reinterpret_as_bytes()[:n], content="56789")
  }
  @fs.remove(test_file)
}

///|
#cfg(target="native")
async test "write at specific position" {
  let test_file = "_build/write_at_test.txt"
  {
    let file = @fs.open(test_file, mode=WriteOnly, create=0o644)
    defer file.close()
    file.write("abcdef")
    file.write_at("CD", position=2)
  }

  // read 3 bytes at position 5
  inspect(@fs.read_file(test_file).text(), content="abCDef")
  @fs.remove(test_file)
}

///|
#cfg(target="native")
async test "size - get file size" {
  let test_file = "_build/test_size.txt"
  @fs.write_file(test_file, b"Hello", create=0o644)
  let file = @fs.open(test_file, mode=ReadOnly)
  let size = file.size()
  file.close()
  @fs.remove(test_file)
  inspect(size, content="5")
}
```

Some important notes when using `read_at` and `write_at`:

- only seekable files (i.e. regular files or block devices) support `read_at` and `write_at`. Calling `read_at` and `write_at` on unsupported file types result in error
- `read_at` and `write_at` does not modify the cursor for reading/writing the file as a stream
- `read_at` always read as much as possible. When its return value is smaller than requested length, it always indicates EOF

## Directory Operations

### Creating Directories

```moonbit check
///|
#cfg(target="native")
async test "mkdir - create directory" {
  let dir_path = "_build/test_mkdir"
  @fs.mkdir(dir_path, permission=0o755)
  let exists = @fs.exists(dir_path)
  @fs.rmdir(dir_path)
  inspect(exists, content="true")
}

///|
#cfg(target="native")
async test "mkdir - create with custom permissions" {
  let dir_path = "_build/test_mkdir_perm"
  @fs.mkdir(dir_path, permission=0o700)
  let kind = @fs.kind(dir_path)
  @fs.rmdir(dir_path)
  inspect(kind, content="Directory")
}
```

### Reading Directories

```moonbit check
///|
#cfg(target="native")
async test "readdir - read directory entries" {
  let dir_path = "_build/test_readdir"
  @fs.mkdir(dir_path, permission=0o755)
  @fs.write_file("\{dir_path}/test1.txt", b"", create=0o644)
  @fs.write_file("\{dir_path}/test2.txt", b"", create=0o644)
  let entries = @fs.readdir(
    dir_path,
    include_hidden=false,
    include_special=false,
  )
  @fs.remove("\{dir_path}/test1.txt")
  @fs.remove("\{dir_path}/test2.txt")
  @fs.rmdir(dir_path)
  inspect(entries.length(), content="2")
}

///|
#cfg(target="native")
async test "readdir with sorting" {
  let dir_path = "_build/test_readdir_sort"
  @fs.mkdir(dir_path, permission=0o755)
  @fs.write_file("\{dir_path}/c.txt", b"", create=0o644)
  @fs.write_file("\{dir_path}/a.txt", b"", create=0o644)
  @fs.write_file("\{dir_path}/b.txt", b"", create=0o644)
  let entries = @fs.readdir(dir_path, sort=true)
  @fs.remove("\{dir_path}/a.txt")
  @fs.remove("\{dir_path}/b.txt")
  @fs.remove("\{dir_path}/c.txt")
  @fs.rmdir(dir_path)
  inspect(entries[0], content="a.txt")
  inspect(entries[1], content="b.txt")
  inspect(entries[2], content="c.txt")
}

///|
#cfg(target="native")
async test "opendir and Directory::read_all" {
  let dir_path = "_build/test_opendir"
  @fs.mkdir(dir_path, permission=0o755)
  @fs.write_file("\{dir_path}/file1.txt", b"test", create=0o644)
  @fs.write_file("\{dir_path}/file2.txt", b"test", create=0o644)
  let dir = @fs.opendir(dir_path)
  let entries = dir.read_all(include_hidden=false, include_special=false)
  dir.close()
  @fs.remove("\{dir_path}/file1.txt")
  @fs.remove("\{dir_path}/file2.txt")
  @fs.rmdir(dir_path)
  inspect(entries.length(), content="2")
  inspect(entries.contains("file1.txt"), content="true")
  inspect(entries.contains("file2.txt"), content="true")
}
```

### Walking Directory Trees

Recursively traverse directory hierarchies:

```moonbit check
///|
#cfg(target="native")
async test "walk directory tree" {
  let base = "_build/test_walk"
  @fs.mkdir(base, permission=0o755)
  @fs.mkdir("\{base}/sub1", permission=0o755)
  @fs.mkdir("\{base}/sub2", permission=0o755)
  @fs.write_file("\{base}/file.txt", b"", create=0o644)
  @fs.write_file("\{base}/sub1/file1.txt", b"", create=0o644)
  let visited : Ref[Int] = Ref::new(0)
  @fs.walk(base, fn(_path, _files) { visited.val = visited.val + 1 })
  @fs.remove("\{base}/file.txt")
  @fs.remove("\{base}/sub1/file1.txt")
  @fs.rmdir("\{base}/sub1")
  @fs.rmdir("\{base}/sub2")
  @fs.rmdir(base)
  inspect(visited.val >= 3, content="true")
}

///|
#cfg(target="native")
async test "walk with max_concurrency" {
  let base = "_build/test_walk_concurrency"
  @fs.mkdir(base, permission=0o755)
  @fs.mkdir("\{base}/dir1", permission=0o755)
  @fs.mkdir("\{base}/dir2", permission=0o755)
  let count : Ref[Int] = Ref::new(0)
  @fs.walk(
    base,
    fn(_path, _files) { count.val = count.val + 1 },
    max_concurrency=1,
  )
  @fs.rmdir("\{base}/dir1")
  @fs.rmdir("\{base}/dir2")
  @fs.rmdir(base)
  inspect(count.val >= 3, content="true")
}
```

### Removing Directories

```moonbit check
///|
#cfg(target="native")
async test "rmdir - remove empty directory" {
  let dir_path = "_build/test_rmdir"
  @fs.mkdir(dir_path, permission=0o755)
  @fs.rmdir(dir_path)
  let exists = @fs.exists(dir_path)
  inspect(exists, content="false")
}

///|
#cfg(target="native")
async test "rmdir recursive - remove directory tree" {
  let base = "_build/test_rmdir_recursive"
  @fs.mkdir(base, permission=0o755)
  @fs.mkdir("\{base}/subdir", permission=0o755)
  @fs.write_file("\{base}/file.txt", b"test", create=0o644)
  @fs.write_file("\{base}/subdir/nested.txt", b"test", create=0o644)
  @fs.rmdir(base, recursive=true)
  let exists = @fs.exists(base)
  inspect(exists, content="false")
}
```

## File Metadata

### File Kind

Determine the type of file system entries:

```moonbit check
///|
#cfg(target="native")
async test "kind - regular file" {
  let test_file = "_build/test_kind_file.txt"
  @fs.write_file(test_file, b"test", create=0o644)
  let kind = @fs.kind(test_file)
  @fs.remove(test_file)
  inspect(kind, content="Regular")
}

///|
#cfg(target="native")
async test "kind - directory" {
  let dir_path = "_build/test_kind_dir"
  @fs.mkdir(dir_path, permission=0o755)
  let kind = @fs.kind(dir_path)
  @fs.rmdir(dir_path)
  inspect(kind, content="Directory")
}

///|
#cfg(target="native")
async test "File::kind method" {
  let test_file = "_build/test_file_kind.txt"
  @fs.write_file(test_file, b"test", create=0o644)
  let file = @fs.open(test_file, mode=ReadOnly)
  let kind = file.kind()
  file.close()
  @fs.remove(test_file)
  inspect(kind, content="Regular")
}
```

### Timestamps

Access file timestamps (atime, mtime, ctime):

```moonbit check
///|
#cfg(all(target="native", not(platform="windows")))
async test "atime - access time" {
  let test_file = "_build/test_atime.txt"
  @fs.write_file(test_file, b"test", create=0o644)
  let (seconds, nanoseconds) = @fs.atime(test_file)
  @fs.remove(test_file)
  inspect(seconds > 0, content="true")
  inspect(nanoseconds >= 0, content="true")
}

///|
#cfg(target="native")
async test "mtime - modification time" {
  let test_file = "_build/test_mtime.txt"
  @fs.write_file(test_file, b"test", create=0o644)
  let (seconds, nanoseconds) = @fs.mtime(test_file)
  @fs.remove(test_file)
  inspect(seconds > 0, content="true")
  inspect(nanoseconds >= 0, content="true")
}

///|
#cfg(target="native")
async test "ctime - status change time" {
  let test_file = "_build/test_ctime.txt"
  @fs.write_file(test_file, b"test", create=0o644)
  let (seconds, nanoseconds) = @fs.ctime(test_file)
  @fs.remove(test_file)
  inspect(seconds > 0, content="true")
  inspect(nanoseconds >= 0, content="true")
}

///|
#cfg(target="native")
async test "File timestamp methods" {
  let test_file = "_build/test_file_times.txt"
  @fs.write_file(test_file, b"test", create=0o644)
  let file = @fs.open(test_file, mode=ReadOnly)
  let (atime_s, _) = file.atime()
  let (mtime_s, _) = file.mtime()
  let (ctime_s, _) = file.ctime()
  file.close()
  @fs.remove(test_file)
  inspect(atime_s > 0, content="true")
  inspect(mtime_s > 0, content="true")
  inspect(ctime_s > 0, content="true")
}
```

### File Permissions

Check file access permissions:

```moonbit check
///|
#cfg(target="native")
async test "exists - check file existence" {
  let test_file = "_build/test_exists.txt"
  @fs.write_file(test_file, b"test", create=0o644)
  let exists = @fs.exists(test_file)
  @fs.remove(test_file)
  inspect(exists, content="true")
}

///|
#cfg(target="native")
async test "exists - non-existent file" {
  let exists = @fs.exists("nonexistent_file_xyz.txt")
  inspect(exists, content="false")
}

///|
#cfg(target="native")
async test "can_read - check read permission" {
  let test_file = "_build/test_can_read.txt"
  @fs.write_file(test_file, b"test", create=0o644)
  let can_read = @fs.can_read(test_file)
  @fs.remove(test_file)
  inspect(can_read, content="true")
}

///|
#cfg(target="native")
async test "can_write - check write permission" {
  let test_file = "_build/test_can_write.txt"
  @fs.write_file(test_file, b"test", create=0o644)
  let can_write = @fs.can_write(test_file)
  @fs.remove(test_file)
  inspect(can_write, content="true")
}

///|
#cfg(target="native")
async test "can_execute - check execute permission" {
  let test_file = "_build/test_can_execute.txt"
  @fs.write_file(test_file, b"test", create=0o755)
  let can_execute = @fs.can_execute(test_file)
  @fs.remove(test_file)
  inspect(can_execute, content="true")
}
```

## Path Operations

```moonbit check
///|
#cfg(target="native")
async test "realpath - resolve absolute path" {
  let test_dir = "_build/test_realpath"
  @fs.mkdir(test_dir, permission=0o755)
  let real_path = @fs.realpath(test_dir)
  @fs.rmdir(test_dir)
  guard @env.current_dir() is Some(cwd)
  assert_true(real_path.has_prefix(cwd))
  inspect(
    // replace `\\` with `/` for Windows
    real_path[cwd.length():].replace_all(old="\\", new="/"),
    content="/_build/test_realpath",
  )
}
```

## File Removal

```moonbit check
///|
#cfg(target="native")
async test "remove - delete file" {
  let test_file = "_build/test_remove.txt"
  @fs.write_file(test_file, b"test", create=0o644)
  @fs.remove(test_file)
  let exists = @fs.exists(test_file)
  inspect(exists, content="false")
}
```

## Types Reference

### FileKind

Represents the type of a file system entry:

- `Regular` - Regular file
- `Directory` - Directory
- `SymLink` - Symbolic link
- `Socket` - Unix socket
- `Pipe` - Named pipe (FIFO)
- `BlockDevice` - Block device
- `CharDevice` - Character device
- `Unknown` - Unknown file type

### Mode

File opening mode:

- `ReadOnly` - Open for reading only
- `WriteOnly` - Open for writing only
- `ReadWrite` - Open for both reading and writing

### SyncMode

Data synchronization mode:

- `NoSync` - No synchronization (default)
- `Data` - Sync data and essential metadata (like file size)
- `Full` - Sync all data and metadata

### SeekMode

How to interpret seek offsets:

- `FromStart` - Absolute offset from start of file
- `FromEnd` - Offset relative to end of file
- `Relative` - Offset relative to current position

### File

Main file handle type. Methods include:
- `fd()` - Get file descriptor
- `close()` - Close file
- `read()` - Read data into buffer
- `read_all()` - Read entire file content
- `read_exactly()` - Read exact number of bytes
- `write()` - Write data
- `write_once()` - Single write operation
- `read_at()` - Read file at specified position
- `read_exact_at()` - Read exect number of bytes at specified position
- `write_at()` - Write file at specified position
- `size()` - Get file size
- `kind()` - Get file kind
- `atime()`, `mtime()`, `ctime()` - Get timestamps

### Directory

Directory handle for reading directory entries:
- `close()` - Close directory
- `read_all()` - Read all entries

## Best Practices

1. **Always close files**: Use `defer file.close()` after opening files
2. **Use appropriate sync modes**: `NoSync` for performance, `Data` or `Full` for durability
3. **Handle permissions**: Specify appropriate UNIX permissions (e.g., `0o644` for files, `0o755` for directories)
4. **Check existence**: Use `exists()` before performing operations on files
5. **Use convenience functions**: `read_file()` and `write_file()` are simpler for common cases
6. **Walk with limits**: Use `max_concurrency` parameter when walking large directory trees

## Error Handling

All async file operations can raise errors. Use proper error handling:

```moonbit check
///|
#cfg(target="native")
async test "error handling example" {
  let result = try? @fs.read_file("nonexistent.txt")
  inspect(result is Err(_), content="true")
}
```

For more examples and detailed usage, see the individual test files in this package.
