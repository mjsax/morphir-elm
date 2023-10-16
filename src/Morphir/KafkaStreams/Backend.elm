module Morphir.KafkaStreams.Backend exposing (..)

import Dict exposing (Dict)
import Morphir.File.FileMap exposing (FileMap)
import Morphir.IR.AccessControlled as AccessControlled exposing (AccessControlled)
import Morphir.IR.Distribution as Distribution exposing (Distribution)
import Morphir.IR.FQName as FQName exposing (FQName)
import Morphir.IR.Literal exposing (Literal(..))
import Morphir.IR.Module as Module exposing (ModuleName)
import Morphir.IR.Name as Name exposing (Name)
import Morphir.IR.Type as Type exposing (Type)
import Morphir.IR.Path as Path exposing (Path)
import Morphir.KafkaStreams.API as KafkaStreams
import Morphir.KafkaStreams.AST as KafkaStreamsAST exposing(..)
import Morphir.Scala.AST as Scala
import Morphir.Scala.Common as Common
import Morphir.Scala.PrettyPrinter as PrettyPrinter



type alias Options =
    {}

type Error
    = FunctionNotFound FQName
    | UnknownArgumentType (Type ())
    | MappingError KafkaStreamsAST.Error

mapDistribution : Options -> Distribution -> FileMap
mapDistribution _ distro =
    case distro of
        Distribution.Library packageName dependencies packageDef ->
            packageDef.modules
                |> Dict.toList
                |> List.map
                    (\( moduleName, accessControlledModuleDef ) ->
                        let
                            programName : String 
                            programName = 
                                moduleName
                                |> List.map (Name.toTitleCase)
                                |> String.concat

                            fileName : String 
                            fileName =
                                programName ++ ".scala"

                            _= Debug.log "Module Name / Program Name" programName

                            packagePath : List String
                            packagePath =
                                packageName
                                 |> List.map (Name.toCamelCase)

                            _= Debug.log "Package Path" (String.join "." packagePath)

                            memberDecl : Scala.MemberDecl
                            memberDecl = Scala.FunctionDecl
                                { modifiers = []
                                , name = (Common.mapValueName (Name.fromString "foo"))
                                , typeArgs = []
                                , args = []
                                , returnType = Just KafkaStreams.kStream
                                , body = Just (Scala.Literal (Scala.StringLit "bar"))
                                }

                            object : Scala.TypeDecl
                            object =
                                Scala.Object
                                    { modifiers = []
                                    , name = programName 
                                    , extends = []
                                    , members = accessControlledModuleDef.value.values
                                                    |> Dict.toList
                                                    |> List.filterMap
                                                        (\( valueName, _ ) -> Just (Scala.withoutAnnotation memberDecl))
                                    , body = Nothing
                                    }

                            compilationUnit : Scala.CompilationUnit
                            compilationUnit =
                                { dirPath = packagePath
                                , fileName = fileName
                                , packageDecl = packagePath
                                , imports = []
                                , typeDecls = [ Scala.Documented Nothing (Scala.withoutAnnotation object) ]
                                }
 
                        in
                            ( ( packagePath, fileName )
                            , PrettyPrinter.mapCompilationUnit (PrettyPrinter.Options 2 80) compilationUnit
                            )

                    )
                |> Dict.fromList

