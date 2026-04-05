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

#include <stdint.h>
#include <windows.h>
#include <bcrypt.h>

// https://learn.microsoft.com/en-us/windows/win32/api/schannel/ns-schannel-sch_credentials
#include <SubAuth.h>
#define SCHANNEL_USE_BLACKLISTS
#include <schannel.h>

#define SECURITY_WIN32
#include <security.h>

#include <moonbit.h>

#pragma comment (lib, "secur32.lib")
#pragma comment (lib, "Crypt32.lib")
#pragma comment (lib, "Bcrypt.lib")

struct Context {
  enum {
    Uninitialized,
    HandleInitialized,
    ContextInitialized
  } state;
  CredHandle handle;
  CtxtHandle context;
  ULONG context_attrs;
  int32_t bytes_read;
  int32_t bytes_to_write;
  int32_t msg_trailer;
  SecPkgContext_StreamSizes stream_sizes;
};

MOONBIT_FFI_EXPORT
void moonbitlang_async_schannel_free(struct Context *ctx) {
  switch (ctx->state) {
    case ContextInitialized:
      DeleteSecurityContext(&ctx->context);
    case HandleInitialized:
      FreeCredentialsHandle(&ctx->handle);
    case Uninitialized:
      break;
  }
  free(ctx);
}

MOONBIT_FFI_EXPORT
struct Context *moonbitlang_async_schannel_new() {
  struct Context *result = (struct Context*)malloc(sizeof(struct Context));
  result->state = Uninitialized;
  result->context.dwUpper = 0;
  result->context.dwLower = 0;
  return result;
}

MOONBIT_FFI_EXPORT
int32_t moonbitlang_async_schannel_bytes_read(struct Context *ctx) {
  return ctx->bytes_read;
}

MOONBIT_FFI_EXPORT
int32_t moonbitlang_async_schannel_bytes_to_write(struct Context *ctx) {
  return ctx->bytes_to_write;
}

MOONBIT_FFI_EXPORT
int32_t moonbitlang_async_schannel_msg_trailer(struct Context *ctx) {
  return ctx->msg_trailer;
}

MOONBIT_FFI_EXPORT
int32_t moonbitlang_async_schannel_header_size(struct Context *ctx) {
  return ctx->stream_sizes.cbHeader;
}

MOONBIT_FFI_EXPORT
int32_t moonbitlang_async_schannel_trailer_size(struct Context *ctx) {
  return ctx->stream_sizes.cbTrailer;
}

MOONBIT_FFI_EXPORT
int32_t moonbitlang_async_schannel_init_client(
  struct Context *ctx,
  int32_t verify
) {
  TLS_PARAMETERS tls_param;
  memset(&tls_param, 0, sizeof(TLS_PARAMETERS));
  tls_param.grbitDisabledProtocols = SP_PROT_TLS1_CLIENT;

  SCH_CREDENTIALS auth_data;
  memset(&auth_data, 0, sizeof(SCH_CREDENTIALS));
  auth_data.dwVersion = SCH_CREDENTIALS_VERSION;
  auth_data.dwFlags = SCH_CRED_IGNORE_NO_REVOCATION_CHECK;
  if (!verify)
    auth_data.dwFlags |= SCH_CRED_MANUAL_CRED_VALIDATION;
  auth_data.cTlsParameters = 1;
  auth_data.pTlsParameters = &tls_param;

  int32_t ret = AcquireCredentialsHandle(
    NULL, // `pszPrincipal`, usused by schannel
    UNISP_NAME, // `pszPackage`
    SECPKG_CRED_OUTBOUND, // `fCredentialUse`
    NULL, // `pvLogonID`, unused by schannel
    &auth_data, // `pAuthData`
    NULL, // `pGetKeyFn`, unused by schannel
    NULL, // `pGetKeyArgument`, unused by schannel
    &ctx->handle,
    NULL
  );
  if (ret == SEC_E_OK) {
    ctx->state = HandleInitialized;
    return 0;
  } else {
    return ret;
  }
}

