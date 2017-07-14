/*
   Chapel's parallel DGEMM implementation

   Contributed by Engin Kayraklioglu (GWU)
*/
use Time;
use BlockDist;
use RangeChunk;
use PrefetchPatterns;

param PRKVERSION = "2.17";

config type dtype = real;

config param useBlockDist = true;


config const order = 10,
             epsilon = 1e-8,
             iterations = 100,
             blockSize = 0,
             debug = false,
             commDiag = false,
             validate = true,
             correctness = false; // being run in start_test

config const staticDomain = false;

config param handPrefetch = false,
             prefetch = false,
             consistent = true;

if prefetch && handPrefetch then
  halt("Wrong configuration");

// TODO current logic assumes order is divisible by blockSize. add that
// check

const vecRange = 0..#order;

const matrixSpace = {vecRange, vecRange};
const matrixDom = matrixSpace dmapped if useBlockDist then
                      new dmap(new Block(boundingBox=matrixSpace)) else
                      defaultDist;

var A: [matrixDom] dtype,
    B: [matrixDom] dtype,
    C: [matrixDom] dtype;

forall (i,j) in matrixDom {
  A[i,j] = j;
  B[i,j] = j;
  C[i,j] = 0;
}

const nTasksPerLocale = here.maxTaskPar;

if !correctness {
  writeln("Chapel Dense matrix-matrix multiplication");
  writeln("Max parallelism      =   ", nTasksPerLocale);
  writeln("Matrix order         =   ", order);
  writeln("Blocking factor      =   ", if blockSize>0 then blockSize+""
      else "N/A");
  writeln("Number of iterations =   ", iterations);
  writeln();
}

const refChecksum = (iterations+1) *
    (0.25*order*order*order*(order-1.0)*(order-1.0));

if prefetch {
  A._instance.rowWiseAllGather(consistent, staticDomain);
  B._instance.colWiseAllGather(consistent, staticDomain);
}

var t = new Timer();

if commDiag then startCommDiagnostics();

