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

#include <stdint.h>
#include <string.h>
#include <moonbit.h>

#ifdef _WIN32

#include <winsock2.h>
#include <ws2tcpip.h>
#include <windows.h>

#define setsockopt(sock, level, opt, optval, len)\
  setsockopt((SOCKET)sock, level, opt, (const char*)(optval), len)

#else

#include <sys/socket.h>
#include <arpa/inet.h>
#include <netinet/tcp.h>
#include <netinet/in.h>
#include <netdb.h>
#include <stdio.h>
#include <fcntl.h>

typedef int HANDLE;
typedef int SOCKET;

#endif

MOONBIT_FFI_EXPORT
HANDLE moonbitlang_async_make_tcp_socket(int family) {
#ifdef _WIN32
  SOCKET sock = WSASocket(
    family == 4 ? AF_INET : AF_INET6,
    SOCK_STREAM,
    0,
    NULL,
    0,
    WSA_FLAG_OVERLAPPED | WSA_FLAG_NO_HANDLE_INHERIT
  );
  if (sock == INVALID_SOCKET)
    return INVALID_HANDLE_VALUE;
  return (HANDLE)sock;
#else
  return socket(family == 4 ? AF_INET : AF_INET6, SOCK_STREAM, 0);
#endif
}

MOONBIT_FFI_EXPORT
int moonbitlang_async_disable_nagle(HANDLE sock) {
  int enable = 1;
  return setsockopt(sock, IPPROTO_TCP, TCP_NODELAY, &enable, sizeof(int));
}

int moonbitlang_async_allow_reuse_addr(HANDLE sock) {
  int reuse_addr = 1;
  return setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &reuse_addr, sizeof(int));
}

MOONBIT_FFI_EXPORT
HANDLE moonbitlang_async_make_udp_socket(int family) {
#ifdef _WIN32
  SOCKET sock = WSASocket(
    family == 4 ? AF_INET : AF_INET6,
    SOCK_DGRAM,
    0,
    NULL,
    0,
    WSA_FLAG_OVERLAPPED
  );
  if (sock == INVALID_SOCKET)
    return INVALID_HANDLE_VALUE;
  return (HANDLE)sock;
#else
  return socket(family == 4 ? AF_INET : AF_INET6, SOCK_DGRAM, 0);
#endif
}

MOONBIT_FFI_EXPORT
int moonbitlang_async_set_ipv6_only(HANDLE sockfd, int ipv6_only) {
  return setsockopt(sockfd, IPPROTO_IPV6, IPV6_V6ONLY, &ipv6_only, sizeof(int));
}

MOONBIT_FFI_EXPORT
int moonbitlang_async_listen(HANDLE sockfd) {
  return listen((SOCKET)sockfd, SOMAXCONN);
}

MOONBIT_FFI_EXPORT
int moonbitlang_async_udp_client_connect(HANDLE sock, struct sockaddr *addr) {
  return connect((SOCKET)sock, addr, Moonbit_array_length(addr));
}

#ifdef TCP_KEEPINTVL
// Note for Windows:
//   According to https://learn.microsoft.com/en-us/windows/win32/winsock/ipproto-tcp-socket-options,
//   both `TCP_KEEPIDLE` and `TCP_KEEPINTVL` were introduced in Windows 10, version 1709,
//   while TCP_KEEPCNT` was introduced in Windows 10, version 1703.
//   So if `TCP_KEEPIDLE` is present, we can set keep alive stuff in a UNIX-like way.

MOONBIT_FFI_EXPORT
int moonbitlang_async_enable_keepalive(
  HANDLE sock,
  int keep_idle,
  int keep_cnt,
  int keep_intvl
) {
  int value = 1;
  if (setsockopt(sock, SOL_SOCKET, SO_KEEPALIVE, &value, sizeof(int)) < 0)
    return -1;

  if (keep_cnt > 0) {
    if (setsockopt(sock, IPPROTO_TCP, TCP_KEEPCNT, &keep_cnt, sizeof(int)) < 0)
      return -1;
  }

  if (keep_idle > 0) {
#ifdef __MACH__
    if (setsockopt(sock, IPPROTO_TCP, TCP_KEEPALIVE, &keep_idle, sizeof(int)) < 0)
      return -1;
#else
    if (setsockopt(sock, IPPROTO_TCP, TCP_KEEPIDLE, &keep_idle, sizeof(int)) < 0)
      return -1;
#endif
  }

  if (keep_intvl > 0) {
    if (setsockopt(sock, IPPROTO_TCP, TCP_KEEPINTVL, &keep_intvl, sizeof(int)) < 0)
      return -1;
  }

  return 0;
}

#elif defined(_WIN32)
// For older Windows version

MOONBIT_FFI_EXPORT
int moonbitlang_async_enable_keepalive(
  HANDLE sock,
  int keep_idle,
  int keep_cnt,
  int keep_intvl
) {
  if (keep_idle > 0 || keep_intvl > 0) {
    // On older Windows versions, we cannot set keepalive timeout and interval individually.
    // So if only one of these are specified, we set the other to the universal default
    // according to https://learn.microsoft.com/en-us/windows/win32/winsock/sio-keepalive-vals.
    struct tcp_keepalive config;
    config.onoff = 1;
    config.keepalivetime = (keep_idle > 0 ? keep_idle : 7200) * 1000;
    config.keepaliveinterval = (keep_intvl > 0 ? keep_intvl : 1) * 1000;
    DWORD number_of_bytes_returned;
    if (
      0 != WSAIoctl(
        (SOCKET)sock,
        SIO_KEEPALIVE_VALS,
        &config,
        sizeof(struct tcp_keepalive),
        NULL,
        0,
        &number_of_bytes_returned,
        NULL,
        NULL
      )
    ) {
      return -1;
    }
  } else {
    // Both `keep_idle` and `keep_intvl` are unspecified,
    // enable keep alive only and leave the timeout setting unchanged.
    int value = 1;
    if (setsockopt(sock, SOL_SOCKET, SO_KEEPALIVE, (const char*)&value, sizeof(int)) < 0)
      return -1;
  }

#ifdef TCP_KEEPCNT
  // For systems older than Windows 10, version 1703,
  // there is no way to set the keep alive count.
  if (keep_cnt > 0) {
    if (setsockopt(sock, IPPROTO_TCP, TCP_KEEPCNT, &keep_cnt, sizeof(int)) < 0)
      return -1;
  }
#endif
}