MOONBIT_FFI_EXPORT
int32_t moonbitlang_async_schannel_init_server(struct Context *ctx) {
  const DWORD encoding_type = PKCS_7_ASN_ENCODING | X509_ASN_ENCODING;
  HCERTSTORE cert_store = CertOpenStore(
    CERT_STORE_PROV_SYSTEM_A,
    encoding_type,
    (HCRYPTPROV_LEGACY)NULL,
    CERT_STORE_READONLY_FLAG | CERT_STORE_OPEN_EXISTING_FLAG | CERT_SYSTEM_STORE_CURRENT_USER,
    "My"
  );
  if (!cert_store) {
    return GetLastError();
  }

  PCCERT_CONTEXT cert = CertFindCertificateInStore(
    cert_store,
    encoding_type,
    0,
    CERT_FIND_HAS_PRIVATE_KEY,
    NULL,
    NULL
  );

  if (!cert) {
    CertCloseStore(cert_store, 0);
    return GetLastError();
  }

  TLS_PARAMETERS tls_param;
  memset(&tls_param, 0, sizeof(TLS_PARAMETERS));
  tls_param.grbitDisabledProtocols = SP_PROT_TLS1_0_SERVER | SP_PROT_TLS1_1_SERVER;

  SCH_CREDENTIALS auth_data;
  memset(&auth_data, 0, sizeof(SCH_CREDENTIALS));
  auth_data.dwVersion = SCH_CREDENTIALS_VERSION;
  auth_data.dwCredFormat = SCH_CRED_FORMAT_CERT_HASH_STORE;
  auth_data.cCreds = 1;
  auth_data.paCred = &cert;
  auth_data.dwFlags = SCH_USE_STRONG_CRYPTO;
  auth_data.cTlsParameters = 1;
  auth_data.pTlsParameters = &tls_param;

  int32_t ret = AcquireCredentialsHandle(
    NULL, // `pszPrincipal`, usused by schannel
    UNISP_NAME, // `pszPackage`
    SECPKG_CRED_INBOUND, // `fCredentialUse`
    NULL, // `pvLogonID`, unused by schannel
    &auth_data, // `pAuthData`
    NULL, // `pGetKeyFn`, unused by schannel
    NULL, // `pGetKeyArgument`, unused by schannel
    &ctx->handle,
    NULL
  );

  CertFreeCertificateContext(cert);
  CertCloseStore(cert_store, 0);

  if (ret == SEC_E_OK) {
    ctx->state = HandleInitialized;
    return 0;
  } else {
    return ret;
  }
}

enum TlsState {
  Completed = 0,
  WantRead = 1,
  WantWrite = 2,
  Error = 3,
  Eof = 4,
  ReNegotiate = 5
};

MOONBIT_FFI_EXPORT
int32_t moonbitlang_async_schannel_connect(
  struct Context *ctx,
  LPWSTR host_name,
  char *in_buffer,
  int32_t in_buffer_offset,
  int32_t in_buffer_len,
  char *out_buffer,
  int32_t out_buffer_offset,
  int32_t out_buffer_len
) {
  SecBufferDesc input_desc, output_desc;
  SecBuffer input[2], output[1];

  if (ctx->state == ContextInitialized) {
    input[0].BufferType = SECBUFFER_TOKEN;
    input[0].cbBuffer = in_buffer_len;
    input[0].pvBuffer = in_buffer + in_buffer_offset;

    input[1].BufferType = SECBUFFER_EMPTY;
    input[1].cbBuffer = 0;
    input[1].pvBuffer = NULL;

    input_desc.ulVersion = SECBUFFER_VERSION;
    input_desc.cBuffers = 2;
    input_desc.pBuffers = input;
  }

  output[0].BufferType = SECBUFFER_TOKEN;
  output[0].cbBuffer = out_buffer_len;
  output[0].pvBuffer = out_buffer + out_buffer_offset;

  output_desc.ulVersion = SECBUFFER_VERSION;
  output_desc.cBuffers = 1;
  output_desc.pBuffers = output;

  ctx->bytes_read = ctx->bytes_to_write = 0;

  int32_t ret = InitializeSecurityContextW(
    &ctx->handle,
    ctx->state == ContextInitialized ? &ctx->context : NULL,
    host_name, // `pszTargetName`
    ISC_REQ_CONFIDENTIALITY | ISC_REQ_INTEGRITY, // `fContextReq`
    0, // `Reserved1`
    0, // `TargetDataRep`, unused by schannel
    ctx->state == ContextInitialized ? &input_desc : NULL, // `pInput`
    0, // `Reserved2`
    &ctx->context, // `phNewContext`
    &output_desc, // `pOutput`
    &ctx->context_attrs, // `pfContextAttr`
    NULL // `ptsExpiry`
  );

  ctx->bytes_read = in_buffer_len;
  if (input[1].BufferType == SECBUFFER_EXTRA)
    ctx->bytes_read -= input[1].cbBuffer;

  switch (ret) {
    case SEC_E_OK:
      ret = Completed;
      ctx->bytes_to_write = output[0].cbBuffer;
      QueryContextAttributes(&ctx->context, SECPKG_ATTR_STREAM_SIZES, &ctx->stream_sizes);
      break;
    case SEC_E_INCOMPLETE_MESSAGE:
      ctx->bytes_read = 0;
      ret = WantRead;
      break;
    case SEC_I_CONTINUE_NEEDED:
      ret = WantWrite;
      ctx->bytes_to_write = output[0].cbBuffer;
      break;
    case SEC_I_CONTEXT_EXPIRED:
      ret = Eof;
      ctx->bytes_to_write = output[0].cbBuffer;
      break;
    default:
      SetLastError(ret);
      return Error; // `HandshakeState::Error`
  }
  // non-error case, properly maintain `ctx->state`
  if (ctx->state == HandleInitialized)
    ctx->state = ContextInitialized;

  return ret;
}

