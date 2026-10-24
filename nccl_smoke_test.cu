
#include <windows.h>
#include <cuda_runtime.h>
#include <cstdio>

#include "nccl.h"

#define CUDA_CHECK(call) do {                                      \
    cudaError_t e = (call);                                        \
    if (e != cudaSuccess) {                                        \
        fprintf(stderr, "CUDA error at line %d: %s (%d)\n",        \
                __LINE__, cudaGetErrorString(e), (int)e);           \
        return 1;                                                  \
    }                                                              \
} while (0)

using InitAllFn = decltype(&ncclCommInitAll);
using AllReduceFn = decltype(&ncclAllReduce);
using DestroyFn = decltype(&ncclCommDestroy);
using ErrorStringFn = decltype(&ncclGetErrorString);

int main()
{
    printf("=== Windows NCCL diagnostic smoke test ===\n");

    HMODULE dll = LoadLibraryA("nccl64_134.11.8.dll");
    if (!dll) {
        printf("LoadLibrary failed: Windows error %lu\n", GetLastError());
        return 1;
    }
    printf("[OK] NCCL DLL loaded\n");

    auto initAll = reinterpret_cast<InitAllFn>(
        GetProcAddress(dll, "ncclCommInitAll"));
    auto allReduce = reinterpret_cast<AllReduceFn>(
        GetProcAddress(dll, "ncclAllReduce"));
    auto destroy = reinterpret_cast<DestroyFn>(
        GetProcAddress(dll, "ncclCommDestroy"));
    auto errorString = reinterpret_cast<ErrorStringFn>(
        GetProcAddress(dll, "ncclGetErrorString"));

    if (!initAll || !allReduce || !destroy || !errorString) {
        printf("Missing NCCL export(s).\n");
        FreeLibrary(dll);
        return 1;
    }
    printf("[OK] Required NCCL exports found\n");

    int deviceCount = 0;
    CUDA_CHECK(cudaGetDeviceCount(&deviceCount));
    printf("CUDA devices detected: %d\n", deviceCount);

    if (deviceCount < 2) {
        printf("Need at least two GPUs.\n");
        FreeLibrary(dll);
        return 1;
    }

    constexpr int n = 2;
    ncclComm_t comms[n] = {};
    int devices[n] = {0, 1};
    int *send[n] = {};
    int *recv[n] = {};
    cudaStream_t streams[n] = {};

    for (int i = 0; i < n; ++i) {
        CUDA_CHECK(cudaSetDevice(devices[i]));
        CUDA_CHECK(cudaMalloc(&send[i], sizeof(int)));
        CUDA_CHECK(cudaMalloc(&recv[i], sizeof(int)));
        CUDA_CHECK(cudaStreamCreate(&streams[i]));

        int value = i + 1;
        CUDA_CHECK(cudaMemcpy(send[i], &value, sizeof(int),
                              cudaMemcpyHostToDevice));

        printf("[OK] GPU %d buffers initialized with %d\n",
               devices[i], value);
    }

    printf("Initializing NCCL communicators...\n");
    ncclResult_t nr = initAll(comms, n, devices);

    if (nr != ncclSuccess) {
        printf("ncclCommInitAll failed: %s (%d)\n",
               errorString(nr), (int)nr);
        FreeLibrary(dll);
        return 1;
    }
    printf("[OK] NCCL communicators initialized\n");

    for (int i = 0; i < n; ++i) {
        CUDA_CHECK(cudaSetDevice(devices[i]));

        // Clear any pre-existing CUDA error before the NCCL call.
        cudaGetLastError();

        printf("Calling ncclAllReduce on GPU %d...\n", devices[i]);

        nr = allReduce(send[i], recv[i], 1, ncclInt,
                       ncclSum, comms[i], streams[i]);

        if (nr != ncclSuccess) {
            printf("\n[FAIL] ncclAllReduce on GPU %d: %s (%d)\n",
                   devices[i], errorString(nr), (int)nr);

            cudaError_t e = cudaGetLastError();
            printf("cudaGetLastError: %s (%d)\n",
                   cudaGetErrorString(e), (int)e);

            e = cudaStreamSynchronize(streams[i]);
            printf("cudaStreamSynchronize: %s (%d)\n",
                   cudaGetErrorString(e), (int)e);

            e = cudaDeviceSynchronize();
            printf("cudaDeviceSynchronize: %s (%d)\n",
                   cudaGetErrorString(e), (int)e);

            printf("\nDiagnostic complete. Stopping at first failure.\n");
            FreeLibrary(dll);
            return 1;
        }

        printf("[OK] ncclAllReduce enqueued on GPU %d\n", devices[i]);
    }

    int results[n] = {};

    for (int i = 0; i < n; ++i) {
        CUDA_CHECK(cudaSetDevice(devices[i]));

        cudaError_t e = cudaStreamSynchronize(streams[i]);
        if (e != cudaSuccess) {
            printf("[FAIL] GPU %d stream synchronization: %s (%d)\n",
                   devices[i], cudaGetErrorString(e), (int)e);

            e = cudaDeviceSynchronize();
            printf("cudaDeviceSynchronize: %s (%d)\n",
                   cudaGetErrorString(e), (int)e);
            FreeLibrary(dll);
            return 1;
        }

        CUDA_CHECK(cudaMemcpy(&results[i], recv[i], sizeof(int),
                              cudaMemcpyDeviceToHost));

        printf("GPU %d result: %d\n", devices[i], results[i]);
    }

    bool passed = (results[0] == 3 && results[1] == 3);

    for (int i = 0; i < n; ++i) {
        cudaSetDevice(devices[i]);
        cudaFree(send[i]);
        cudaFree(recv[i]);
        cudaStreamDestroy(streams[i]);
        destroy(comms[i]);
    }

    FreeLibrary(dll);

    if (passed) {
        printf("\nSUCCESS: AllReduce returned 3 on both GPUs!\n");
        return 0;
    }

    printf("\n[FAIL] Unexpected reduction result.\n");
    return 2;
}
