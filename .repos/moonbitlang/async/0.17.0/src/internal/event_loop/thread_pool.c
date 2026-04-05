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
#include <moonbit.h>

#ifdef _WIN32

#ifndef _MSC_VER
#error "Currently only MSVC is supported on Windows"
#endif

#include <winsock2.h>
#include <windows.h>
#include <ws2tcpip.h>

#else

#include <pthread.h>
#include <signal.h>
#include <unistd.h>
#include <stdlib.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <errno.h>
#include <time.h>
#include <dirent.h>
#if !defined(__ANDROID__) || __ANDROID_API__ >= 28
#include <spawn.h>
#endif
#include <sys/socket.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <sys/stat.h>
#include <sys/file.h>
#include <sys/wait.h>

typedef int HANDLE;
typedef int SOCKET;

#endif


#ifdef _WIN32
// Windows, use native event system to wake up worker thread
#define WAKEUP_METHOD_EVENT

#elif defined(__MACH__)
// MacOS, there are some bug with thread-directed signal and `sigwait`,
// so use condition variable to wake up worker threads
#include <sys/event.h>
#define WAKEUP_METHOD_COND_VAR

#include <Availability.h>
#ifdef __MAC_OS_X_VERSION_MIN_REQUIRED
#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 260000
#define posix_spawn_file_actions_addchdir_np posix_spawn_file_actions_addchdir
#endif
#endif

#else
// Other UNIX-like systems, use signal and `sigwait` to wake up worker threads
#define WAKEUP_METHOD_SIGNAL

#if defined(__ANDROID__) && __ANDROID_API__ < 34
#define posix_spawn_file_actions_addchdir_np(...) ENOSYS
#endif

#endif

struct job {
  // the return value of the job.
  // should be set by the worker and read by waiter.
  // for result that cannot fit in an integer,
  // jobs can also store extra result in their payload
  int32_t ret;

  // the error code of the job.
  // should be zefo iff the job succeeds
  int32_t err;

  // the worker that actually performs the job.
  // it will receive the job itself as parameter.
  // extra payload can be placed after the header fields in `struct job`
  void (*worker)(struct job*);
};

MOONBIT_FFI_EXPORT
int64_t moonbitlang_async_job_get_ret(struct job *job) {
  return job->ret;
}

MOONBIT_FFI_EXPORT
int32_t moonbitlang_async_job_get_err(struct job *job) {
  return job->err;
}

// =======================================================
// =================== the thread pool ===================
// =======================================================

struct {
  int initialized;

  HANDLE notify_send;

#ifdef WAKEUP_METHOD_SIGNAL
  sigset_t wakeup_signal;
  sigset_t old_sigmask;
#endif
} pool;


// The type for a worker thread
struct worker {
#ifdef _WIN32
  HANDLE id;
#else
  pthread_t id;
#endif

  // an unique identifier for current job,
  // used to find the waiter of a job
  int32_t job_id;

  // the job currently being processed
  struct job *job;

  int waiting;

#ifdef WAKEUP_METHOD_EVENT
  HANDLE event;
#elif defined(WAKEUP_METHOD_COND_VAR)
  pthread_mutex_t mutex;
  pthread_cond_t cond;
#endif
};

#ifdef _WIN32

typedef DWORD thread_worker_result_t;
#define THREAD_PROC_CALLING_CONVENTION WINAPI

#else

typedef void* thread_worker_result_t;
#define THREAD_PROC_CALLING_CONVENTION

#endif

static
thread_worker_result_t THREAD_PROC_CALLING_CONVENTION worker_loop(void *data) {
  int sig;
  struct worker *self = (struct worker*)data;

  int job_id = self->job_id;
  struct job *job = self->job;

#ifdef WAKEUP_METHOD_EVENT
  self->event = CreateEventA(NULL, FALSE, FALSE, NULL);
#elif defined(WAKEUP_METHOD_COND_VAR)
  pthread_mutex_init(&(self->mutex), 0);
  pthread_cond_init(&(self->cond), 0);
#endif

  while (job) {
    job->ret = 0;
    job->err = 0;

    job->worker(job);

    self->waiting = 1;

#ifdef _WIN32
    PostQueuedCompletionStatus(
      pool.notify_send,
      job_id,
      (ULONG_PTR)INVALID_HANDLE_VALUE,
      0
    );
#else
    do {
      if (write(pool.notify_send, &job_id, sizeof(int)) > 0)
        break;
    } while (errno == EINTR);
#endif

#ifdef WAKEUP_METHOD_EVENT
    WaitForSingleObject(self->event, INFINITE);
#elif defined(WAKEUP_METHOD_SIGNAL)
    sigwait(&pool.wakeup_signal, &sig);
#elif defined(WAKEUP_METHOD_COND_VAR)
    pthread_mutex_lock(&(self->mutex));
    while (self->waiting) {
#ifdef __MACH__
      // There's a bug in the MacOS's `pthread_cond_wait`,
      // see https://github.com/graphia-app/graphia/issues/33
      // We know the arguments must be valid here, so use a loop to work around
      while (pthread_cond_wait(&(self->cond), &(self->mutex)) == EINVAL) {}
#else
      pthread_cond_wait(&(self->cond), &(self->mutex));
#endif
    }
    pthread_mutex_unlock(&(self->mutex));
#endif
    job_id = self->job_id;
    job = self->job;
  }
  return 0;
}

MOONBIT_FFI_EXPORT
void moonbitlang_async_wake_worker(
  struct worker *worker,
  int32_t job_id,
  struct job *job
) {
  if (worker->job)
    moonbit_decref(worker->job);

  worker->job_id = job_id;
  worker->job = job;

#ifdef WAKEUP_METHOD_EVENT
  worker->waiting = 0;
  SetEvent(worker->event);
#elif defined(WAKEUP_METHOD_SIGNAL)
  worker->waiting = 0;
  pthread_kill(worker->id, SIGUSR1);
#elif defined(WAKEUP_METHOD_COND_VAR)
  pthread_mutex_lock(&(worker->mutex));
  worker->waiting = 0;
  pthread_cond_signal(&(worker->cond));
  pthread_mutex_unlock(&(worker->mutex));
#endif
}

MOONBIT_FFI_EXPORT
void moonbitlang_async_worker_enter_idle(struct worker *worker) {
  if (worker->job)
    moonbit_decref(worker->job);

  worker->job = 0;
}

MOONBIT_FFI_EXPORT
int32_t moonbitlang_async_cancel_worker(struct worker *worker) {
  if (worker->waiting)
    return 1;

#ifdef _WIN32

  if (CancelSynchronousIo(worker->id)) {
    return 1;
  } else if (GetLastError() == ERROR_NOT_FOUND) {
    return 0;
  } else {
    return -1;
  }

#else

  pthread_kill(worker->id, SIGUSR2);
  return 0;

#endif
}

MOONBIT_FFI_EXPORT
void moonbitlang_async_free_worker(struct worker *worker) {
  // terminate the worker
  moonbitlang_async_wake_worker(worker, 0, 0);

#ifdef _WIN32
  WaitForSingleObject(worker->id, INFINITE);
#else
  pthread_join(worker->id, 0);
#endif

#ifdef WAKEUP_METHOD_EVENT
  CloseHandle(worker->event);
#elif defined(WAKEUP_METHOD_COND_VAR)
  pthread_mutex_destroy(&(worker->mutex));
  pthread_cond_destroy(&(worker->cond));
#endif

  free(worker);
}