MOONBIT_FFI_EXPORT
int32_t moonbitlang_async_schannel_accept(
  struct Context *ctx,
  char *in_buffer,
  int32_t in_buffer_offset,
  int32_t in_buffer_len,
  char *out_buffer,
  int32_t out_buffer_offset,
  int32_t out_buffer_len
) {
  SecBufferDesc input_desc, output_desc;
  SecBuffer input[2], output[1];

  input[0].BufferType = SECBUFFER_TOKEN;
  input[0].cbBuffer = in_buffer_len;
  input[0].pvBuffer = in_buffer + in_buffer_offset;

  input[1].BufferType = SECBUFFER_EMPTY;
  input[1].cbBuffer = 0;
  input[1].pvBuffer = NULL;

  input_desc.ulVersion = SECBUFFER_VERSION;
  input_desc.cBuffers = 2;
  input_desc.pBuffers = input;

  output[0].BufferType = SECBUFFER_TOKEN;
  output[0].cbBuffer = out_buffer_len;
  output[0].pvBuffer = out_buffer + out_buffer_offset;

  output_desc.ulVersion = SECBUFFER_VERSION;
  output_desc.cBuffers = 1;
  output_desc.pBuffers = output;

  ctx->bytes_read = ctx->bytes_to_write = 0;

  int32_t ret = AcceptSecurityContext(
    &ctx->handle,
    ctx->state == ContextInitialized ? &ctx->context : NULL,
    &input_desc, // `pInput`
    ASC_REQ_CONFIDENTIALITY | ASC_REQ_INTEGRITY, // `fContextReq`
    0, // `TargetDataRep`, unused by schannel
    &ctx->context, // `phNewContext`
    &output_desc, // `pOutput`
    &ctx->context_attrs, // `pfContextAttr`
    NULL // `ptsExpiry`
  );

  ctx->bytes_read = in_buffer_len;
  if (input[1].BufferType == SECBUFFER_EXTRA)
    ctx->bytes_read -= input[1].cbBuffer;

  switch (ret) {
    case SEC_E_OK:
      ret = Completed;
      ctx->bytes_to_write = output[0].cbBuffer;
      QueryContextAttributes(&ctx->context, SECPKG_ATTR_STREAM_SIZES, &ctx->stream_sizes);
      break;
    case SEC_E_INCOMPLETE_MESSAGE:
      ctx->bytes_read = 0;
      ret = WantRead;
      break;
    case SEC_I_CONTINUE_NEEDED:
      ret = WantWrite;
      ctx->bytes_to_write = output[0].cbBuffer;
      break;
    case SEC_I_CONTEXT_EXPIRED:
      ret = Eof;
      break;
    default:
      SetLastError(ret);
      return Error;
  }
  // non-error case, properly maintain `ctx->state`
  if (
    ctx->state == HandleInitialized
    // Notice that if the first `ClientHello` has not been completely received,
    // `AcceptSecurityContext` will NOT initialize the `ctx->context` handle.
    // So it may take multiple `AcceptSecurityContext` before `ctx->handle` is properly initialized.
    && (ctx->context.dwLower != 0 || ctx->context.dwUpper != 0)
  ) {
    ctx->state = ContextInitialized;
  }

  return ret;
}