if blockSize == 0 {
  for niter in 0..iterations {
    if niter==1 then t.start();

    forall (i,j) in matrixSpace do
      for k in vecRange do
        C[i,j] += A[i,k] * B[k,j];

  }
  t.stop();
}
else {
  // we need task-local arrays for blocked matrix multiplication. It
  // seems that in intent for arrays is not working currently, so I am
  // falling back to writing my own coforall. Engin
  coforall l in Locales with (ref t) {
    on l {
      const bVecRange = 0..#blockSize;
      const blockDom = {bVecRange, bVecRange};
      const localDom = matrixDom.localSubdomain();

      var localADom: domain(2);
      var localBDom: domain(2);

      var localA: [localADom] real;
      var localB: [localBDom] real;

      if handPrefetch {
        localADom = {localDom.dim(1),matrixDom.dim(2)};
        localBDom = {matrixDom.dim(1),localDom.dim(2)};

        localA = A[localADom];
        localB = B[localBDom];
      }

      inline proc accessA(i,j) ref {
        if handPrefetch then local { return localA[i,j]; }
        else { return A[i,j]; }
      }

      inline proc accessB(i,j) ref {
        if handPrefetch then local { return localB[i,j]; }
        else { return B[i,j]; }
      }

      coforall tid in 0..#nTasksPerLocale with (ref t) {
        const myChunk = chunk(localDom.dim(2), nTasksPerLocale, tid);
        const tileIterDom =
        {myChunk by blockSize, vecRange by blockSize};

        var AA = c_calloc(real, blockDom.size);
        var BB = c_calloc(real, blockDom.size);
        var CC = c_calloc(real, blockDom.size);

        for niter in 0..iterations {
          if handPrefetch {
            localA = A[localADom];
            localB = B[localBDom];
          }
          else if prefetch && !consistent {
            A._value.updatePrefetchHere();
            B._value.updatePrefetchHere();
          }
          if l.id==0 && tid==0 && niter==1 then t.start();

          for (jj,kk) in tileIterDom {
            // two parts are identical
            if handPrefetch || (prefetch && !consistent) {
              local { //comment this if !prefetch
                const jMax = min(jj+blockSize-1, myChunk.high);
                const kMax = min(kk+blockSize-1, vecRange.high);
                const jRange = 0..jMax-jj;
                const kRange = 0..kMax-kk;

                for (jB, j) in zip(jj..jMax, bVecRange) do
                  for (kB, k) in zip(kk..kMax, bVecRange) do
                    BB[j*blockSize+k] = accessB[kB,jB];

                for ii in localDom.dim(1) by blockSize {
                  const iMax = min(ii+blockSize-1, localDom.dim(1).high);
                  const iRange = 0..iMax-ii;

                  for (iB, i) in zip(ii..iMax, bVecRange) do
                    for (kB, k) in zip(kk..kMax, bVecRange) do
                      AA[i*blockSize+k] = accessA[iB, kB];

                  local {
                    c_memset(CC, 0:int(32), blockDom.size*8);

                    // we could create domains here, but domain literals
                    // trigger fences. So iterate over ranges
                    // explicitly.
                    for k in kRange {
                      for j in jRange {
                        for i in iRange {
                          CC[i*blockSize+j] += AA[i*blockSize+k] *
                            BB[j*blockSize+k];
                        }
                      }
                    }

                    for (iB, i) in zip(ii..iMax, bVecRange) do
                      for (jB, j) in zip(jj..jMax, bVecRange) do
                        C[iB,jB] += CC[i*blockSize+j];
                  }
                }
              }
            }
            else {
              const jMax = min(jj+blockSize-1, myChunk.high);
              const kMax = min(kk+blockSize-1, vecRange.high);
              const jRange = 0..jMax-jj;
              const kRange = 0..kMax-kk;

              /*writeln(here, " to proxy B ", jj..jMax,",", kk..kMax);*/
              for (jB, j) in zip(jj..jMax, bVecRange) do
                for (kB, k) in zip(kk..kMax, bVecRange) do
                  BB[j*blockSize+k] = accessB[kB,jB];

              for ii in localDom.dim(1) by blockSize {
                const iMax = min(ii+blockSize-1, localDom.dim(1).high);
                const iRange = 0..iMax-ii;

                  /*writeln(here, " to proxy A ", ii..iMax,",", kk..kMax);*/
                for (iB, i) in zip(ii..iMax, bVecRange) do
                  for (kB, k) in zip(kk..kMax, bVecRange) do
                    AA[i*blockSize+k] = accessA[iB, kB];

                local {
                  c_memset(CC, 0:int(32), blockDom.size*8);

                  // we could create domains here, but domain literals
                  // trigger fences. So iterate over ranges
                  // explicitly.
                  for k in kRange {
                    for j in jRange {
                      for i in iRange {
                        CC[i*blockSize+j] += AA[i*blockSize+k] *
                          BB[j*blockSize+k];
                      }
                    }
                  }

                  for (iB, i) in zip(ii..iMax, bVecRange) do
                    for (jB, j) in zip(jj..jMax, bVecRange) do
                      C[iB,jB] += CC[i*blockSize+j];
                }
              }
            }
          }
        }
      }
    }
  }
  t.stop();
}

if commDiag {
  stopCommDiagnostics();
  writeln(getCommDiagnostics());
}

if validate {
  const checksum = + reduce C;
  if abs(checksum-refChecksum)/refChecksum > epsilon then
    halt("VALIDATION FAILED! Reference checksum = ", refChecksum,
        " Checksum = ", checksum);
  else
    writeln("Validation successful");
}

inline proc c_memset(dest :c_ptr, val: int(32), n: integral) {
  extern proc memset(dest: c_void_ptr, val: c_int, n: size_t):
    c_void_ptr;
  return memset(dest, val, n.safeCast(size_t));
}
if !correctness {
  const nflops = 2.0*(order**3);
  const avgTime = t.elapsed()/iterations;
  writeln("Rate(MFlop/s) = ", 1e-6*nflops/avgTime, " Time : ", avgTime);
}