#ifndef _WIN32
static
void nop_signal_handler(int signum) {}
#endif

MOONBIT_FFI_EXPORT
void moonbitlang_async_init_thread_pool(HANDLE notify_send) {
  if (pool.initialized)
    abort();

#ifdef WAKEUP_METHOD_SIGNAL
  sigemptyset(&pool.wakeup_signal);
  sigaddset(&pool.wakeup_signal, SIGUSR1);
  pthread_sigmask(SIG_BLOCK, &pool.wakeup_signal, &pool.old_sigmask);
#endif

#ifndef _WIN32
  sigset_t signals_to_block;
  sigemptyset(&signals_to_block);
  sigaddset(&signals_to_block, SIGCHLD);
  pthread_sigmask(SIG_BLOCK, &signals_to_block, 0);

  signal(SIGPIPE, SIG_IGN);

  // register a dummy handler for `SIGUSR2,
  // so that when we cancel blocking IO in worker thread via `SIGUSR2`:
  // 1. the program won't get killed
  // 2. blocked syscall will be interrupted
  struct sigaction act;
  act.sa_handler = nop_signal_handler;
  sigemptyset(&act.sa_mask);
  act.sa_flags = 0;
  sigaction(SIGUSR2, &act, NULL);
#endif

  pool.notify_send = notify_send;
  pool.initialized = 1;
}

MOONBIT_FFI_EXPORT
void moonbitlang_async_destroy_thread_pool() {
  if (!pool.initialized)
    abort();

  pool.initialized = 0;

#ifdef WAKEUP_METHOD_SIGNAL
  pthread_sigmask(SIG_SETMASK, &pool.old_sigmask, 0);
#endif
}

MOONBIT_FFI_EXPORT
struct worker *moonbitlang_async_spawn_worker(
  int32_t init_job_id,
  struct job *init_job
) {
  struct worker *worker = (struct worker*)malloc(sizeof(struct worker));
  worker->job_id = init_job_id;
  worker->job = init_job;
  worker->waiting = 0;

#ifdef _WIN32
  worker->id = CreateThread(
    NULL,
    512,
    &worker_loop,
    worker,
    0,
    0
  );
#else
  pthread_attr_t attr;
  pthread_attr_init(&attr);
#ifdef __ANDROID__
  pthread_attr_setstacksize(&attr, 64 * 1024);
#else
  pthread_attr_setstacksize(&attr, 512);
#endif

  pthread_create(&(worker->id), &attr, &worker_loop, worker);
  pthread_attr_destroy(&attr);
#endif

  return worker;
}

#ifndef _WIN32
int32_t moonbitlang_async_fetch_completion(int notify_recv, int32_t *output) {
  int max_len = Moonbit_array_length(output);
  return read(notify_recv, (char*)output, max_len * sizeof(int32_t));
}
#endif

MOONBIT_FFI_EXPORT
int32_t moonbitlang_async_errno_is_cancelled(int32_t err) {
#ifdef _WIN32
  return err == ERROR_OPERATION_ABORTED;
#else
  return err == EINTR;
#endif
}

// =========================================================
// ===================== concrete jobs =====================
// =========================================================

static
struct job *make_job(
  int32_t size,
  void (*free_job)(void*),
  void (*worker)(struct job*)
) {
  struct job *job = (struct job*)moonbit_make_external_object(
    free_job,
    size
  );
  job->ret = 0;
  job->err = 0;
  job->worker = worker;
  return job;
}

#define MAKE_JOB(name) (struct name##_job*)make_job(\
  sizeof(struct name##_job),\
  free_##name##_job,\
  name##_job_worker\
)

// ===== sleep job, sleep via thread pool, for testing only =====

struct sleep_job {
  struct job job;
  int duration;
};

static
void free_sleep_job(void *job) {}

static
void sleep_job_worker(struct job *job) {
#ifdef _WIN32
  Sleep(((struct sleep_job*)job)->duration);
#else
  int32_t ms = ((struct sleep_job*)job)->duration;
  struct timespec duration = { ms / 1000, (ms % 1000) * 1000000 };

#ifdef __MACH__
  // On GitHub CI MacOS runner, `nanosleep` is very imprecise,
  // causing corrupted test result.
  // However `kqueue` seems to have very accurate timing.
  // Since `OP_SLEEP` is only for testing purpose,
  // here we use `kqueue` (in an absolutely wrong way) to perform sleep.
  int kqfd = kqueue();
  struct kevent kev;
  kevent(kqfd, 0, 0, &kev, 1, &duration);
  close(kqfd);
#else
  nanosleep(&duration, 0);
#endif

#endif
}

MOONBIT_FFI_EXPORT
struct sleep_job *moonbitlang_async_make_sleep_job(int ms) {
  struct sleep_job *job = MAKE_JOB(sleep);
  job->duration = ms;
  return job;
}

// ===== read job, for reading non-pollable stuff =====

struct read_job {
  struct job job;
  HANDLE fd;
  char *buf;
  int offset;
  int len;
  int64_t position;
};

static
void free_read_job(void *obj) {
  struct read_job *job = (struct read_job*)obj;
  moonbit_decref(job->buf);
}

static
void read_job_worker(struct job *job) {
  struct read_job *read_job = (struct read_job*)job;

#ifdef _WIN32

   OVERLAPPED overlapped;
   memset(&overlapped, 0, sizeof(OVERLAPPED));
   if (read_job->position > 0) {
     overlapped.Offset = read_job->position & 0xffffffff;
     overlapped.OffsetHigh = read_job->position >> 32;
   }

   DWORD bytes_transferred;
   BOOL result = ReadFile(
     read_job->fd,
     read_job->buf + read_job->offset,
     read_job->len,
     &bytes_transferred,
     read_job->position < 0 ? NULL : &overlapped
   );
   if (result)
     job->ret = bytes_transferred;
   else
     job->err = GetLastError();

#else

  if (read_job->position < 0) {
    job->ret = read(read_job->fd, read_job->buf + read_job->offset, read_job->len);
  } else {
    job->ret = pread(
      read_job->fd,
      read_job->buf + read_job->offset,
      read_job->len,
      read_job->position
    );
  }
  if (job->ret < 0)
    job->err = errno;

#endif
}

struct read_job *moonbitlang_async_make_read_job(
  HANDLE fd,
  char *buf,
  int offset,
  int len,
  int64_t position
) {
  struct read_job *job = MAKE_JOB(read);
  job->fd = fd;
  job->buf = buf;
  job->offset = offset;
  job->len = len;
  job->position = position;
  return job;
}

// ===== write job, for writing non-pollable stuff =====

struct write_job {
  struct job job;
  HANDLE fd;
  char *buf;
  int offset;
  int len;
  int64_t position;
};

static
void free_write_job(void *obj) {
  struct write_job *job = (struct write_job*)obj;
  moonbit_decref(job->buf);
}

