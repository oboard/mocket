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

#ifndef _WIN32

#include <sys/wait.h>
#include <sys/types.h>
#include <string.h>
#include <signal.h>
#include <moonbit.h>

extern char **environ;

moonbit_bytes_t *moonbitlang_async_get_curr_env() {
  int len = 0;
  for (char **cursor = environ; *cursor; ++cursor)
    ++len;

  moonbit_bytes_t *result = (moonbit_bytes_t*)moonbit_make_ref_array(len + 1, 0);
  for (int i = 0; i < len; ++i) {
    char *entry = environ[i];
    int len = strlen(entry) + 1;
    moonbit_bytes_t bytes = moonbit_make_bytes(len, 0);
    memcpy(bytes, entry, len);
    result[i] = bytes;
  }
  result[len] = 0;

  return result;
}

void moonbitlang_async_terminate_process(pid_t pid) {
  kill(pid, SIGTERM);
}

void moonbitlang_async_kill_process(pid_t pid) {
  kill(pid, SIGKILL);
}

#endif