#endif

MOONBIT_FFI_EXPORT
void *moonbitlang_async_make_ip_addr(uint32_t ip, int port) {
  // For IPv4, create traditional sockaddr_in structure
  struct sockaddr_in *addr = (struct sockaddr_in*)moonbit_make_bytes(
    sizeof(struct sockaddr_in),
    0
  );
  addr->sin_family = AF_INET;
  addr->sin_port = htons(port);
  addr->sin_addr.s_addr = htonl(ip);
  return addr;
}

MOONBIT_FFI_EXPORT
void *moonbitlang_async_make_empty_addr(int family) {
  if (family == 4) {
    struct sockaddr *addr = (struct sockaddr*)moonbit_make_bytes(
      sizeof(struct sockaddr_in),
      0
    );
    addr->sa_family = AF_INET;
    return addr;
  } else {
    struct sockaddr *addr = (struct sockaddr*)moonbit_make_bytes(
      sizeof(struct sockaddr_in6),
      0
    );
    addr->sa_family = AF_INET6;
    return addr;
  };
}

MOONBIT_FFI_EXPORT
void *moonbitlang_async_make_ipv6_addr(uint8_t *ip, int port) {
  // For IPv6, create sockaddr_in6 structure directly
  struct sockaddr_in6 *addr = (struct sockaddr_in6*)moonbit_make_bytes(
    sizeof(struct sockaddr_in6),
    0
  );
  addr->sin6_family = AF_INET6;
  addr->sin6_flowinfo = 0;
  addr->sin6_port = htons(port);
  memcpy(&addr->sin6_addr, ip, 16);
  addr->sin6_scope_id = 0;
  return addr;
}

MOONBIT_FFI_EXPORT
uint32_t moonbitlang_async_ip_addr_get_ip(struct sockaddr_in *addr) {
  return ntohl(addr->sin_addr.s_addr);
}

MOONBIT_FFI_EXPORT
uint32_t moonbitlang_async_ip_addr_get_port(struct sockaddr_in *addr) {
  return ntohs(addr->sin_port);
}

MOONBIT_FFI_EXPORT
int32_t moonbitlang_async_addr_is_ipv6(void *addr_bytes) {
  // Check if the address family is AF_INET6
  // use sa_family to be compatible with more platforms(BSD, Linux)
  struct sockaddr *sa = (struct sockaddr *)addr_bytes;
  return sa->sa_family == AF_INET6;
}

MOONBIT_FFI_EXPORT
uint8_t *moonbitlang_async_addr_get_ipv6_bytes(struct sockaddr_in6 *addr) {
  return addr->sin6_addr.s6_addr;
}

MOONBIT_FFI_EXPORT
int32_t moonbitlang_async_addr_is_ipv6_wildcard(struct sockaddr_in6 *addr) {
  uint64_t *chunks = (uint64_t*)(addr->sin6_addr.s6_addr);
  return chunks[0] == 0 && chunks[1] == 0;
}

#ifdef _WIN32
typedef ADDRINFOW addrinfo_t;
#else
typedef struct addrinfo addrinfo_t;
#endif

MOONBIT_FFI_EXPORT
int32_t moonbitlang_async_addrinfo_is_null(addrinfo_t *addrinfo) {
  return addrinfo == 0;
}

MOONBIT_FFI_EXPORT
addrinfo_t *moonbitlang_async_addrinfo_get_next(addrinfo_t *addrinfo) {
  return addrinfo->ai_next;
}

MOONBIT_FFI_EXPORT
void* moonbitlang_async_addrinfo_to_addr(addrinfo_t *addrinfo, int port) {
  if (addrinfo == NULL || addrinfo->ai_addr == NULL) {
    return NULL;
  }

  if (addrinfo->ai_family == AF_INET) {
    // IPv4
    struct sockaddr_in *addr = (struct sockaddr_in*)moonbit_make_bytes(
      sizeof(struct sockaddr_in),
      0
    );
    memcpy(addr, addrinfo->ai_addr, sizeof(struct sockaddr_in));
    addr->sin_port = htons(port);
    return addr;
  } else if (addrinfo->ai_family == AF_INET6) {
    // IPv6
    struct sockaddr_in6 *addr = (struct sockaddr_in6*)moonbit_make_bytes(
      sizeof(struct sockaddr_in6),
      0
    );
    memcpy(addr, addrinfo->ai_addr, sizeof(struct sockaddr_in6));
    addr->sin6_port = htons(port);
    return addr;
  } else {
      return NULL;
  }
}

MOONBIT_FFI_EXPORT
int moonbitlang_async_getsockname(HANDLE sock, struct sockaddr *addr_out) {
  socklen_t len = Moonbit_array_length(addr_out);
  return getsockname((SOCKET)sock, addr_out, &len);
}

MOONBIT_FFI_EXPORT
int moonbitlang_async_getpeername(HANDLE sock, struct sockaddr *addr_out) {
  socklen_t len = Moonbit_array_length(addr_out);
  return getpeername((SOCKET)sock, addr_out, &len);
}