static
void write_job_worker(struct job *job) {
  struct write_job *write_job = (struct write_job*)job;

#ifdef _WIN32

   OVERLAPPED overlapped;
   memset(&overlapped, 0, sizeof(OVERLAPPED));
   if (write_job->position > 0) {
     overlapped.Offset = write_job->position & 0xffffffff;
     overlapped.OffsetHigh = write_job->position >> 32;
   }

   DWORD bytes_transferred;
   BOOL result = WriteFile(
     write_job->fd,
     write_job->buf + write_job->offset,
     write_job->len,
     &bytes_transferred,
     write_job->position < 0 ? NULL : &overlapped
   );
   if (result)
     job->ret = bytes_transferred;
   else
     job->err = GetLastError();

#else

  if (write_job->position < 0) {
    job->ret = write(
      write_job->fd,
      write_job->buf + write_job->offset,
      write_job->len
    );
  } else {
    job->ret = pwrite(
      write_job->fd,
      write_job->buf + write_job->offset,
      write_job->len,
      write_job->position
    );
  }
  if (job->ret < 0)
    job->err = errno;

#endif
}

struct write_job *moonbitlang_async_make_write_job(
  HANDLE fd,
  char *buf,
  int offset,
  int len,
  int64_t position
) {
  struct write_job *job = MAKE_JOB(write);
  job->fd = fd;
  job->buf = buf;
  job->offset = offset;
  job->len = len;
  job->position = position;
  return job;
}

// ===== open job =====

struct open_job {
  struct job job;
  char *filename;
  int access;
  int create;
  int append;
  int truncate;
  int sync;
  int mode;
  HANDLE result;
  int64_t kind;
};

static
void free_open_job(void *obj) {
  struct open_job *job = (struct open_job*)obj;
  moonbit_decref(job->filename);
}

#ifdef _WIN32
static
BOOL get_file_kind(HANDLE handle, int64_t *out) {
  SetLastError(0);
  DWORD kind = GetFileType(handle);
  if (kind != FILE_TYPE_DISK) {
    *out = kind;
    return TRUE;
  }

  if (GetLastError())
    return FALSE;

  BY_HANDLE_FILE_INFORMATION info;
  if (!GetFileInformationByHandle(handle, &info)) {
    return FALSE;
  }

  *out = (((int64_t)info.dwFileAttributes) << 32) | (int64_t)kind;
  return TRUE;
}
#endif

static
void open_job_worker(struct job *job) {
#ifdef _WIN32
  static int access_flags[] = { GENERIC_READ, GENERIC_WRITE, GENERIC_READ | GENERIC_WRITE };
#else
  static int access_flags[] = { O_RDONLY, O_WRONLY, O_RDWR };
  static int sync_flags[] = { 0, O_DSYNC, O_SYNC };
#endif

  struct open_job *open_job = (struct open_job*)job;

#ifdef _WIN32
  DWORD create_flags =
    open_job->create
    ? (open_job->truncate ? CREATE_ALWAYS : OPEN_ALWAYS)
    : (open_job->truncate ? TRUNCATE_EXISTING : OPEN_EXISTING);

  DWORD flags = FILE_ATTRIBUTE_NORMAL | FILE_FLAG_BACKUP_SEMANTICS;

  DWORD access_flag = access_flags[open_job->access];
  if (open_job->append)
    access_flag = (access_flag ^ GENERIC_WRITE) | FILE_APPEND_DATA;

  do {
    open_job->result = CreateFileW(
      (LPCWSTR)open_job->filename,
      access_flag, // desired access
      FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, // shared mode
      NULL, // security attributes
      create_flags, // creation
      flags, // flags and attributes. Note that we open files in synchronous mode
      NULL // template file
    );

    // get the kind of the file
    if (open_job->result == INVALID_HANDLE_VALUE) {
      job->err = GetLastError();
      if (job->err != ERROR_PIPE_BUSY)
        return;

      // We are trying to open a named pipe, but no pipe instance is available,
      // so wait until any instance is available.
      // This wait is cancellable via `CancelSynchronousIo`.
      if (!WaitNamedPipeW((LPCWSTR)open_job->filename, NMPWAIT_WAIT_FOREVER))
        job->err = GetLastError();
      continue;
    }
  } while (0);

  if (!get_file_kind(open_job->result, &(open_job->kind))) {
    job->err = GetLastError();
    CloseHandle(open_job->result);
  }

#else

  int flags = access_flags[open_job->access] | sync_flags[open_job->sync];
  if (open_job->create) flags |= O_CREAT;
  if (open_job->append) flags |= O_APPEND;
  if (open_job->truncate) flags |= O_TRUNC;

  open_job->result = open(
    open_job->filename,
    flags | O_CLOEXEC,
    open_job->mode
  );
  if (open_job->result < 0) {
    job->err = errno;
    return;
  }
  struct stat stat;
  if (fstat(open_job->result, &stat) < 0) {
    job->err = errno;
    return;
  }
  open_job->kind = stat.st_mode;

#endif
}

MOONBIT_FFI_EXPORT
struct open_job *moonbitlang_async_make_open_job(
  char *filename,
  int access,
  int create,
  int append,
  int truncate,
  int sync,
  int mode
) {

  struct open_job *job = MAKE_JOB(open);
  job->filename = filename;
  job->access = access;
  job->create = create;
  job->append = append;
  job->truncate = truncate;
  job->sync = sync;
  job->mode = mode;
  return job;
}

MOONBIT_FFI_EXPORT
HANDLE moonbitlang_async_get_open_job_result(struct open_job *job) {
  return job->result;
}

MOONBIT_FFI_EXPORT
int64_t moonbitlang_async_get_open_job_kind(struct open_job *job) {
  return job->kind;
}

// ===== file kind by path job, get kind of path on file system =====

struct file_kind_by_path_job {
  struct job job;
  char *path;
  int follow_symlink;
  int64_t result;
};

static
void free_file_kind_by_path_job(void *obj) {
  struct file_kind_by_path_job *job = (struct file_kind_by_path_job*)obj;
  moonbit_decref(job->path);
}

static
void file_kind_by_path_job_worker(struct job *job) {
  struct file_kind_by_path_job *file_kind_by_path_job = (struct file_kind_by_path_job*)job;
#ifdef _WIN32
  DWORD flags = FILE_ATTRIBUTE_NORMAL | FILE_FLAG_BACKUP_SEMANTICS;
  if (!file_kind_by_path_job->follow_symlink)
    flags |= FILE_FLAG_OPEN_REPARSE_POINT;

  HANDLE handle = CreateFileW(
    (LPCWSTR)file_kind_by_path_job->path,
    FILE_READ_ATTRIBUTES, // desired access
    FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, // shared mode
    NULL, // security attributes
    OPEN_EXISTING, // creation mode
    flags, // flags and attributes
    NULL // template file
  );

  if (handle == INVALID_HANDLE_VALUE) {
    job->err = GetLastError();
    return;
  }

  if (!get_file_kind(handle, &(file_kind_by_path_job->result)))
    job->err = GetLastError();

  CloseHandle(handle);

#else

  struct stat stat_obj;
  if (file_kind_by_path_job->follow_symlink) {
    job->ret = stat(file_kind_by_path_job->path, &stat_obj);
  } else {
    job->ret = lstat(file_kind_by_path_job->path, &stat_obj);
  }
  if (job->ret < 0) {
    job->err = errno;
  } else {
    file_kind_by_path_job->result = stat_obj.st_mode;
  }

#endif
}

