module Morphir.KafkaStreams.Backend exposing (..)



import Dict exposing (Dict)

import Morphir.File.FileMap exposing (FileMap)

import Morphir.IR.AccessControlled as AccessControlled exposing (AccessControlled)
import Morphir.IR.Distribution as Distribution exposing (Distribution)
import Morphir.IR.Documented exposing (Documented)
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
    | UnknownType
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

                            -- generate Scala types (eg, case classes etc)
                            typeMembers : List (Scala.Annotated Scala.MemberDecl)
                            typeMembers = accessControlledModuleDef.value.types
                                                    |> Dict.toList
                                                    |> List.concatMap
                                                        (\types ->
                                                            mapTypeMember types
                                                        )

                            -- generate Scala function
                            functionMembers : List (Scala.Annotated Scala.MemberDecl)
                            functionMembers = accessControlledModuleDef.value.values
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

                            object : Scala.TypeDecl
                            object =
                                Scala.Object
                                    { modifiers = []
                                    , name = programName
                                    , extends = []
                                    , members = List.append typeMembers functionMembers
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

mapTypeMember : ( Name, AccessControlled (Documented (Type.Definition ta)) ) -> List (Scala.Annotated Scala.MemberDecl)
mapTypeMember (typeName, accessControlledDocumentedTypeDef) =
    case accessControlledDocumentedTypeDef.value.value of
        Type.TypeAliasDefinition typeParams (Type.Record _ fields) ->
            [ Scala.withoutAnnotation
                (Scala.MemberTypeDecl
                    (Scala.Class
                            { modifiers = [ Scala.Final, Scala.Case ]
                            , name = typeName |> Name.toTitleCase
                            , typeArgs = []
                            , ctorArgs =
                                 fields
                                    |> List.map
                                        (\( field ) ->
                                            { modifiers = []
                                            , tpe = mapType field.tpe
                                            , name = field.name |> Name.toCamelCase
                                            , defaultValue = Nothing
                                            }
                                        )
                                    |> List.singleton
                            , extends = []
                            , members = []
                            , body = []
                            }
                    )
                )
             ]

        other ->
            let
                _= Debug.log "ERROR -- Kafka Streams; skipping unknown custom type: " other
            in
            []

mapType : Type a -> Scala.Type
mapType tpe =
    case tpe of
        Type.Variable a name ->
            Scala.TypeVar (name |> Name.toTitleCase)

        Type.Reference a fQName argTypes ->
            let
                typeRef = Scala.TypeRef [] (FQName.getLocalName fQName |> Name.toTitleCase)
            in
            if List.isEmpty argTypes then
                typeRef

            else
                Scala.TypeApply typeRef (argTypes |> List.map mapType)

        Type.Tuple a elemTypes ->
            Scala.TupleType (elemTypes |> List.map mapType)

        Type.Record a fields ->
            Scala.StructuralType
                (fields
                    |> List.map
                        (\field ->
                            Scala.FunctionDecl
                                { modifiers = []
                                , name = Common.mapValueName field.name
                                , typeArgs = []
                                , args = []
                                , returnType = Just (mapType field.tpe)
                                , body = Nothing
                                }
                        )
                )

        Type.ExtensibleRecord a argName fields ->
            Scala.StructuralType
                (fields
                    |> List.map
                        (\field ->
                            Scala.FunctionDecl
                                { modifiers = []
                                , name = Common.mapValueName field.name
                                , typeArgs = []
                                , args = []
                                , returnType = Just (mapType field.tpe)
                                , body = Nothing
                                }
                        )
                )

        Type.Function a argType returnType ->
            Scala.FunctionType (mapType argType) (mapType returnType)

        Type.Unit a ->
            Scala.TypeRef [ "scala" ] "Unit"


mapFunctionDefinition: Distribution -> FQName -> Result Error Scala.MemberDecl
mapFunctionDefinition ir ((_, _, functionName) as fullyQualifiedFunctionName) =
    let
        _= Debug.log "Compiling Function " (Name.toCamelCase functionName)

        mapValueType : List ( Name, va, Type () ) -> Type ()
        mapValueType inputTypes =
            inputTypes
               |> List.map
                   (\(_, _, argType) ->
                       case argType of
                            Type.Reference _ ( [ [ "morphir" ], [ "s", "d", "k" ] ], [ [ "list" ] ], [ "list" ] ) [ valueType ] ->
                                valueType

                            other -> (Type.Unit ())
                   )
               |> List.head
               |> Maybe.withDefault (Type.Unit ())

        mapFunctionInputs : List ( Name, va, Type () ) -> Result Error (List Scala.ArgDecl)
        mapFunctionInputs inputTypes =
            inputTypes
                |> List.map
                    (\( argName, _, argType ) ->
                        -- we only support List type which maps to a KStream
                        -- could we support Set type by mapppin it to a KTable (?)
                        case argType of
                            Type.Reference _ ( [ [ "morphir" ], [ "s", "d", "k" ] ], [ [ "list" ] ], [ "list" ] ) [ valueType ] ->
                                Ok
                                    { modifiers = []
                                    , tpe = (KafkaStreams.kStream (mapType valueType))
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
                    let
                        valueType : Type ()
                        valueType = mapValueType functionDef.inputTypes
                    in
                    Result.map2
                        (\scalaArgs scalaFunctionBody ->
                            Scala.FunctionDecl
                                { modifiers = []
                                , name = functionName |> Name.toCamelCase
                                , typeArgs = []
                                , args = [ scalaArgs ]
                                , returnType = Just (KafkaStreams.kStream (mapType valueType))
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
    let
        _= Debug.log "debug: " expression
    in
    case expression of
        Literal literal ->
            mapLiteral literal |> Scala.Literal

        Variable name ->
            Scala.Variable name

        Field fieldName ->
            KafkaStreams.field (Scala.Variable "test") fieldName

        Lambda parameter body ->
            -- we hard-code Kafka Streams' kv-pair
            --   key is unused (as _)
            --   value variable name is taken from original Elm program
            Scala.Lambda [("_", Nothing), (Name.toCamelCase parameter, Nothing)] (mapExpressionWithVar body parameter)


        BinaryOperation simpleExpression leftExpr rightExpr ->
            Scala.BinOp
                (mapExpression leftExpr)
                simpleExpression
                (mapExpression rightExpr)

mapExpressionWithVar : Expression -> Name -> Scala.Value
mapExpressionWithVar expression lambdaVariable =
    let
        _= Debug.log "debug: " expression
    in
    case expression of
        Literal literal ->
            mapLiteral literal |> Scala.Literal

        Variable name ->
            Scala.Variable name

        Field fieldName ->
            KafkaStreams.field (Scala.Variable (Name.toCamelCase lambdaVariable)) fieldName

        Lambda parameter body ->
            -- we hard-code Kafka Streams' kv-pair
            --   key is unused (as _)
            --   value variable name is taken from original Elm program
            Scala.Lambda [("_", Nothing), (Name.toCamelCase parameter, Nothing)] (mapExpressionWithVar body parameter)


        BinaryOperation simpleExpression leftExpr rightExpr ->
            Scala.BinOp
                (mapExpressionWithVar leftExpr lambdaVariable)
                simpleExpression
                (mapExpressionWithVar rightExpr lambdaVariable)

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
