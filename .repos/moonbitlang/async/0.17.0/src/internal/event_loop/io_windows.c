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
#include <moonbit.h>
#include <winsock2.h>
#include <ws2tcpip.h>
#include <Mswsock.h>
#include <windows.h>

#pragma comment(lib, "ws2_32.lib")

MOONBIT_FFI_EXPORT
int32_t moonbitlang_async_init_WSA() {
  WSADATA data;
  return WSAStartup(MAKEWORD(2, 2), &data);
}

MOONBIT_FFI_EXPORT
int32_t moonbitlang_async_cleanup_WSA() {
  return WSACleanup();
}

enum IoResultKind {
  File = 0,
  Socket,
  SocketWithAddr,
  Connect,
  Accept
};

struct IoResult {
  OVERLAPPED overlapped;
  enum IoResultKind kind;
  int32_t job_id;
};

struct FileIoResult {
  struct IoResult header;

  // retain a reference to the MoonBit buffer object,
  // so that it lives long enough
  char *buf_obj;

  // pointer to the start of buffer
  char *buf;
  int32_t len;
};

struct SocketIoResult {
  struct IoResult header;

  // retain a reference to the MoonBit buffer object,
  // so that it lives long enough
  char *buf_obj;

  // data for WSA socket IO
  WSABUF buf;
  DWORD flags;
};

struct SocketWithAddrIoResult {
  struct IoResult header;

  // retain a reference to the MoonBit buffer object,
  // so that it lives long enough
  char *buf_obj;

  // data for WSA socket IO
  WSABUF buf;
  DWORD flags;

  // address buffer.
  // According to the https://learn.microsoft.com/en-us/windows/win32/api/winsock2/nf-winsock2-wsarecvfrom,
  // both the address and address length pointer of `WSARecvFrom` should be persistent
  struct sockaddr *addr;
  int addr_len;
};

struct ConnectIoResult {
  struct IoResult header;
  struct sockaddr *addr;
};

struct AcceptIoResult {
  struct IoResult header;


  // output buffer used for `AcceptEx`
  DWORD bytes_received;
  char accept_buffer[sizeof(struct sockaddr_storage) * 2];
};

static inline
struct IoResult *make_io_result(int job_id, enum IoResultKind kind, size_t size) {
  struct IoResult *result = (struct IoResult*)malloc(size);
  memset(result, 0, sizeof(OVERLAPPED));
  result->kind = kind;
  result->job_id = job_id;
  return result;
}