struct file_kind_by_path_job *moonbitlang_async_make_file_kind_by_path_job(
  char *path,
  int follow_symlink
) {
  struct file_kind_by_path_job *job = MAKE_JOB(file_kind_by_path);
  job->path = path;
  job->follow_symlink = follow_symlink;
  job->result = 0;
  return job;
}

int64_t moonbitlang_async_get_file_kind_by_path_result(struct file_kind_by_path_job *job) {
  return job->result;
}

// ===== file size job, get size of opened file =====

struct file_size_job {
  struct job job;
  HANDLE fd;
  int64_t result;
};

static
void free_file_size_job(void *obj) {}

static
void file_size_job_worker(struct job *job) {
  struct file_size_job *file_size_job = (struct file_size_job*)job;
#ifdef _WIN32
  LARGE_INTEGER size;
  if (!GetFileSizeEx(file_size_job->fd, &size)) {
    job->err = GetLastError();
    return;
  }
  file_size_job->result = size.QuadPart;
#else
  struct stat stat;
  job->ret = fstat(file_size_job->fd, &stat);
  if (job->ret < 0) {
    job->err = errno;
  } else {
    file_size_job->result = stat.st_size;
  }
#endif
}

struct file_size_job *moonbitlang_async_make_file_size_job(HANDLE fd) {
  struct file_size_job *job = MAKE_JOB(file_size);
  job->fd = fd;
  return job;
}

int64_t moonbitlang_async_get_file_size_result(struct file_size_job *job) {
  return job->result;
}

// ===== file time job, get timestamp of opened file =====

struct file_time_job {
  struct job job;
  HANDLE fd;
  void *out;
};

static
void free_file_time_job(void *obj) {
  struct file_time_job *job = (struct file_time_job*)obj;
  moonbit_decref(job->out);
}

static
void file_time_job_worker(struct job *job) {
  struct file_time_job *file_time_job = (struct file_time_job*)job;
#ifdef _WIN32
  if (
    !GetFileInformationByHandleEx(
      file_time_job->fd,
      FileBasicInfo,
      file_time_job->out,
      sizeof(FILE_BASIC_INFO)
    )
  ) {
    job->err = GetLastError();
  }
#else
  job->ret = fstat(file_time_job->fd, file_time_job->out);
  if (job->ret < 0)
    job->err = errno;
#endif
}

struct file_time_job *moonbitlang_async_make_file_time_job(HANDLE fd, void *out) {
  struct file_time_job *job = MAKE_JOB(file_time);
  job->fd = fd;
  job->out = out;
  return job;
}

// ===== file time by path job, get timestamp of path on file system =====

struct file_time_by_path_job {
  struct job job;
  char *path;
  void *out;
  int follow_symlink;
};

static
void free_file_time_by_path_job(void *obj) {
  struct file_time_by_path_job *job = (struct file_time_by_path_job*)obj;
  moonbit_decref(job->path);
  moonbit_decref(job->out);
}

static
void file_time_by_path_job_worker(struct job *job) {
  struct file_time_by_path_job *file_time_by_path_job = (struct file_time_by_path_job*)job;
#ifdef _WIN32
  DWORD flags = FILE_ATTRIBUTE_NORMAL | FILE_FLAG_BACKUP_SEMANTICS;
  if (!file_time_by_path_job->follow_symlink)
    flags |= FILE_FLAG_OPEN_REPARSE_POINT;

  HANDLE handle = CreateFileW(
    (LPCWSTR)file_time_by_path_job->path,
    FILE_READ_ATTRIBUTES, // desired access
    FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, // shared mode
    NULL, // security attributes
    OPEN_EXISTING, // creation mode
    flags, // flags and attributes
    NULL // template file
  );
  if (handle == INVALID_HANDLE_VALUE) {
    job->err = GetLastError();
    return;
  }

  if (
    !GetFileInformationByHandleEx(
      handle,
      FileBasicInfo,
      file_time_by_path_job->out,
      sizeof(FILE_BASIC_INFO)
    )
  ) {
    job->err = GetLastError();
  }

  CloseHandle(handle);

#else

  if (file_time_by_path_job->follow_symlink) {
    job->ret = stat(file_time_by_path_job->path, file_time_by_path_job->out);
  } else {
    job->ret = lstat(file_time_by_path_job->path, file_time_by_path_job->out);
  }
  if (job->ret < 0)
    job->err = errno;

#endif
}

struct file_time_by_path_job *moonbitlang_async_make_file_time_by_path_job(
  char *path,
  void *out,
  int follow_symlink
) {
  struct file_time_by_path_job *job = MAKE_JOB(file_time_by_path);
  job->path = path;
  job->out = out;
  job->follow_symlink = follow_symlink;
  return job;
}

// ===== access job, test permission of file path =====

struct access_job {
  struct job job;
  char *path;
  int amode;
};

static
void free_access_job(void *obj) {
  struct access_job *job = (struct access_job*)obj;
  moonbit_decref(job->path);
}

static
void access_job_worker(struct job *job) {
#ifdef _WIN32

  static int access_modes[] = { 0, GENERIC_READ, GENERIC_WRITE, FILE_EXECUTE };
  struct access_job *access_job = (struct access_job*)job;

  HANDLE handle = CreateFileW(
    (LPCWSTR)access_job->path,
    access_modes[access_job->amode],
    FILE_SHARE_DELETE | FILE_SHARE_READ | FILE_SHARE_WRITE,
    NULL,
    OPEN_EXISTING,
    FILE_ATTRIBUTE_NORMAL | FILE_FLAG_BACKUP_SEMANTICS,
    NULL
  );
  if (handle == INVALID_HANDLE_VALUE) {
    job->err = GetLastError();
  } else {
    CloseHandle(handle);
  }

#else

  static int access_modes[] = { F_OK, R_OK, W_OK, X_OK };
  struct access_job *access_job = (struct access_job*)job;
  job->ret = access(access_job->path, access_modes[access_job->amode]);
  if (job->ret < 0)
    job->err = errno;

#endif
}

struct access_job *moonbitlang_async_make_access_job(char *path, int amode) {
  struct access_job *job = MAKE_JOB(access);
  job->path = path;
  job->amode = amode;
  return job;
}

#ifndef _WIN32
// ===== chmod job, change permission of file =====

struct chmod_job {
  struct job job;
  char *path;
  mode_t mode;
};

static
void free_chmod_job(void *obj) {
  struct chmod_job *job = (struct chmod_job*)obj;
  moonbit_decref(job->path);
}

static
void chmod_job_worker(struct job *job) {
  struct chmod_job *chmod_job = (struct chmod_job*)job;
  job->ret = chmod(chmod_job->path, chmod_job->mode);
  if (job->ret < 0)
    job->err = errno;
}

struct chmod_job *moonbitlang_async_make_chmod_job(char *path, int mode) {
  struct chmod_job *job = MAKE_JOB(chmod);
  job->path = path;
  job->mode = mode;
  return job;
}

 
#endif
// ===== fsync job, synchronize file modification to disk =====

struct fsync_job {
  struct job job;
  HANDLE fd;
  int only_data;
};

static
void free_fsync_job(void *obj) {}

