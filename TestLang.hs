-- automatically generated by BNF Converter
module Main where

import System.IO ( stdin, hGetContents )
import System.Environment ( getArgs, getProgName )
import System.Exit ( exitFailure, exitSuccess )
import Control.Monad (when)
import qualified Data.Map as M
import qualified Data.Set as S

import Data.Sequence
import Data.Foldable
import Data.Maybe (fromJust)

import LexLang
import ParLang
import SkelLang
import PrintLang
import AbsLang
import ErrM

type ParseFun a = [Token] -> Err a

myLLexer = myLexer

type Verbosity = Int

putStrV :: Verbosity -> String -> IO ()
putStrV v s = when (v > 1) $ putStrLn s

runFile :: (Print a, Show a) => Verbosity -> ParseFun a -> FilePath -> IO ()
runFile v p f = putStrLn f >> readFile f >>= run v p

run :: (Print a, Show a) => Verbosity -> ParseFun a -> String -> IO ()
run v p s = let ts = myLLexer s in case p ts of
           Bad s    -> do putStrLn "\nParse              Failed...\n"
                          putStrV v "Tokens:"
                          putStrV v $ show ts
                          putStrLn s
                          exitFailure
           Ok  tree -> do putStrLn "\nParse Successful!"
                          showTree v tree

                          exitSuccess


showTree :: (Show a, Print a) => Int -> a -> IO ()
showTree v tree
 = do
      putStrV v $ "\n[Abstract Syntax]\n\n" ++ show tree
      putStrV v $ "\n[Linearized tree]\n\n" ++ printTree tree

usage :: IO ()
usage = do
  putStrLn $ unlines
    [ "usage: Call with one of the following argument combinations:"
    , "  --help          Display this help message."
    , "  (no arguments)  Parse stdin verbosely."
    , "  (files)         Parse content of files verbosely."
    , "  -s (files)      Silent mode. Parse content of files silently."
    ]
  exitFailure

main :: IO ()
main = do
  args <- getArgs
  if Prelude.length args <= 1
  then do
    putStrLn "bad usage"
    return ()
  else do
    let formulaFile = head args
        valueFiles = tail $ init args
        outputFile = last args
    formulas <- readFile formulaFile
    assignments <- traverse readFile valueFiles
    let alf = getExpAL formulas
        e = getITE alf
        alas = map (\s -> getAL' s (\x -> read x :: Int)) assignments
        rs = map (eval e . M.fromList) alas
        str = unlines $ map show rs
    writeFile outputFile str

getITE :: [(String,Exp)] -> Exp
getITE al = let mexp = M.fromList al
                order@(h:_) = Prelude.reverse $ map fst al
                Just e = M.lookup h mexp
            in loop order mexp e

loop :: [String] -> M.Map String Exp -> Exp -> Exp
loop [] m e = e
loop (v:vs) m e = loop vs m $ substitute e v $ ite' v s
  where Just s = M.lookup v m
        ite' x e = EAdd (EMul (EVar (Ident x)) e)
                       (ESub (EInt 1) (EVar (Ident x)))


fromIdent :: Ident -> String
fromIdent (Ident s) = s

-- return the variables that a expression depends on
getVariables :: Exp -> S.Set String
getVariables e = case e of
  EVar idt   -> S.singleton $ fromIdent idt
  EAdd e1 e2 -> getVariables e1 <> getVariables e2
  ESub e1 e2 -> getVariables e1 <> getVariables e2
  EMul e1 e2 -> getVariables e1 <> getVariables e2
  EDiv e1 e2 -> getVariables e1 <> getVariables e2
  EInt n     -> S.empty

-- substitute variable var with expression subs in expression e
substitute :: Exp -> String -> Exp -> Exp
substitute e var subs = case e of
  EVar idt | fromIdent idt == var -> subs
  EAdd e1 e2 -> EAdd (substitute e1 var subs) (substitute e2 var subs)
  ESub e1 e2 -> ESub (substitute e1 var subs) (substitute e2 var subs)
  EMul e1 e2 -> EMul (substitute e1 var subs) (substitute e2 var subs)
  EDiv e1 e2 -> EDiv (substitute e1 var subs) (substitute e2 var subs)
  _          -> e

eval :: Exp -> M.Map String Int -> Double
eval e m = case e of
  EAdd e1 e2 -> eval e1 m + eval e2 m
  ESub e1 e2 -> eval e1 m - eval e2 m
  EMul e1 e2 -> eval e1 m * eval e2 m
  EDiv e1 e2 -> eval e1 m / eval e2 m
  EInt n     -> fromIntegral n
  EVar (Ident s) -> case M.lookup s m of
                      Nothing -> error $ "Could not find variable " ++ s
                      Just n -> fromIntegral n

group :: Int -> [a] -> [[a]]
group n ls = map toList . toList $ chunksOf n s
  where s = fromList ls

getAL' :: String -> (String -> a) -> [(String, a)]
getAL' s f = map (\[s1,s2] -> (s1, f s2)) g
  where g = group 2 $ lines s

getAL :: String -> [(String, String)]
getAL s = getAL' s id

getExpAL :: String -> [(String,Exp)]
getExpAL s = getAL' s f
  where f = u . pExp . myLexer
        u (Ok e) = e
printAL :: [(String,Exp)] -> IO ()
printAL = putStrLn . unlines . map show
