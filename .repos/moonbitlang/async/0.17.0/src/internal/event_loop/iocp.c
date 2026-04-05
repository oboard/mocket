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

MOONBIT_FFI_EXPORT
HANDLE moonbitlang_async_poll_create() {
  return CreateIoCompletionPort(INVALID_HANDLE_VALUE, NULL, 0, 0);
}

MOONBIT_FFI_EXPORT
void moonbitlang_async_poll_destroy(HANDLE iocp) {
  CloseHandle(iocp);
}

MOONBIT_FFI_EXPORT
int moonbitlang_async_poll_register(HANDLE iocp, HANDLE fd) {
  if (!SetFileCompletionNotificationModes(fd, FILE_SKIP_COMPLETION_PORT_ON_SUCCESS))
    return -1;
  return CreateIoCompletionPort(fd, iocp, (ULONG_PTR)fd, 0) == NULL ? -1 : 0;
}

#define EVENT_BUFFER_SIZE 1024
static OVERLAPPED_ENTRY event_buffer[EVENT_BUFFER_SIZE];

MOONBIT_FFI_EXPORT
int moonbitlang_async_poll_wait(HANDLE iocp, int timeout) {
  ULONG n;
  if (
    !GetQueuedCompletionStatusEx(
      iocp,
      event_buffer,
      EVENT_BUFFER_SIZE,
      &n,
      timeout < 0 ? INFINITE : timeout,
      0
    )
  ) {
    return GetLastError() == WAIT_TIMEOUT ? 0 : -1;
  }
  return n;
}

MOONBIT_FFI_EXPORT
OVERLAPPED_ENTRY *moonbitlang_async_event_list_get(int index) {
  return event_buffer + index;
}

MOONBIT_FFI_EXPORT
HANDLE moonbitlang_async_event_get_fd(OVERLAPPED_ENTRY *entry) {
  return (HANDLE)entry->lpCompletionKey;
}

MOONBIT_FFI_EXPORT
LPOVERLAPPED moonbitlang_async_event_get_io_result(OVERLAPPED_ENTRY *entry) {
  LPOVERLAPPED result = entry->lpOverlapped;
  return result;
}

MOONBIT_FFI_EXPORT
int32_t moonbitlang_async_event_get_bytes_transferred(OVERLAPPED_ENTRY *entry) {
  return entry->dwNumberOfBytesTransferred;
}

#endif