static
void fsync_job_worker(struct job *job) {
  struct fsync_job *fsync_job = (struct fsync_job*)job;
#ifdef _WIN32
  if (!FlushFileBuffers(fsync_job->fd))
    job->err = GetLastError();
#elif defined(__MACH__)
  // it seems that `fdatasync` is not available on some MacOS versions
  job->ret = fsync(fsync_job->fd);
#else
  if (fsync_job->only_data) {
    job->ret = fdatasync(fsync_job->fd);
  } else {
    job->ret = fsync(fsync_job->fd);
  }
#endif
  if (job->ret < 0)
    job->err = errno;
}

struct fsync_job *moonbitlang_async_make_fsync_job(HANDLE fd, int only_data) {
  struct fsync_job *job = MAKE_JOB(fsync);
  job->fd = fd;
  job->only_data = only_data;
  return job;
}

// ===== flock job, place advisory lock on a file =====
struct flock_job {
  struct job job;
  HANDLE fd;
  int exclusive;
};

static
void free_flock_job(void *obj) {}

static
void flock_job_worker(struct job *job) {
  struct flock_job *flock_job = (struct flock_job*)job;

#ifdef _WIN32

  OVERLAPPED overlapped;
  memset(&overlapped, 0, sizeof(OVERLAPPED));
  // We want to provide advisory lock here
  // (i.e. only lock operations conflict with each other, raw IO are not affected),
  // because mandatory file lock is not available on Linux/MacOS.
  // However, Windows only provides mandatory file lock.
  // Fortunately, https://learn.microsoft.com/en-us/windows/win32/api/fileapi/nf-fileapi-lockfileex
  // explicitly state that locking a region beyond end of file is *not* an error.
  // So, here we lock the last byte in the whole address space to simulate advisory locking,
  // as this region can almost never get touched by normal IO operations.
  overlapped.Offset = 0xfffffffe;
  overlapped.OffsetHigh = 0xffffffff;
  BOOL ret = LockFileEx(
    flock_job->fd,
    flock_job->exclusive ? LOCKFILE_EXCLUSIVE_LOCK : 0,
    0, // reserved
    1,
    0,
    &overlapped
  );

  if (!ret)
    job->err = GetLastError();

#else

  int ret = flock(flock_job->fd, flock_job->exclusive ? LOCK_EX : LOCK_SH);
  if (ret < 0)
    job->err = errno;

#endif
}

struct flock_job *moonbitlang_async_make_flock_job(HANDLE fd, int exclusive) {
  struct flock_job *job = MAKE_JOB(flock);
  job->fd = fd;
  job->exclusive = exclusive;
  return job;
}

// ===== remove job, remove file from file system =====

struct remove_job {
  struct job job;
  char *path;
};

static
void free_remove_job(void *obj) {
  struct remove_job *job = (struct remove_job*)obj;
  moonbit_decref(job->path);
}

static
void remove_job_worker(struct job *job) {
  struct remove_job *remove_job = (struct remove_job*)job;
#ifdef _WIN32
  if (!DeleteFileW((LPCWSTR)remove_job->path))
    job->err = GetLastError();
#else
  job->ret = remove(remove_job->path);
  if (job->ret < 0)
    job->err = errno;
#endif
}

struct remove_job *moonbitlang_async_make_remove_job(char *path) {
  struct remove_job *job = MAKE_JOB(remove);
  job->path = path;
  return job;
}

// ===== symlink job, create symbolic link =====

struct symlink_job {
  struct job job;
  char *target;
  char *path;
};

static
void free_symlink_job(void *obj) {
  struct symlink_job *job = (struct symlink_job*)obj;
  moonbit_decref(job->target);
  moonbit_decref(job->path);
}

static
void symlink_job_worker(struct job *job) {
  struct symlink_job *symlink_job = (struct symlink_job*)job;

#ifdef _WIN32
  LPCWSTR target = (LPCWSTR)symlink_job->target;
  LPCWSTR path = (LPCWSTR)symlink_job->path;

  DWORD attrs = GetFileAttributesW(target);
  if (attrs == INVALID_FILE_ATTRIBUTES) {
    job->err = GetLastError();
    return;
  }

  if (
    !CreateSymbolicLinkW(
      (LPCWSTR)symlink_job->path,
      (LPCWSTR)symlink_job->target,
      attrs & FILE_ATTRIBUTE_DIRECTORY ? SYMBOLIC_LINK_FLAG_DIRECTORY : 0
    )
  ) {
    job->err = GetLastError();
  }

#else

  job->ret = symlink(symlink_job->target, symlink_job->path);
  if (job->ret < 0)
    job->err = errno;

#endif
}

struct symlink_job *moonbitlang_async_make_symlink_job(char *target, char *path) {
  struct symlink_job *job = MAKE_JOB(symlink);
  job->target = target;
  job->path = path;
  return job;
}

// ===== mkdir job, create new directory =====

struct mkdir_job {
  struct job job;
  char *path;
  int mode;
};

static
void free_mkdir_job(void *obj) {
  struct mkdir_job *job = (struct mkdir_job*)obj;
  moonbit_decref(job->path);
}

static
void mkdir_job_worker(struct job *job) {
  struct mkdir_job *mkdir_job = (struct mkdir_job*)job;
#ifdef _WIN32

  if (!CreateDirectoryW((LPCWSTR)mkdir_job->path, NULL))
    job->err = GetLastError();

#else

  job->ret = mkdir(mkdir_job->path, mkdir_job->mode);
  if (job->ret < 0)
    job->err = errno;

#endif
}

struct mkdir_job *moonbitlang_async_make_mkdir_job(char *path, int mode) {
  struct mkdir_job *job = MAKE_JOB(mkdir);
  job->path = path;
  job->mode = mode;
  return job;
}

// ===== rmdir job, remove directory =====

struct rmdir_job {
  struct job job;
  char *path;
};

static
void free_rmdir_job(void *obj) {
  struct rmdir_job *job = (struct rmdir_job*)obj;
  moonbit_decref(job->path);
}

static
void rmdir_job_worker(struct job *job) {
  struct rmdir_job *rmdir_job = (struct rmdir_job*)job;

#ifdef _WIN32

  if (!RemoveDirectoryW((LPCWSTR)rmdir_job->path))
    job->err = GetLastError();

#else

  job->ret = rmdir(rmdir_job->path);
  if (job->ret < 0)
    job->err = errno;

#endif
}

struct rmdir_job *moonbitlang_async_make_rmdir_job(char *path) {
  struct rmdir_job *job = MAKE_JOB(rmdir);
  job->path = path;
  return job;
}

// ===== opendir job, open directory =====

#ifdef _WIN32

typedef struct {
  HANDLE handle;

  // In Windows, the directory search handle is obtained via `FindFirstFile`,
  // which, in addition to creating the search handle,
  // also read the first entry from the directory.
  // So on the next `readdir` request, we should just return this initial entry.
  int32_t has_cached_entry;
  WIN32_FIND_DATAW curr_entry;
} DIR;

int32_t moonbitlang_async_closedir(DIR *dir) {
  int32_t ret = FindClose(dir->handle) ? 0 : -1;
  free(dir);
  return ret;
}

#endif

struct opendir_job {
  struct job job;
  char *path;
  DIR *result;

  // if the waiter is cancelled before `opendir` succeed,
  // we need to call `closedir` to free resource on the result.
  // however, if the waiter is not cancelled,
  // the ownership of the result should be transferred to the waiter.
  // here we use a flag `result_fetched` to determine which case it is.
  int result_fetched;
};

