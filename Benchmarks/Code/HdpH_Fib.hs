
-- / sequential Fibonacci 

fib :: Int -> Integer
fib n | n <= 1    = 1
      | otherwise = fib (n-1) + fib (n-2)


-- / parallel Fibonacci; shared memory

par_fib :: Int -> Int -> Par Integer
par_fib seqThreshold n
  | n <= k    = force $ fib n
  | otherwise = do v <- new
                   let job = par_fib seqThreshold (n - 1) >>=
                             force >>=
                             put v
                   fork job
                   y <- par_fib seqThreshold (n - 2)
                   x <- get v
                   force $ x + y
  where k = max 1 seqThreshold

-- / parallel Fibonacci; distributed memory

dist_fib :: Int -> Int -> Int -> Par Integer
dist_fib seqThreshold parThreshold n
  | n <= k    = force $ fib n
  | n <= l    = par_fib seqThreshold n
  | otherwise = do
      v <- new
      gv <- glob v
      spark $(mkClosure [| dist_fib_abs (seqThreshold, parThreshold, n, gv) |])
      y <- dist_fib seqThreshold parThreshold (n - 2)
      clo_x <- get v
      force $ unClosure clo_x + y
  where k = max 1 seqThreshold
        l = parThreshold

dist_fib_abs :: (Int, Int, Int, GIVar (Closure Integer)) -> Thunk (Par ())
dist_fib_abs (seqThreshold, parThreshold, n, gv) =
  Thunk $ dist_fib seqThreshold parThreshold (n - 1) >>=
          force >>=
          rput gv . toClosure

-- / parallel Fibonacci; distributed memory; using sparking d-n-c skeleton

spark_skel_fib :: Int -> Int -> Par Integer
spark_skel_fib seqThreshold n = unClosure <$> skel (toClosure n)
  where 
    skel = parDivideAndConquer
             $(mkClosure [| dnc_trivial_abs (seqThreshold) |])
             $(mkClosure [| dnc_decompose |])
             $(mkClosure [| dnc_combine |])
             $(mkClosure [| dnc_f |])

dnc_trivial_abs :: Int -> Thunk (Closure Int -> Bool)
dnc_trivial_abs (seqThreshold) =
  Thunk $ \ clo_n -> unClosure clo_n <= max 1 seqThreshold

dnc_decompose =
  \ clo_n -> let n = unClosure clo_n in [toClosure (n-1), toClosure (n-2)]

dnc_combine =
  \ _ clos -> toClosure $ sum $ map unClosure clos

dnc_f =
  \ clo_n -> toClosure <$> (force $ fib $ unClosure clo_n)

--  / parallel Fibonacci; distributed memory; using pushing d-n-c skeleton

push_skel_fib :: [Node] -> Int -> Int -> Par Integer
push_skel_fib nodes seqThreshold n = unClosure <$> skel (toClosure n)
  where 
    skel = pushDivideAndConquer
             nodes
             $(mkClosure [| dnc_trivial_abs (seqThreshold) |])
             $(mkClosure [| dnc_decompose |])
             $(mkClosure [| dnc_combine |])
             $(mkClosure [| dnc_f |])

