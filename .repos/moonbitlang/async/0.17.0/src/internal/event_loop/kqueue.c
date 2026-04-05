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

#if defined(__MACH__) || defined(BSD)

#include <unistd.h>
#include <time.h>
#include <sys/event.h>
#include <sys/wait.h>
#include <errno.h>

int moonbitlang_async_poll_create() {
  return kqueue();
}

void moonbitlang_async_poll_destroy(int kqfd) {
  close(kqfd);
}

static const int ev_masks[] = {
  0,
  EVFILT_READ,
  EVFILT_WRITE,
  EVFILT_READ | EVFILT_WRITE
};

int moonbitlang_async_poll_register(
  int kqfd,
  int fd,
  int prev_events,
  int new_events,
  int oneshot
) {
  int filter = ev_masks[new_events];

  int flags = EV_ADD | EV_CLEAR;
  if (oneshot)
    flags |= EV_DISPATCH;

  struct kevent event;
  EV_SET(&event, fd, filter, flags, 0, 0, 0);
  return kevent(kqfd, &event, 1, 0, 0, 0);
}

int moonbitlang_async_support_wait_pid_via_poll() {
  return 1;
}

// return value:
// - `>= 0`: success, return the pid itself
// - `-1`: failure
// - `-2`: pid already terminated
int moonbitlang_async_poll_register_pid(int kqfd, pid_t pid) {
  struct kevent event;
#ifdef __MACH__
  EV_SET(&event, pid, EVFILT_PROC, EV_ADD, NOTE_EXITSTATUS, 0, 0);
#else
  EV_SET(&event, pid, EVFILT_PROC, EV_ADD, NOTE_EXIT, 0, 0);
#endif
  int ret = kevent(kqfd, &event, 1, 0, 0, 0);

  if (ret >= 0) {
    return pid;
  } else if (errno == ESRCH) {
    return -2;
  } else {
    return -1;
  }
}

int moonbitlang_async_poll_remove(int kqfd, int fd, int events) {
  struct kevent event;
  EV_SET(&event, fd, ev_masks[events], EV_DELETE, 0, 0, 0);
  return kevent(kqfd, &event, 1, 0, 0, 0);
}

int moonbitlang_async_poll_remove_pid(int kqfd, pid_t pid) {
  // after the process exit, the pid is automatically removed
  return 0;
}

#define EVENT_BUFFER_SIZE 1024
static struct kevent event_buffer[EVENT_BUFFER_SIZE];

int moonbitlang_async_poll_wait(int kqfd, int timeout) {
  struct timespec timeout_spec = { timeout / 1000, (timeout % 1000) * 1000000 };
  return kevent(
    kqfd,
    0,
    0,
    event_buffer,
    EVENT_BUFFER_SIZE,
    timeout < 0 ? 0 : &timeout_spec
  );
}

// wrapper for handling event list
struct kevent *moonbitlang_async_event_list_get(int index) {
  return event_buffer + index;
}

int moonbitlang_async_event_get_fd(struct kevent *ev) {
  return ev->ident;
}

int moonbitlang_async_event_get_events(struct kevent *ev) {
  if (ev->filter == EVFILT_READ)
    return 1;

  if (ev->filter == EVFILT_WRITE)
    return 2;

  if (ev->filter == EVFILT_PROC)
    return 4;

  if (ev->flags & EV_ERROR)
    return 3;

  return 0;
}

#endif