static
void free_opendir_job(void *obj) {
  struct opendir_job *job = (struct opendir_job*)obj;
  moonbit_decref(job->path);

  if (job->result && !(job->result_fetched)) {
#ifdef _WIN32
    moonbitlang_async_closedir(job->result);
#else
    closedir(job->result);
#endif
  }
}

static
void opendir_job_worker(struct job *job) {
  struct opendir_job *opendir_job = (struct opendir_job*)job;

#ifdef _WIN32

  DIR *dir = (DIR*)malloc(sizeof(DIR));
  opendir_job->result = dir;

  dir->handle = FindFirstFileW(
    (LPCWSTR)opendir_job->path,
    &(dir->curr_entry)
  );
  if (dir->handle == INVALID_HANDLE_VALUE) {
    job->err = GetLastError();
    return;
  }
  dir->has_cached_entry = 1;

#else

  opendir_job->result = opendir(opendir_job->path);
  if (!(opendir_job->result)) {
    job->err = errno;
  }

#endif
}

struct opendir_job *moonbitlang_async_make_opendir_job(char *path) {
  struct opendir_job *job = MAKE_JOB(opendir);
  job->path = path;
  job->result = 0;
  job->result_fetched = 0;
  return job;
}

DIR *moonbitlang_async_get_opendir_result(struct opendir_job *job) {
  job->result_fetched = 1;
  return job->result;
}

// ===== readdir job, read directory entry =====

struct readdir_job {
  struct job job;
  DIR *dir;
  char *result;
};

static
void free_readdir_job(void *obj) {}

static
void readdir_job_worker(struct job *job) {
  struct readdir_job *readdir_job = (struct readdir_job*)job;

#ifdef _WIN32

  if (readdir_job->dir->has_cached_entry) {
    readdir_job->result = (char*)readdir_job->dir->curr_entry.cFileName;
    readdir_job->dir->has_cached_entry = 0;
  } else if (FindNextFileW(readdir_job->dir->handle, &(readdir_job->dir->curr_entry))) {
    readdir_job->result = (char*)readdir_job->dir->curr_entry.cFileName;
  } else {
    int err = GetLastError();
    if (err == ERROR_NO_MORE_FILES) {
      readdir_job->result = 0;
    } else {
      job->ret = -1;
      job->err = err;
    }
  }

#else

  errno = 0;
  struct dirent *dirent = readdir(readdir_job->dir);
  if (dirent) {
    readdir_job->result = dirent->d_name;
  } else if (errno) {
    job->ret = -1;
    job->err = errno;
  } else {
    readdir_job->result = 0;
  }

#endif
}

struct readdir_job *moonbitlang_async_make_readdir_job(DIR *dir) {
  struct readdir_job *job = MAKE_JOB(readdir);
  job->dir = dir;
  return job;
}

char *moonbitlang_async_get_readdir_result(struct readdir_job *job) {
  return job->result;
}

// ===== realpath job, get canonical representation of a path =====

struct realpath_job {
  struct job job;
  char *path;
  char *result;
};

static
void free_realpath_job(void *obj) {
  struct realpath_job *job = (struct realpath_job*)obj;
  moonbit_decref(job->path);
}

static
void realpath_job_worker(struct job *job) {
  struct realpath_job *realpath_job = (struct realpath_job*)job;

#ifdef _WIN32
  static wchar_t buf[1024];
  DWORD len = GetFullPathNameW(
    (LPCWSTR)realpath_job->path,
    1024,
    buf,
    NULL
  );

  if (!len) {
    job->err = GetLastError();
    return;
  }

  realpath_job->result = (char*)moonbit_make_string_raw(len);
  if (len <= 1024) {
    memcpy(realpath_job->result, buf, len * sizeof(wchar_t));
  } else if (
    !GetFullPathNameW(
      (LPCWSTR)realpath_job->path,
      len,
      (LPWSTR)realpath_job->result,
      NULL
    )
  ) {
    job->err = GetLastError();
    moonbit_decref(realpath_job->result);
  }

#else

  realpath_job->result = realpath(realpath_job->path, 0);
  if (!realpath_job->result) {
    job->ret = -1;
    job->err = errno;
  }

#endif
}

struct realpath_job *moonbitlang_async_make_realpath_job(char *path) {
  struct realpath_job *job = MAKE_JOB(realpath);
  job->path = path;
  return job;
}

char *moonbitlang_async_get_realpath_result(struct realpath_job *job) {
  return job->result;
}

// ===== spawn job, spawn foreign process =====
#ifdef _WIN32

static
HANDLE global_job_object = INVALID_HANDLE_VALUE;

int32_t moonbitlang_async_init_global_job_objeect() {
  HANDLE job = CreateJobObjectA(NULL, NULL);
  if (job == NULL)
    return 0;

  JOBOBJECT_EXTENDED_LIMIT_INFORMATION info;
  memset(&info, 0, sizeof(JOBOBJECT_EXTENDED_LIMIT_INFORMATION));

  info.BasicLimitInformation.LimitFlags =
    JOB_OBJECT_LIMIT_BREAKAWAY_OK
    | JOB_OBJECT_LIMIT_SILENT_BREAKAWAY_OK
    | JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE;

  if (
    !SetInformationJobObject(
      job,
      JobObjectExtendedLimitInformation,
      &info,
      sizeof(info)
    )
  ) {
    goto on_error;
  }

  if (!AssignProcessToJobObject(job, GetCurrentProcess())) {
    if (GetLastError() == ERROR_ACCESS_DENIED) {
      // Here we try to assign current process to the job for two purpose:
      //
      // 1. workaround the bug mentioned in https://github.com/libuv/libuv/pull/4152
      // 2. according to https://learn.microsoft.com/en-us/windows/win32/api/jobapi2/nf-jobapi2-assignprocesstojobobject,
      //    prior to Windows 8, a process can only be associated with a single job.
      //    In this case, if the main process is already in a job,
      //    our child process will by default also be in the same job,
      //    so we cannot associate child process to a new job.
      //    So here we simply give up auto-kill child process if
      //    we cannot assign current process to the new object, which means:
      //    
      //    a. we are in Windows 7 or earlier
      //    b. the main process is already associated with a job
      SetLastError(0);
    }
    goto on_error;
  }

  global_job_object = job;
  return 1;

on_error:
  CloseHandle(job);
  return 0;
}

struct spawn_job {
  struct job job;
  LPWSTR command_line;
  void *environment;
  HANDLE stdio[3];
  LPWSTR cwd;
  int32_t is_orphan;
};

static
void free_spawn_job(void *obj) {
  struct spawn_job *job = (struct spawn_job*)obj;
  moonbit_decref(job->command_line);
  if (job->environment)
    moonbit_decref(job->environment);
  if (job->cwd)
    moonbit_decref(job->cwd);
}