MOONBIT_FFI_EXPORT
int32_t moonbitlang_async_schannel_read(
  struct Context *ctx,
  char *buffer,
  int32_t offset,
  int32_t len
) {
  SecBuffer buffers[4];
  buffers[0].BufferType = SECBUFFER_DATA;
  buffers[0].cbBuffer = len;
  buffers[0].pvBuffer = buffer + offset;
  for (int i = 1; i < 4; ++i) {
    buffers[i].BufferType = SECBUFFER_EMPTY;
    buffers[i].cbBuffer = 0;
    buffers[i].pvBuffer = NULL;
  }

  SecBufferDesc input_desc;
  input_desc.ulVersion = SECBUFFER_VERSION;
  input_desc.cBuffers = 4;
  input_desc.pBuffers = buffers;

  ctx->bytes_read = 0;

  int32_t ret = DecryptMessage(&ctx->context, &input_desc, 0, NULL);

  switch (ret) {
    case SEC_E_OK:
      ctx->msg_trailer = buffers[2].cbBuffer;
      ctx->bytes_read = len;
      if (buffers[3].BufferType = SECBUFFER_EXTRA) {
        ctx->bytes_read -= buffers[3].cbBuffer;
        ctx->msg_trailer -= buffers[3].cbBuffer;
      }
      return Completed;
    case SEC_E_INCOMPLETE_MESSAGE:
      return WantRead;
    case SEC_I_CONTEXT_EXPIRED:
      return Eof;
    case SEC_I_RENEGOTIATE:
      return ReNegotiate;
    default:
      SetLastError(ret);
      return Error;
  }
}

MOONBIT_FFI_EXPORT
int32_t moonbitlang_async_schannel_write(
  struct Context *ctx,
  char *buffer,
  int32_t offset,
  int32_t len
) {
  SecBuffer buffers[4];

  buffers[0].BufferType = SECBUFFER_STREAM_HEADER;
  buffers[0].cbBuffer = ctx->stream_sizes.cbHeader;
  buffers[0].pvBuffer = buffer + offset;

  buffers[1].BufferType = SECBUFFER_DATA;
  buffers[1].cbBuffer = len;
  buffers[1].pvBuffer = (char*)(buffers[0].pvBuffer) + buffers[0].cbBuffer;

  buffers[2].BufferType = SECBUFFER_STREAM_TRAILER;
  buffers[2].cbBuffer = ctx->stream_sizes.cbTrailer;
  buffers[2].pvBuffer = (char*)(buffers[1].pvBuffer) + buffers[1].cbBuffer;

  buffers[3].BufferType = SECBUFFER_EMPTY;
  buffers[3].cbBuffer = 0;
  buffers[3].pvBuffer = NULL;

  SecBufferDesc input_desc;
  input_desc.ulVersion = SECBUFFER_VERSION;
  input_desc.cBuffers = 4;
  input_desc.pBuffers = buffers;

  ctx->bytes_to_write = 0;

  int32_t ret = EncryptMessage(&ctx->context, 0, &input_desc, 0);

  switch (ret) {
    case SEC_E_OK:
      ctx->bytes_to_write =
        buffers[0].cbBuffer + buffers[1].cbBuffer + buffers[2].cbBuffer;
      return WantWrite;
    default:
      SetLastError(ret);
      return Error;
  }
}

MOONBIT_FFI_EXPORT
int32_t moonbitlang_async_schannel_shutdown(struct Context *ctx) {
  DWORD type = SCHANNEL_SHUTDOWN;

  SecBuffer buf;
  buf.BufferType = SECBUFFER_TOKEN;
  buf.cbBuffer = sizeof(DWORD);
  buf.pvBuffer = &type;

  SecBufferDesc buf_desc;
  buf_desc.ulVersion = SECBUFFER_VERSION;
  buf_desc.cBuffers = 1;
  buf_desc.pBuffers = &buf;

  return ApplyControlToken(&ctx->context, &buf_desc);
}

MOONBIT_FFI_EXPORT
int32_t moonbitlang_async_tls_rand_bytes(void *buf, int32_t num) {
  return BCryptGenRandom(NULL, buf, num, BCRYPT_USE_SYSTEM_PREFERRED_RNG) == STATUS_SUCCESS;
}

MOONBIT_FFI_EXPORT
int32_t moonbitlang_async_tls_SHA1(void *data, int32_t num, void *out) {
  BCRYPT_ALG_HANDLE algorithm;
  BCRYPT_HASH_HANDLE hasher;
  NTSTATUS status;

  status = BCryptOpenAlgorithmProvider(&algorithm, BCRYPT_SHA1_ALGORITHM, NULL, 0);
  if (status != STATUS_SUCCESS)
    goto exit;

  status = BCryptCreateHash(algorithm, &hasher, NULL, 0, NULL, 0, 0);
  if (status != STATUS_SUCCESS)
    goto exit_with_algorithm;

  status = BCryptHashData(hasher, data, num, 0);
  if (status != STATUS_SUCCESS)
    goto exit_with_hasher;

  status = BCryptFinishHash(hasher, out, 20, 0);

exit_with_hasher:
  BCryptDestroyHash(hasher);

exit_with_algorithm:
  BCryptCloseAlgorithmProvider(algorithm, 0);

exit:
  if (status != STATUS_SUCCESS) {
    SetLastError(status);
    return 0;
  } else {
    return 1;
  }
}

#endif
