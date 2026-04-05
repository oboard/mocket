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
#include <wchar.h>
#include <moonbit.h>

MOONBIT_FFI_EXPORT
moonbit_string_t moonbitlang_async_c_buffer_as_string(wchar_t *str) {
  size_t bytes = wcslen(str) * sizeof(wchar_t);
  moonbit_string_t result = moonbit_make_string(bytes / 2, 0);
  memcpy(result, str, bytes);
  return result;
}
