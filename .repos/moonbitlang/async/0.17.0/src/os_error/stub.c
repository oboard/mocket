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

#include <string.h>
#include <moonbit.h>

#ifdef _WIN32
#include <windows.h>
#else
#include <errno.h>
#endif

MOONBIT_FFI_EXPORT
int moonbitlang_async_get_errno() {
#ifdef _WIN32
  return GetLastError();
#else
  return errno;
#endif
}

MOONBIT_FFI_EXPORT
int moonbitlang_async_is_nonblocking_io_error(int err) {
#ifdef _WIN32
  return err == ERROR_IO_INCOMPLETE || err == ERROR_IO_PENDING;
#else
  return err == EAGAIN || err == EINPROGRESS || err == EWOULDBLOCK;
#endif
}

MOONBIT_FFI_EXPORT
int moonbitlang_async_is_EINTR(int err) {
#ifdef _WIN32
  // TODO: alertable wait?
  return 0;
#else
  return err == EINTR;
#endif
}

MOONBIT_FFI_EXPORT
int moonbitlang_async_is_ENOENT(int err) {
#ifdef _WIN32
  return err == ERROR_FILE_NOT_FOUND || err == ERROR_PATH_NOT_FOUND;
#else
  return err == ENOENT;
#endif
}

MOONBIT_FFI_EXPORT
int moonbitlang_async_is_EEXIST(int err) {
#ifdef _WIN32
  return err == ERROR_FILE_EXISTS || err == ERROR_ALREADY_EXISTS;
#else
  return err == EEXIST;
#endif
}

MOONBIT_FFI_EXPORT
int moonbitlang_async_is_EACCES(int err) {
#ifdef _WIN32
  return err == ERROR_ACCESS_DENIED;
#else
  return err == EACCES;
#endif
}

MOONBIT_FFI_EXPORT
int moonbitlang_async_is_ECONNREFUSED(int err) {
#ifdef _WIN32
  return err == ERROR_CONNECTION_REFUSED;
#else
  return err == ECONNREFUSED;
#endif
}

MOONBIT_FFI_EXPORT
char *moonbitlang_async_errno_to_string(int err) {
#ifdef _WIN32
  LPWSTR result = 0;
  if (
    !FormatMessageW(
      FORMAT_MESSAGE_ALLOCATE_BUFFER
      | FORMAT_MESSAGE_FROM_SYSTEM
      | FORMAT_MESSAGE_IGNORE_INSERTS,
      NULL,
      err,
      0x409, // language ID for en-US
      (LPWSTR)&result,
      1,
      NULL
    )
  ) {
    return moonbitlang_async_errno_to_string(GetLastError());
  }
  return (char*)result;
#else
  return strerror(err);
#endif
}

MOONBIT_FFI_EXPORT
void moonbitlang_async_free_errno_str(void *ptr) {
#ifdef _WIN32
  LocalFree(ptr);
#endif
}
