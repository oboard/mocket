#include <moonbit.h>
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

// FFI namespace moonbit_native_

void *moonbit_native_memcpy(void *dest, void *src, uint64_t count) {
  return memcpy(dest, src, count);
}

void *moonbit_native_memset(void *dest, uint8_t val, uint64_t count) {
  return memset(dest, val, count);
}

void *moonbit_native_memmove(void *dest, void *src, uint64_t count) {
  return memmove(dest, src, count);
}

int32_t moonbit_native_memcmp(void *lhs, void *rhs, uint64_t count) {
  return memcmp(lhs, rhs, count);
}

void *moonbit_native_malloc(uint64_t size) { return malloc(size); }

void moonbit_native_free(void *ptr) { free(ptr); }

void *moonbit_native_realloc(void *ptr, uint64_t size) {
  return realloc(ptr, size);
}

void *moonbit_native_pointer_add(void *ptr, int64_t offset) {
  return (void *)((int64_t)ptr + offset);
}

int64_t moonbit_native_pointer_sub(void *lhs, void *rhs) {
  return (int64_t)lhs - (int64_t)rhs;
}

void *moonbit_native_null_pointer() { return NULL; }

int64_t moonbit_native_pointer_reinterpret_as_int64(void *ptr) {
  return (int64_t)ptr;
}

void *moonbit_native_int64_reinterpret_as_pointer(int64_t val) {
  return (void *)val;
}

int8_t moonbit_native_int8_pointer_get(void *ptr) { return *(int8_t *)ptr; }

void moonbit_native_int8_pointer_set(void *ptr, int8_t val) {
  *(int8_t *)ptr = val;
}

int16_t moonbit_native_int16_pointer_get(void *ptr) { return *(int16_t *)ptr; }

void moonbit_native_int16_pointer_set(void *ptr, int16_t val) {
  *(int16_t *)ptr = val;
}

int32_t moonbit_native_int32_pointer_get(void *ptr) { return *(int32_t *)ptr; }

void moonbit_native_int32_pointer_set(void *ptr, int32_t val) {
  *(int32_t *)ptr = val;
}

int64_t moonbit_native_int64_pointer_get(void *ptr) { return *(int64_t *)ptr; }

void moonbit_native_int64_pointer_set(void *ptr, int64_t val) {
  *(int64_t *)ptr = val;
}

uint8_t moonbit_native_uint8_pointer_get(void *ptr) { return *(uint8_t *)ptr; }

void moonbit_native_uint8_pointer_set(void *ptr, uint8_t val) {
  *(uint8_t *)ptr = val;
}

uint16_t moonbit_native_uint16_pointer_get(void *ptr) {
  return *(uint16_t *)ptr;
}

void moonbit_native_uint16_pointer_set(void *ptr, uint16_t val) {
  *(uint16_t *)ptr = val;
}

uint32_t moonbit_native_uint32_pointer_get(void *ptr) {
  return *(uint32_t *)ptr;
}

void moonbit_native_uint32_pointer_set(void *ptr, uint32_t val) {
  *(uint32_t *)ptr = val;
}

uint64_t moonbit_native_uint64_pointer_get(void *ptr) {
  return *(uint64_t *)ptr;
}

void moonbit_native_uint64_pointer_set(void *ptr, uint64_t val) {
  *(uint64_t *)ptr = val;
}

float moonbit_native_float_pointer_get(void *ptr) { return *(float *)ptr; }

void moonbit_native_float_pointer_set(void *ptr, float val) {
  *(float *)ptr = val;
}

double moonbit_native_double_pointer_get(void *ptr) { return *(double *)ptr; }

void moonbit_native_double_pointer_set(void *ptr, double val) {
  *(double *)ptr = val;
}

moonbit_bytes_t moonbit_native_cstring_to_bytes(const char *str) {
  size_t len = strlen(str);
  moonbit_bytes_t bytes = moonbit_make_bytes(len + 1, 0);
  memcpy(bytes, str, len + 1);
  return bytes;
}