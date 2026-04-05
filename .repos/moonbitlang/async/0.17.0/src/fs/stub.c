/*
 * Copyright 2025 International Digital Economy Academy
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#ifdef _WIN32

#include <windows.h>
#include <moonbit.h>

#else

#include <fcntl.h>
#include <stdint.h>
#include <unistd.h>
#include <dirent.h>
#include <string.h>
#include <errno.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <sys/file.h>
#include <moonbit.h>

#endif


#ifndef _WIN32

int moonbitlang_async_dir_is_null(DIR *dir) {
  return dir == 0;
}

#endif


#ifdef _WIN32

MOONBIT_FFI_EXPORT
int32_t moonbitlang_async_errno_is_lock_violation(int32_t err) {
  return err == ERROR_LOCK_VIOLATION;
}

MOONBIT_FFI_EXPORT
int moonbitlang_async_try_lock_file(HANDLE handle, int exclusive) {
  OVERLAPPED overlapped;
  memset(&overlapped, 0, sizeof(OVERLAPPED));
  // See the comment on `flock_job_worker` in `thread_pool.c` for more details
  overlapped.Offset = 0xfffffffe;
  overlapped.OffsetHigh = 0xffffffff;
  BOOL result = LockFileEx(
    handle,
    LOCKFILE_FAIL_IMMEDIATELY | (exclusive ? LOCKFILE_EXCLUSIVE_LOCK : 0),
    0,
    1,
    0,
    &overlapped
  );
  return result ? 0 : -1;
}

MOONBIT_FFI_EXPORT
int moonbitlang_async_unlock_file(HANDLE handle) {
  BOOL result = UnlockFile(handle, 0xfffffffe, 0xffffffff, 1, 0);
  return result ? 0 : -1;
}

#else

int32_t moonbitlang_async_errno_is_lock_violation(int32_t err) {
  return err == EWOULDBLOCK;
}

int moonbitlang_async_try_lock_file(int fd, int exclusive) {
  return flock(fd, LOCK_NB | (exclusive ? LOCK_EX : LOCK_SH));
}

int moonbitlang_async_unlock_file(int fd) {
  return flock(fd, LOCK_UN);
}

#endif

#ifdef _WIN32

MOONBIT_FFI_EXPORT
moonbit_string_t moonbitlang_async_get_tmp_path() {
  static wchar_t buffer[1024];

  const DWORD buffer_len = sizeof(buffer) / sizeof(wchar_t);
  DWORD len = GetTempPath2W(buffer_len, buffer);

  if (len == 0) {
    return NULL;
  }

  if (len > buffer_len) {
    moonbit_string_t str = moonbit_make_string_raw(len - 1);
    len = GetTempPath2W(len, (LPWSTR)str);
    return len == 0 ? NULL : str;
  } else {
    moonbit_string_t str = moonbit_make_string_raw(len);
    memcpy(str, buffer, len * sizeof(wchar_t));
    return str;
  }
}

#else

moonbit_string_t moonbitlang_async_get_tmp_path() {
  const char *path;
#ifdef __ANDROID__
  const char *tmpdir = getenv("TMPDIR");
  path = tmpdir ? tmpdir : "/data/local/tmp/";
#else
  path = "/tmp/";
#endif
  size_t len = strlen(path);
  moonbit_string_t str = moonbit_make_string_raw(len);
  for (size_t i = 0; i < len; i++) {
    ((uint16_t*)str)[i] = (uint16_t)(unsigned char)path[i];
  }
  return str;
}
#endif
