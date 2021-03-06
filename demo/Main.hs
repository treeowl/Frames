{-# LANGUAGE BangPatterns, DataKinds, TemplateHaskell #-}
{-# LANGUAGE FlexibleContexts, TypeOperators #-}
module Main where
import Data.Functor.Identity
import Frames
import Lens.Micro
import qualified ListT as L
import qualified Pipes as P
import qualified Pipes.Prelude as P

tableTypes "Row" "data/data1.csv"

listTlist :: Monad m => L.ListT m a -> m [a]
listTlist = L.toList

tbl :: IO [Row]
tbl = listTlist $ readTable' "data/data1.csv"

ageDoubler :: (Age ∈ rs) => Record rs -> Record rs
ageDoubler = age %~ (* 2)

tbl2 :: IO [Row]
tbl2 = listTlist $ readTable' "data/data2.csv"

tbl2a :: IO [ColFun Maybe Row]
tbl2a = P.toListM $ readTableMaybe "data/data2.csv"

{-

REPL examples:

λ> tbl >>= mapM_ print
{name :-> "joe", age :-> 21}
{name :-> "sue", age :-> 23}
{name :-> "bob", age :-> 44}
{name :-> "laura", age :-> 18}

λ> tbl2 >>= mapM_ print
{name :-> "joe", age :-> 21}
{name :-> "sue", age :-> 23}
{name :-> "laura", age :-> 18}

λ> tbl2a >>= mapM_ (putStrLn . showRecF)
{Just (name :-> "joe"), Just (age :-> 21)}
{Just (name :-> "sue"), Just (age :-> 23)}
{Just (name :-> "bob"), Nothing}
{Just (name :-> "laura"), Just (age :-> 18)}

-}

-- Sample data from http://support.spatialkey.com/spatialkey-sample-csv-data/
-- Note: We have to replace carriage returns (\r) with line feed
-- characters (\n) for the text library's line parsing to work.
tableTypes "Ins" "data/FL2.csv"

insuranceTbl :: P.Producer Ins IO ()
insuranceTbl = readTable "data/FL2.csv"

insMaybe :: P.Producer (ColFun Maybe Ins) IO ()
insMaybe = readTableMaybe "data/FL2.csv"

type TinyIns = Record [PolicyID, PointLatitude, PointLongitude]

main :: IO ()
main = do itbl <- inCore $ P.for insuranceTbl (P.yield . rcast)
            :: IO (P.Producer TinyIns Identity ())
          putStrLn "In-core representation prepared"
          let Identity (n,sumLat) =
                P.fold (\ !(!i,!s) r -> (i+1, s+rget pointLatitude r))
                       (0::Int,0)
                       id
                       itbl
          putStrLn $ "Considering " ++ show n ++ " records..."
          putStrLn $ "Average latitude: " ++ show (sumLat / fromIntegral n)
          let Identity sumLong =
                P.fold (\ !s r -> (s + rget pointLongitude r)) 0 id itbl
          putStrLn $ "Average longitude: " ++ show (sumLong / fromIntegral n)