static
void spawn_job_worker(struct job *job) {
  static DWORD std_handle_values[] = {
    STD_INPUT_HANDLE,
    STD_OUTPUT_HANDLE,
    STD_ERROR_HANDLE
  };

  struct spawn_job *spawn_job = (struct spawn_job *)job;

  for (int i = 0; i < 3; ++i) {
    if (spawn_job->stdio[i] == INVALID_HANDLE_VALUE)
      spawn_job->stdio[i] = GetStdHandle(std_handle_values[i]);

    if (spawn_job->stdio[i] == INVALID_HANDLE_VALUE) {
      job->err = GetLastError();
      return;
    }

    if (
      !SetHandleInformation(
        spawn_job->stdio[i],
        HANDLE_FLAG_INHERIT,
        HANDLE_FLAG_INHERIT
      )
    ) {
      job->err = GetLastError();
      return;
    }
  }

  DWORD create_flags =
    CREATE_NEW_PROCESS_GROUP // so that we can gracefully terminate this process
                             // via sending Ctrl+Break console event
    | CREATE_UNICODE_ENVIRONMENT;

  STARTUPINFOEXW startup_info;
  memset(&startup_info, 0, sizeof(STARTUPINFOEXW));
  startup_info.StartupInfo.cb = sizeof(STARTUPINFOW);
  startup_info.StartupInfo.dwFlags = STARTF_USESTDHANDLES;
  startup_info.StartupInfo.hStdInput = spawn_job->stdio[0];
  startup_info.StartupInfo.hStdOutput = spawn_job->stdio[1];
  startup_info.StartupInfo.hStdError = spawn_job->stdio[2];

#ifdef PROC_THREAD_ATTRIBUTE_JOB_LIST

  if (!spawn_job->is_orphan) {
    // On Windows 10 and later, there is a way to
    // atomically assign a child process to new job atomically on creation.
    // This can avoid race condition when main process is killed after `CreateProcess`,
    // but before `AssignProcessToJobObject` on the child process.
    create_flags |= EXTENDED_STARTUPINFO_PRESENT;
    startup_info.StartupInfo.cb = sizeof(STARTUPINFOEXW);

    SIZE_T attrs_size;
    InitializeProcThreadAttributeList(NULL, 1, 0, &attrs_size);
    startup_info.lpAttributeList = malloc(attrs_size);
    if (
      !InitializeProcThreadAttributeList(
        startup_info.lpAttributeList,
        1,
        0,
        &attrs_size
      )
    ) {
      job->err = GetLastError();
      free(startup_info.lpAttributeList);
      return;
    }

    if (
      !UpdateProcThreadAttribute(
        startup_info.lpAttributeList,
        0,
        PROC_THREAD_ATTRIBUTE_JOB_LIST,
        &global_job_object,
        sizeof(global_job_object),
        NULL,
        NULL
      )
    ) {
      job->err = GetLastError();
      free(startup_info.lpAttributeList);
      return;
    }
  }

#else

  // Notice that we are not setting `CREATE_BREAKAWAY_FROM_JOB` here for orphan process here.
  // Because in case the main process is already in a job disallowing break away,
  // setting `CREATE_BREAKAWAY_FROM_JOB` will fail the `CreateProcess` call.
  if (!spawn_job->is_orphan && global_job_object != INVALID_HANDLE_VALUE) {
    // to avoid the child process exit too fast
    // before we assign it to the job object
    create_flags |= CREATE_SUSPENDED;
  }

#endif

  PROCESS_INFORMATION process_info;
  BOOL result = CreateProcessW(
    NULL,
    spawn_job->command_line,
    NULL, // security attributes for process
    NULL, // security attributes for main thread
    TRUE, // do not inherit handle
    create_flags,
    spawn_job->environment,
    spawn_job->cwd,
    (LPSTARTUPINFOW)&startup_info,
    &process_info
  );

  if (startup_info.lpAttributeList) {
    DeleteProcThreadAttributeList(startup_info.lpAttributeList);
    free(startup_info.lpAttributeList);
  }

  if (!result) {
    job->err = GetLastError();
    return;
  }

  if (create_flags & CREATE_SUSPENDED) {
    // On Windows, hard termination is much more common,
    // due to lack of a universal way for graceful process termination.
    // So assign the new process to a job object,
    // so that it is automatically killed on when the main process is killed.
    if (!AssignProcessToJobObject(global_job_object, process_info.hProcess)) {
      job->err = GetLastError();
      TerminateProcess(process_info.hProcess, 1);
      return;
    }
    ResumeThread(process_info.hThread);
  }

  // Since process waiting is not performance-critical,
  // here we discard the handles returned by `CreateProcessW`,
  // and use `OpenProcess` to obtain another handle later when needed,
  // so that the API style is closer to UNIX-like systems.
  CloseHandle(process_info.hThread);
  CloseHandle(process_info.hProcess);

  job->ret = process_info.dwProcessId;
}

struct spawn_job *moonbitlang_async_make_spawn_job(
  LPWSTR command_line,
  void *environment,
  HANDLE stdin_handle,
  HANDLE stdout_handle,
  HANDLE stderr_handle,
  LPWSTR cwd,
  int32_t is_orphan
) {
  struct spawn_job *job = MAKE_JOB(spawn);
  job->command_line = command_line;
  job->environment = environment;
  job->stdio[0] = stdin_handle;
  job->stdio[1] = stdout_handle;
  job->stdio[2] = stderr_handle;
  job->cwd = cwd;
  job->is_orphan = is_orphan;
  return job;
}

// For windows, waiting for process is done via one dedicated thread per process,
// As a future optimization, we may wait for multiple processes in a single thread.
// But that would make cancellation a lot trickier.

struct wait_for_process_job {
  struct job job;
  DWORD pid;
  HANDLE cancel;
};

static
void free_wait_for_process_job(void *obj) {
  struct wait_for_process_job *job = (struct wait_for_process_job*)obj;
  CloseHandle(job->cancel);
};

static
void wait_for_process_job_worker(struct job *job) {
  struct wait_for_process_job *wait_for_process_job = (struct wait_for_process_job*)job;

  HANDLE handles[2] = { INVALID_HANDLE_VALUE, wait_for_process_job->cancel };

  handles[0] = OpenProcess(SYNCHRONIZE, FALSE, wait_for_process_job->pid);
  if (handles[0] == INVALID_HANDLE_VALUE) {
    job->err = GetLastError();
    return;
  }

  DWORD result = WaitForMultipleObjects(2, handles, FALSE, INFINITE);
  if (result == WAIT_FAILED)
    job->err = GetLastError();
  else if (result == WAIT_OBJECT_0 + 1)
    job->err = ERROR_OPERATION_ABORTED;
}

struct wait_for_process_job *moonbitlang_async_make_wait_for_process_job(
  DWORD pid
) {
  struct wait_for_process_job *job = MAKE_JOB(wait_for_process);
  job->pid = pid;
  job->cancel = CreateEventA(NULL, FALSE, FALSE, NULL);
  return job;
}

void moonbitlang_async_cancel_wait_for_process_job(struct wait_for_process_job *job) {
  SetEvent(job->cancel);
}

#else

struct spawn_job {
  struct job job;
  char *path;
  char **args;
  char **envp;
  int stdio[3];
  char *cwd;
};

static
void free_spawn_job(void *obj) {
  struct spawn_job *job = (struct spawn_job*)obj;
  moonbit_decref(job->path);
  moonbit_decref(job->args);
  moonbit_decref(job->envp);
  if (job->cwd)
    moonbit_decref(job->cwd);
}

#if defined(__ANDROID__) && __ANDROID_API__ < 28

