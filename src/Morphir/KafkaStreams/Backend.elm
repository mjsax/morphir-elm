module Morphir.KafkaStreams.Backend exposing (..)



import Dict exposing (Dict)

import Morphir.File.FileMap exposing (FileMap)

import Morphir.IR.AccessControlled as AccessControlled exposing (AccessControlled)
import Morphir.IR.Distribution as Distribution exposing (Distribution)
import Morphir.IR.FQName as FQName exposing (FQName, getLocalName)
import Morphir.IR.Literal exposing (Literal(..))
import Morphir.IR.Module as Module exposing (ModuleName)
import Morphir.IR.Name as Name exposing (Name)
import Morphir.IR.Type as Type exposing (Type)
import Morphir.IR.Path as Path exposing (Path)
import Morphir.IR.Value as Value exposing (TypedValue)

import Morphir.KafkaStreams.API as KafkaStreams
import Morphir.KafkaStreams.AST as KafkaStreamsAST exposing(..)

import Morphir.Scala.AST as Scala
import Morphir.Scala.Common as Common
import Morphir.Scala.PrettyPrinter as PrettyPrinter

import Morphir.SDK.ResultList as ResultList



type alias Options =
    {}

type Error
    = FunctionNotFound FQName
    | UnknownArgumentType (Type ())
    | MappingError KafkaStreamsAST.Error



mapDistribution : Options -> Distribution -> FileMap
mapDistribution _ ir =
   case ir of
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

                            object : Scala.TypeDecl
                            object =
                                Scala.Object
                                    { modifiers = []
                                    , name = programName 
                                    , extends = []
                                    , members = accessControlledModuleDef.value.values
                                                    |> Dict.toList
                                                    |> List.filterMap
                                                        (\( valueName, _ ) ->
                                                            case mapFunctionDefinition ir (packageName, moduleName, valueName) of
                                                                Ok memberDecl -> Just (Scala.withoutAnnotation memberDecl)
                                                                Err err ->
                                                                    let
                                                                        _= Debug.log "CRASH -- Kafka Streams: " err
                                                                    in
                                                                        Nothing
                                                        )

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


mapFunctionDefinition: Distribution -> FQName -> Result Error Scala.MemberDecl
mapFunctionDefinition ir ((_, _, functionName) as fullyQualifiedFunctionName) =
    let
        _= Debug.log "Compiling Function " (Name.toCamelCase functionName)

        mapFunctionInputs : List ( Name, va, Type () ) -> Result Error (List Scala.ArgDecl)
        mapFunctionInputs inputTypes =
            inputTypes
                |> List.map
                    (\( argName, _, argType ) ->
                        -- we only support List type which maps to a KStream
                        -- could we support Set type by mapppin it to a KTable (?)
                        case argType of
                            Type.Reference _ ( [ [ "morphir" ], [ "s", "d", "k" ] ], [ [ "list" ] ], [ "list" ] ) [ _ ] ->
                                Ok
                                    { modifiers = []
                                    , tpe = KafkaStreams.kStream
                                    , name = Name.toCamelCase argName
                                    , defaultValue = Nothing
                                    }

                            other -> Err (UnknownArgumentType other)
                    )
                |> ResultList.keepFirstError

        mapFunctionBody : TypedValue -> Result Error Scala.Value
        mapFunctionBody ast =
            ast
                |> KafkaStreamsAST.objectExpressionFromValue ir
                |> Result.mapError MappingError
                |> Result.andThen mapObjectExpressionToScala
    in
        ir
            |> Distribution.lookupValueDefinition fullyQualifiedFunctionName
            |> Result.fromMaybe (FunctionNotFound fullyQualifiedFunctionName)
            |> Result.andThen
                (\functionDef ->
                    Result.map2
                        (\scalaArgs scalaFunctionBody ->
                            Scala.FunctionDecl
                                { modifiers = []
                                , name = functionName |> Name.toCamelCase
                                , typeArgs = []
                                , args = [ scalaArgs ]
                                , returnType = Just KafkaStreams.kStream
                                , body = Just scalaFunctionBody
                                }
                        )
                        (mapFunctionInputs functionDef.inputTypes)
                        (mapFunctionBody functionDef.body)
                )
 
mapObjectExpressionToScala : ObjectExpression -> Result Error Scala.Value
mapObjectExpressionToScala objectExpression =
    case objectExpression of
        From name ->
            Name.toCamelCase name |> Scala.Variable |> Ok

        Filter predicate inputKStream ->
            mapObjectExpressionToScala inputKStream
                |> Result.map
                    (KafkaStreams.streamFilter
                        (mapExpression predicate)
                    )

mapExpression : Expression -> Scala.Value
mapExpression expression =
    case expression of
        Literal literal ->
            mapLiteral literal |> Scala.Literal

        Lambda parameter body ->
            -- we hard-code Kafka Streams' kv-pair
            --   key is unused (as _)
            --   value variable name is taken from original Elm program
            Scala.Lambda [("_", Nothing), (Name.toCamelCase parameter, Nothing)] (mapExpression body)

mapLiteral : Literal -> Scala.Lit
mapLiteral l =
    case l of
        BoolLiteral bool ->
            Scala.BooleanLit bool

        CharLiteral char ->
            Scala.CharacterLit char

        StringLiteral string ->
            Scala.StringLit string

        WholeNumberLiteral int ->
            Scala.IntegerLit int

        FloatLiteral float ->
            Scala.FloatLit float

        DecimalLiteral _ ->
            Debug.todo "branch 'DecimalLiteral _' not implemented"
