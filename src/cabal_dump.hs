module Main where

import Control.Monad (when)
import Data.List (intercalate)
import qualified Data.Set as S
import qualified Distribution.Compiler as D
import qualified Distribution.Package as D
import qualified Distribution.PackageDescription as D
import qualified Distribution.PackageDescription.Configuration as D
import qualified Distribution.PackageDescription.Parse as D
import qualified Distribution.System as D
import qualified Distribution.Verbosity as D
import System.Environment (getArgs)
import System.Exit (exitFailure)
import System.IO (hPutStr, hPutStrLn, stderr)
import System.Info (compilerVersion)




readGenPkgDesc :: FilePath -> IO D.GenericPackageDescription
readGenPkgDesc = D.readPackageDescription D.silent


pkgName :: D.GenericPackageDescription -> String
pkgName genPkgDesc = name
  where
    D.PackageName name = D.packageName genPkgDesc


finalizePkgDesc ::
     D.GenericPackageDescription
  -> Either [D.Dependency] (D.PackageDescription, D.FlagAssignment)
finalizePkgDesc =
    D.finalizePackageDescription
      []
      (const True)
      D.buildPlatform
      (D.CompilerId D.buildCompilerFlavor compilerVersion)
      []


readPkgDesc :: FilePath -> IO D.PackageDescription
readPkgDesc pkgFile = do
    genPkgDesc <- readGenPkgDesc pkgFile
    case finalizePkgDesc genPkgDesc of
      Right (pkgDesc, _flags) -> return pkgDesc
      Left errDeps -> do
        hPutStrLn stderr $
             "-----> ERROR: Unexpected missing deps for "
          ++ show (pkgName genPkgDesc)
          ++ ": "
          ++ intercalate ", " (map depPkgName errDeps)
        exitFailure


libExeBuildInfo :: D.PackageDescription -> [D.BuildInfo]
libExeBuildInfo pkgDesc =
       [D.libBuildInfo lib | Just lib <- [D.library pkgDesc]]
    ++ [D.buildInfo exe    | exe      <- D.executables pkgDesc]


allBuildInfo :: D.PackageDescription -> [D.BuildInfo]
allBuildInfo pkgDesc =
       [D.libBuildInfo lib         | Just lib <- [D.library pkgDesc]]
    ++ [D.buildInfo exe            | exe      <- D.executables pkgDesc]
    ++ [D.testBuildInfo test       | test     <- D.testSuites pkgDesc]
    ++ [D.benchmarkBuildInfo bench | bench    <- D.benchmarks pkgDesc]


depPkgName :: D.Dependency -> String
depPkgName (D.Dependency (D.PackageName name) _) = name


sortUnique :: Ord a => [a] -> [a]
sortUnique = S.toAscList . S.fromList


buildDeps :: [D.BuildInfo] -> [String]
buildDeps = sortUnique . map depPkgName . concatMap D.targetBuildDepends


buildTools :: [D.BuildInfo] -> [String]
buildTools = sortUnique . map depPkgName . concatMap D.buildTools


extraLibs :: [D.BuildInfo] -> [String]
extraLibs = sortUnique . concatMap D.extraLibs


frameworks :: [D.BuildInfo] -> [String]
frameworks = sortUnique . concatMap D.frameworks


pkgconfigDeps :: [D.BuildInfo] -> [String]
pkgconfigDeps = sortUnique . map depPkgName . concatMap D.pkgconfigDepends




main :: IO ()
main = do
    args <- getArgs
    case args of
      [pkgFile, flag] -> do
        pkgDesc <- readPkgDesc pkgFile
        let info = libExeBuildInfo pkgDesc
        results <- case flag of
          "--build-depends-only"     -> return (buildDeps info)
          "--build-tools-only"       -> return (buildTools info)
          "--extra-libs-only"        -> return (extraLibs info)
          "--frameworks-only"        -> return (frameworks info)
          "--pkgconfig-depends-only" -> return (pkgconfigDeps info)
          _ -> die ("-----> ERROR: Unexpected flag: " ++ flag)
        when (not (null results)) $
          putStr (unlines results)
      _ -> die "-----> ERROR: Expected args: package_file flag"
  where
    die msg = do
        hPutStrLn stderr msg
        hPutStr stderr $ unlines $
          [ "-----> Expected flags:"
          , "       --build-depends-only"
          , "       --build-tools-only"
          , "       --extra-libs-only"
          , "       --frameworks-only"
          , "       --pkgconfig-depends-only"
          ]
        exitFailure
