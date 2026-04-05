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

#ifdef __linux__

#include <unistd.h>
#include <sys/syscall.h>
#include <sys/epoll.h>
#include <sys/wait.h>
#include <errno.h>
#include <linux/version.h>

int moonbitlang_async_poll_create() {
  return epoll_create1(0);
}

void moonbitlang_async_poll_destroy(int epfd) {
  close(epfd);
}

static const int ev_masks[] = {
  0,
  EPOLLIN,
  EPOLLOUT,
  EPOLLIN | EPOLLOUT,
};

// use mask to classify different kinds of entity
static const uint64_t pid_mask = (uint64_t)1 << 63;

int moonbitlang_async_poll_register(
  int epfd,
  int fd,
  int prev_events,
  int new_events,
  int oneshot
) {
  int events = ev_masks[prev_events | new_events];
  if (oneshot)
    events |= EPOLLONESHOT;

  events |= EPOLLET;
  events |= EPOLLRDHUP;

  epoll_data_t data;
  data.u64 = fd;
  struct epoll_event event = { events, data };
  int op = prev_events == 0 ? EPOLL_CTL_ADD : EPOLL_CTL_MOD;
  return epoll_ctl(epfd, op, fd, &event);
}

int moonbitlang_async_support_wait_pid_via_poll() {
#if LINUX_VERSION_CODE >= KERNEL_VERSION(5, 3, 0)
  int pidfd = syscall(SYS_pidfd_open, getpid(), 0);
  if (pidfd >= 0) {
    close(pidfd);
    return 1;
  } else {
    // TODO: check if `errno` is one of `ENOSYS` or `EPERM`.
    return 0;
  }
#else
  return 0;
#endif
}

// return value:
// - `>= 0`: success, return the pidfd
// - `-1`: failure
// - `-2`: already terminated
int moonbitlang_async_poll_register_pid(int epfd, pid_t pid) {
#if LINUX_VERSION_CODE >= KERNEL_VERSION(5, 3, 0)

  int pidfd = syscall(SYS_pidfd_open, pid, 0);
  if (pidfd < 0)
    return -1;

  epoll_data_t data;
  data.u64 = pid_mask | pidfd;

  struct epoll_event event = { EPOLLIN, data };
  int ret = epoll_ctl(epfd, EPOLL_CTL_ADD, pidfd, &event);
  if (ret < 0) {
    close(pidfd);
    return -1;
  }

  return pidfd;

#else

  return -1;

#endif
}

int moonbitlang_async_poll_remove(int epfd, int fd, int events) {
  return epoll_ctl(epfd, EPOLL_CTL_DEL, fd, 0);
}

int moonbitlang_async_poll_remove_pid(int epfd, int pidfd) {
  int ret = epoll_ctl(epfd, EPOLL_CTL_DEL, pidfd, 0);
  close(pidfd);
  return ret;
}

#define EVENT_BUFFER_SIZE 1024
static struct epoll_event event_buffer[EVENT_BUFFER_SIZE];

int moonbitlang_async_poll_wait(int epfd, int timeout) {
  return epoll_wait(epfd, event_buffer, EVENT_BUFFER_SIZE, timeout);
}

// wrapper for handling event list
struct epoll_event* moonbitlang_async_event_list_get(int index) {
  return event_buffer + index;
}

int moonbitlang_async_event_get_fd(struct epoll_event *ev) {
  return ev->data.u64 & ~pid_mask;
}

int moonbitlang_async_event_get_events(struct epoll_event *ev) {
  if (ev->data.u64 & pid_mask)
    return 4;

  if (ev->events & (EPOLLERR | EPOLLHUP | EPOLLRDHUP))
    return 3;

  int result = 0;
  if (ev->events & EPOLLIN)
    result |= 1;
  if (ev->events & EPOLLOUT)
    result |= 2;

  return result;
}

#endif