// posix_spawn is unavailable on Android API < 28.
// Return a job pre-filled with ENOSYS so the caller gets a proper error
// instead of hanging forever (a NULL job causes the worker thread to exit
// without sending a completion notification).
static
void spawn_job_worker(struct job *job) {
  job->err = ENOSYS;
}

#else // posix_spawn available

static
void spawn_job_worker(struct job *job) {
  struct spawn_job *spawn_job = (struct spawn_job *)job;
  posix_spawnattr_t attr;
  posix_spawnattr_init(&attr);
#ifdef WAKEUP_METHOD_SIGNAL
  posix_spawnattr_setflags(&attr, POSIX_SPAWN_SETSIGMASK | POSIX_SPAWN_SETSIGDEF);
  posix_spawnattr_setsigmask(&attr, &pool.old_sigmask);
#else
  posix_spawnattr_setflags(&attr, POSIX_SPAWN_SETSIGDEF);
#endif

  sigset_t sigdefault_set;
  sigemptyset(&sigdefault_set);
  sigaddset(&sigdefault_set, SIGCHLD);
  sigaddset(&sigdefault_set, SIGHUP);
  sigaddset(&sigdefault_set, SIGINT);
  sigaddset(&sigdefault_set, SIGQUIT);
  sigaddset(&sigdefault_set, SIGTERM);
  sigaddset(&sigdefault_set, SIGALRM);
  posix_spawnattr_setsigdefault(&attr, &sigdefault_set);

  posix_spawn_file_actions_t file_actions;
  posix_spawn_file_actions_init(&file_actions);
  for (int i = 0; i < 3; ++i) {
    int fd = spawn_job->stdio[i];
    if (fd >= 0) {
      job->err = posix_spawn_file_actions_adddup2(&file_actions, fd, i);
      if (job->err) goto exit;
    }
  }
  if (spawn_job->cwd) {
    job->err = posix_spawn_file_actions_addchdir_np(&file_actions, spawn_job->cwd);
    if (job->err) goto exit;
  }

  if (strchr(spawn_job->path, '/')) {
    job->err = posix_spawn(
      &(job->ret),
      spawn_job->path,
      &file_actions,
      &attr,
      spawn_job->args,
      spawn_job->envp
    );
  } else {
    job->err = posix_spawnp(
      &(job->ret),
      spawn_job->path,
      &file_actions,
      &attr,
      spawn_job->args,
      spawn_job->envp
    );
  }
exit:
  posix_spawnattr_destroy(&attr);
  posix_spawn_file_actions_destroy(&file_actions);
}

#endif // posix_spawn availability

struct spawn_job *moonbitlang_async_make_spawn_job(
  char *path,
  char **args,
  char **envp,
  int stdin_fd,
  int stdout_fd,
  int stderr_fd,
  char *cwd
) {
  struct spawn_job *job = MAKE_JOB(spawn);
  job->path = path;
  job->args = args;
  job->envp = envp;
  job->stdio[0] = stdin_fd;
  job->stdio[1] = stdout_fd;
  job->stdio[2] = stderr_fd;
  job->cwd = cwd;
  return job;
}

// Unix wait_for_process: blocking waitpid in worker thread
// Used as fallback when pidfd_open is not available (e.g. Android, older Linux)

struct wait_for_process_job {
  struct job job;
  pid_t pid;
};

static
void free_wait_for_process_job(void *obj) {}

static
void wait_for_process_job_worker(struct job *job) {
  struct wait_for_process_job *wj = (struct wait_for_process_job*)job;
  int status;
  int ret = waitpid(wj->pid, &status, 0);
  if (ret == wj->pid) {
    job->ret = WEXITSTATUS(status);
  } else {
    job->err = errno;
  }
}

struct wait_for_process_job *moonbitlang_async_make_wait_for_process_job(
  int pid
) {
  struct wait_for_process_job *job = MAKE_JOB(wait_for_process);
  job->pid = pid;
  return job;
}

#endif

// ===== bind job, bind socket to specific address =====
struct bind_job {
  struct job job;
  HANDLE socket;
  struct sockaddr *addr;
};

static
void free_bind_job(void *obj) {
  struct bind_job *job = (struct bind_job*)obj;
  moonbit_decref(job->addr);
}

static
void bind_job_worker(struct job *job) {
  struct bind_job *bind_job = (struct bind_job*)job;

  job->ret = bind((SOCKET)bind_job->socket, bind_job->addr, Moonbit_array_length(bind_job->addr));

  if (job->ret < 0)
#ifdef _WIN32
    job->err = GetLastError();
#else
    job->err = errno;
#endif
}

MOONBIT_FFI_EXPORT
struct bind_job *moonbitlang_async_make_bind_job(HANDLE socket, struct sockaddr *addr) {
  struct bind_job *job = MAKE_JOB(bind);
  job->socket = socket;
  job->addr = addr;
  return job;
}

// ===== getaddrinfo job, resolve host name via `getaddrinfo` =====

#ifdef _WIN32
typedef ADDRINFOW addrinfo_t;
#else
typedef struct addrinfo addrinfo_t;
#endif

struct getaddrinfo_job {
  struct job job;
  char *hostname;
  addrinfo_t *result;
  int32_t result_fetched;
};

static
void free_getaddrinfo_job(void *obj) {
  struct getaddrinfo_job *job = (struct getaddrinfo_job*)obj;
  moonbit_decref(job->hostname);
  if (job->result && !job->result_fetched) {
#ifdef _WIN32
    FreeAddrInfoW(job->result);
#else
    freeaddrinfo(job->result);
#endif
  }
}

static
void getaddrinfo_job_worker(struct job *job) {
  struct getaddrinfo_job *getaddrinfo_job = (struct getaddrinfo_job*)job;

  addrinfo_t hint = {
    AI_ADDRCONFIG, // ai_flags
    AF_UNSPEC, // ai_family, support both IPv4 and IPv6
    0, // ai_socktype
    0, // ai_protocol
    0, 0, 0, 0
  };

#ifdef _WIN32
  int err = GetAddrInfoW(
    (LPCWSTR)getaddrinfo_job->hostname,
    0,
    &hint,
    &(getaddrinfo_job->result)
  );
  // https://learn.microsoft.com/en-us/windows/win32/api/ws2tcpip/nf-ws2tcpip-getaddrinfow#return-value
  switch (err) {
    case WSATRY_AGAIN:
    case WSANO_RECOVERY:
    case WSAEAFNOSUPPORT:
    case WSAHOST_NOT_FOUND:
    case WSATYPE_NOT_FOUND:
    case WSAESOCKTNOSUPPORT:
      job->ret = err;
      break;
    default:
      job->err = err;
      break;
  }

#else

  job->ret = getaddrinfo(
    getaddrinfo_job->hostname, 
    0,
    &hint,
    &(getaddrinfo_job->result)
  );
  if (job->ret == EAI_SYSTEM)
    job->err = errno;

#endif
}

struct getaddrinfo_job *moonbitlang_async_make_getaddrinfo_job(char *hostname) {
  struct getaddrinfo_job *job = MAKE_JOB(getaddrinfo);
  job->hostname = hostname;
  job->result = 0;
  job->result_fetched = 0;
  return job;
}

addrinfo_t *moonbitlang_async_get_getaddrinfo_result(struct getaddrinfo_job *job) {
  job->result_fetched = 1;
  return job->result;
}