#define MAKE_IO_RESULT(job_id, kind)\
  (struct kind##IoResult*)make_io_result(job_id, kind, sizeof(struct kind##IoResult))

MOONBIT_FFI_EXPORT
struct FileIoResult *moonbitlang_async_make_file_io_result(
  int32_t job_id,
  char *buf,
  int32_t offset,
  int32_t len,
  int64_t position
) {
  struct FileIoResult *result = MAKE_IO_RESULT(job_id, File);
  result->header.overlapped.Offset = position & 0xffffffff;
  result->header.overlapped.OffsetHigh = position >> 32;
  result->buf_obj = buf;
  result->buf = buf + offset;
  result->len = len;
  return result;
}

MOONBIT_FFI_EXPORT
struct SocketIoResult *moonbitlang_async_make_socket_io_result(
  int32_t job_id,
  char *buf,
  int32_t offset,
  int32_t len,
  int32_t flags
) {
  struct SocketIoResult *result = MAKE_IO_RESULT(job_id, Socket);
  result->buf_obj = buf;
  result->buf.buf = buf + offset;
  result->buf.len = len;
  result->flags = flags;
  return result;
}

MOONBIT_FFI_EXPORT
struct SocketWithAddrIoResult *moonbitlang_async_make_socket_with_addr_io_result(
  int32_t job_id,
  char *buf,
  int32_t offset,
  int32_t len,
  int32_t flags,
  struct sockaddr *addr
) {
  struct SocketWithAddrIoResult *result = MAKE_IO_RESULT(job_id, SocketWithAddr);
  result->buf_obj = buf;
  result->buf.buf = buf + offset;
  result->buf.len = len;
  result->flags = flags;
  result->addr = addr;
  result->addr_len = addr->sa_family == AF_INET
    ? sizeof(struct sockaddr_in)
    : sizeof(struct sockaddr_in6);
  return result;
}

MOONBIT_FFI_EXPORT
struct ConnectIoResult *moonbitlang_async_make_connect_io_result(
  int32_t job_id,
  struct sockaddr *addr
) {
  struct ConnectIoResult *result = MAKE_IO_RESULT(job_id, Connect);
  result->addr = addr;
  return result;
}

MOONBIT_FFI_EXPORT
struct AcceptIoResult *moonbitlang_async_make_accept_io_result(int32_t job_id) {
  return MAKE_IO_RESULT(job_id, Accept);
}

MOONBIT_FFI_EXPORT
void moonbitlang_async_free_io_result(struct IoResult *obj) {
  switch (obj->kind) {
  case File:
    moonbit_decref(((struct FileIoResult*)obj)->buf_obj);
    break;
  case Socket:
    moonbit_decref(((struct SocketIoResult*)obj)->buf_obj);
    break;
  case SocketWithAddr:
    moonbit_decref(((struct SocketWithAddrIoResult*)obj)->buf_obj);
    moonbit_decref(((struct SocketWithAddrIoResult*)obj)->addr);
    break;
  case Connect:
    moonbit_decref(((struct ConnectIoResult*)obj)->addr);
    break;
  case Accept:
    break;
  }
  free(obj);
}

MOONBIT_FFI_EXPORT
int32_t moonbitlang_async_io_result_get_job_id(struct IoResult *result) {
  return result->job_id;
}

MOONBIT_FFI_EXPORT
int32_t moonbitlang_async_io_result_get_status(
  LPOVERLAPPED overlapped,
  HANDLE file
) {
  DWORD bytes_transferred;
  if (GetOverlappedResult(file, overlapped, &bytes_transferred, FALSE)) {
    return bytes_transferred;
  } else {
    return -1;
  }
}

MOONBIT_FFI_EXPORT
int32_t moonbitlang_async_cancel_io_result(LPOVERLAPPED overlapped, HANDLE handle) {
  int32_t result = CancelIoEx(handle, overlapped);
  // cancellation failure, wait for completion packet
  if (!result)
    return GetLastError() == ERROR_NOT_FOUND ? 0 : -1;

  // no need to wait if the operation already completed
  DWORD bytes_transferred;
  if (GetOverlappedResult(handle, overlapped, &bytes_transferred, FALSE))
    return 0;

  // If the operation is still pending, wait for completion packet (`return 1`).
  // Otherwise, the operation already failed, no need to wait.
  return GetLastError() == ERROR_IO_INCOMPLETE ? 1 : 0;
}

MOONBIT_FFI_EXPORT
int32_t moonbitlang_async_errno_is_read_EOF(int32_t err) {
  return err == ERROR_HANDLE_EOF || err == ERROR_BROKEN_PIPE;
}

MOONBIT_FFI_EXPORT
int moonbitlang_async_read(HANDLE handle, struct IoResult *result_obj) {
  DWORD n_read = 0;
  int success;

  switch (result_obj->kind) {
    case File: {
      struct FileIoResult *result = (struct FileIoResult*)result_obj;
      success = ReadFile(
        handle,
        result->buf,
        result->len,
        &n_read,
        (LPOVERLAPPED)result
      );
      break;
    }
    case Socket: {
      struct SocketIoResult *result = (struct SocketIoResult*)result_obj;
      success = 0 == WSARecv(
        (SOCKET)handle,
        &(result->buf),
        1,
        &n_read,
        &(result->flags),
        (LPOVERLAPPED)result,
        NULL
      );
      break;
    }
    case SocketWithAddr: {
      struct SocketWithAddrIoResult *result = (struct SocketWithAddrIoResult*)result_obj;
      success = 0 == WSARecvFrom(
        (SOCKET)handle,
        &(result->buf),
        1,
        &n_read,
        &(result->flags),
        result->addr,
        &result->addr_len,
        (LPOVERLAPPED)result,
        NULL
      );
      break;
    }
  }

  if (success) {
    return n_read;
  } else if (GetLastError() == ERROR_HANDLE_EOF) {
    return 0;
  } else {
    return -1;
  }
}

MOONBIT_FFI_EXPORT
int moonbitlang_async_write(HANDLE handle, struct IoResult *result_obj) {
  DWORD n_written = 0;
  int success;

  switch (result_obj->kind) {
    case File: {
      struct FileIoResult *result = (struct FileIoResult*)result_obj;
      success = WriteFile(
        handle,
        result->buf,
        result->len,
        &n_written,
        (LPOVERLAPPED)result
      );
      break;
    }
    case Socket: {
      struct SocketIoResult *result = (struct SocketIoResult*)result_obj;
      success = 0 == WSASend(
        (SOCKET)handle,
        &(result->buf),
        1,
        &n_written,
        result->flags,
        (LPOVERLAPPED)result,
        NULL
      );
      break;
    }
    case SocketWithAddr: {
      struct SocketWithAddrIoResult *result = (struct SocketWithAddrIoResult*)result_obj;
      success = 0 == WSASendTo(
        (SOCKET)handle,
        &(result->buf),
        1,
        &n_written,
        result->flags,
        result->addr,
        result->addr_len,
        (LPOVERLAPPED)result,
        NULL
      );
      break;
    }
  }

  return success ? n_written : -1;
}

void *get_WSA_extension(HANDLE handle, GUID *guid) {
  void *result;
  DWORD pointer_size;
  if (
    0 != WSAIoctl(
      (SOCKET)handle,
      SIO_GET_EXTENSION_FUNCTION_POINTER,
      guid,
      sizeof(GUID),
      &result,
      sizeof(void*),
      &pointer_size,
      NULL,
      NULL
    )
  ) {
    return NULL;
  }
  return result;
}

MOONBIT_FFI_EXPORT
int32_t moonbitlang_async_connect(HANDLE handle, struct ConnectIoResult *result) {
  // `ConnectEx` is a "Microsoft-specific extension to the Windows Sockets specification".
  // So we can only obtain it dynamically via `WSAIoctl` at runtime for every socket.
  GUID ConnectEx_guid = WSAID_CONNECTEX;
  LPFN_CONNECTEX ConnectEx = (LPFN_CONNECTEX)get_WSA_extension(handle, &ConnectEx_guid);
  if (!ConnectEx)
    return -1;

  // `ConnectEx` requires the socket to be bound to a local address first.
  int bind_result;
  if (result->addr->sa_family == AF_INET) {
    struct sockaddr_in addr = { AF_INET, 0, INADDR_ANY };
    bind_result = bind(
      (SOCKET)handle,
      (struct sockaddr*)&addr,
      sizeof(struct sockaddr_in)
    );
  } else {
    struct sockaddr_in6 addr = { AF_INET6, 0, 0, in6addr_any, 0 };
    bind_result = bind(
      (SOCKET)handle,
      (struct sockaddr*)&addr,
      sizeof(struct sockaddr_in6)
    );
  };
  if (bind_result != 0)
    return FALSE;

  return ConnectEx(
    (SOCKET)handle,
    result->addr,
    result->addr->sa_family == AF_INET
      ? sizeof(struct sockaddr_in)
      : sizeof(struct sockaddr_in6),
    NULL,
    0,
    NULL,
    (LPOVERLAPPED)result
  );
}

MOONBIT_FFI_EXPORT
int32_t moonbitlang_async_setup_connected_socket(HANDLE handle) {
  // We need to setup the `SO_UPDATE_CONNECT_CONTEXT` option
  // to obtain various properties such as socket address after `connect`.
  // See https://learn.microsoft.com/en-us/windows/win32/winsock/sol-socket-socket-options
  DWORD yes = TRUE;
  return setsockopt(
    (SOCKET)handle,
    SOL_SOCKET,
    SO_UPDATE_CONNECT_CONTEXT,
    (char*)&yes,
    sizeof(DWORD)
  );
}

MOONBIT_FFI_EXPORT
int32_t moonbitlang_async_accept(
  HANDLE handle,
  HANDLE conn_sock,
  struct AcceptIoResult *result
) {
  // `AcceptEx` is a "Microsoft-specific extension to the Windows Sockets specification".
  // So we can only obtain it dynamically via `WSAIoctl` at runtime for every socket.
  GUID AcceptEx_guid = WSAID_ACCEPTEX;
  // TODO: cache `AcceptEx` and compute it only once for each socket
  LPFN_ACCEPTEX AcceptEx = (LPFN_ACCEPTEX)get_WSA_extension(handle, &AcceptEx_guid);
  if (!AcceptEx)
    return -1;

  return AcceptEx(
    (SOCKET)handle,
    (SOCKET)conn_sock,
    &(result->accept_buffer),
    0,
    sizeof(struct sockaddr_storage),
    sizeof(struct sockaddr_storage),
    &(result->bytes_received),
    (LPOVERLAPPED)result
  );
}

MOONBIT_FFI_EXPORT
int32_t moonbitlang_async_setup_accepted_socket(HANDLE listen_sock, HANDLE accept_sock) {
  // We need to setup the `SO_UPDATE_ACCEPT_CONTEXT` option
  // to obtain various properties such as socket address after `accept`.
  // See https://learn.microsoft.com/en-us/windows/win32/api/mswsock/nf-mswsock-acceptex
  //
  // According to https://learn.microsoft.com/en-us/windows/win32/winsock/sol-socket-socket-options,
  // the type of `SO_UPDATE_ACCEPT_CONTEXT` option is a DWORD (boolean).
  // BUT IT IS NOT.
  // The listen socket should be passed as value for `SO_UPDATE_ACCEPT_CONTEXT`.
  return setsockopt(
    (SOCKET)accept_sock,
    SOL_SOCKET,
    SO_UPDATE_ACCEPT_CONTEXT,
    (char*)&listen_sock,
    sizeof(UINT_PTR)
  );
}

MOONBIT_FFI_EXPORT
HANDLE moonbitlang_async_get_std_handle(int32_t id) {
  return GetStdHandle(id);
}

#endif // #ifdef _WIN32
