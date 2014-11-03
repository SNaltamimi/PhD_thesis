-- / Euler's totient function (for positive integers)

totient :: Int -> Integer
totient n = toInteger $ length $ filter (\ k -> gcd n k == 1) [1 .. n]

-- / sequential sum of totients

sum_totient :: [Int] -> Integer
sum_totient = sum . map totient

-- / parallel sum of totients; shared memory

par_sum_totient_chunked :: Int -> Int -> Int -> Par Integer
par_sum_totient_chunked lower upper chunksize =
  sum <$> (mapM get =<< (mapM fork_sum_euler $ chunked_list))
    where
      chunked_list = chunk chunksize [upper, upper - 1 .. lower] :: [[Int]]


par_sum_totient_sliced :: Int -> Int -> Int -> Par Integer
par_sum_totient_sliced lower upper slices =
  sum <$> (mapM get =<< (mapM fork_sum_euler $ sliced_list))
    where
      sliced_list = slice slices [upper, upper - 1 .. lower] :: [[Int]]


fork_sum_euler :: [Int] -> Par (IVar Integer)
fork_sum_euler xs = do v <- new
                       fork $ force (sum_totient xs) >>= put v
                       return v

-- / parallel sum of totients; distributed memory

dist_sum_totient_chunked :: Int -> Int -> Int -> Par Integer
dist_sum_totient_chunked lower upper chunksize = do
  sum <$> (mapM get_and_unClosure =<< (mapM spark_sum_euler $ chunked_list))
    where
      chunked_list = chunk chunksize [upper, upper - 1 .. lower] :: [[Int]]


dist_sum_totient_sliced :: Int -> Int -> Int -> Par Integer
dist_sum_totient_sliced lower upper slices = do
  sum <$> (mapM get_and_unClosure =<< (mapM spark_sum_euler $ sliced_list))
    where
      sliced_list = slice slices [upper, upper - 1 .. lower] :: [[Int]]


spark_sum_euler :: [Int] -> Par (IVar (Closure Integer))
spark_sum_euler xs = do 
  v <- new
  gv <- glob v
  spark $(mkClosure [| spark_sum_euler_abs (xs, gv) |])
  return v

spark_sum_euler_abs :: ([Int], GIVar (Closure Integer)) -> Thunk (Par ())
spark_sum_euler_abs (xs, gv) =
  Thunk $ force (sum_totient xs) >>= rput gv . toClosure

get_and_unClosure :: IVar (Closure a) -> Par a
get_and_unClosure = return . unClosure <=< get

-- / parallel sum of totients; distributed memory (using plain task farm)

farm_sum_totient_chunked :: Int -> Int -> Int -> Par Integer
farm_sum_totient_chunked lower upper chunksize =
  sum <$> parMapNF $(mkClosure [| sum_totient |]) chunked_list
    where
      chunked_list = chunk chunksize [upper, upper - 1 .. lower] :: [[Int]]


farm_sum_totient_sliced :: Int -> Int -> Int -> Par Integer
farm_sum_totient_sliced lower upper slices =
  sum <$> parMapNF $(mkClosure [| sum_totient |]) sliced_list
    where
      sliced_list = slice slices [upper, upper - 1 .. lower] :: [[Int]]

-- / parallel sum of totients; distributed memory (chunking/slicing task farms)

chunkfarm_sum_totient :: Int -> Int -> Int -> Par Integer
chunkfarm_sum_totient lower upper chunksize =
  sum <$> parMapChunkedNF chunksize $(mkClosure [| totient |]) list
    where
      list = [upper, upper - 1 .. lower] :: [Int]


slicefarm_sum_totient :: Int -> Int -> Int -> Par Integer
slicefarm_sum_totient lower upper slices =
  sum <$> parMapSlicedNF slices $(mkClosure [| totient |]) list
    where
      list = [upper, upper - 1 .. lower] :: [Int]

