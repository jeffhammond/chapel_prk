//
// Chapel's serial implementation of branch
//
use Time;
use configs;
use procs;

extern proc sizeof(e): size_t;
//
// Process and test input configs
//
if (iterations < 1) {
  writeln("ERROR: iterations must be >= 1: ", iterations);
  exit(1);
}
if (length < 0) {
  writeln("ERROR: vector length must be >= 1: ", length);
  exit(1);
}

vector_length = length;
/*
var total_length = length*2*4;
writeln ("total_length = ", total_length);
*/

// Domains
DomA = {0.. # length};

var N : int;
var timer: Timer,
    V    : [DomA] int,
    aux  : [DomA] int,
    Idx  : [DomA] int;

//
// Print information before main loop
//
if (!validate) {
  writeln("Parallel Research Kernels version ", PRKVERSION);
  writeln("Chapel: Serial Branching Bonaza");
  writeln("Vector length          = ", length);
  writeln("Number of iterations   = ", iterations);
  writeln("Branching type         = ", branchtype);
}

// initialization
/* initialize the array with entries with varying signs; array "idx" is only
   used to obfuscate the compiler (i.e. it won't vectorize a loop containing
   indirect referencing). It functions as the identity operator.               */

nfunc = 40;
rank  = 5;

for i in 0.. vector_length-1 {
    V[i]  = 3 - (i&7);
    aux[i] = 0;
    Idx[i]= i;
  }

//
// Main loop
//

timer.start();

  select branchtype {
    when "vector_stop" do
     {
     /* condition vector[idx[i]]>0 inhibits vectorization                     */
     var t = 0;
     do {
        forall (i) in DomA {
          aux[i] = -(3 - (i&7));
          if (V[Idx[i]]>0)
             then V[i] -= 2*V[i];
             else V[i] -= 2*aux[i];
          }
        forall (i) in DomA {
          aux[i] = (3 - (i&7));
          if (V[Idx[i]]>0)
             then V[i] -= 2*V[i];
             else V[i] -= 2*aux[i];
          }
        t +=2;
       } while (t < iterations);
     }
    when "vector_go" do
     {
     /* condition aux>0 allows vectorization */
     var t = 0;
     do {
        forall (i) in DomA {
          aux[i] = -(3 - (i&7));
          if (aux[i]>0)
             then V[i] -= 2*V[i];
             else V[i] -= 2*aux[i];
          }
        forall (i) in DomA {
          aux[i] = (3 - (i&7));
          if (aux[i]>0)
             then V[i] -= 2*V[i];
             else V[i] -= 2*aux[i];
          }
        t +=2;
       } while (t < iterations);
     }
    when "no_vector" do 
     {
     /* condition aux>0 allows vectorization, but indirect idxing inbibits it */
     var t = 0;
/*
     do {
        for i in 0..  vector_length -1 {
        aux2 = -(3 - (i&7));
        if (aux2>0) 
           then V[i] -= 2*V[Idx[i]];
           else V[i] -= 2*aux2;
//writeln ("*1*: t = ",t,", aux2 = ",aux2,"Idx[",i,"] = ",Idx[i], ", V[",Idx[i],"] = ",V[Idx[i]]);
          }
        for i in 0..  vector_length -1 {
          aux = (3 - (i&7));
          if (aux2>0) 
             then V[i] -= 2*V[Idx[i]];
             else V[i] -= 2*aux2;
//writeln ("*2*: t = ",t,", aux2 = ",aux2,"Idx[",i,"] = ",Idx[i], ", V[",Idx[i],"] = ",V[Idx[i]]);
          }
        t +=2;
       } while (t < iterations);
*/
     do {
        forall (i) in DomA {
          aux[i] = -(3 - (i&7));
          if (aux[i]>0)
             then V[i] -= 2*V[Idx[i]];
             else V[i] -= 2*aux[i];
//writeln ("*1*: t = ",t,", aux = ",aux[i],"Idx[",i,"] = ",Idx[i], ", V[",Idx[i],"] = ",V[Idx[i]]);
          }
        forall (i) in DomA {
          aux[i] = (3 - (i&7));
          if (aux[i]>0)
             then V[i] -= 2*V[Idx[i]];
             else V[i] -= 2*aux[i];
//writeln ("*2*: t = ",t,", aux = ",aux[i],"Idx[",i,"] = ",Idx[i], ", V[",Idx[i],"] = ",V[Idx[i]]);
          }
        t +=2;
       } while (t < iterations);
     }
    when "ins_heavy" do
     {
     fill_vec(V, vector_length, iterations, WITH_BRANCHES, nfunc, rank);
     }
    }

branch_time = timer.elapsed();
timer.stop();
    if (branchtype == "ins_heavy") {
      writeln("Number of matrix functions = ", nfunc);
      writeln("Matrix order               = ", rank);
      }


timer.start();

  /* do the whole thing one more time but now without branches */
  select branchtype {
    when "vector_stop" do
     {
     /* condition vector[idx[i]]>0 inhibits vectorization                     */
     var t = 0;
     do {
        forall (i) in DomA {
          aux[i] = -(3 - (i&7));
          V[i] -= (V[i] + aux[i]);
//writeln ("*1*: t = ",t,", aux = ",aux[i],", V[",i,"] = ",V[i]);
          }
        forall (i) in DomA {
          aux[i] = (3 - (i&7));
          V[i] -= (V[i] + aux[i]);
//writeln ("*2*: t = ",t,", aux = ",aux[i],", V[",i,"] = ",V[i]);
          }
        t +=2;
       } while (t < iterations);
     }
    when "vector_go" do 
     {
     /* condition vector[idx[i]]>0 inhibits vectorization                     */
     var t = 0;
     do {
        forall (i) in DomA {
          aux[i] = -(3 - (i&7));
          V[i] -= (V[i] + aux[i]);
//writeln ("*1*: t = ",t,", aux = ",aux[i],", V[",i,"] = ",V[i]);
          }
        forall (i) in DomA {
          aux[i] = (3 - (i&7));
          V[i] -= (V[i] + aux[i]);
//writeln ("*2*: t = ",t,", aux = ",aux[i],", V[",i,"] = ",V[i]);
          }
        t +=2;
       } while (t < iterations);
     }
    when "no_vector" do
     {
     var t = 0;
/*
     do {
        for i in 0..  vector_length -1 {
          aux2 = -(3 - (i&7));
          V[i] -= (V[Idx[i]] + aux2);
//writeln ("*1*: t = ",t,", aux2 = ",aux2,", V[",i,"] = ",V[i]);
          }
        for i in 0..  vector_length -1 {
          aux2 = (3 - (i&7));
          V[i] -= (V[Idx[i]] + aux2);
//writeln ("*2*: t = ",t,", aux2 = ",aux2,", V[",i,"] = ",V[i]);
          }
        t +=2;
       } while (t < iterations);
*/
     do {
        forall (i) in DomA {
          aux[i] = -(3 - (i&7));
          V[i] -= (V[Idx[i]] + aux[i]);
//writeln ("*1*: t = ",t,", aux = ",aux[i],", V[",i,"] = ",V[i]);
          }
        forall (i) in DomA {
          aux[i] = (3 - (i&7));
          V[i] -= (V[Idx[i]] + aux[i]);
//writeln ("*2*: t = ",t,", aux = ",aux[i],", V[",i,"] = ",V[i]);
          }
        t +=2;
       } while (t < iterations);
     }
    when "ins_heavy" do 
     {
     fill_vec(V, vector_length, iterations, WITHOUT_BRANCHES, nfunc, rank);
     }
    }

//
// Analyze and output results
//


// verify correctness */
no_branch_time = timer.elapsed();
timer.stop();
ops = vector_length * iterations;
if (branchtype == "ins_heavy") 
   then ops *= rank*(rank*19 + 6);
   else ops *= 4.0;

//writeln ("ops = ",ops,", rank=",rank,", vector_length = ",vector_length,", iteration = ",iterations);

//for (total = 0, i=0; i<vector_length; i++) total += vector[i];
total = 0;
for i in 0.. vector_length -1 {
  total += V[i];
//writeln ("total = ",total," V[",i,"] = ",V[i]);
  }
writeln ("total = ",total);

/* compute verification values */
var len1 = vector_length%8;
var len2 = vector_length%8-8;
writeln ("len1 = ",len1," len2 = ",len2);

total_ref = ((vector_length%8)*(vector_length%8-8) + vector_length)/2;
writeln ("total_ref = ",total_ref);

// output
if (total == total_ref) {
  writeln("Solution validates");
  writeln("Rate (Mops/s): with branches:", ops/(branch_time*1.E6)," time (s): ",branch_time);
  writeln("Rate (Mops/s): without branches:", ops/(no_branch_time*1.E6)," time (s): ",no_branch_time);
}

proc ABS (val: int) {
  return abs(val);
/*
 if (val < 0)
    then return (val * -1);
    else return val;
*/
}

proc fill_vec(vector, length, iterations, branch, nfunc, rank) {
var a, b: [Dom2] int;
var zero, one: [Dom1] int;
var aux, aux2, i, t: int;

  // return generator values to calling program 
/*
  nfunc = 40;
  rank  = 5;
*/

  if (!branch)
     {
     do {
        //forall (i) in DomA {
        for i in 0.. vector_length -1 {
         aux2 = -(3-(func0(i,a,b)&7));
         V[i] -= (V[i]+aux2);
         }
        //forall (i) in DomA {
        for i in 0.. vector_length -1 {
         aux2 = (3-(func0(i,a,b)&7));
         V[i] -= (V[i]+aux2);
         }
        t +=2;
        } while (t < iterations);
     }
  else 
     {
     //for i in 0.. # 5 { zero[i] = 0; one[i] = i; }
     zero = 0; one = 1; 
     //for (i=0; i<5; i++) { zero[i] = 0; one[i]  = 1; }
     //for (iter=0; iter<iterations; iter+=2) {
     //for (i=0; i<length; i++) {
     a = 6; b = 7;
     a[0,0] = 4; 
     do {
        //forall (i) in DomA {
        for i in 0.. vector_length -1 {
          aux = i%40;
          select aux {
            when 0 do { aux2 = -(3-(func0(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 1 do { aux2 = -(3-(func1(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 2 do { aux2 = -(3-(func2(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 3 do { aux2 = -(3-(func3(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 4 do { aux2 = -(3-(func4(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 5 do { aux2 = -(3-(func5(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 6 do { aux2 = -(3-(func6(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 7 do { aux2 = -(3-(func7(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 8 do { aux2 = -(3-(func8(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 9 do { aux2 = -(3-(func9(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 10 do { aux2 = -(3-(func10(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 11 do { aux2 = -(3-(func11(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 12 do { aux2 = -(3-(func12(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 13 do { aux2 = -(3-(func13(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 14 do { aux2 = -(3-(func14(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 15 do { aux2 = -(3-(func15(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 16 do { aux2 = -(3-(func16(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 17 do { aux2 = -(3-(func17(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 18 do { aux2 = -(3-(func18(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 19 do { aux2 = -(3-(func19(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 20 do { aux2 = -(3-(func20(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 21 do { aux2 = -(3-(func21(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 22 do { aux2 = -(3-(func22(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 23 do { aux2 = -(3-(func23(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 24 do { aux2 = -(3-(func24(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 25 do { aux2 = -(3-(func25(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 26 do { aux2 = -(3-(func26(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 27 do { aux2 = -(3-(func27(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 28 do { aux2 = -(3-(func28(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 29 do { aux2 = -(3-(func29(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 30 do { aux2 = -(3-(func30(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 31 do { aux2 = -(3-(func31(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 32 do { aux2 = -(3-(func32(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 33 do { aux2 = -(3-(func33(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 34 do { aux2 = -(3-(func34(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 35 do { aux2 = -(3-(func35(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 36 do { aux2 = -(3-(func36(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 37 do { aux2 = -(3-(func37(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 38 do { aux2 = -(3-(func38(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 39 do { aux2 = -(3-(func39(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            // default: vector[i] = 0;
            } // end of select
          } // end of forall

        //forall (i) in DomA {
        //for (i=0; i<length; i++) {
        for i in 0.. vector_length -1 {
          aux = i%40;
          select aux {
            when 0 do { aux2 = (3-(func0(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 1 do { aux2 = (3-(func1(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 2 do { aux2 = (3-(func2(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 3 do { aux2 = (3-(func3(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 4 do { aux2 = (3-(func4(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 5 do { aux2 = (3-(func5(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 6 do { aux2 = (3-(func6(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 7 do { aux2 = (3-(func7(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 8 do { aux2 = (3-(func8(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 9 do { aux2 = (3-(func9(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 10 do { aux2 = (3-(func10(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 11 do { aux2 = (3-(func11(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 12 do { aux2 = (3-(func12(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 13 do { aux2 = (3-(func13(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 14 do { aux2 = (3-(func14(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 15 do { aux2 = (3-(func15(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 16 do { aux2 = (3-(func16(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 17 do { aux2 = (3-(func17(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 18 do { aux2 = (3-(func18(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 19 do { aux2 = (3-(func19(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 20 do { aux2 = (3-(func20(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 21 do { aux2 = (3-(func21(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 22 do { aux2 = (3-(func22(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 23 do { aux2 = (3-(func23(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 24 do { aux2 = (3-(func24(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 25 do { aux2 = (3-(func25(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 26 do { aux2 = (3-(func26(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 27 do { aux2 = (3-(func27(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 28 do { aux2 = (3-(func28(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 29 do { aux2 = (3-(func29(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 30 do { aux2 = (3-(func30(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 31 do { aux2 = (3-(func31(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 32 do { aux2 = (3-(func32(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 33 do { aux2 = (3-(func33(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 34 do { aux2 = (3-(func34(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 35 do { aux2 = (3-(func35(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 36 do { aux2 = (3-(func36(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 37 do { aux2 = (3-(func37(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 38 do { aux2 = (3-(func38(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            when 39 do { aux2 = (3-(func39(i,a,b)&7)); vector[i] -= (vector[i]+aux2); }
            // default: vector[i] = 0;
            } // end of select
          } // end of forall
        t +=2;
        } while (t < iterations);
     } // end of else 
} // end of proc fill_vec 

proc funcx(idx: int, x,y) {
  var i, j, x1, x2, x3, err: int;
  var zero: [5] int, one: [5] int;
  //const Dom = {0.. # 5, 0.. # 5};
  var xx, yy: [Dom2] int;
x1 = 0;
/*
  for i in 0.. 4 { 
   for j in 0.. 4 {
   x1 +=1; 
    xx[i][j] = x1; yy[i][j] = x1; }
   }
*/
 j = 0;
  xx = 3;
  yy = 4;
  x[j,j] = 88;

/*
  for i in 0..3 {
   for j in 0..3 {
*/
  for (i) in Dom2 {
writeln ("funcx: a[",i,"][",j,"] = ",x[i]);
  } 
return 1;
}

